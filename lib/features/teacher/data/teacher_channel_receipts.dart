import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../domain/teacher_messages_models.dart';

/// The real "I have seen this thread" receipt shared by Teacher Messages' own leadership
/// (`teacher_leadership_receipt`) and department (`teacher_department_receipt`) channels
/// (`apps/schoollife/messaging/teacher_channels.py`) - both real receipts share the exact same
/// shape, just under a different entity type per channel.

/// Every real receipt this membership has recorded for a channel, mapped by thread id to the
/// latest time they saw it - real state, computed from real receipt rows, never a stored flag.
Future<Map<String, DateTime>> loadOwnChannelReceipts(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
  required String receiptEntityType,
}) async {
  final records = await db.getLocalRecords(tenantId: tenantId, entityType: receiptEntityType);
  final latest = <String, DateTime>{};
  for (final record in records) {
    if (record.payload['membershipId'] != membershipId) continue;
    final threadId = record.payload['threadId'] as String?;
    final seenAt = _parseDate(record.payload['seenAt']);
    if (threadId == null || seenAt == null) continue;
    final existing = latest[threadId];
    if (existing == null || seenAt.isAfter(existing)) {
      latest[threadId] = seenAt;
    }
  }
  return latest;
}

/// A thread is unread when its own latest message was not sent by the person looking at it, and
/// either they have never recorded a receipt for it or a real message arrived after their last one.
bool isChannelThreadUnread(List<TeacherMessage> messages, DateTime? lastSeen) {
  if (messages.isEmpty) return false;
  final last = messages.last;
  if (last.isOutgoing) return false;
  if (lastSeen == null) return true;
  final createdAt = last.createdAt == null ? null : DateTime.tryParse(last.createdAt!)?.toLocal();
  return createdAt == null || createdAt.isAfter(lastSeen);
}

/// Queues this membership's own real receipt for a channel thread - create-only, the same
/// append-only shape every message in these channels already uses.
Future<void> queueChannelSeenReceipt(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
  required String threadId,
  required String receiptEntityType,
}) async {
  final now = DateTime.now().toUtc();
  final receiptId = '$membershipId:thread-seen:$threadId:${now.microsecondsSinceEpoch}';
  final wirePayload = <String, Object?>{
    'id': receiptId,
    'threadId': threadId,
    'seenAt': now.toIso8601String(),
  };
  final localPayload = <String, Object?>{
    ...wirePayload,
    'membershipId': membershipId,
  };
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: receiptEntityType,
    entityId: receiptId,
    payload: localPayload,
    isDirty: true,
  );
  await db.queueMutation(
    tenantId: tenantId,
    membershipId: membershipId,
    entityType: receiptEntityType,
    entityId: receiptId,
    operation: SyncOperation.create,
    payload: wirePayload,
  );
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
