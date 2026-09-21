import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/core/sync/http_sync_transport.dart';
import 'package:schoolos_app/core/sync/sync_engine.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/sync/sync_puller.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';

import 'backend_test_support.dart';

/// The outbox, in memory. Only what the engine touches is implemented.
class FakeOutbox implements LocalDatabase {
  final queue = <SyncMutation>[];
  final status = <String, String>{};
  final errors = <String, String>{};
  final versions = <String, int?>{};

  void add(
    String id, {
    String type = 'school_event',
    SyncOperation op = SyncOperation.create,
  }) {
    queue.add(
      SyncMutation(
        id: id,
        tenantId: teacher.schoolId,
        membershipId: teacher.id,
        entityType: type,
        entityId: id,
        operation: op,
        payload: {'id': id},
        createdAt: DateTime.utc(2026, 9, 21),
        status: SyncMutationStatus.pending,
      ),
    );
    status[id] = 'pending';
  }

  @override
  Future<List<SyncMutation>> pendingMutations({
    required String tenantId,
    int limit = 50,
  }) async =>
      queue.where((m) => status[m.id] == 'pending').take(limit).toList();

  @override
  void markMutationSyncing(String id) => status[id] = 'syncing';

  @override
  void markMutationPending(String id) => status[id] = 'pending';

  @override
  void markMutationSynced(String id, {int? serverVersion}) {
    status[id] = 'synced';
    versions[id] = serverVersion;
  }

