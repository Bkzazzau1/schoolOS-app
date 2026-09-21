import 'sync_mutation.dart';

/// What pulling needs from the device's storage. `LocalDatabase` provides it;
/// tests use memory.
abstract interface class SyncStore {
  /// How far down the school's changes this membership has already read (0 = nothing yet).
  Future<int> readSyncCursor({required String tenantId, required String membershipId});

  Future<void> writeSyncCursor({
    required String tenantId,
    required String membershipId,
    required int cursor,
  });

  Future<LocalRecord?> getLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  });

  Future<void> upsertLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
    int? serverVersion,
    bool isDirty,
  });

  Future<void> deleteLocalRecord({
    required String tenantId,
    required String entityType,
    required String entityId,
  });
}
