import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_messages_models.dart';
import 'parent_children_repository.dart';

class ParentMessagesRepository {
  ParentMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _children = children;

  static const _messageEntityType = 'parent_message';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;

  /// One real, approved communication channel per real linked child, scoped to their real class —
  /// never a pre-populated conversation that never actually happened. The server's own
  /// `ParentMessageHandler` (`apps/schoollife/messaging/parent_messages.py`) authorizes and publishes
  /// this same channel to the real guardian and the child's real current class teacher, so a reply
  /// from the actual class teacher lands here through the ordinary sync pull, read generically off
  /// this device's local cache the same way every other real sync entity is — not filtered to this
  /// membership's own messages the way a purely outbound channel would be.
  Future<ParentMessagesSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
    );
    final byThread = <String, List<ParentMessageItem>>{};
    for (final record in records) {
      final threadId = record.payload['threadId'] as String?;
      if (threadId == null) continue;
      byThread.putIfAbsent(threadId, () => []).add(
            ParentMessageItem.fromCanonical(
              payload: Map<String, Object?>.from(record.payload),
              viewerMembershipId: membership.id,
              isDirty: record.isDirty,
            ),
          );
    }

    final threads = <ParentMessageThread>[];
    for (final child in linked) {
      final threadId = 'channel-${child.id}';
      final messages = [...(byThread[threadId] ?? const <ParentMessageItem>[])]
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

      threads.add(ParentMessageThread(
        id: threadId,
        participantName: '${child.className} class channel',
        participantRole: 'Class communication · ${child.className}',
        childLabel: child.name,
        preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
        timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
        // No read-receipt record exists yet for this channel, so a real reply from the class
        // teacher is not tracked as seen/unseen — it is simply visible in the thread once pulled.
        unread: false,
        approvedParticipant: true,
        messages: messages,
      ));
    }

    return ParentMessagesSnapshot(familyAccountId: membership.id, threads: threads);
  }

  Future<ParentMessageItem> queueReply({
    required String threadId,
    required String body,
  }) async {
    final membership = _requireParentMembership();
    final normalizedThreadId = threadId.trim();
    final normalizedBody = body.trim();

    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Thread id is required.');
    }
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Message text is required.');
    }
    if (normalizedBody.length > 4000) {
      throw ArgumentError.value(
        body,
        'body',
        'Messages cannot exceed 4000 characters.',
      );
    }

    final snapshot = await load();
    final thread = snapshot.threadById(normalizedThreadId);
    if (thread == null || !thread.approvedParticipant) {
      throw StateError(
        'This conversation is not an approved family communication channel.',
      );
    }

    final now = DateTime.now().toUtc();
    final messageId = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    // The wire payload carries only what a guardian actually contributes; who really sent it and
    // when are the server's own stamp (see ParentMessageHandler.clean), never taken on trust from
    // the app. The local cache copy also keeps a same-shaped, locally-inferred author so this
    // device can render its own just-sent message correctly before the next pull confirms it.
    final wirePayload = <String, Object?>{
      'id': messageId,
      'threadId': thread.id,
      'body': normalizedBody,
    };
    final localPayload = <String, Object?>{
      ...wirePayload,
      'authorRole': 'parent',
      'authorMembershipId': membership.id,
      'createdAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
      entityId: messageId,
      payload: localPayload,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _messageEntityType,
      entityId: messageId,
      operation: SyncOperation.create,
      payload: wirePayload,
    );

    return ParentMessageItem.fromCanonical(
      payload: localPayload,
      viewerMembershipId: membership.id,
      isDirty: true,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family messages require an active Parent membership.');
    }
    return membership;
  }
}
