import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_controller.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/notifications/notifications_controller.dart';
import 'package:schoolos_app/core/sync/round_follow_up.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_scope.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/presentation/driver_workspace_page.dart';
import 'package:schoolos_app/features/notifications/presentation/notifications_bell.dart';
import 'package:schoolos_app/features/notifications/presentation/notifications_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const driver = SchoolMembership(
  id: '44444444-4444-4444-4444-444444444444',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.driver,
);

Map<String, Object?> _access(List<String> activities, {List<Map<String, Object?>> blocking = const []}) => {
      'membershipId': driver.id,
      'role': 'driver',
      'activities': activities,
      'blocking': blocking,
    };

Map<String, Object?> _note(int id, {bool read = false}) => {
      'id': id,
      'kind': 'access_changed',
      'title': 'Title $id',
      'message': 'Message $id',
      'data': <String, Object?>{},
      'createdAt': '2026-09-21T08:00:00Z',
      'read': read,
    };

class _Unsent implements UnsentWork {
  bool unsent = false;
  @override
  Future<bool> hasUnsentChanges(String tenantId) async => unsent;
}

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) return Future<LocalRecord?>.value(null);
    if (invocation.memberName == #getLocalRecords) return Future<List<LocalRecord>>.value([]);
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}

const _quiet = SyncRunSummary(attempted: 0, synced: 0, failed: 0, conflicts: 0);

