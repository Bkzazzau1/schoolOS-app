import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../domain/parent_messages_models.dart';

/// The real "I have seen this thread" receipt for `parent_message` (`apps/schoollife/messaging/
/// parent_messages.py: ParentMessageReceiptHandler`) - shared by `ParentMessagesRepository` and
/// `TeacherFamilyMessagesRepository`, since both read and write the exact same real family thread,
/// just from the other real participant's point of view.
const parentMessageReceiptEntityType = 'parent_message_receipt';

/// Every real receipt this membership has recorded, mapped by thread id to the latest time they
/// saw it - real state, computed from real receipt rows, never a stored flag.
Future<Map<String, DateTime>> loadOwnThreadReceipts(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
}) async {
  final records = await db.getLocalRecords(
    tenantId: tenantId,
    entityType: parentMessageReceiptEntityType,
  );
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
bool isThreadUnread(List<ParentMessageItem> messages, DateTime? lastSeen) {
  if (messages.isEmpty) return false;
  final last = messages.last;
  if (last.authorLabel == 'You') return false;
  if (lastSeen == null) return true;
  return last.createdAt == null || last.createdAt!.isAfter(lastSeen);
}

/// Queues this membership's own real receipt for a thread - create-only, the same append-only
/// shape every message in this channel already uses.
Future<void> queueThreadSeenReceipt(
  LocalDatabase db, {
  required String tenantId,
  required String membershipId,
  required String threadId,
}) async {
  final now = DateTime.now().toUtc();
  final receiptId = '$membershipId:thread-seen:$threadId:${now.microsecondsSinceEpoch}';
  // The wire payload carries only what the app actually contributes; who really recorded this
  // receipt is the server's own stamp (see ParentMessageReceiptHandler.clean), never taken from
  // the app. The local cache copy also keeps membershipId so this device can compute its own
  // unread state immediately, before the next pull confirms it.
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
    entityType: parentMessageReceiptEntityType,
    entityId: receiptId,
    payload: localPayload,
    isDirty: true,
  );
  await db.queueMutation(
    tenantId: tenantId,
    membershipId: membershipId,
    entityType: parentMessageReceiptEntityType,
    entityId: receiptId,
    operation: SyncOperation.create,
    payload: wirePayload,
  );
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
