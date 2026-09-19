enum SyncOperation {
  create,
  update,
  delete,
}

enum SyncMutationStatus {
  pending,
  syncing,
  failed,
}

class SyncMutation {
  const SyncMutation({
    required this.id,
    required this.tenantId,
    required this.membershipId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.status,
    this.baseVersion,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final String tenantId;
  final String membershipId;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, Object?> payload;
  final int? baseVersion;
  final DateTime createdAt;
  final SyncMutationStatus status;
  final int attemptCount;
  final String? lastError;
}

class LocalRecord {
  const LocalRecord({
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.isDirty,
    this.serverVersion,
  });

  final String tenantId;
  final String entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final int? serverVersion;
  final DateTime updatedAt;
  final bool isDirty;
}
