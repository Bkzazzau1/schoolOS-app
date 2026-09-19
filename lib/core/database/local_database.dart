import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/payload_cipher.dart';
import '../sync/sync_mutation.dart';

class LocalDatabase {
  LocalDatabase({required PayloadCipher cipher}) : _cipher = cipher;

  final PayloadCipher _cipher;
  Database? _database;

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('LocalDatabase has not been initialized.');
    }
    return database;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    await _cipher.initialize();
    final supportDirectory = await getApplicationSupportDirectory();
    final databasePath = p.join(supportDirectory.path, 'schoolos_local.db');

    final db = sqlite3.open(databasePath);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('PRAGMA busy_timeout = 5000;');

    db.execute('''
      CREATE TABLE IF NOT EXISTS local_records (
        tenant_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        encrypted_payload TEXT NOT NULL,
        server_version INTEGER,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (tenant_id, entity_type, entity_id)
      );
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_local_records_tenant_type
      ON local_records (tenant_id, entity_type);
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        membership_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        encrypted_payload TEXT NOT NULL,
        base_version INTEGER,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_tenant_status_created
      ON sync_outbox (tenant_id, status, created_at);
    ''');

    _database = db;
  }

  Future<void> upsertLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
    int? serverVersion,
    bool isDirty = false,
  }) async {
    _requireTenant(tenantId);
    final encryptedPayload = await _cipher.encryptJson(payload);
    final now = DateTime.now().toUtc().toIso8601String();

    _db.execute(
      '''
      INSERT INTO local_records (
        tenant_id,
        entity_type,
        entity_id,
        encrypted_payload,
        server_version,
        updated_at,
        is_dirty
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(tenant_id, entity_type, entity_id) DO UPDATE SET
        encrypted_payload = excluded.encrypted_payload,
        server_version = excluded.server_version,
        updated_at = excluded.updated_at,
        is_dirty = excluded.is_dirty;
      ''',
      [
        tenantId,
        entityType,
        entityId,
        encryptedPayload,
        serverVersion,
        now,
        isDirty ? 1 : 0,
      ],
    );
  }

  Future<LocalRecord?> getLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  }) async {
    _requireTenant(tenantId);

    final rows = _db.select(
      '''
      SELECT * FROM local_records
      WHERE tenant_id = ? AND entity_type = ? AND entity_id = ?
      LIMIT 1;
      ''',
      [tenantId, entityType, entityId],
    );

    if (rows.isEmpty) return null;
    return _decodeLocalRecord(rows.first);
  }

  Future<List<LocalRecord>> getLocalRecords({
    required String tenantId,
    required String entityType,
  }) async {
    _requireTenant(tenantId);

    final rows = _db.select(
      '''
      SELECT * FROM local_records
      WHERE tenant_id = ? AND entity_type = ?
      ORDER BY updated_at DESC;
      ''',
      [tenantId, entityType],
    );

    final records = <LocalRecord>[];
    for (final row in rows) {
      records.add(await _decodeLocalRecord(row));
    }
    return records;
  }

  Future<String> queueMutation({
    required String tenantId,
    required String membershipId,
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, Object?> payload,
    int? baseVersion,
  }) async {
    _requireTenant(tenantId);
    if (membershipId.trim().isEmpty) {
      throw ArgumentError.value(
        membershipId,
        'membershipId',
        'Membership id is required for offline mutations.',
      );
    }

    final encryptedPayload = await _cipher.encryptJson(payload);
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final existing = _db.select(
      '''
      SELECT id, operation
      FROM sync_outbox
      WHERE tenant_id = ?
        AND entity_type = ?
        AND entity_id = ?
        AND status IN ('pending', 'failed')
      ORDER BY created_at DESC
      LIMIT 1;
      ''',
      [tenantId, entityType, entityId],
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as String;
      final existingOperation = SyncOperation.values.byName(
        existing.first['operation'] as String,
      );
      final effectiveOperation =
          existingOperation == SyncOperation.create && operation != SyncOperation.delete
              ? SyncOperation.create
              : operation;

      _db.execute(
        '''
        UPDATE sync_outbox
        SET membership_id = ?,
            operation = ?,
            encrypted_payload = ?,
            base_version = ?,
            created_at = ?,
            status = 'pending',
            last_error = NULL
        WHERE id = ?;
        ''',
        [
          membershipId,
          effectiveOperation.name,
          encryptedPayload,
          baseVersion,
          createdAt,
          existingId,
        ],
      );
      return existingId;
    }

    final id = _newMutationId();
    _db.execute(
      '''
      INSERT INTO sync_outbox (
        id,
        tenant_id,
        membership_id,
        entity_type,
        entity_id,
        operation,
        encrypted_payload,
        base_version,
        created_at,
        status,
        attempt_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0);
      ''',
      [
        id,
        tenantId,
        membershipId,
        entityType,
        entityId,
        operation.name,
        encryptedPayload,
        baseVersion,
        createdAt,
      ],
    );

    return id;
  }

  Future<List<SyncMutation>> pendingMutations({
    required String tenantId,
    int limit = 50,
  }) async {
    _requireTenant(tenantId);
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'Use a limit from 1 to 500.');
    }

    final rows = _db.select(
      '''
      SELECT * FROM sync_outbox
      WHERE tenant_id = ? AND status IN ('pending', 'failed')
      ORDER BY created_at ASC
      LIMIT ?;
      ''',
      [tenantId, limit],
    );

    final mutations = <SyncMutation>[];
    for (final row in rows) {
      mutations.add(await _decodeMutation(row));
    }
    return mutations;
  }

  List<SyncQueueItem> syncQueueItems({
    required String tenantId,
    int limit = 200,
  }) {
    _requireTenant(tenantId);
    if (limit < 1 || limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'Use a limit from 1 to 1000.');
    }

    final rows = _db.select(
      '''
      SELECT
        id,
        tenant_id,
        membership_id,
        entity_type,
        entity_id,
        operation,
        base_version,
        created_at,
        status,
        attempt_count,
        last_error
      FROM sync_outbox
      WHERE tenant_id = ?
      ORDER BY
        CASE status
          WHEN 'failed' THEN 0
          WHEN 'syncing' THEN 1
          ELSE 2
        END,
        created_at ASC
      LIMIT ?;
      ''',
      [tenantId, limit],
    );

    return rows
        .map(
          (row) => SyncQueueItem(
            id: row['id'] as String,
            tenantId: row['tenant_id'] as String,
            membershipId: row['membership_id'] as String,
            entityType: row['entity_type'] as String,
            entityId: row['entity_id'] as String,
            operation: SyncOperation.values.byName(row['operation'] as String),
            baseVersion: row['base_version'] as int?,
            createdAt: DateTime.parse(row['created_at'] as String),
            status: SyncMutationStatus.values.byName(row['status'] as String),
            attemptCount: row['attempt_count'] as int,
            lastError: row['last_error'] as String?,
          ),
        )
        .toList(growable: false);
  }

  int pendingCount({required String tenantId}) {
    _requireTenant(tenantId);

    final rows = _db.select(
      '''
      SELECT COUNT(*) AS count
      FROM sync_outbox
      WHERE tenant_id = ? AND status IN ('pending', 'failed', 'syncing');
      ''',
      [tenantId],
    );

    return rows.first['count'] as int;
  }

  void queueMutationForRetry({
    required String tenantId,
    required String mutationId,
  }) {
    _requireTenant(tenantId);

    _db.execute(
      '''
      UPDATE sync_outbox
      SET status = 'pending', last_error = NULL
      WHERE id = ? AND tenant_id = ? AND status = 'failed';
      ''',
      [mutationId, tenantId],
    );
  }

  void markMutationSyncing(String mutationId) {
    _db.execute(
      '''
      UPDATE sync_outbox
      SET status = 'syncing', attempt_count = attempt_count + 1, last_error = NULL
      WHERE id = ?;
      ''',
      [mutationId],
    );
  }

  void markMutationFailed(String mutationId, String error) {
    _db.execute(
      '''
      UPDATE sync_outbox
      SET status = 'failed', last_error = ?
      WHERE id = ?;
      ''',
      [error, mutationId],
    );
  }

  void markMutationSynced(
    String mutationId, {
    int? serverVersion,
  }) {
    final mutation = _db.select(
      '''
      SELECT tenant_id, entity_type, entity_id
      FROM sync_outbox
      WHERE id = ?
      LIMIT 1;
      ''',
      [mutationId],
    );

    if (mutation.isNotEmpty) {
      final row = mutation.first;
      _db.execute(
        '''
        UPDATE local_records
        SET is_dirty = 0,
            server_version = COALESCE(?, server_version)
        WHERE tenant_id = ? AND entity_type = ? AND entity_id = ?;
        ''',
        [
          serverVersion,
          row['tenant_id'] as String,
          row['entity_type'] as String,
          row['entity_id'] as String,
        ],
      );
    }

    _db.execute(
      'DELETE FROM sync_outbox WHERE id = ?;',
      [mutationId],
    );
  }

  void close() {
    _database?.close();
    _database = null;
  }

  Future<LocalRecord> _decodeLocalRecord(Row row) async {
    return LocalRecord(
      tenantId: row['tenant_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      payload: await _cipher.decryptJson(row['encrypted_payload'] as String),
      serverVersion: row['server_version'] as int?,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isDirty: (row['is_dirty'] as int) == 1,
    );
  }

  Future<SyncMutation> _decodeMutation(Row row) async {
    return SyncMutation(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      membershipId: row['membership_id'] as String,
      entityType: row['entity_type'] as String,
      entityId: row['entity_id'] as String,
      operation: SyncOperation.values.byName(row['operation'] as String),
      payload: await _cipher.decryptJson(row['encrypted_payload'] as String),
      baseVersion: row['base_version'] as int?,
      createdAt: DateTime.parse(row['created_at'] as String),
      status: SyncMutationStatus.values.byName(row['status'] as String),
      attemptCount: row['attempt_count'] as int,
      lastError: row['last_error'] as String?,
    );
  }

  void _requireTenant(String tenantId) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError.value(
        tenantId,
        'tenantId',
        'Every local read/write must be tenant scoped.',
      );
    }
  }
}

String _newMutationId() {
  final random = Random.secure();
  final randomPart = List<int>.generate(12, (_) => random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
}
