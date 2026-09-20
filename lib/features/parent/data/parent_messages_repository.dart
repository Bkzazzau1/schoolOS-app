import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_messages_models.dart';
import 'parent_messages_demo_data.dart';

class ParentMessagesRepository {
  ParentMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _snapshotEntityType = 'parent_messages_snapshot';
  static const _messageEntityType = 'parent_message';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentMessagesSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentMessagesSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: parentDefaultMessages.toJson(),
    );
    return parentDefaultMessages;
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

    final updatedThread = thread.copyWith(
      preview: normalizedBody,
      timeLabel: 'Queued',
      unread: false,
      messages: [...thread.messages, message],
    );
    final updatedSnapshot = snapshot.replaceThread(updatedThread);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: updatedSnapshot.toJson(),
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

  Future<void> replaceFromServer({
    required ParentMessagesSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _validateSnapshot(ParentMessagesSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Family messages are missing the family account id.');
    }

    final threadIds = <String>{};
    final messageIds = <String>{};
    for (final thread in snapshot.threads) {
      if (thread.id.trim().isEmpty || !threadIds.add(thread.id)) {
        throw StateError('Family messages contain an invalid thread id.');
      }
      if (!thread.approvedParticipant) {
        throw StateError('Family messages contain an unapproved participant.');
      }
      if (thread.participantName.trim().isEmpty ||
          thread.participantRole.trim().isEmpty ||
          thread.childLabel.trim().isEmpty) {
        throw StateError('A family message thread is missing participant scope.');
      }

      for (final message in thread.messages) {
        if (message.id.trim().isEmpty || !messageIds.add(message.id)) {
          throw StateError('Family messages contain an invalid message id.');
        }
        if (message.body.trim().isEmpty) {
          throw StateError('Family messages contain an empty message.');
        }
        if (message.direction == ParentMessageDirection.guardianToSchool &&
            message.state == ParentMessageState.received) {
          throw StateError('A guardian message cannot use the received state.');
        }
      }
    }
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
