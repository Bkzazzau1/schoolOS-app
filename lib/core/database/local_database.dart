import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/payload_cipher.dart';
import '../sync/sync_mutation.dart';
import '../sync/sync_store.dart';

class LocalDatabase implements SyncStore {
  /// [databasePath] is for tests (use `':memory:'`); the app leaves it out and
  /// gets its own file in the platform's private support folder.
  LocalDatabase({required PayloadCipher cipher, String? databasePath})
    : _cipher = cipher,
      _databasePath = databasePath;

  final PayloadCipher _cipher;
  final String? _databasePath;

  /// Called whenever there is new work in the outbox, so the app can send it
  /// soon without every screen having to ask.
  void Function()? onMutationQueued;
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
    final databasePath =
        _databasePath ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'schoolos_local.db',
        );

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

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_cursors (
        tenant_id TEXT NOT NULL,
        membership_id TEXT NOT NULL,
        cursor INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (tenant_id, membership_id)
      );
    ''');

    _database = db;
  }

  @override
  Future<int> readSyncCursor({
    required String tenantId,
    required String membershipId,
  }) async {
    _requireTenant(tenantId);
    final rows = _db.select(
      'SELECT cursor FROM sync_cursors WHERE tenant_id = ? AND membership_id = ?;',
      [tenantId, membershipId],
    );
    return rows.isEmpty ? 0 : rows.first['cursor'] as int;
  }

  @override
  Future<void> writeSyncCursor({
    required String tenantId,
    required String membershipId,
    required int cursor,
  }) async {
    _requireTenant(tenantId);
    _db.execute(
      '''
      INSERT INTO sync_cursors (tenant_id, membership_id, cursor) VALUES (?, ?, ?)
      ON CONFLICT(tenant_id, membership_id) DO UPDATE SET cursor = excluded.cursor;
      ''',
      [tenantId, membershipId, cursor],
    );
  }

  @override
  Future<void> deleteLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  }) async {
    _requireTenant(tenantId);
    _db.execute(
      'DELETE FROM local_records WHERE tenant_id = ? AND entity_type = ? AND entity_id = ?;',
      [tenantId, entityType, entityId],
    );
  }

  @override
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

  @override
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
    final now = _nextQueueTime();
    final existing = _db.select(
      '''
      SELECT id, operation, status, attempt_count, created_at
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

    var effectiveOperation = operation;
    var createdAt = now;

    if (existing.isNotEmpty) {
      final row = existing.first;
      final existingId = row['id'] as String;
      final existingOperation = SyncOperation.values.byName(
        row['operation'] as String,
      );
      // The server has never seen an earlier create, so the record is still a
      // create however many times it is edited before it is sent.
      final stillACreate =
          existingOperation == SyncOperation.create &&
          operation != SyncOperation.delete;

      if (row['status'] == 'pending' && (row['attempt_count'] as int) == 0) {
        // Nothing has been sent yet: fold the new edit into the waiting change.
        // It keeps its id and its place in the queue, because changes must
        // reach the server in the order they were first made (a comment cannot
        // arrive before the post it is on).
        _db.execute(
          '''
          UPDATE sync_outbox
          SET membership_id = ?, operation = ?, encrypted_payload = ?, base_version = ?
          WHERE id = ?;
          ''',
          [
            membershipId,
            (stillACreate ? SyncOperation.create : operation).name,
            encryptedPayload,
            baseVersion,
            existingId,
          ],
        );
        onMutationQueued?.call();
        return existingId;
      }

      if (row['status'] == 'failed') {
        // The server refused the earlier change. The new edit replaces it, but
        // under a new id, because the server remembers its answer to the old
        // one and would give the same answer again. It keeps its place too.
        _db.execute('DELETE FROM sync_outbox WHERE id = ?;', [row['id']]);
        createdAt = row['created_at'] as String;
        if (stillACreate) effectiveOperation = SyncOperation.create;
      }
      // A change that was sent but never answered may already be applied on the
      // server, so it is left alone and the new edit follows it as its own
      // change. Editing it in place could make the server ignore the edit.
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
        effectiveOperation.name,
        encryptedPayload,
        baseVersion,
        createdAt,
      ],
    );

    onMutationQueued?.call();
    return id;
  }

  /// The time to stamp a new change with. Strictly later than every change
  /// already queued, so the order of the queue is never a tie, and always
  /// written with six decimals so that ordering by text is ordering by time.
  String _nextQueueTime() {
    var time = DateTime.now().toUtc();
    final latest = _db
        .select('SELECT MAX(created_at) AS latest FROM sync_outbox;')
        .first['latest'] as String?;
    if (latest != null) {
      final last = DateTime.parse(latest);
      if (!time.isAfter(last)) time = last.add(const Duration(microseconds: 1));
    }
    return time.toIso8601String().replaceFirstMapped(
          RegExp(r'\.(\d{3})Z$'),
          (match) => '.${match[1]}000Z',
        );
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
      WHERE tenant_id = ? AND status = 'pending'
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

    // A new id, because the server remembers its answer to the old one and
    // would simply repeat it.
    _db.execute(
      '''
      UPDATE sync_outbox
      SET id = ?, status = 'pending', attempt_count = 0, last_error = NULL
      WHERE id = ? AND tenant_id = ? AND status = 'failed';
      ''',
      [_newMutationId(), mutationId, tenantId],
    );
    onMutationQueued?.call();
  }

  /// Puts a change that was being sent back in the queue, untouched, because it
  /// could not be delivered yet (no signal). It is not a failure.
  void markMutationPending(String mutationId) {
    _db.execute(
      "UPDATE sync_outbox SET status = 'pending' WHERE id = ? AND status = 'syncing';",
      [mutationId],
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

  void markMutationSynced(String mutationId, {int? serverVersion}) {
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

    _db.execute('DELETE FROM sync_outbox WHERE id = ?;', [mutationId]);
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
  final randomPart = List<int>.generate(
    12,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${DateTime.now().microsecondsSinceEpoch}-$randomPart';
}
