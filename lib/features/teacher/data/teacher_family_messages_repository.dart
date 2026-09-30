import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../parent/domain/parent_messages_models.dart';
import '../domain/teacher_family_messages_models.dart';
import 'teacher_roster.dart';

/// A real reply channel per real family, scoped to the classes this Teacher membership is really
/// assigned to — the same server-authorized `parent_message` conversation
/// `ParentMessagesRepository` reads from the guardian's own side (see
/// `apps/schoollife/messaging/parent_messages.py`). Deliberately separate from
/// `TeacherMessagesRepository`, whose own class-wide guardian-group channels and threads are
/// untouched by this: that is a broadcast channel to a whole class; this is one real, private
/// conversation per real family.
class TeacherFamilyMessagesRepository {
  TeacherFamilyMessagesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _messageEntityType = 'parent_message';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  Future<TeacherFamilyMessagesSnapshot> load() async {
    final membership = _requireTeacherMembership();

    final assigned = await _roster.assignedClasses(membership);
    final classNames = <String>{
      for (final entry in assigned)
        if (entry.className.trim().isNotEmpty) entry.className,
    };

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
    for (final className in classNames) {
      final students = await _roster.studentsIn(className);
      for (final student in students) {
        final threadId = 'channel-${student.id}';
        final messages = [...(byThread[threadId] ?? const <ParentMessageItem>[])]
          ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
        final guardianLabel =
            student.primaryGuardian.trim().isEmpty ? 'Guardian' : student.primaryGuardian;

        threads.add(ParentMessageThread(
          id: threadId,
          participantName: guardianLabel,
          participantRole: 'Guardian · $className',
          childLabel: student.name,
          preview: messages.isEmpty ? 'No messages yet' : messages.last.body,
          timeLabel: messages.isEmpty ? '' : messages.last.timeLabel,
          unread: false,
          approvedParticipant: true,
          messages: messages,
        ));
      }
    }

    return TeacherFamilyMessagesSnapshot(teacherMembershipId: membership.id, threads: threads);
  }

  Future<ParentMessageItem> queueReply({
    required String threadId,
    required String body,
  }) async {
    final membership = _requireTeacherMembership();
    final normalizedThreadId = threadId.trim();
    final normalizedBody = body.trim();

    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(threadId, 'threadId', 'Thread id is required.');
    }
    if (normalizedBody.isEmpty) {
      throw ArgumentError.value(body, 'body', 'Message text is required.');
    }
    if (normalizedBody.length > 4000) {
      throw ArgumentError.value(body, 'body', 'Messages cannot exceed 4000 characters.');
    }

    final snapshot = await load();
    final thread = snapshot.threadById(normalizedThreadId);
    if (thread == null || !thread.approvedParticipant) {
      throw StateError('This is not a family conversation you teach into.');
    }

    final now = DateTime.now().toUtc();
    final messageId = 'LOCAL-${membership.id}-${now.microsecondsSinceEpoch}';

    final wirePayload = <String, Object?>{
      'id': messageId,
      'threadId': thread.id,
      'body': normalizedBody,
    };
    final localPayload = <String, Object?>{
      ...wirePayload,
      'authorRole': 'teacher',
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

  SchoolMembership _requireTeacherMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.teacher) {
      throw StateError('Family reply messages require an active Teacher membership.');
    }
    return membership;
  }
}