  @override
  void markMutationFailed(String id, String error) {
    status[id] = 'failed';
    errors[id] = error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SchoolSessionController> signedInSession() async {
  final session = SchoolSessionController(store: FakeSessionStore());
  await session.setMemberships([teacher]);
  await session.selectSchool(teacher);
  return session;
}

void main() {
  late FakeOutbox outbox;
  late MemorySyncStore store;

  setUp(() {
    outbox = FakeOutbox();
    store = MemorySyncStore();
  });

  Future<SyncEngine> engine(FakeServer server, {bool pull = true}) async {
    final api = apiFor(server);
    return SyncEngine(
      localDatabase: outbox,
      schoolSession: await signedInSession(),
      transport: HttpSyncTransport(api),
      puller: pull ? SyncPuller(api: api, store: store) : null,
    );
  }

  Response respond(Object body, [int status = 200]) =>
      jsonResponse(body, status);

  test('sends what is queued, then downloads what changed', () async {
    outbox.add('m1');
    outbox.add('m2');
    final server = FakeServer((r) async {
      if (r.url.path.endsWith('sync/push/')) {
        return jsonResponse({
          'disposition': 'accepted',
          'serverVersion': 1,
          'message': '',
        });
      }
      return jsonResponse({
        'records': [rec('school_event', 'E-9')],
        'cursor': 5,
        'hasMore': false,
      });
    });
    final summary = await (await engine(server)).syncActiveSchool();

    expect(
      (
        summary.attempted,
        summary.synced,
        summary.failed,
        summary.conflicts,
        summary.pulled,
      ),
      (2, 2, 0, 0, 1),
    );
    expect(outbox.status, {'m1': 'synced', 'm2': 'synced'});
    expect(outbox.versions['m1'], 1);
    // Sending comes before asking what changed.
    expect(
      server.requests.map((r) => r.method + r.url.path.split('/api/v1').last),
      ['POST/sync/push/', 'POST/sync/push/', 'GET/sync/pull/'],
    );
    expect(store.cursors['${teacher.schoolId}|${teacher.id}'], 5);
  });

  test(
    'conflicts and refusals are recorded on the change, and the rest carry on',
    () async {
      outbox.add('m1');
      outbox.add('m2');
      outbox.add('m3');
      final answers = [
        () => respond({
          'disposition': 'conflict',
          'serverVersion': 4,
          'message': 'This record changed on the server first.',
        }, 409),
        () => respond({
          'disposition': 'rejected',
          'serverVersion': null,
          'message': 'Only the owner can decide.',
        }, 422),
        () => respond({
          'disposition': 'accepted',
          'serverVersion': 2,
          'message': '',
        }),
      ];
      var i = 0;
      final server = FakeServer(
        (r) async => r.url.path.endsWith('sync/push/')
            ? answers[i++]()
            : jsonResponse({'records': [], 'cursor': 0, 'hasMore': false}),
      );
      final summary = await (await engine(server)).syncActiveSchool();
      expect((summary.synced, summary.failed, summary.conflicts), (1, 1, 1));
      expect(outbox.errors['m1'], startsWith('SYNC_CONFLICT:'));
      expect(outbox.errors['m2'], 'Only the owner can decide.');
      expect(outbox.status['m3'], 'synced');
    },
  );

  test(
    'with no signal the change goes back in the queue, the order is kept, and nothing is downloaded',
    () async {
      outbox.add('m1');
      outbox.add('m2');
      final server = FakeServer((r) async => throw const ApiOfflineException());
      final summary = await (await engine(server)).syncActiveSchool();

      expect(summary.stoppedOffline, isTrue);
      expect(summary.needsSignIn, isFalse);
      expect((summary.synced, summary.failed), (0, 0));
      expect(outbox.status, {'m1': 'pending', 'm2': 'pending'});
      expect(outbox.errors, isEmpty);
      expect(
        server.requests.length,
        1,
      ); // it stopped at the first: no point trying the rest
      expect(server.to('sync/pull/'), isEmpty);
    },
  );

  test('an expired sign-in stops the run and says so', () async {
    outbox.add('m1');
    final server = FakeServer((r) async => jsonResponse({}, 401));
    final summary = await (await engine(server)).syncActiveSchool();
    expect((summary.stoppedOffline, summary.needsSignIn), (true, true));
    expect(outbox.status['m1'], 'pending');
  });

  test(
    'a change that goes through after being offline is sent, once',
    () async {
      outbox.add('m1');
      var online = false;
      final server = FakeServer((r) async {
        if (!online) throw const ApiOfflineException();
        return r.url.path.endsWith('sync/push/')
            ? jsonResponse({
                'disposition': 'accepted',
                'serverVersion': 1,
                'message': '',
              })
            : jsonResponse({'records': [], 'cursor': 0, 'hasMore': false});
      });
      final sync = await engine(server);
      await sync.syncActiveSchool();
      online = true;
      final summary = await sync.syncActiveSchool();
      expect((summary.synced, summary.stoppedOffline), (1, false));
      expect(outbox.status['m1'], 'synced');
      expect(server.to('sync/push/').length, 2);
    },
  );

  test(
    'going offline while downloading is reported and keeps what was sent',
    () async {
      outbox.add('m1');
      final server = FakeServer((r) async {
        if (r.url.path.endsWith('sync/push/')) {
          return jsonResponse({
            'disposition': 'accepted',
            'serverVersion': 1,
            'message': '',
          });
        }
        throw const ApiOfflineException();
      });
      final summary = await (await engine(server)).syncActiveSchool();
      expect(
        (summary.synced, summary.stoppedOffline, summary.pulled),
        (1, true, 0),
      );
      expect(outbox.status['m1'], 'synced');
    },
  );

  test('without a puller it only sends, as before', () async {
    outbox.add('m1');
    final server = FakeServer(
      (r) async => jsonResponse({
        'disposition': 'accepted',
        'serverVersion': 1,
        'message': '',
      }),
    );
    final summary = await (await engine(
      server,
      pull: false,
    )).syncActiveSchool();
    expect((summary.synced, summary.pulled), (1, 0));
    expect(server.to('sync/pull/'), isEmpty);
  });

  test('a run that is already going is not started twice', () async {
    outbox.add('m1');
    final gate = Future<void>.delayed(const Duration(milliseconds: 50));
    final server = FakeServer((r) async {
      await gate;
      return r.url.path.endsWith('sync/push/')
          ? jsonResponse({
              'disposition': 'accepted',
              'serverVersion': 1,
              'message': '',
            })
          : jsonResponse({'records': [], 'cursor': 0, 'hasMore': false});
    });
    final sync = await engine(server);
    final results = await Future.wait([
      sync.syncActiveSchool(),
      sync.syncActiveSchool(),
    ]);
    expect(results.map((r) => r.attempted).toList()..sort(), [0, 1]);
    expect(server.to('sync/push/').length, 1);
  });
}

Map<String, Object?> rec(String type, String id) => {
  'entityType': type,
  'entityId': id,
  'version': 1,
  'deleted': false,
  'payload': {'id': id},
};
