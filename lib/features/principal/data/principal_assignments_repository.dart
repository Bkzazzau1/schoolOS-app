import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_assignments_models.dart';
import 'principal_assignments_demo_data.dart';

class PrincipalAssignmentsSnapshot {
  const PrincipalAssignmentsSnapshot({
    required this.assignments,
    required this.teachers,
    required this.transfers,
    required this.permissions,
  });

  final List<PrincipalTeachingAssignment> assignments;
  final List<PrincipalAssignmentTeacher> teachers;
  final List<PrincipalAssignmentTransfer> transfers;
  final PrincipalAssignmentPermissions permissions;
}

class PrincipalAssignmentActionResult {
  const PrincipalAssignmentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class PrincipalAssignmentsRepository {
  PrincipalAssignmentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _assignmentType = 'principal_teaching_assignment';
  static const _teacherType = 'principal_assignment_teacher';
  static const _transferType = 'principal_assignment_transfer';
  static const _historyType = 'principal_assignment_history';
  static const _accessType = 'teaching_record_access_grant';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalAssignmentPermissions permissionsFor(SchoolMembership membership) => PrincipalAssignmentPermissions(
        canManageSecondaryAssignments: membership.role == SchoolRole.principal,
        canCreateProvisionalTargets: membership.role == SchoolRole.principal,
        canTransferWork: membership.role == SchoolRole.principal,
        canManagePrimary: false,
      );

  Future<PrincipalAssignmentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final teacherRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _teacherType,
    );
    final transferRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _transferType,
    );

    final assignments = assignmentRecords
        .map((record) => PrincipalTeachingAssignment.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final teachers = teacherRecords
        .map((record) => PrincipalAssignmentTeacher.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final transfers = transferRecords
        .map((record) => PrincipalAssignmentTransfer.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.transferredAt.compareTo(a.transferredAt));

    return PrincipalAssignmentsSnapshot(
      assignments: assignments,
      teachers: teachers,
      transfers: transfers,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalAssignmentActionResult> addAssignment({
    required String className,
    required String subject,
    required String teacherId,
    required int periodsPerWeek,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageSecondaryAssignments) {
      return const PrincipalAssignmentActionResult(success: false, message: 'This membership cannot manage Secondary teaching assignments.');
    }
    if (!principalAssignmentClasses.contains(className)) {
      return const PrincipalAssignmentActionResult(success: false, message: 'That class is outside the active Secondary leadership scope.');
    }
    if (periodsPerWeek < 1 || periodsPerWeek > 10) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Periods per week must be between 1 and 10.');
    }

    final snapshot = await load();
    final teacher = snapshot.teachers.where((item) => item.id == teacherId).firstOrNull;
    if (teacher == null) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Choose a valid teacher.');
    }
    if (!teacher.canTeach(subject)) {
      return PrincipalAssignmentActionResult(success: false, message: '${teacher.name} is not listed as qualified for $subject.');
    }
    if (snapshot.assignments.any((item) => item.className == className && item.subject == subject)) {
      return PrincipalAssignmentActionResult(success: false, message: '$className already has a $subject assignment. Transfer or edit the existing responsibility instead.');
    }

    final id = 'ASN-${DateTime.now().microsecondsSinceEpoch}';
    final assignment = PrincipalTeachingAssignment(
      id: id,
      className: className,
      subject: subject,
      teacherId: teacherId,
      periodsPerWeek: periodsPerWeek,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: id,
      payload: assignment.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: id,
      operation: SyncOperation.create,
      payload: assignment.toJson(),
    );
    return PrincipalAssignmentActionResult(success: true, message: '${teacher.name} assigned to $subject for $className. Saved offline and queued for sync.');
  }

  Future<PrincipalAssignmentActionResult> transferAssignment({
    required String assignmentId,
    String? existingTeacherId,
    String? newStaffName,
    String? newStaffDepartment,
    required String reason,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canTransferWork) {
      return const PrincipalAssignmentActionResult(success: false, message: 'This membership cannot transfer Secondary teaching work.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Add a transfer reason so the handover remains auditable.');
    }

    final snapshot = await load();
    final assignment = snapshot.assignments.where((item) => item.id == assignmentId).firstOrNull;
    if (assignment == null) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Teaching assignment not found.');
    }

    PrincipalAssignmentTeacher target;
    if ((existingTeacherId ?? '').trim().isNotEmpty) {
      final match = snapshot.teachers.where((item) => item.id == existingTeacherId).firstOrNull;
      if (match == null) {
        return const PrincipalAssignmentActionResult(success: false, message: 'Choose a valid receiving teacher.');
      }
      target = match;
    } else {
      if (!permissions.canCreateProvisionalTargets) {
        return const PrincipalAssignmentActionResult(success: false, message: 'This membership cannot create a provisional teaching target.');
      }
      final name = (newStaffName ?? '').trim();
      if (name.isEmpty) {
        return const PrincipalAssignmentActionResult(success: false, message: 'Add the new staff member’s name.');
      }
      final targetId = 'PST-${DateTime.now().microsecondsSinceEpoch}';
      target = PrincipalAssignmentTeacher(
        id: targetId,
        name: name,
        department: (newStaffDepartment ?? '').trim().isEmpty ? 'Pending onboarding' : newStaffDepartment!.trim(),
        qualifiedSubjects: [assignment.subject],
        weeklyPeriods: 0,
        provisional: true,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _teacherType,
        entityId: target.id,
        payload: target.toJson(),
        isDirty: true,
      );
      await _localDatabase.queueMutation(
        tenantId: membership.schoolId,
        membershipId: membership.id,
        entityType: _teacherType,
        entityId: target.id,
        operation: SyncOperation.create,
        payload: target.toJson(),
      );
    }

    if (target.id == assignment.teacherId) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Choose a different receiving teacher.');
    }
    if (!target.canTeach(assignment.subject)) {
      return PrincipalAssignmentActionResult(success: false, message: '${target.name} is not listed as qualified for ${assignment.subject}. Transfer was not made.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final transferId = 'TRN-${DateTime.now().microsecondsSinceEpoch}';
    final oldVersion = assignment.version;
    final updated = assignment.copyWith(teacherId: target.id, version: oldVersion + 1);
    final transfer = PrincipalAssignmentTransfer(
      id: transferId,
      assignmentId: assignment.id,
      className: assignment.className,
      subject: assignment.subject,
      fromTeacherId: assignment.teacherId,
      toTeacherId: target.id,
      reason: normalizedReason,
      transferredByMembershipId: membership.id,
      transferredAt: now,
      recordScope: principalTransferRecordScope,
      previousAssignmentVersion: oldVersion,
      newAssignmentVersion: updated.version,
    );
    final access = PrincipalTeachingRecordAccess(
      id: 'ACCESS-${assignment.id}-${target.id}',
      assignmentId: assignment.id,
      teacherId: target.id,
      className: assignment.className,
      subject: assignment.subject,
      recordScope: principalTransferRecordScope,
      grantedByMembershipId: membership.id,
      grantedAt: now,
      provisionalTarget: target.provisional,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _historyType,
      entityId: '${assignment.id}-v$oldVersion',
      payload: {...assignment.toJson(), 'archivedAt': now, 'transferId': transferId},
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _historyType,
      entityId: '${assignment.id}-v$oldVersion',
      operation: SyncOperation.create,
      payload: {...assignment.toJson(), 'archivedAt': now, 'transferId': transferId},
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _transferType,
      entityId: transfer.id,
      payload: transfer.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _transferType,
      entityId: transfer.id,
      operation: SyncOperation.create,
      payload: transfer.toJson(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _accessType,
      entityId: access.id,
      payload: access.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _accessType,
      entityId: access.id,
      operation: SyncOperation.create,
      payload: access.toJson(),
    );

    final accessMessage = target.provisional
        ? ' The complete teaching handover is preserved now and will become available when this provisional target is linked to the staff account.'
        : ' The receiving teacher now inherits the teaching-record access package for this responsibility.';
    return PrincipalAssignmentActionResult(
      success: true,
      message: '${assignment.className} · ${assignment.subject} transferred to ${target.name}.$accessMessage',
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final teachers = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _teacherType);
    if (teachers.isEmpty) {
      for (final teacher in principalAssignmentTeachers) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _teacherType,
          entityId: teacher.id,
          payload: teacher.toJson(),
        );
      }
    }
    final assignments = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _assignmentType);
    if (assignments.isEmpty) {
      for (final assignment in principalAssignmentSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _assignmentType,
          entityId: assignment.id,
          payload: assignment.toJson(),
        );
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
