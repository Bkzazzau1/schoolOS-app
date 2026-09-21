import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/app.dart';
import 'package:schoolos_app/app/app_services.dart';
import 'package:schoolos_app/features/authentication/presentation/login_page.dart';
import 'package:schoolos_app/core/access/access_controller.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/notifications/notifications_controller.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/invitations/domain/invitation_link.dart';
import 'package:schoolos_app/features/invitations/presentation/invitation_accept_page.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_server_api.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const _secret = 'Zx9-pQ4_mK2vL8nR5tY7uW3aB6cD1eF0gH2jI4kO';

const teacher = SchoolMembership(
  id: '11111111-1111-1111-1111-111111111111',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.driver,
);

const _joined = {'id': 'm-9', 'schoolId': 's-9', 'schoolName': 'BrightGate', 'role': 'driver'};

const _me = {'id': 'u-1', 'email': 'musa@school.ng', 'name': 'Musa Ibrahim', 'memberships': [_joined]};

Map<String, Object?> _preview({bool exists = false}) => {
      'schoolName': 'BrightGate',
      'staffName': 'Musa Ibrahim',
      'email': 'm***@school.ng',
      'expiresAt': '2026-10-04T09:00:00Z',
      'accountExists': exists,
    };

Map<String, Object?> _accepted() => {
      'access': 'a-1',
      'refresh': 'r-1',
      'membership': _joined,
      'staffId': 'STAFF-1',
    };

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) return Future<LocalRecord?>.value(null);
    if (invocation.memberName == #getLocalRecords) return Future<List<LocalRecord>>.value([]);
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}

class _Services implements AppServices {
  _Services(this.auth, this.schoolSession);

  @override
  final AuthRepository? auth;
  @override
  final SchoolSessionController schoolSession;
  @override
  final localDatabase = _Database();
  @override
  late final schoolAppearance = SchoolAppearanceController(localDatabase: localDatabase, schoolSession: schoolSession);
  @override
  final apiConfig = testConfig;
  @override
  final SyncEngine? syncEngine = null;
  @override
  final SyncCoordinator? syncCoordinator = null;
  @override
  final AccessController? access = null;
  @override
  final NotificationsController? notifications = null;
  @override
  final OwnerAccessRepository? ownerAccess = null;
  @override
  final StaffServerApi? staffServer = null;
  @override
  bool get usesBackend => true;

  final began = <String>[];

  @override
  Future<void> beginSchool(SchoolMembership membership) async => began.add(membership.id);

  @override
  Future<void> endSession() async {}

  /// Fields added to AppServices later are optional; a fake answers null for them.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('reading a link', () {
    test('finds the secret in a whole link, part of one, or on its own', () {
      expect(invitationTokenFrom('https://brightgate.schoolos.ng/invite/$_secret/'), _secret);
      expect(invitationTokenFrom('  http://school.example.ng/invite/$_secret  '), _secret);
      expect(invitationTokenFrom('/invite/$_secret/'), _secret);
      expect(invitationTokenFrom('https://x.ng/invite/$_secret/?utm=1#top'), _secret);
      expect(invitationTokenFrom(_secret), _secret);
      expect(invitationTokenFrom('$_secret/'), _secret);
    });

