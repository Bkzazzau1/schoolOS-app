import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/auth_repository.dart';
import 'package:schoolos_app/core/auth/token_store.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/sync/sync_coordinator.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';

import 'backend_test_support.dart';

SyncRunSummary summary({
  int synced = 0,
  int pulled = 0,
  bool offline = false,
  bool signIn = false,
  bool lost = false,
  String? error,
}) => SyncRunSummary(
  attempted: synced,
  synced: synced,
  failed: 0,
  conflicts: 0,
  pulled: pulled,
  stoppedOffline: offline || signIn,
  needsSignIn: signIn,
  accessLost: lost,
  pullError: error,
);

class FakeRunner implements SyncRunner {
  final answers = <Object Function()>[];
  Object Function() fallback = () => summary();
  int rounds = 0;
  Completer<void>? hold;

  @override
  Future<SyncRunSummary> syncActiveSchool() async {
    rounds += 1;
    if (hold != null) await hold!.future;
    final answer = (answers.isNotEmpty ? answers.removeAt(0) : fallback)();
    if (answer is SyncRunSummary) return answer;
    throw answer;
  }
}

const tick = Duration(milliseconds: 10);
Future<void> pause([int ms = 80]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeRunner runner;
  SyncCoordinator? coordinator;

  SyncCoordinator make({
    AuthRepository? auth,
    Duration interval = const Duration(seconds: 30),
    Duration first = const Duration(milliseconds: 30),
    Duration max = const Duration(milliseconds: 100),
  }) {
    return coordinator = SyncCoordinator(
      runner: runner,
      auth: auth,
      interval: interval,
      debounce: tick,
      firstBackoff: first,
      maxBackoff: max,
      observeLifecycle: false,
    );
  }

  setUp(() => runner = FakeRunner());
  tearDown(() => coordinator?.dispose());

  test('starting runs a round at once and notes when it finished', () async {
    runner.fallback = () => summary(synced: 2, pulled: 1);
    final sync = make()..start();
    await pause();
    expect(runner.rounds, 1);
    expect(sync.status, SyncStatus.idle);
    expect(sync.lastSyncedAt, isNotNull);
    expect(sync.changes, 1);
    expect(sync.lastSummary!.synced, 2);
  });

  test('a round that found nothing does not count as a change', () async {
    final sync = make()..start();
    await pause();
    expect((sync.changes, sync.status), (0, SyncStatus.idle));
  });

  test('a burst of requests is one round', () async {
    final sync = make()..start();
    await pause();
    for (var i = 0; i < 6; i++) {
      sync.requestSync();
    }
    await pause();
    expect(runner.rounds, 2);
  });

  test(
    'a change queued during a round makes another round follow it',
    () async {
      runner.hold = Completer<void>();
      final sync = make()..start();
      await pause();
      expect(runner.rounds, 1);
      expect(sync.status, SyncStatus.syncing);
      sync.requestSync();
      await pause();
      expect(runner.rounds, 1); // never two at once
      runner.hold!.complete();
      await pause();
      expect(runner.rounds, 2);
      expect(sync.status, SyncStatus.idle);
    },
  );

  test('the timer keeps it going', () async {
    make(interval: const Duration(milliseconds: 40)).start();
    await pause(220);
    expect(runner.rounds, greaterThanOrEqualTo(3));
  });

  group('when the server cannot be reached', () {
    test(
      'it says so, keeps trying with longer gaps, and recovers by itself',
      () async {
        runner.answers.addAll([
          () => summary(offline: true),
          () => summary(offline: true),
          () => summary(offline: true),
        ]);
        final sync = make()..start();
        await pause(20);
        expect(sync.status, SyncStatus.offline);
        expect(sync.message, contains('offline'));
        await pause(400);
        expect(runner.rounds, greaterThanOrEqualTo(4));
        expect(
          sync.status,
          SyncStatus.idle,
        ); // the fourth round found the server
        expect(sync.message, isNull);
      },
    );

    test('the gaps grow to a limit', () async {
      runner.fallback = () => summary(offline: true);
      make(
        first: const Duration(milliseconds: 20),
        max: const Duration(milliseconds: 60),
      ).start();
      final marks = <int>[];
      final watch = Stopwatch()..start();
      var seen = 0;
      while (marks.length < 5 && watch.elapsedMilliseconds < 1500) {
        await pause(2);
        if (runner.rounds > seen) {
          seen = runner.rounds;
          marks.add(watch.elapsedMilliseconds);
        }
      }
      final gaps = [
        for (var i = 1; i < marks.length; i++) marks[i] - marks[i - 1],
      ];
      expect(gaps.length, greaterThanOrEqualTo(3));
      expect(
        gaps.last,
        greaterThan(gaps.first),
      ); // 20ms, 40ms, then held at 60ms
      expect(gaps.every((g) => g < 200), isTrue);
    });

    test('coming back to the front of the app tries at once', () async {
      runner.answers.add(() => summary(offline: true));
      final sync = make(first: const Duration(seconds: 30))..start();
      await pause();
      expect((runner.rounds, sync.status), (1, SyncStatus.offline));
      sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pause();
      expect((runner.rounds, sync.status), (2, SyncStatus.idle));
    });

    test(
      'an offline error thrown from inside is treated the same way',
      () async {
        runner.answers.add(() => const ApiOfflineException());
        final sync = make(first: const Duration(seconds: 30))..start();
        await pause();
        expect(sync.status, SyncStatus.offline);
      },
    );
  });

  group('when the sign-in has ended', () {
    test(
      'it stops sending, says so, and resumes when the person signs in again',
      () async {
        runner.answers.add(() => summary(signIn: true));
        final sync = make(interval: const Duration(milliseconds: 30))..start();
        await pause();
        expect(sync.status, SyncStatus.needsSignIn);
        expect(sync.message, contains('Sign in again'));
        final rounds = runner.rounds;
        sync.requestSync(immediately: true);
        await pause(150);
        expect(runner.rounds, rounds); // no more rounds, not even on the timer

        sync.start(); // the person signed in again
        await pause();
        expect(sync.status, SyncStatus.idle);
        expect(runner.rounds, greaterThan(rounds));
      },
    );

    test('a session that ends inside a round is caught too', () async {
      runner.answers.add(() => const SessionExpiredException());
      final sync = make()..start();
      await pause();
      expect(sync.status, SyncStatus.needsSignIn);
    });
  });

  group('when the person no longer belongs to the school', () {
    test(
      'it asks the server which schools are left, then stops and says so',
      () async {
        final tokens = MemoryTokenStore()
          ..tokens = const AuthTokens(access: 'a', refresh: 'r');
        final session = SchoolSessionController(store: FakeSessionStore());
        await session.setMemberships([teacher]);
        await session.selectSchool(teacher);
        final server = FakeServer(
          (r) async => jsonResponse({
            'id': 'u',
            'email': 'a@b.ng',
            'name': '',
            'memberships': [],
          }),
        );
        final auth = AuthRepository(
          api: apiFor(server, tokens: tokens),
          tokens: tokens,
          schoolSession: session,
        );

        runner.answers.add(() => summary(lost: true));
        final sync = make(auth: auth)..start();
        await pause();
        expect(sync.status, SyncStatus.lostAccess);
        expect(sync.message, contains('no longer have access'));
        expect(server.to('me/').length, 1);
        expect(session.activeMembership, isNull);
        final rounds = runner.rounds;
        await pause(60);
        expect(runner.rounds, rounds);
      },
    );
  });

  group('when something goes wrong', () {
    test('no school chosen yet is not an error', () async {
      runner.answers.add(
        () => StateError('No active school membership is selected.'),
      );
      final sync = make()..start();
      await pause();
      expect(sync.status, SyncStatus.idle);
    });

    test(
      'an unexpected problem is shown, and the next round tries again',
      () async {
        runner.answers.add(() => Exception('boom'));
        final sync = make(interval: const Duration(milliseconds: 40))..start();
        await pause(20);
        expect(sync.status, SyncStatus.error);
        expect(sync.message, contains('will try again'));
        await pause(120);
        expect(sync.status, SyncStatus.idle);
      },
    );

    test(
      'a download that failed for a reason other than being offline is reported',
      () async {
        runner.answers.add(
          () => summary(
            synced: 1,
            error: 'The server sent an unexpected answer.',
          ),
        );
        final sync = make()..start();
        await pause();
        expect(
          (sync.status, sync.message),
          (SyncStatus.error, 'The server sent an unexpected answer.'),
        );
      },
    );
  });

  test('stopping ends everything, and it can be started again', () async {
    final sync = make(interval: const Duration(milliseconds: 30))..start();
    await pause(50);
    sync.stop();
    final rounds = runner.rounds;
    sync.requestSync(immediately: true);
    await pause(120);
    expect(runner.rounds, rounds);
    sync.start();
    await pause();
    expect(runner.rounds, greaterThan(rounds));
  });

  test('screens can listen for changes', () async {
    runner.fallback = () => summary(pulled: 3);
    final sync = make();
    var heard = 0;
    sync.addListener(() => heard++);
    sync.start();
    await pause();
    expect(heard, greaterThan(0));
    expect(sync.changes, 1);
  });
}
