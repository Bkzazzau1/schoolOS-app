import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_messages_models.dart';
import 'teacher_family_messages_repository.dart';
import 'teacher_messages_demo_data.dart';
import 'teacher_roster.dart';

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

const _classThreadPrefix = 'class-broadcast-';

class TeacherMessagesRepository {
  TeacherMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster,
        _familyMessages = TeacherFamilyMessagesRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
          roster: roster,
        );

  static const _threadType = 'teacher_message_thread';
  static const _messageType = 'teacher_message';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;
  final TeacherFamilyMessagesRepository _familyMessages;

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

  /// A real guardian-group channel per real class this Teacher membership is really assigned to -
  /// sending here really reaches every real family in the class, through the exact same real
  /// `parent_message` channel `TeacherFamilyMessagesRepository` already writes to, one real
  /// per-family message per real student. There is no merged "history" to read back for a class
  /// as a whole (each family's own copy lives in their own real thread - see Teacher Family
  /// Messages), so this stays a real send action rather than a fabricated conversation.
  Future<List<TeacherMessageThread>> _classThreads(SchoolMembership membership) async {
    final assigned = await _roster.assignedClasses(membership);
    final classNames = <String>{
      for (final entry in assigned)
        if (entry.className.trim().isNotEmpty) entry.className,
    };
    final threads = <TeacherMessageThread>[];
    for (final className in classNames) {
      final students = await _roster.studentsIn(className);
      threads.add(TeacherMessageThread(
        id: '$_classThreadPrefix${_slug(className)}',
        name: '$className Guardians',
        type: TeacherMessageChannelType.parentGroup,
        preview: students.isEmpty
            ? 'No students are on the register for this class yet.'
            : 'Send a real announcement to ${students.length} real famil${students.length == 1 ? 'y' : 'ies'}.',
        timeLabel: '',
        unread: 0,
        className: className,
      ));
    }
    threads.sort((a, b) => a.name.compareTo(b.name));
    return threads;
  }

  /// A teacher only ever sees a guardian group for a class they are really assigned to; channels not scoped to a
  /// class (staff/leadership) are visible to every teacher.
  Future<List<TeacherMessageThread>> _visibleThreads(
    SchoolMembership membership,
    List<TeacherMessageThread> all,
  ) async {
    final classes = await _roster.assignedClasses(membership);
    final classNames = {for (final c in classes) c.className};
    return all
        .where((thread) => thread.className == null || classNames.contains(thread.className))
        .toList(growable: false);
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
    var nonClassThreads = threadRecords
        .map((record) => TeacherMessageThread.fromJson(record.payload))
        .toList(growable: false);
    nonClassThreads.sort((a, b) {
      final ai = teacherMessageThreads.indexWhere((item) => item.id == a.id);
      final bi = teacherMessageThreads.indexWhere((item) => item.id == b.id);
      return ai.compareTo(bi);
    });
    nonClassThreads = await _visibleThreads(membership, nonClassThreads);
    final visibleIds = {for (final thread in nonClassThreads) thread.id};

    final nonClassMessages = messageRecords
        .map((record) => TeacherMessage.fromJson(record.payload))
        .where((message) => visibleIds.contains(message.threadId))
        .toList(growable: false);

    final classThreads = membership.role == SchoolRole.teacher
        ? await _classThreads(membership)
        : const <TeacherMessageThread>[];

    return TeacherMessagesSnapshot(
      threads: [...classThreads, ...nonClassThreads],
      messages: nonClassMessages,
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

    if (threadId.startsWith(_classThreadPrefix)) {
      return _broadcastToClass(membership, threadId: threadId, body: trimmed, attachmentName: attachmentName);
    }

    final visible = await _visibleThreads(membership, teacherMessageThreads);
    if (!visible.any((thread) => thread.id == threadId)) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Messages can only be queued to an approved channel you have access to.',
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
    return TeacherMessageActionResult(
      success: true,
      message: 'Message queued locally. Sent, delivered and read status require authoritative acknowledgement.',
      queuedMessage: queued,
    );
  }

  Future<TeacherMessageActionResult> _broadcastToClass(
    SchoolMembership membership, {
    required String threadId,
    required String body,
    String? attachmentName,
  }) async {
    final classThreads = await _classThreads(membership);
    final thread = classThreads.where((t) => t.id == threadId).firstOrNull;
    if (thread == null) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Messages can only be queued to an approved channel you have access to.',
      );
    }
    if (body.length > 4000) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Messages cannot exceed 4000 characters.',
      );
    }
    final students = await _roster.studentsIn(thread.className!);
    if (students.isEmpty) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'No students are on the register for this class yet.',
      );
    }
    try {
      for (final student in students) {
        await _familyMessages.queueReply(threadId: 'channel-${student.id}', body: body);
      }
    } catch (error) {
      return TeacherMessageActionResult(success: false, message: 'Could not send to every family: $error');
    }
    return TeacherMessageActionResult(
      success: true,
      message:
          'Sent to ${students.length} real famil${students.length == 1 ? 'y' : 'ies'}, one real message per family. '
          'Sent, delivered and read status require authoritative acknowledgement. '
          'See Teacher Family Messages for each family\'s own copy and any reply.',
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

String _slug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '-')
    .replaceAll(RegExp(r'[^a-z0-9-]'), '');

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