void main() {
  late MemorySyncStore store;
  setUp(() => store = MemorySyncStore());

  group('after a sync round', () {
    late FakeServer server;
    late AccessController access;
    late NotificationsController notifications;
    late _Unsent unsent;
    late RoundFollowUp followUp;
    var access0 = _access(['driver.dashboard', 'driver.riders']);
    var inboxFails = false;
    var accessFails = false;

    setUp(() {
      access0 = _access(['driver.dashboard', 'driver.riders']);
      inboxFails = accessFails = false;
      server = FakeServer((r) async {
        final path = r.url.path;
        if (path.endsWith('/notifications/')) {
          if (inboxFails) throw const ApiOfflineException();
          return jsonResponse({'unread': 1, 'notifications': [_note(1)]});
        }
        if (path.endsWith('/acknowledge/')) return jsonResponse(_access(['driver.dashboard']));
        if (path.endsWith('/access/me/')) {
          if (accessFails) throw const ApiOfflineException();
          return jsonResponse(access0);
        }
        return jsonResponse({});
      });
      final api = apiFor(server);
      access = AccessController(api: api, store: store);
      notifications = NotificationsController(api: api, store: store);
      unsent = _Unsent();
      followUp = RoundFollowUp(access: access, notifications: notifications, unsent: unsent, activeMembership: () => driver);
    });

    test('reads what the person may use and their inbox', () async {
      await followUp(_quiet);
      expect(access.allows('driver.riders'), isTrue);
      expect(access.allows('driver.route'), isFalse);
      expect(notifications.unread, 1);
      expect(server.to('/acknowledge/'), isEmpty);
    });

    test('a waiting block is acknowledged once nothing is left unsent', () async {
      access0 = _access(['driver.dashboard', 'driver.riders'], blocking: [
        {'activity': 'driver.riders', 'finalizeAt': '2026-09-23T00:00:00Z'},
      ]);
      await followUp(_quiet);
      expect(body(server.to('/acknowledge/').single), {'activities': ['driver.riders']});
      expect(access.allows('driver.riders'), isFalse);        // it took effect
      expect(access.blocking, isEmpty);
    });

    test('a waiting block is left alone while work is still unsent, so nothing is lost', () async {
      access0 = _access(['driver.dashboard', 'driver.riders'], blocking: [
        {'activity': 'driver.riders', 'finalizeAt': '2026-09-23T00:00:00Z'},
      ]);
      unsent.unsent = true;
      await followUp(_quiet);
      expect(server.to('/acknowledge/'), isEmpty);
      expect(access.allows('driver.riders'), isTrue);          // still theirs until it is sent
    });

    test('a problem with the inbox does not stop access from updating, and the other way round', () async {
      inboxFails = true;
      await followUp(_quiet);
      expect(access.known, isTrue);
      expect(notifications.unread, 0);

      inboxFails = false;
      accessFails = true;
      await followUp(_quiet);
      expect(notifications.unread, 1);
    });

    test('with no school chosen it does nothing', () async {
      final none = RoundFollowUp(access: access, notifications: notifications, unsent: unsent, activeMembership: () => null);
      await none(_quiet);
      expect(server.requests, isEmpty);
    });
  });

  group('the coordinator runs the follow-up', () {
    test('after a round that reached the server, not after one that could not', () async {
      var followUps = 0;
      final answers = <SyncRunSummary>[
        const SyncRunSummary(attempted: 1, synced: 0, failed: 0, conflicts: 0, stoppedOffline: true),
        _quiet,
      ];
      final coordinator = SyncCoordinator(
        runner: _Runner(() => answers.isEmpty ? _quiet : answers.removeAt(0)),
        observeLifecycle: false,
        firstBackoff: const Duration(milliseconds: 20),
        interval: const Duration(minutes: 5),
        afterRound: (_) async => followUps++,
      );
      addTearDown(coordinator.dispose);
      coordinator.start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(followUps, 0);                       // offline: nothing to follow up
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(followUps, 1);
    });

    test('a failing follow-up never stops syncing', () async {
      final coordinator = SyncCoordinator(
        runner: _Runner(() => _quiet),
        observeLifecycle: false,
        interval: const Duration(minutes: 5),
        afterRound: (_) async => throw StateError('boom'),
      );
      addTearDown(coordinator.dispose);
      coordinator.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(coordinator.status, SyncStatus.idle);
    });
  });

  group('menus follow the owner\'s decisions', () {
    late AccessController access;
    late SchoolSessionController session;

    setUp(() async {
      access = AccessController(api: apiFor(FakeServer((r) async => jsonResponse(_access(const [])))), store: store);
      session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships([driver]);
      await session.selectSchool(driver);
    });

    Future<void> pumpDriver(WidgetTester tester, {AccessController? withAccess}) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = _Database();
      Widget app = MaterialApp(
        home: DriverWorkspacePage(
          membership: driver,
          localDatabase: db,
          schoolSession: session,
          schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
        ),
      );
      if (withAccess != null) app = AccessScope(access: withAccess, child: app);
      await tester.pumpWidget(app);
      await tester.pump();
    }

    Future<void> openDrawerMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Driver menu'));
      await tester.pumpAndSettle();
    }

    testWidgets('until access is known every screen is offered', (tester) async {
      await pumpDriver(tester, withAccess: access);
      await openDrawerMenu(tester);
      for (final label in ['Morning Run', 'Riders', 'Route & Stops', 'Vehicle Check']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('only the screens the owner allows are offered, and it redraws when that changes', (tester) async {
      await tester.runAsync(() async {
        final server = FakeServer((r) async => jsonResponse(_access(['driver.dashboard', 'driver.morning'])));
        access = AccessController(api: apiFor(server), store: store);
        await access.refresh(driver);
      });
      await pumpDriver(tester, withAccess: access);
      await openDrawerMenu(tester);
      expect(find.text('Morning Run'), findsWidgets);
      expect(find.text('Riders'), findsNothing);
      expect(find.text('Vehicle Check'), findsNothing);

      // The owner gives them Riders; the next sync brings it, and the open menu redraws.
      await tester.runAsync(() async {
        final server = FakeServer((r) async => jsonResponse(_access(['driver.dashboard', 'driver.morning', 'driver.riders'])));
        final next = AccessController(api: apiFor(server), store: store);
        await next.refresh(driver);
        await access.restore(driver);
      });
      await tester.pumpAndSettle();
      expect(find.text('Riders'), findsWidgets);
      expect(find.text('Vehicle Check'), findsNothing);
    });

    testWidgets('nothing changes on demo data (no access controller)', (tester) async {
      await pumpDriver(tester);
      await openDrawerMenu(tester);
      expect(find.text('Riders'), findsWidgets);
    });
  });

  group('the inbox', () {
    late NotificationsController notifications;

    Future<void> load(WidgetTester tester, List<Map<String, Object?>> notes, {int unread = 2}) async {
      final server = FakeServer((r) async => r.method == 'GET'
          ? jsonResponse({'unread': unread, 'notifications': notes})
          : jsonResponse({'ok': true}));
      notifications = NotificationsController(api: apiFor(server), store: store);
      await tester.runAsync(() => notifications.refresh(driver));
    }

    Future<void> pumpBell(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: NotificationsScope(
          notifications: notifications,
          child: Scaffold(appBar: AppBar(actions: const [NotificationsBell(membership: driver)])),
        ),
      ));
    }

    testWidgets('the bell shows the unread count and opens the inbox', (tester) async {
      await load(tester, [_note(2), _note(1)]);
      await pumpBell(tester);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications · 2 unread'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Title 2'), findsOneWidget);
      expect(find.text('Message 1'), findsOneWidget);
    });

    testWidgets('there is no bell on demo data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NotificationsBell(membership: driver))));
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('opening a message marks it read and lowers the count', (tester) async {
      await load(tester, [_note(2), _note(1)]);
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(notifications: notifications, membership: driver)));
      expect(find.byIcon(Icons.circle), findsNWidgets(2));
      await tester.runAsync(() async {
        await tester.tap(find.text('Title 2'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(notifications.unread, 1);
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('mark all read clears every dot and the button goes away', (tester) async {
      await load(tester, [_note(2), _note(1)]);
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(notifications: notifications, membership: driver)));
      await tester.runAsync(() async {
        await tester.tap(find.text('Mark all read'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(notifications.unread, 0);
      expect(find.byIcon(Icons.circle), findsNothing);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('an empty inbox says so', (tester) async {
      await load(tester, [], unread: 0);
      await tester.pumpWidget(MaterialApp(home: NotificationsPage(notifications: notifications, membership: driver)));
      expect(find.text('No notifications'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });
  });
}

class _Runner implements SyncRunner {
  _Runner(this.next);
  final SyncRunSummary Function() next;
  @override
  Future<SyncRunSummary> syncActiveSchool() async => next();
}
