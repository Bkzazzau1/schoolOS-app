import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';

/// Secure storage in memory, so the real database can run in a test.
class MemorySecureStorage implements FlutterSecureStorage {
  final data = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => data[key] = value!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const tenant = 'school-1';
const membership = 'membership-1';

void main() {
  late LocalDatabase db;

  setUp(() async {
    db = LocalDatabase(
      cipher: PayloadCipher(secureStorage: MemorySecureStorage()),
      databasePath: ':memory:',
    );
    await db.initialize();
  });

  tearDown(() => db.close());

  Future<String> queue(
    String entityId,
    Map<String, Object?> payload, {
    SyncOperation op = SyncOperation.update,
    String type = 'school_event',
    int? base,
  }) {
    return db.queueMutation(
      tenantId: tenant,
      membershipId: membership,
      entityType: type,
      entityId: entityId,
      operation: op,
      payload: payload,
      baseVersion: base,
    );
  }

  Future<List<SyncMutation>> pending() => db.pendingMutations(tenantId: tenant);

  /// What the sync engine does when the server said no.
  void refuse(String id) {
    db.markMutationSyncing(id);
    db.markMutationFailed(id, 'Only the owner can decide.');
  }

  group('editing a record again before anything was sent', () {
    test(
      'merges into the one waiting change, keeping its id and its place in the queue',
      () async {
        final first = await queue('A', {'v': 1}, op: SyncOperation.create);
        await queue('B', {'v': 1}, op: SyncOperation.create);
        final again = await queue('A', {'v': 2});

        expect(again, first);
        final waiting = await pending();
        expect(waiting.map((m) => m.entityId), [
          'A',
          'B',
        ]); // A did not jump behind B
        expect(waiting.first.payload['v'], 2);
        expect(
          waiting.first.operation,
          SyncOperation.create,
        ); // still a create: the server has never seen it
      },
    );

    test('an edit of an edit stays one update', () async {
      await queue('A', {'v': 1}, base: 3);
      await queue('A', {'v': 2}, base: 3);
      final waiting = await pending();
      expect(
        (waiting.length, waiting.single.operation, waiting.single.payload['v']),
        (1, SyncOperation.update, 2),
      );
    });
  });

  group('editing a record again after an attempt to send it', () {
    test(
      'is a new change, so an edit is never swallowed by an answer the server already gave',
      () async {
        final first = await queue('A', {'v': 1}, op: SyncOperation.create);
        // The change reached the server, but the reply was lost: it is back in the queue.
        db.markMutationSyncing(first);
        db.markMutationPending(first);

        final second = await queue('A', {'v': 2}, base: 1);
        expect(second, isNot(first));
        final waiting = await pending();
        expect(waiting.map((m) => (m.id, m.operation, m.payload['v'])), [
          (first, SyncOperation.create, 1),
          (second, SyncOperation.update, 2),
        ]);
      },
    );

    test(
      'putting a change back for a bad connection does not count as a failure or a new attempt',
      () async {
        final id = await queue('A', {'v': 1});
        db.markMutationSyncing(id);
        db.markMutationPending(id);
        final item = db.syncQueueItems(tenantId: tenant).single;
        expect(
          (item.status, item.attemptCount, item.lastError),
          (SyncMutationStatus.pending, 1, null),
        );
      },
    );
  });

  group('a change the server refused', () {
    test(
      'is not sent again by itself, and does not crowd out new work',
      () async {
        final ids = [
          for (var i = 0; i < 60; i++)
            await queue('R$i', {'v': i}, op: SyncOperation.create),
        ];
        ids.forEach(refuse);
        await queue('NEW', {'v': 1}, op: SyncOperation.create);
        final waiting = await db.pendingMutations(tenantId: tenant, limit: 50);
        expect(waiting.map((m) => m.entityId), ['NEW']);
      },
    );

    test(
      'is replaced by the next edit, under a new id, in the same place in the queue',
      () async {
        final refused = await queue('A', {'v': 1}, op: SyncOperation.create);
        await queue('B', {'v': 1}, op: SyncOperation.create);
        refuse(refused);

        final corrected = await queue('A', {'v': 2}, base: null);
        expect(
          corrected,
          isNot(refused),
        ); // the server remembers its answer to the old id
        final waiting = await pending();
        expect(waiting.map((m) => m.entityId), ['A', 'B']);
        expect(
          (waiting.first.operation, waiting.first.payload['v']),
          (SyncOperation.create, 2),
        );
        expect(
          db
              .syncQueueItems(tenantId: tenant)
              .where((i) => i.status == SyncMutationStatus.failed),
          isEmpty,
        );
      },
    );

    test('retrying it by hand sends it under a new id', () async {
      final refused = await queue('A', {'v': 1});
      refuse(refused);
      db.queueMutationForRetry(tenantId: tenant, mutationId: refused);
      final waiting = await pending();
      expect(waiting.length, 1);
      expect(waiting.single.id, isNot(refused));
      expect((waiting.single.entityId, waiting.single.payload['v']), ('A', 1));
      final item = db.syncQueueItems(tenantId: tenant).single;
      expect(
        (item.status, item.attemptCount, item.lastError),
        (SyncMutationStatus.pending, 0, null),
      );
    });

    test('still counts as waiting work until someone deals with it', () async {
      refuse(await queue('A', {'v': 1}));
      expect(db.pendingCount(tenantId: tenant), 1);
    });
  });

  group('the queue tells the app when there is something new to send', () {
    test('every way of queueing rings the bell', () async {
      var rang = 0;
      db.onMutationQueued = () => rang++;
      final first = await queue('A', {'v': 1}); // new
      await queue('A', {'v': 2}); // merged
      refuse(first);
      await queue('A', {'v': 3}); // replacing a refused one
      refuse((await pending()).single.id);
      db.queueMutationForRetry(
        tenantId: tenant,
        mutationId: (db.syncQueueItems(tenantId: tenant).single).id,
      );
      expect(rang, 4);
    });
  });

  group('sent and confirmed', () {
    test(
      'a confirmed change leaves the queue and marks the record as no longer edited',
      () async {
        await db.upsertLocalRecord(
          tenantId: tenant,
          entityType: 'school_event',
          entityId: 'A',
          payload: {'v': 1},
          isDirty: true,
        );
        final id = await queue('A', {'v': 1}, op: SyncOperation.create);
        db.markMutationSyncing(id);
        db.markMutationSynced(id, serverVersion: 4);
        expect(await pending(), isEmpty);
        final record = (await db.getLocalRecord(
          tenantId: tenant,
          entityType: 'school_event',
          entityId: 'A',
        ))!;
        expect((record.isDirty, record.serverVersion), (false, 4));
      },
    );
  });

  group('downloaded state', () {
    test(
      'the cursor is kept for each school and membership, and survives a rewrite',
      () async {
        expect(
          await db.readSyncCursor(tenantId: tenant, membershipId: membership),
          0,
        );
        await db.writeSyncCursor(
          tenantId: tenant,
          membershipId: membership,
          cursor: 7,
        );
        await db.writeSyncCursor(
          tenantId: tenant,
          membershipId: membership,
          cursor: 12,
        );
        expect(
          await db.readSyncCursor(tenantId: tenant, membershipId: membership),
          12,
        );
        expect(
          await db.readSyncCursor(tenantId: tenant, membershipId: 'other'),
          0,
        );
      },
    );

    test(
      'a record removed by the server is removed here, and only that one',
      () async {
        await db.upsertLocalRecord(
          tenantId: tenant,
          entityType: 'a',
          entityId: '1',
          payload: {'v': 1},
        );
        await db.upsertLocalRecord(
          tenantId: tenant,
          entityType: 'a',
          entityId: '2',
          payload: {'v': 2},
        );
        await db.deleteLocalRecord(
          tenantId: tenant,
          entityType: 'a',
          entityId: '1',
        );
        expect(
          await db.getLocalRecord(
            tenantId: tenant,
            entityType: 'a',
            entityId: '1',
          ),
          isNull,
        );
        expect(
          await db.getLocalRecord(
            tenantId: tenant,
            entityType: 'a',
            entityId: '2',
          ),
          isNotNull,
        );
      },
    );
  });
}
