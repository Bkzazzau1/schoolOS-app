import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/app_services.dart';
import 'package:schoolos_app/app/sync_status_banner.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/authentication/presentation/login_page.dart';
import 'package:schoolos_app/features/school_switcher/presentation/school_selection_page.dart';

import 'core/backend_test_support.dart';

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) {
      return Future<LocalRecord?>.value(null);
    }
    if (invocation.memberName == #getLocalRecords) {
      return Future<List<LocalRecord>>.value([]);
    }
    return super.noSuchMethod(invocation);
  }
}

class _Runner implements SyncRunner {
  int rounds = 0;
  @override
  Future<SyncRunSummary> syncActiveSchool() async {
    rounds += 1;
    return const SyncRunSummary(
      attempted: 0,
      synced: 0,
      failed: 0,
      conflicts: 0,
    );
  }
}

class _BackendServices implements AppServices {
  _BackendServices(this.auth, this.syncCoordinator, this.schoolSession);

  @override
  final AuthRepository? auth;
  @override
  final SyncCoordinator? syncCoordinator;
  @override
  final SchoolSessionController schoolSession;
  @override
  final localDatabase = _Database();
  @override
  late final schoolAppearance = SchoolAppearanceController(
    localDatabase: localDatabase,
    schoolSession: schoolSession,
  );
  @override
  final apiConfig = testConfig;
  @override
  final SyncEngine? syncEngine = null;
  @override
  bool get usesBackend => true;
}

const _twoSchools = {
  'id': 'u-1',
  'email': 'musa@school.ng',
  'name': 'Musa',
  'memberships': [
    {
      'id': 'm-1',
      'schoolId': 's-1',
      'schoolName': 'BrightGate',
      'role': 'teacher',
    },
    {'id': 'm-2', 'schoolId': 's-2', 'schoolName': 'Other', 'role': 'parent'},
  ],
};

void main() {
  late MemoryTokenStore tokens;
  late SchoolSessionController session;
  late _Runner runner;
  late SyncCoordinator coordinator;

  _BackendServices services(FakeServer server) {
    final auth = AuthRepository(
      api: apiFor(server, tokens: tokens),
      tokens: tokens,
      schoolSession: session,
    );
    return _BackendServices(auth, coordinator, session);
  }

  setUp(() {
    tokens = MemoryTokenStore();
    session = SchoolSessionController(store: FakeSessionStore());
    runner = _Runner();
    coordinator = SyncCoordinator(
      runner: runner,
      observeLifecycle: false,
      interval: const Duration(minutes: 5),
    );
  });

  tearDown(() => coordinator.dispose());

  Future<void> pumpLogin(WidgetTester tester, _BackendServices s) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginPage(services: s)));
  }

  Future<void> signInWith(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('login with a backend', () {
    testWidgets('asks for an email and shows no demo panel', (tester) async {
      await pumpLogin(
        tester,
        services(FakeServer((r) async => jsonResponse({}))),
      );
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Try the demo'), findsNothing);
      expect(find.textContaining('Demo mode'), findsNothing);
    });

    testWidgets('wrong details show one plain message and go nowhere', (
      tester,
    ) async {
      final server = FakeServer(
        (r) async => jsonResponse({'detail': 'No active account found'}, 401),
      );
      await pumpLogin(tester, services(server));
      await signInWith(tester, 'musa@school.ng', 'wrong');
      expect(
        find.text('The email or password is not correct.'),
        findsOneWidget,
      );
      expect(find.byType(SchoolSelectionPage), findsNothing);
      expect(runner.rounds, 0);
    });

    testWidgets('no signal says so', (tester) async {
      final server = FakeServer((r) async => throw const ApiOfflineException());
      await pumpLogin(tester, services(server));
      await signInWith(tester, 'musa@school.ng', 'a-good-password');
      expect(find.textContaining('Could not reach SchoolOS'), findsOneWidget);
    });

    testWidgets('an email is required before anything is sent', (tester) async {
      final server = FakeServer((r) async => jsonResponse({}));
      await pumpLogin(tester, services(server));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('someone with no school yet is told so and is signed out', (
      tester,
    ) async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('auth/token/')) {
          return jsonResponse({'access': 'a', 'refresh': 'r'});
        }
        return jsonResponse({..._twoSchools, 'memberships': []});
      });
      await pumpLogin(tester, services(server));
      await signInWith(tester, 'musa@school.ng', 'a-good-password');
      expect(
        find.textContaining('not connected to any school yet'),
        findsOneWidget,
      );
      expect(tokens.tokens, isNull);
    });

    testWidgets('a person with two schools is offered both', (tester) async {
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('auth/token/')) {
          return jsonResponse({'access': 'a', 'refresh': 'r'});
        }
        return jsonResponse(_twoSchools);
      });
      await pumpLogin(tester, services(server));
      await signInWith(tester, 'Musa@School.ng', 'a-good-password');
      await tester.pumpAndSettle();
      expect(find.byType(SchoolSelectionPage), findsOneWidget);
      expect(find.text('BrightGate'), findsWidgets);
      expect(find.text('Other'), findsWidgets);
      expect(tokens.tokens, isNotNull);
    });
  });

  group('the sync banner', () {
    Future<void> pumpBanner(WidgetTester tester, VoidCallback onSignIn) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SyncStatusBanner(
            coordinator: coordinator,
            onSignInAgain: onSignIn,
            child: const Scaffold(body: Text('the app')),
          ),
        ),
      );
    }

    testWidgets('shows nothing when all is well', (tester) async {
      await pumpBanner(tester, () {});
      expect(find.text('the app'), findsOneWidget);
      expect(find.textContaining('offline'), findsNothing);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('says the work is safe when offline', (tester) async {
      runner = _Runner();
      final offline = SyncCoordinator(
        runner: _OfflineRunner(),
        observeLifecycle: false,
        firstBackoff: const Duration(minutes: 5),
      );
      addTearDown(offline.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SyncStatusBanner(
            coordinator: offline,
            onSignInAgain: () {},
            child: const Scaffold(body: Text('the app')),
          ),
        ),
      );
      await tester.runAsync(() async {
        offline.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.textContaining('You are offline'), findsOneWidget);
      expect(find.text('the app'), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('offers to sign in again when the sign-in ended', (
      tester,
    ) async {
      var tapped = 0;
      final ended = SyncCoordinator(
        runner: _SignedOutRunner(),
        observeLifecycle: false,
      );
      addTearDown(ended.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SyncStatusBanner(
            coordinator: ended,
            onSignInAgain: () => tapped++,
            child: const Scaffold(body: Text('the app')),
          ),
        ),
      );
      await tester.runAsync(() async {
        ended.start();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.textContaining('sign-in has ended'), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      expect(tapped, 1);
    });
  });
}

class _OfflineRunner implements SyncRunner {
  @override
  Future<SyncRunSummary> syncActiveSchool() async => const SyncRunSummary(
    attempted: 1,
    synced: 0,
    failed: 0,
    conflicts: 0,
    stoppedOffline: true,
  );
}

class _SignedOutRunner implements SyncRunner {
  @override
  Future<SyncRunSummary> syncActiveSchool() async => const SyncRunSummary(
    attempted: 1,
    synced: 0,
    failed: 0,
    conflicts: 0,
    stoppedOffline: true,
    needsSignIn: true,
  );
}
