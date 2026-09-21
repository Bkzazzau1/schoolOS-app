import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/server_confirm.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';

import 'local_database_queue_test.dart' show MemorySecureStorage;

const tenant = 'school-1';

void main() {
  late LocalDatabase db;
  var rounds = 0;

  setUp(() async {
    rounds = 0;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
  });

  tearDown(() => db.close());

  Future<String> queue(String type, String id, {SyncOperation op = SyncOperation.create, Map<String, Object?> payload = const {'v': 1}, int? serverVersion}) async {
    await db.upsertLocalRecord(tenantId: tenant, entityType: type, entityId: id, payload: payload, serverVersion: serverVersion, isDirty: true);
    return db.queueMutation(tenantId: tenant, membershipId: 'm-1', entityType: type, entityId: id, operation: op, payload: payload);
  }

  /// What one sync round does with the queue, decided by [answer] for each waiting change.
  ServerConfirm confirming(String Function(SyncQueueItem item) answer) => ServerConfirm(
        database: db,
        syncNow: () async {
          rounds++;
          for (final item in db.syncQueueItems(tenantId: tenant).where((i) => i.status == SyncMutationStatus.pending)) {
            db.markMutationSyncing(item.id);
            final result = answer(item);
            if (result == 'ok') {
              db.markMutationSynced(item.id, serverVersion: 1);
            } else if (result == 'offline') {
              db.markMutationPending(item.id);
            } else {
              db.markMutationFailed(item.id, result);
            }
          }
        },
      );

  test('a change the server accepts says nothing', () async {
    await queue('payroll_batch', '2026-09');
    await confirming((_) => 'ok').afterQueued(tenant, 'payroll_batch', '2026-09');
    expect(db.syncQueueItems(tenantId: tenant), isEmpty);
    expect((await db.getLocalRecord(tenantId: tenant, entityType: 'payroll_batch', entityId: '2026-09'))!.isDirty, isFalse);
    expect(rounds, 1);
  });

  test('a change the server refuses is dropped, the server\'s version is asked for, and its words are thrown', () async {
    await queue('payroll_batch', '2026-09', op: SyncOperation.update, payload: {'status': 'approved'}, serverVersion: 4);
    final confirm = confirming((_) => 'A different person must approve a batch you prepared.');

    await expectLater(
      confirm.afterQueued(tenant, 'payroll_batch', '2026-09'),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'A different person must approve a batch you prepared.')),
    );
    expect(db.syncQueueItems(tenantId: tenant), isEmpty);              // nothing left to retry forever
    final record = (await db.getLocalRecord(tenantId: tenant, entityType: 'payroll_batch', entityId: '2026-09'))!;
    expect((record.isDirty, record.serverVersion), (false, 4));         // no longer counts as an edit
    expect(await db.readSyncCursor(tenantId: tenant, membershipId: 'm-1'), 0);
    expect(rounds, 2);                                                  // one to send, one to bring the truth back
  });

  test('a new record the server refused is removed from the device', () async {
    await queue('concession_request', 'CNC-1');
    await expectLater(
      confirming((_) => 'The concession cannot be more than the term fee.').afterQueued(tenant, 'concession_request', 'CNC-1'),
      throwsStateError,
    );
    expect(await db.getLocalRecord(tenantId: tenant, entityType: 'concession_request', entityId: 'CNC-1'), isNull);
  });

  test('offline: it stays queued, nothing is thrown, and it is not lost', () async {
    await queue('payroll_batch', '2026-09');
    await confirming((_) => 'offline').afterQueued(tenant, 'payroll_batch', '2026-09');
    final waiting = db.syncQueueItems(tenantId: tenant).single;
    expect(waiting.status, SyncMutationStatus.pending);
  });

  test('a conflict (someone else changed it first) stays for the person to resolve and is not thrown', () async {
    await queue('payroll_batch', '2026-09', op: SyncOperation.update);
    await confirming((_) => 'SYNC_CONFLICT: This record changed on the server first.').afterQueued(tenant, 'payroll_batch', '2026-09');
    final item = db.syncQueueItems(tenantId: tenant).single;
    expect(item.isConflict, isTrue);
  });

  test('it only reports on the record it was asked about', () async {
    await queue('payroll_batch', '2026-09');
    await queue('payroll_batch', '2026-10');
    await confirming((item) => item.entityId == '2026-10' ? 'Refused.' : 'ok').afterQueued(tenant, 'payroll_batch', '2026-09');
    // Another record's refusal is not this one's problem, and is left for its own screen.
    expect(db.syncQueueItems(tenantId: tenant).map((i) => i.entityId), ['2026-10']);
  });
}