    test('anything else is not an invitation', () {
      for (final bad in [
        '', '   ', 'hello', 'short-secret', 'https://example.com/', 'https://x.ng/other/$_secret',
        'https://x.ng/invite/registration/', 'https://x.ng/invite/', 'not a link at all really',
        'https://x.ng/invite/has spaces in it here/',
      ]) {
        expect(invitationTokenFrom(bad), isNull, reason: bad);
      }
    });
  });

  group('AuthRepository and invitations', () {
    late MemoryTokenStore tokens;
    late SchoolSessionController session;

    AuthRepository repo(FakeServer server) {
      tokens = MemoryTokenStore();
      session = SchoolSessionController(store: FakeSessionStore());
      return AuthRepository(api: apiFor(server, tokens: tokens), tokens: tokens, schoolSession: session);
    }

    test('the preview needs no sign-in and shows only what the link is for', () async {
      final server = FakeServer((r) async => jsonResponse(_preview()));
      final preview = await repo(server).previewInvitation(_secret);
      expect(server.requests.single.url.path, endsWith('/invitations/$_secret/'));
      expect(server.requests.single.headers.containsKey('Authorization'), isFalse);
      expect((preview.schoolName, preview.staffName, preview.maskedEmail, preview.accountExists), ('BrightGate', 'Musa Ibrahim', 'm***@school.ng', false));
    });

    test('a new account chooses a password and is signed in, with the school it joined', () async {
      final server = FakeServer((r) async => r.url.path.endsWith('/accept/') ? jsonResponse(_accepted()) : jsonResponse(_me));
      final accepted = await repo(server).acceptInvitation(_secret, firstName: ' Musa ', lastName: 'Ibrahim', password: 'a-good-long-password-1');
      final sent = server.to('/accept/').single;
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(body(sent), {'firstName': 'Musa', 'lastName': 'Ibrahim', 'password': 'a-good-long-password-1'});
      expect((tokens.tokens!.access, tokens.tokens!.refresh), ('a-1', 'r-1'));
      expect((accepted.membership.id, accepted.membership.role, accepted.staffId), ('m-9', SchoolRole.driver, 'STAFF-1'));
      expect(session.memberships.map((m) => m.id), ['m-9']);
    });

    test('an existing account signs in first, and the link is then accepted as that account', () async {
      final server = FakeServer((r) async {
        final path = r.url.path;
        if (path.endsWith('/auth/token/')) return jsonResponse({'access': 'a-0', 'refresh': 'r-0'});
        if (path.endsWith('/accept/')) return jsonResponse(_accepted());
        return jsonResponse(_me);
      });
      final accepted = await repo(server).acceptInvitationWithAccount(_secret, email: 'Musa@School.ng', password: 'my-password');
      expect(body(server.to('/auth/token/').single), {'email': 'musa@school.ng', 'password': 'my-password'});
      expect(server.to('/accept/').single.headers['Authorization'], 'Bearer a-0');       // signed in as themselves
      expect(body(server.to('/accept/').single), isEmpty);
      expect(accepted.membership.id, 'm-9');
    });

    test('the server\'s refusals keep their codes', () async {
      for (final (code, status) in [('invitation_invalid', 404), ('already_accepted', 409), ('already_linked', 409), ('wrong_account', 403)]) {
        final server = FakeServer((r) async => jsonResponse({'code': code, 'message': 'x'}, status));
        await expectLater(repo(server).previewInvitation(_secret), throwsA(isA<ApiException>().having((e) => e.code, 'code', code)));
      }
    });

    test('a wrong password for an existing account stops before any acceptance', () async {
      final server = FakeServer((r) async => jsonResponse({'detail': 'No active account found'}, 401));
      await expectLater(repo(server).acceptInvitationWithAccount(_secret, email: 'a@b.ng', password: 'x'), throwsA(isA<ApiException>()));
      expect(server.to('/accept/'), isEmpty);
      expect(tokens.tokens, isNull);
    });
  });

  group('the accept page', () {
    late MemoryTokenStore tokens;
    late SchoolSessionController session;
    late _Services services;

    Future<FakeServer> open(WidgetTester tester, Future<dynamic> Function(dynamic request) handler, {String? link}) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = FakeServer((r) async => await handler(r));
      tokens = MemoryTokenStore();
      session = SchoolSessionController(store: FakeSessionStore());
      services = _Services(AuthRepository(api: apiFor(server, tokens: tokens), tokens: tokens, schoolSession: session), session);
      await tester.pumpWidget(MaterialApp(home: InvitationAcceptPage(services: services, initialLink: link)));
      await tester.pumpAndSettle();
      return server;
    }

    Future<void> pasteAndContinue(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField).first, text);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }

    Future<void> fillNewAccount(WidgetTester tester, {String first = 'Musa', String last = 'Ibrahim', String password = 'a-good-long-password-1', String? again}) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), first);
      await tester.enterText(fields.at(1), last);
      await tester.enterText(fields.at(2), password);
      await tester.enterText(fields.at(3), again ?? password);
    }

    Future<dynamic> normal(dynamic r, {bool exists = false, Object? acceptAnswer, int acceptStatus = 200}) async {
      final path = (r as dynamic).url.path as String;
      if (path.endsWith('/accept/')) return jsonResponse(acceptAnswer ?? _accepted(), acceptStatus);
      if (path.contains('/invitations/')) return jsonResponse(_preview(exists: exists));
      if (path.endsWith('/auth/token/')) return jsonResponse({'access': 'a-0', 'refresh': 'r-0'});
      return jsonResponse(_me);
    }

    testWidgets('something that is not a link is refused without asking the server', (tester) async {
      final server = await open(tester, normal);
      await pasteAndContinue(tester, 'hello there');
      expect(find.textContaining('does not look like an invitation link'), findsOneWidget);
      expect(server.requests, isEmpty);
    });

    testWidgets('a link the server does not accept says it may have expired', (tester) async {
      await open(tester, (r) async => jsonResponse({'code': 'invitation_invalid', 'message': 'This link is not valid.'}, 404));
      await pasteAndContinue(tester, 'https://x.ng/invite/$_secret/');
      expect(find.textContaining('may have expired or been replaced'), findsOneWidget);
    });

    testWidgets('a link that was already used points to signing in', (tester) async {
      await open(tester, (r) async => jsonResponse({'code': 'already_accepted', 'message': 'x'}, 409));
      await pasteAndContinue(tester, _secret);
      expect(find.textContaining('already used'), findsOneWidget);
    });

    testWidgets('no signal is explained', (tester) async {
      await open(tester, (r) async => throw const ApiOfflineException());
      await pasteAndContinue(tester, _secret);
      expect(find.textContaining('Could not reach SchoolOS'), findsOneWidget);
    });

    testWidgets('a good link shows who it is for, and a link the app was opened with is checked straight away', (tester) async {
      await open(tester, normal, link: 'https://x.ng/invite/$_secret/');
      expect(find.text('BrightGate invited you'), findsOneWidget);
      expect(find.textContaining('Musa Ibrahim · m***@school.ng'), findsOneWidget);
      expect(find.text('Create my account'), findsOneWidget);
    });

    testWidgets('a new account is checked before anything is sent', (tester) async {
      final server = await open(tester, normal);
      await pasteAndContinue(tester, _secret);
      final before = server.requests.length;

      await fillNewAccount(tester, first: '');
      await tester.tap(find.text('Create my account'));
      await tester.pump();
      expect(find.text('Enter your first and last name.'), findsOneWidget);

      await fillNewAccount(tester, password: 'short');
      await tester.tap(find.text('Create my account'));
      await tester.pump();
      expect(find.textContaining('at least 8 characters'), findsOneWidget);

      await fillNewAccount(tester, again: 'different-password-9');
      await tester.tap(find.text('Create my account'));
      await tester.pump();
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      expect(server.requests.length, before);                     // nothing was sent
    });

    testWidgets('accepting creates the account and opens the school\'s workspace', (tester) async {
      final server = await open(tester, normal);
      await pasteAndContinue(tester, _secret);
      await fillNewAccount(tester);
      await tester.tap(find.text('Create my account'));
      await tester.pumpAndSettle();

      expect(body(server.to('/accept/').single)['password'], 'a-good-long-password-1');
      expect(services.began, ['m-9']);                            // syncing began for that school
      expect(session.activeMembership!.id, 'm-9');
      expect(find.byType(InvitationAcceptPage), findsNothing);    // replaced by the driver workspace
      expect(find.byTooltip('Driver menu'), findsOneWidget);
    });

    testWidgets('a weak password shows the server\'s reasons', (tester) async {
      await open(tester, (r) async => normal(r, acceptAnswer: {
            'code': 'invalid_password', 'message': 'Password is not strong enough.',
            'details': ['This password is too common.', 'This password is entirely numeric.'],
          }, acceptStatus: 400));
      await pasteAndContinue(tester, _secret);
      await fillNewAccount(tester, password: '12345678');
      await tester.tap(find.text('Create my account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('too common. This password is entirely numeric.'), findsOneWidget);
      expect(find.byType(InvitationAcceptPage), findsOneWidget);
    });

    testWidgets('an email that already has an account signs in instead of choosing a password', (tester) async {
      final server = await open(tester, (r) async => normal(r, exists: true));
      await pasteAndContinue(tester, _secret);
      expect(find.text('Sign in and join'), findsOneWidget);
      expect(find.text('First name'), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), 'musa@school.ng');
      await tester.enterText(find.byType(TextField).at(1), 'my-password');
      await tester.tap(find.text('Sign in and join'));
      await tester.pumpAndSettle();
      expect(server.to('/auth/token/').length, 1);
      expect(server.to('/accept/').single.headers['Authorization'], 'Bearer a-0');
      expect(find.byTooltip('Driver menu'), findsOneWidget);
    });

    testWidgets('the wrong account, or wrong details, are said plainly', (tester) async {
      await open(tester, (r) async {
        final path = (r as dynamic).url.path as String;
        if (path.endsWith('/accept/')) return jsonResponse({'code': 'wrong_account', 'message': 'x'}, 403);
        return normal(r, exists: true);
      });
      await pasteAndContinue(tester, _secret);
      await tester.enterText(find.byType(TextField).at(0), 'other@school.ng');
      await tester.enterText(find.byType(TextField).at(1), 'pw');
      await tester.tap(find.text('Sign in and join'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not the one this invitation was sent to'), findsOneWidget);
    });

    testWidgets('wrong sign-in details for an existing account give one plain message', (tester) async {
      await open(tester, (r) async {
        final path = (r as dynamic).url.path as String;
        if (path.endsWith('/auth/token/')) return jsonResponse({'detail': 'No active account found'}, 401);
        return normal(r, exists: true);
      });
      await pasteAndContinue(tester, _secret);
      await tester.enterText(find.byType(TextField).at(0), 'musa@school.ng');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(find.text('Sign in and join'));
      await tester.pumpAndSettle();
      expect(find.text('The email or password is not correct.'), findsOneWidget);
    });

    testWidgets('"Use a different link" goes back to the start', (tester) async {
      await open(tester, normal);
      await pasteAndContinue(tester, _secret);
      await tester.tap(find.text('Use a different link'));
      await tester.pumpAndSettle();
      expect(find.text('Paste the link from your invitation email.'), findsOneWidget);
    });
  });

  group('opening the app from a link', () {
    late _Services services;

    Future<void> start(WidgetTester tester, {String? link, bool signedIn = false}) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = FakeServer((r) async => jsonResponse(_preview()));
      final tokens = MemoryTokenStore();
      final session = SchoolSessionController(store: FakeSessionStore());
      if (signedIn) {
        await session.setMemberships([teacher]);
        await session.selectSchool(teacher);
      }
      services = _Services(AuthRepository(api: apiFor(server, tokens: tokens), tokens: tokens, schoolSession: session), session);
      await tester.pumpWidget(SchoolOsApp(services: services, initialInvitationLink: link));
      await tester.pumpAndSettle();
    }

    testWidgets('someone who is not signed in lands on the accept page with the link already checked', (tester) async {
      await start(tester, link: 'https://x.ng/invite/$_secret/');
      expect(find.byType(InvitationAcceptPage), findsOneWidget);
      expect(find.text('BrightGate invited you'), findsOneWidget);
    });

    testWidgets('without a link, the login screen', (tester) async {
      await start(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('I have an invitation link'), findsOneWidget);
    });

    testWidgets('someone already signed in is not pulled away from their school by a link', (tester) async {
      await start(tester, link: 'https://x.ng/invite/$_secret/', signedIn: true);
      expect(find.byType(InvitationAcceptPage), findsNothing);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('the login screen opens the accept page from its own button', (tester) async {
      await start(tester);
      await tester.tap(find.text('I have an invitation link'));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationAcceptPage), findsOneWidget);
      expect(find.text('Paste the link from your invitation email.'), findsOneWidget);
    });
  });
}
