import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../media/media_queue_models.dart';
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

  /// True when the app talks to a school server. Many screens fill an empty list with sample records
  /// (so the demo has something to show). With a server those samples would look like the school's
  /// real data, and could never be accepted by it, so they are not written at all.
  ///
  /// A sample is recognisable: it is not an edit waiting to be sent, and it was never downloaded (it
  /// has no server version). The app's own local-only records (their type starts with `_`) are not samples.
  static bool blockDemoSeeds = false;

  /// Called whenever there is new work in the outbox, so the app can send it
  /// soon without every screen having to ask.
  void Function()? onMutationQueued;

  /// Called whenever a file is queued (or asked to retry), so the upload queue can try soon without every
  /// screen having to ask - the same role [onMutationQueued] plays for ordinary sync.
  void Function()? onMediaUploadQueued;
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

    // A file picked or captured while offline (or while the queue has not caught up yet): the bytes are already
    // copied into this app's own storage (local_path) before this row exists, so a picker handle that stops
    // working later can never lose them. `state` is one of local/waiting/uploading/uploaded/failed - see
    // media_queue_models.dart - and is never shown to a person as "uploaded" until the server has said so.
    db.execute('''
      CREATE TABLE IF NOT EXISTS media_uploads (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        membership_id TEXT NOT NULL,
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        category TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        byte_size INTEGER NOT NULL,
        sha256 TEXT NOT NULL,
        local_path TEXT NOT NULL,
        caption TEXT NOT NULL DEFAULT '',
        visibility TEXT NOT NULL DEFAULT 'private',
        state TEXT NOT NULL DEFAULT 'waiting',
        server_asset_id TEXT,
        server_status TEXT,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error_code TEXT,
        last_error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_media_uploads_owner
      ON media_uploads (tenant_id, owner_type, owner_id);
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_media_uploads_state
      ON media_uploads (tenant_id, state);
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
    if (blockDemoSeeds && !isDirty && serverVersion == null && !entityType.startsWith('_')) return;
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
    final latest =
        _db
                .select('SELECT MAX(created_at) AS latest FROM sync_outbox;')
                .first['latest']
            as String?;
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

  /// Gives up on a change the server refused (or that conflicted), so the
  /// school's version stands.
  ///
  /// The change leaves the queue. If it was a new record the server never
  /// accepted, the local copy is removed; otherwise the copy stops counting as
  /// edited here, and the download position is reset so the server's version of
  /// it (skipped while it was being edited here) is read again.
  void discardMutation({required String tenantId, required String mutationId}) {
    _requireTenant(tenantId);
    final rows = _db.select(
      'SELECT entity_type, entity_id FROM sync_outbox WHERE id = ? AND tenant_id = ? AND status = ?;',
      [mutationId, tenantId, 'failed'],
    );
    if (rows.isEmpty) return;
    final type = rows.first['entity_type'] as String;
    final id = rows.first['entity_id'] as String;

    _db.execute('DELETE FROM sync_outbox WHERE id = ?;', [mutationId]);
    final others = _db.select(
      'SELECT 1 FROM sync_outbox WHERE tenant_id = ? AND entity_type = ? AND entity_id = ? LIMIT 1;',
      [tenantId, type, id],
    );
    if (others.isNotEmpty) {
      return; // a later edit of the same record is still waiting
    }

    _db.execute(
      'DELETE FROM local_records WHERE tenant_id = ? AND entity_type = ? AND entity_id = ? AND server_version IS NULL;',
      [tenantId, type, id],
    );
    _db.execute(
      'UPDATE local_records SET is_dirty = 0 WHERE tenant_id = ? AND entity_type = ? AND entity_id = ?;',
      [tenantId, type, id],
    );
    _db.execute('DELETE FROM sync_cursors WHERE tenant_id = ?;', [tenantId]);
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

  // -- media uploads --------------------------------------------------------------------------------------------
  //
  // A file's bytes are copied into this app's own storage before any of this runs (see
  // media_local_files.dart), so nothing here ever touches a picker's own temporary handle. A row here is the
  // durable record of one file's journey from that copy to the server; it survives an app restart the same way
  // the ordinary sync outbox does, because it lives in the same database file.

  /// Records a file already copied to [localPath], queued in the 'waiting' state. Nothing here has touched the
  /// network yet.
  Future<String> queueMediaUpload({
    required String tenantId,
    required String membershipId,
    required String ownerType,
    required String ownerId,
    required String category,
    required String fileName,
    required String mimeType,
    required int byteSize,
    required String sha256,
    required String localPath,
    String caption = '',
    String visibility = 'private',
  }) async {
    _requireTenant(tenantId);
    final id = _newMutationId();
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      INSERT INTO media_uploads (
        id, tenant_id, membership_id, owner_type, owner_id, category, file_name, mime_type, byte_size, sha256,
        local_path, caption, visibility, state, attempt_count, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'waiting', 0, ?, ?);
      ''',
      [
        id, tenantId, membershipId, ownerType, ownerId, category, fileName, mimeType, byteSize, sha256,
        localPath, caption, visibility, now, now,
      ],
    );
    onMediaUploadQueued?.call();
    return id;
  }

  /// Every upload - queued, sent, done or given up on - attached to one owner, oldest first: a screen shows this
  /// alongside the server's own list so a file the server has not caught up to yet is never simply missing.
  List<QueuedMediaUpload> mediaUploadsForOwner({
    required String tenantId,
    required String ownerType,
    required String ownerId,
  }) {
    _requireTenant(tenantId);
    final rows = _db.select(
      '''
      SELECT * FROM media_uploads WHERE tenant_id = ? AND owner_type = ? AND owner_id = ? ORDER BY created_at ASC;
      ''',
      [tenantId, ownerType, ownerId],
    );
    return rows.map(_decodeMediaUpload).toList(growable: false);
  }

  /// Uploads due to be attempted now: waiting for their first try, or waiting to be retried after a backoff.
  List<QueuedMediaUpload> dueMediaUploads({required String tenantId, int limit = 3}) {
    _requireTenant(tenantId);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = _db.select(
      '''
      SELECT * FROM media_uploads
      WHERE tenant_id = ? AND state = 'waiting' AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
      ORDER BY created_at ASC LIMIT ?;
      ''',
      [tenantId, nowIso, limit],
    );
    return rows.map(_decodeMediaUpload).toList(growable: false);
  }

  int pendingMediaUploadCount({required String tenantId}) {
    _requireTenant(tenantId);
    final rows = _db.select(
      "SELECT COUNT(*) AS count FROM media_uploads WHERE tenant_id = ? AND state IN ('waiting', 'uploading');",
      [tenantId],
    );
    return rows.first['count'] as int;
  }

  QueuedMediaUpload? mediaUpload(String id) {
    final rows = _db.select('SELECT * FROM media_uploads WHERE id = ? LIMIT 1;', [id]);
    return rows.isEmpty ? null : _decodeMediaUpload(rows.first);
  }

  void markMediaUploadUploading(String id) {
    _db.execute(
      "UPDATE media_uploads SET state = 'uploading', updated_at = ? WHERE id = ?;",
      [DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  /// A transient failure (no network, the server unreachable, a 5xx): back to 'waiting', tried again after
  /// [nextAttemptAt] - never marked failed for something that might work next time.
  void markMediaUploadWaitingRetry(
    String id, {
    required String errorCode,
    required String errorMessage,
    required DateTime nextAttemptAt,
  }) {
    _db.execute(
      '''
      UPDATE media_uploads
      SET state = 'waiting', attempt_count = attempt_count + 1, last_error_code = ?, last_error_message = ?,
          next_attempt_at = ?, updated_at = ?
      WHERE id = ?;
      ''',
      [errorCode, errorMessage, nextAttemptAt.toUtc().toIso8601String(), DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  /// A definite refusal (the server rejected the file itself) or every retry used up: given up on automatically.
  void markMediaUploadFailed(String id, {required String errorCode, required String errorMessage}) {
    _db.execute(
      "UPDATE media_uploads SET state = 'failed', last_error_code = ?, last_error_message = ?, updated_at = ? WHERE id = ?;",
      [errorCode, errorMessage, DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  void markMediaUploadUploaded(String id, {required String serverAssetId, required String serverStatus}) {
    _db.execute(
      '''
      UPDATE media_uploads
      SET state = 'uploaded', server_asset_id = ?, server_status = ?, last_error_code = NULL, last_error_message = NULL, updated_at = ?
      WHERE id = ?;
      ''',
      [serverAssetId, serverStatus, DateTime.now().toUtc().toIso8601String(), id],
    );
  }

  /// A person asking to try a failed upload again, by hand.
  void retryMediaUpload(String id) {
    _db.execute(
      "UPDATE media_uploads SET state = 'waiting', attempt_count = 0, next_attempt_at = NULL, last_error_code = NULL, last_error_message = NULL, updated_at = ? WHERE id = ? AND state = 'failed';",
      [DateTime.now().toUtc().toIso8601String(), id],
    );
    onMediaUploadQueued?.call();
  }

  /// Forgets a queued upload without ever having sent it (a person cancelling their own pending pick).
  void deleteMediaUpload(String id) {
    _db.execute('DELETE FROM media_uploads WHERE id = ?;', [id]);
  }

  QueuedMediaUpload _decodeMediaUpload(Row row) => QueuedMediaUpload(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        membershipId: row['membership_id'] as String,
        ownerType: row['owner_type'] as String,
        ownerId: row['owner_id'] as String,
        category: row['category'] as String,
        fileName: row['file_name'] as String,
        mimeType: row['mime_type'] as String,
        byteSize: row['byte_size'] as int,
        sha256: row['sha256'] as String,
        localPath: row['local_path'] as String,
        caption: row['caption'] as String,
        visibility: row['visibility'] as String,
        state: mediaUploadStateFrom(row['state'] as String),
        serverAssetId: row['server_asset_id'] as String?,
        serverStatus: row['server_status'] as String?,
        attemptCount: row['attempt_count'] as int,
        nextAttemptAt: row['next_attempt_at'] == null ? null : DateTime.parse(row['next_attempt_at'] as String),
        lastErrorCode: row['last_error_code'] as String?,
        lastErrorMessage: row['last_error_message'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

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
