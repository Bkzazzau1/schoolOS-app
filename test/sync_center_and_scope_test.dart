import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_scope.dart';
import 'package:schoolos_app/features/sync_center/presentation/sync_center_page.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

class _Runner implements SyncRunner {
  int rounds = 0;
  SyncRunSummary Function() answer = () =>
      const SyncRunSummary(attempted: 0, synced: 0, failed: 0, conflicts: 0);

  @override
  Future<SyncRunSummary> syncActiveSchool() async {
    rounds += 1;
    return answer();
  }
}

SyncRunSummary _got({int pulled = 0, int synced = 0}) => SyncRunSummary(
  attempted: synced,
  synced: synced,
  failed: 0,
  conflicts: 0,
  pulled: pulled,
);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with SyncRefresh<_Counter> {
  int reloads = 0;

  @override
  void onSynced() => setState(() => reloads++);

  @override
  Widget build(BuildContext context) => Text('reloads: $reloads');
}

void main() {
  late LocalDatabase db;
  late _Runner runner;
  late SyncCoordinator coordinator;

  setUp(() async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    runner = _Runner();
    coordinator = SyncCoordinator(
      runner: runner,
      observeLifecycle: false,
      interval: const Duration(minutes: 5),
      debounce: const Duration(milliseconds: 5),
    );
  });

  tearDown(() {
    coordinator.dispose();
    db.close();
  });

  Future<String> queue(
    WidgetTester tester,
    String entityId, {
    SyncOperation op = SyncOperation.create,
  }) async {
    return (await tester.runAsync(
      () => db.queueMutation(
        tenantId: teacher.schoolId,
        membershipId: teacher.id,
        entityType: 'school_event',
        entityId: entityId,
        operation: op,
        payload: {'id': entityId},
      ),
    ))!;
  }

  /// Timers made by the coordinator must be real ones, so it is started (and asked) in the real zone.
  Future<void> real(
    WidgetTester tester,
    FutureOr<void> Function() action,
  ) async {
    await tester.runAsync(() async {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pump();
  }

  /// Lets timers made in the test's own (fake) zone fire, then real work finish.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump();
  }

  void refuse(String id, String message) {
    db.markMutationSyncing(id);
    db.markMutationFailed(id, message);
  }

  Future<void> pumpCenter(WidgetTester tester, {bool withScope = true}) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = SyncCenterPage(localDatabase: db, membership: teacher);
    await tester.pumpWidget(
      MaterialApp(
        home: withScope
            ? SyncScope(coordinator: coordinator, child: page)
            : page,
      ),
    );
  }

  group('Sync Center', () {
    testWidgets('on demo data it says so and offers no sync', (tester) async {
      await tester.runAsync(db.initialize);
      await pumpCenter(tester, withScope: false);
      expect(find.text('Demo data'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('shows where syncing stands and syncs on request', (
      tester,
    ) async {
      await tester.runAsync(db.initialize);
      await pumpCenter(tester);
      expect(find.text('Not synced yet'), findsOneWidget);

      await real(tester, coordinator.start);
      expect(find.textContaining('Up to date · last synced'), findsOneWidget);
      final rounds = runner.rounds;

      await tester.tap(find.text('Sync now'));
      await settle(tester);
      expect(runner.rounds, greaterThan(rounds));
    });

    testWidgets('says when the device is offline, and when the sign-in ended', (
      tester,
    ) async {
      await tester.runAsync(db.initialize);
      await pumpCenter(tester);
      runner.answer = () => const SyncRunSummary(
        attempted: 1,
        synced: 0,
        failed: 0,
        conflicts: 0,
        stoppedOffline: true,
      );
      await real(tester, coordinator.start);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.textContaining('saved and will be sent'), findsOneWidget);

      runner.answer = () => const SyncRunSummary(
        attempted: 1,
        synced: 0,
        failed: 0,
        conflicts: 0,
        stoppedOffline: true,
        needsSignIn: true,
      );
      await real(tester, () {
        coordinator.stop();
        coordinator.start();
      });
      expect(find.text('Your sign-in has ended'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Sync now'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(
        button.onPressed,
        isNull,
      ); // nothing can be sent until they sign in again
    });

    testWidgets('lists what is waiting and what the school refused', (
      tester,
    ) async {
      await tester.runAsync(db.initialize);
      await queue(tester, 'WAITING');
      final refused = await queue(tester, 'REFUSED');
      refuse(refused, 'Only the owner can decide.');
      final conflicted = await queue(
        tester,
        'CONFLICT',
        op: SyncOperation.update,
      );
      refuse(
        conflicted,
        'SYNC_CONFLICT: This record changed on the server first.',
      );
      await pumpCenter(tester);

      expect(find.text('Waiting · 1'), findsOneWidget);
      expect(find.text('Failed · 1'), findsOneWidget);
      expect(find.text('Conflicts · 1'), findsOneWidget);
      expect(find.text('Only the owner can decide.'), findsOneWidget);
      expect(
        find.text('This record changed on the server first.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget); // only for a plain refusal
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text("Use school's version"), findsOneWidget);
    });

    testWidgets('retrying puts a refused change back and asks for a sync', (
      tester,
    ) async {
      await tester.runAsync(db.initialize);
      refuse(await queue(tester, 'REFUSED'), 'Only the owner can decide.');
      await real(tester, coordinator.start);
      final rounds = runner.rounds;
      await pumpCenter(tester);

      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Waiting · 1'), findsOneWidget);
      expect(find.text('Failed · 0'), findsOneWidget);
      expect(runner.rounds, greaterThan(rounds));
    });

    testWidgets(
      'discarding a conflict asks first, then uses the school\'s version',
      (tester) async {
        await tester.runAsync(db.initialize);
        await tester.runAsync(
          () => db.upsertLocalRecord(
            tenantId: teacher.schoolId,
            entityType: 'school_event',
            entityId: 'CONFLICT',
            payload: {'v': 'mine'},
            serverVersion: 2,
            isDirty: true,
          ),
        );
        refuse(
          await queue(tester, 'CONFLICT', op: SyncOperation.update),
          'SYNC_CONFLICT: This record changed on the server first.',
        );
        await pumpCenter(tester);

        await tester.tap(find.text("Use school's version"));
        await tester.pumpAndSettle();
        expect(find.text("Use the school's version?"), findsOneWidget);

        // Changing their mind changes nothing.
        await tester.tap(find.text('Keep it'));
        await tester.pumpAndSettle();
        expect(find.text('Conflicts · 1'), findsOneWidget);

        await tester.tap(find.text("Use school's version"));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(FilledButton, "Use the school's version"),
        );
        await tester.pumpAndSettle();
        expect(find.text('Conflicts · 0'), findsOneWidget);
        expect(find.text('No local changes are waiting'), findsOneWidget);
        final record = await tester.runAsync(
          () => db.getLocalRecord(
            tenantId: teacher.schoolId,
            entityType: 'school_event',
            entityId: 'CONFLICT',
          ),
        );
        expect(record!.isDirty, isFalse);
      },
    );

    testWidgets('the list refreshes by itself as syncing goes on', (
      tester,
    ) async {
      await tester.runAsync(db.initialize);
      final id = await queue(tester, 'A');
      await pumpCenter(tester);
      expect(find.text('Waiting · 1'), findsOneWidget);

      // The change is sent and confirmed while the screen is open.
      db.markMutationSyncing(id);
      db.markMutationSynced(id, serverVersion: 1);
      runner.answer = () => _got(synced: 1);
      await real(tester, coordinator.start);
      expect(find.text('Waiting · 0'), findsOneWidget);
    });
  });

  group('SyncScope and SyncRefresh', () {
    testWidgets(
      'a screen reloads when a round sent or brought in changes, not after an idle round',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SyncScope(coordinator: coordinator, child: const _Counter()),
          ),
        );
        expect(find.text('reloads: 0'), findsOneWidget);

        await real(tester, coordinator.start);
        expect(
          find.text('reloads: 0'),
          findsOneWidget,
        ); // an idle round changes nothing

        runner.answer = () => _got(pulled: 2);
        await real(tester, () => coordinator.requestSync(immediately: true));
        expect(find.text('reloads: 1'), findsOneWidget);

        runner.answer = () => _got(synced: 1);
        await real(tester, () => coordinator.requestSync(immediately: true));
        expect(find.text('reloads: 2'), findsOneWidget);
      },
    );

    testWidgets(
      'without a coordinator (demo data) nothing happens and nothing breaks',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: _Counter()));
        expect(find.text('reloads: 0'), findsOneWidget);
      },
    );

    testWidgets('a screen that is gone stops listening', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SyncScope(coordinator: coordinator, child: const _Counter()),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SyncScope(coordinator: coordinator, child: const SizedBox()),
        ),
      );
      runner.answer = () => _got(pulled: 1);
      await real(tester, coordinator.start);
      expect(tester.takeException(), isNull);
    });
  });
}
