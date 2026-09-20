import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_assignment_models.dart';
import 'teacher_assignment_demo_data.dart';

class TeacherAssignmentSnapshot {
  const TeacherAssignmentSnapshot({
    required this.assignments,
    required this.draft,
    required this.permissions,
  });

  final List<TeacherAssignment> assignments;
  final TeacherAssignment draft;
  final TeacherAssignmentPermissions permissions;
}

class TeacherAssignmentActionResult {
  const TeacherAssignmentActionResult({
    required this.success,
    required this.message,
    this.assignment,
  });

  final bool success;
  final String message;
  final TeacherAssignment? assignment;
}

class TeacherAssignmentRepository {
  TeacherAssignmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _assignmentType = 'teacher_assignment';
  static const _eventType = 'teacher_assignment_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherAssignmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssignmentPermissions(
      canViewAssignedClassAssignments: teacher,
      canCreateDraft: teacher,
      canQueuePublication: teacher,
      canConfirmPublication: false,
      canConfirmScores: teacher,
      canAutoGrade: false,
    );
  }

  Future<TeacherAssignmentSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = records
        .map((record) => TeacherAssignment.fromJson(record.payload))
        .toList(growable: false);
    final draft = assignments.firstWhere(
      (item) => item.id == teacherAssignmentDraft.id,
      orElse: () => teacherAssignmentDraft,
    );
    final library = assignments
        .where((item) => item.id != teacherAssignmentDraft.id)
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return TeacherAssignmentSnapshot(
      assignments: library,
      draft: draft,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherAssignmentActionResult> saveDraft(TeacherAssignment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canCreateDraft) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'This membership cannot create Teacher assignment drafts.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'A queued or published assignment cannot be silently rewritten.',
      );
    }
    if (draft.title.trim().isEmpty || draft.instructions.trim().isEmpty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Add an assignment title and instructions before saving.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssignmentState.draft,
      version: draft.version + 1,
      updatedAt: now,
    );
    await _persist(membership, updated);
    await _appendEvent(
      membership,
      assignment: updated,
      action: TeacherAssignmentEventAction.savedDraft,
      occurredAt: now,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment draft saved locally and queued for synchronization.',
      assignment: updated,
    );
  }

  Future<TeacherAssignmentActionResult> queuePublication(TeacherAssignment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canQueuePublication) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'This membership cannot publish Teacher assignments.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'This assignment is already queued or published.',
      );
    }
    if (draft.title.trim().isEmpty ||
        draft.instructions.trim().isEmpty ||
        draft.maximumScore <= 0 ||
        draft.dueDate.trim().isEmpty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Complete title, instructions, due date and maximum score before publication.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: now,
      queuedAt: now,
    );
    await _persist(membership, updated);
    await _appendEvent(
      membership,
      assignment: updated,
      action: TeacherAssignmentEventAction.queuedForPublication,
      occurredAt: now,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment queued for publication. Student delivery is not confirmed until the server acknowledges it.',
      assignment: updated,
    );
  }

  Future<void> _persist(
    SchoolMembership membership,
    TeacherAssignment assignment,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: assignment.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: SyncOperation.update,
      payload: assignment.toJson(),
    );
  }

  Future<void> _appendEvent(
    SchoolMembership membership, {
    required TeacherAssignment assignment,
    required TeacherAssignmentEventAction action,
    required String occurredAt,
  }) async {
    final event = TeacherAssignmentEvent(
      id: '${assignment.id}-${DateTime.now().microsecondsSinceEpoch}',
      assignmentId: assignment.id,
      action: action,
      actorMembershipId: membership.id,
      version: assignment.version,
      occurredAt: occurredAt,
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
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    if (records.isNotEmpty) return;
    for (final assignment in [...teacherAssignments, teacherAssignmentDraft]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _assignmentType,
        entityId: assignment.id,
        payload: assignment.toJson(),
      );
    }
  }
}
