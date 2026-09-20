import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_messages_models.dart';
import 'teacher_messages_demo_data.dart';

class TeacherMessagesSnapshot {
  const TeacherMessagesSnapshot({
    required this.threads,
    required this.messages,
    required this.permissions,
  });

  final List<TeacherMessageThread> threads;
  final List<TeacherMessage> messages;
  final TeacherMessagePermissions permissions;

  List<TeacherMessage> messagesForThread(String threadId) => messages
      .where((message) => message.threadId == threadId)
      .toList(growable: false);
}

class TeacherMessageActionResult {
  const TeacherMessageActionResult({
    required this.success,
    required this.message,
    this.queuedMessage,
  });

  final bool success;
  final String message;
  final TeacherMessage? queuedMessage;
}

class TeacherMessagesRepository {
  TeacherMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _threadType = 'teacher_message_thread';
  static const _messageType = 'teacher_message';
  static const _eventType = 'teacher_message_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherMessagePermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherMessagePermissions(
      canViewApprovedChannels: teacher,
      canQueueMessages: teacher,
      canViewPrivateContactDetails: false,
      canConfirmSent: false,
      canConfirmDelivered: false,
      canConfirmRead: false,
      canUseAiDraft: teacher,
    );
  }

  Future<TeacherMessagesSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final threadRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _threadType,
    );
    final messageRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageType,
    );
    final threads = threadRecords
        .map((record) => TeacherMessageThread.fromJson(record.payload))
        .toList(growable: false);
    threads.sort((a, b) {
      final ai = teacherMessageThreads.indexWhere((item) => item.id == a.id);
      final bi = teacherMessageThreads.indexWhere((item) => item.id == b.id);
      return ai.compareTo(bi);
    });
    final messages = messageRecords
        .map((record) => TeacherMessage.fromJson(record.payload))
        .toList(growable: false);
    messages.sort((a, b) {
      final aSeed = teacherMessageSeedMessages.indexWhere((item) => item.id == a.id);
      final bSeed = teacherMessageSeedMessages.indexWhere((item) => item.id == b.id);
      if (aSeed >= 0 && bSeed >= 0) return aSeed.compareTo(bSeed);
      if (aSeed >= 0) return -1;
      if (bSeed >= 0) return 1;
      return (a.createdAt ?? '').compareTo(b.createdAt ?? '');
    });
    return TeacherMessagesSnapshot(
      threads: threads,
      messages: messages,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherMessageActionResult> queueMessage({
    required String threadId,
    required String body,
    String? attachmentName,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canQueueMessages) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'This membership cannot send Teacher messages.',
      );
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Write a professional school message before sending.',
      );
    }
    final approved = teacherMessageThreads.any((thread) => thread.id == threadId);
    if (!approved) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Messages can only be queued to approved SchoolOS channels.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'teacher-msg-${DateTime.now().microsecondsSinceEpoch}';
    final queued = TeacherMessage(
      id: id,
      threadId: threadId,
      direction: TeacherMessageDirection.outgoing,
      body: trimmed,
      timeLabel: 'Queued',
      deliveryState: TeacherMessageDeliveryState.queued,
      createdAt: now,
      attachmentName: attachmentName,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _messageType,
      entityId: queued.id,
      payload: queued.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _messageType,
      entityId: queued.id,
      operation: SyncOperation.create,
      payload: queued.toJson(),
    );
    final event = TeacherMessageEvent(
      id: '$id-queued',
      messageId: id,
      threadId: threadId,
      action: TeacherMessageEventAction.queued,
      actorMembershipId: membership.id,
      occurredAt: now,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );
    return TeacherMessageActionResult(
      success: true,
      message: 'Message queued locally. Sent, delivered and read status require authoritative acknowledgement.',
      queuedMessage: queued,
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final threads = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _threadType,
    );
    if (threads.isEmpty) {
      for (final thread in teacherMessageThreads) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _threadType,
          entityId: thread.id,
          payload: thread.toJson(),
        );
      }
    }
    final messages = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _messageType,
    );
    if (messages.isEmpty) {
      for (final message in teacherMessageSeedMessages) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _messageType,
          entityId: message.id,
          payload: message.toJson(),
        );
      }
    }
  }
}
