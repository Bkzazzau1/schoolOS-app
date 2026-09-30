import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_messages_models.dart';
import 'teacher_channel_receipts.dart';
import 'teacher_family_messages_repository.dart';
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
const _leadershipThreadPrefix = 'leadership-thread-';
const _departmentThreadPrefix = 'department-thread-';
const _leadershipMessageType = 'teacher_leadership_message';
const _leadershipReceiptType = 'teacher_leadership_receipt';
const _departmentMessageType = 'teacher_department_message';
const _departmentReceiptType = 'teacher_department_receipt';

/// Every channel Teacher Messages shows is now real: a guardian-group broadcast per real assigned
/// class (`_classThreads`, sending through the real `parent_message` channel - see
/// TeacherFamilyMessagesRepository), one real private thread to school leadership per real teacher,
/// and one real, shared thread per real subject a teacher currently teaches
/// (`apps/schoollife/messaging/teacher_channels.py`). Nothing here is demo furniture any more.
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

  Future<List<TeacherMessage>> _loadChannelMessages(
    SchoolMembership membership, {
    required String entityType,
    required String threadId,
  }) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: entityType,
    );
    final messages = [
      for (final record in records)
        if (record.payload['threadId'] == threadId)
          TeacherMessage.fromCanonical(
            payload: Map<String, Object?>.from(record.payload),
            viewerMembershipId: membership.id,
            isDirty: record.isDirty,
          ),
    ]..sort((a, b) => _parsed(a.createdAt).compareTo(_parsed(b.createdAt)));
    return messages;
  }

  /// The one real private thread from this teacher to school leadership
  /// (`apps/schoollife/messaging/teacher_channels.py: TeacherLeadershipMessageHandler`).
  Future<TeacherMessageThread> _leadershipThread(SchoolMembership membership) async {
    final threadId = '$_leadershipThreadPrefix${membership.id}';
    final messages = await _loadChannelMessages(membership, entityType: _leadershipMessageType, threadId: threadId);
    final receipts = await loadOwnChannelReceipts(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      receiptEntityType: _leadershipReceiptType,
    );
    return TeacherMessageThread(
      id: threadId,
      name: 'Academic Office',
      type: TeacherMessageChannelType.schoolLeadership,
      preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
      timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
      unread: isChannelThreadUnread(messages, receipts[threadId]) ? 1 : 0,
    );
  }

  /// One real, shared thread per real subject this teacher currently teaches
  /// (`apps/schoollife/messaging/teacher_channels.py: TeacherDepartmentMessageHandler`) -
  /// deduplicated the same way the guardian-group broadcast deduplicates by class, since a
  /// teacher who teaches the same subject to more than one class shares one department, not one
  /// per class.
  Future<List<TeacherMessageThread>> _departmentThreads(SchoolMembership membership) async {
    final assigned = await _roster.assignedClasses(membership);
    final subjectNameByCode = <String, String>{
      for (final entry in assigned)
        if (entry.subjectCode.trim().isNotEmpty) entry.subjectCode: entry.subject,
    };
    final threads = <TeacherMessageThread>[];
    for (final code in subjectNameByCode.keys) {
      final threadId = '$_departmentThreadPrefix$code';
      final messages = await _loadChannelMessages(membership, entityType: _departmentMessageType, threadId: threadId);
      final receipts = await loadOwnChannelReceipts(
        _localDatabase,
        tenantId: membership.schoolId,
        membershipId: membership.id,
        receiptEntityType: _departmentReceiptType,
      );
      threads.add(TeacherMessageThread(
        id: threadId,
        name: '${subjectNameByCode[code]} Department',
        type: TeacherMessageChannelType.staffChannel,
        preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
        timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
        unread: isChannelThreadUnread(messages, receipts[threadId]) ? 1 : 0,
      ));
    }
    threads.sort((a, b) => a.name.compareTo(b.name));
    return threads;
  }

  Future<TeacherMessagesSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.teacher) {
      return TeacherMessagesSnapshot(threads: const [], messages: const [], permissions: permissionsFor(membership));
    }

    final classThreads = await _classThreads(membership);
    final leadershipThread = await _leadershipThread(membership);
    final departmentThreads = await _departmentThreads(membership);

    final leadershipMessages = await _loadChannelMessages(membership, entityType: _leadershipMessageType, threadId: leadershipThread.id);
    final departmentMessages = <TeacherMessage>[];
    for (final thread in departmentThreads) {
      departmentMessages.addAll(await _loadChannelMessages(membership, entityType: _departmentMessageType, threadId: thread.id));
    }

    return TeacherMessagesSnapshot(
      threads: [...classThreads, leadershipThread, ...departmentThreads],
      messages: [...leadershipMessages, ...departmentMessages],
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
    if (trimmed.length > 4000) {
      return const TeacherMessageActionResult(
        success: false,
        message: 'Messages cannot exceed 4000 characters.',
      );
    }

    if (threadId.startsWith(_classThreadPrefix)) {
      return _broadcastToClass(membership, threadId: threadId, body: trimmed, attachmentName: attachmentName);
    }
    if (threadId == '$_leadershipThreadPrefix${membership.id}') {
      return _sendChannelMessage(membership, entityType: _leadershipMessageType, threadId: threadId, body: trimmed);
    }
    if (threadId.startsWith(_departmentThreadPrefix)) {
      final code = threadId.substring(_departmentThreadPrefix.length);
      final assigned = await _roster.assignedClasses(membership);
      final reallyTeaches = assigned.any((entry) => entry.subjectCode == code);
      if (!reallyTeaches) {
        return const TeacherMessageActionResult(
          success: false,
          message: 'Messages can only be queued to an approved channel you have access to.',
        );
      }
      return _sendChannelMessage(membership, entityType: _departmentMessageType, threadId: threadId, body: trimmed);
    }
    return const TeacherMessageActionResult(
      success: false,
      message: 'Messages can only be queued to an approved channel you have access to.',
    );
  }

  Future<TeacherMessageActionResult> _sendChannelMessage(
    SchoolMembership membership, {
    required String entityType,
    required String threadId,
    required String body,
  }) async {
    final now = DateTime.now().toUtc();
    final id = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    // The wire payload carries only what the teacher actually contributes; who really sent it
    // and when are the server's own stamp (see teacher_channels.py's own clean()), never taken
    // on trust from the app.
    final wirePayload = <String, Object?>{'id': id, 'threadId': threadId, 'body': body};
    final localPayload = <String, Object?>{
      ...wirePayload,
      'authorRole': membership.role.name,
      'authorMembershipId': membership.id,
      'createdAt': now.toIso8601String(),
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: id,
      payload: localPayload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: entityType,
      entityId: id,
      operation: SyncOperation.create,
      payload: wirePayload,
    );

    return TeacherMessageActionResult(
      success: true,
      message: 'Message queued locally. Sent, delivered and read status require authoritative acknowledgement.',
      queuedMessage: TeacherMessage.fromCanonical(payload: localPayload, viewerMembershipId: membership.id, isDirty: true),
    );
  }

  /// Records this teacher's own real receipt for their leadership thread or a department thread
  /// they are really part of. The guardian-group broadcast has no merged thread to mark seen (see
  /// `_classThreads`), so this is a no-op for those ids.
  Future<void> markThreadSeen(String threadId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.teacher) return;

    String receiptEntityType;
    if (threadId == '$_leadershipThreadPrefix${membership.id}') {
      receiptEntityType = _leadershipReceiptType;
    } else if (threadId.startsWith(_departmentThreadPrefix)) {
      receiptEntityType = _departmentReceiptType;
    } else {
      return;
    }

    final snapshot = await load();
    final thread = snapshot.threads.where((t) => t.id == threadId).firstOrNull;
    if (thread == null || thread.unread == 0) return;
    await queueChannelSeenReceipt(
      _localDatabase,
      tenantId: membership.schoolId,
      membershipId: membership.id,
      threadId: threadId,
      receiptEntityType: receiptEntityType,
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
}

DateTime _parsed(String? value) => value == null ? DateTime(0) : (DateTime.tryParse(value) ?? DateTime(0));

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
