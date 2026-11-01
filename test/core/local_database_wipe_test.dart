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

  /// Phase D Stage 4, Task 8 audit finding: logging out on a shared/school-owned device
  /// must never leave a previous account's cached data readable by whoever signs in next.
  test(
    'wipeAllData erases cached records, queued mutations, and the sync cursor',
    () async {
      await db.upsertLocalRecord(
        tenantId: tenant,
        entityType: 'student',
        entityId: 'STU-1',
        payload: {'name': 'A previous user\'s student record'},
        serverVersion: 3,
      );
      await db.queueMutation(
        tenantId: tenant,
        membershipId: membership,
        entityType: 'school_event',
        entityId: 'E1',
        operation: SyncOperation.create,
        payload: {'title': 'An unsent mutation'},
      );
      await db.writeSyncCursor(tenantId: tenant, membershipId: membership, cursor: 42);

      expect(
        await db.getLocalRecord(tenantId: tenant, entityType: 'student', entityId: 'STU-1'),
        isNotNull,
      );
      expect(await db.pendingMutations(tenantId: tenant), isNotEmpty);
      expect(await db.readSyncCursor(tenantId: tenant, membershipId: membership), 42);

      await db.wipeAllData();

      expect(
        await db.getLocalRecord(tenantId: tenant, entityType: 'student', entityId: 'STU-1'),
        isNull,
      );
      expect(await db.pendingMutations(tenantId: tenant), isEmpty);
      expect(await db.readSyncCursor(tenantId: tenant, membershipId: membership), 0);
    },
  );

  test('wipeAllData leaves the database usable for a freshly signed-in account', () async {
    await db.wipeAllData();

    // A later sign-in must be able to write and read normally - wiping must never leave
    // the database in a broken or half-initialized state.
    await db.upsertLocalRecord(
      tenantId: 'school-2',
      entityType: 'student',
      entityId: 'STU-9',
      payload: {'name': 'The next account\'s own student'},
      serverVersion: 1,
    );
    expect(
      await db.getLocalRecord(tenantId: 'school-2', entityType: 'student', entityId: 'STU-9'),
      isNotNull,
    );
  });
}
