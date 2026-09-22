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

  /// One real, approved communication channel per real linked child, scoped to their real class — never
  /// a pre-populated conversation that never actually happened. No real school-to-guardian messaging
  /// system exists anywhere in the app yet (Teacher's own Messages screen is class-wide sample content
  /// that was never addressed to a specific real family — see docs/BACKEND_INTEGRATION.md), so every
  /// channel honestly starts with zero messages until the guardian queues a real one with [queueReply].
  Future<ParentMessagesSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
    );
    final queuedByThread = <String, List<ParentMessageItem>>{};
    for (final record in records) {
      if (record.payload['membershipId'] != membership.id) continue;
      final threadId = record.payload['threadId'] as String?;
      if (threadId == null) continue;
      queuedByThread
          .putIfAbsent(threadId, () => [])
          .add(ParentMessageItem.fromJson(Map<String, dynamic>.from(record.payload)));
    }

    final threads = <ParentMessageThread>[];
    for (final child in linked) {
      final threadId = 'channel-${child.id}';
      final messages = [...(queuedByThread[threadId] ?? const <ParentMessageItem>[])]
        ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));

      threads.add(ParentMessageThread(
        id: threadId,
        participantName: '${child.className} class channel',
        participantRole: 'Class communication · ${child.className}',
        childLabel: child.name,
        preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
        timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
        // Every real message here is guardian-authored — no real school-to-guardian channel exists
        // yet — so there is nothing school-sent for a guardian to have left unread.
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

    final now = DateTime.now();
    final messageId =
        'LOCAL-${membership.id}-${now.toUtc().microsecondsSinceEpoch}';
    final message = ParentMessageItem(
      id: messageId,
      direction: ParentMessageDirection.guardianToSchool,
      authorLabel: 'You',
      body: normalizedBody,
      timeLabel: _clockLabel(now),
      state: ParentMessageState.queued,
      createdAt: now,
    );

    final payload = message.toJson()
      ..addAll(<String, Object?>{
        'membershipId': membership.id,
        'threadId': thread.id,
      });

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _messageEntityType,
      entityId: message.id,
      payload: payload,
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _messageEntityType,
      entityId: message.id,
      operation: SyncOperation.create,
      payload: {
        'messageId': message.id,
        'threadId': thread.id,
        'familyAccountId': snapshot.familyAccountId,
        'participantName': thread.participantName,
        'participantRole': thread.participantRole,
        'childLabel': thread.childLabel,
        'body': normalizedBody,
        'deliveryState': ParentMessageState.queued.name,
        'createdAt': now.toUtc().toIso8601String(),
      },
    );

    return message;
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family messages require an active Parent membership.');
    }
    return membership;
  }

  String _clockLabel(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
