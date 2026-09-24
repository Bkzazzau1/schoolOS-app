import 'dart:math';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/principal_assignments_models.dart';

class PrincipalAssignmentsSnapshot {
  const PrincipalAssignmentsSnapshot({
    required this.assignments,
    required this.teachers,
    required this.transfers,
    required this.classOptions,
    required this.subjectOptions,
    required this.unassigned,
    required this.permissions,
  });

  final List<PrincipalTeachingAssignment> assignments;
  final List<PrincipalAssignmentTeacher> teachers;
  final List<PrincipalAssignmentTransfer> transfers;
  final List<String> classOptions;
  final List<String> subjectOptions;
  final List<PrincipalUnassignedSubject> unassigned;
  final PrincipalAssignmentPermissions permissions;
}

class PrincipalAssignmentActionResult {
  const PrincipalAssignmentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

bool _teaches(AdministratorStaffRecord record) => record.role.toLowerCase().contains('teacher');

class _CurriculumOffering {
  const _CurriculumOffering({
    required this.id,
    required this.className,
    required this.subject,
    required this.periods,
  });

  final String id;
  final String className;
  final String subject;
  final int periods;
}

class PrincipalAssignmentsRepository {
  PrincipalAssignmentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required Object students,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _staff = staff;

  static const _assignmentType = 'academic_teaching_assignment';
  static const _classSubjectType = 'academic_class_subject';
  static const _classType = 'academic_class';
  static const _transferType = 'principal_assignment_transfer';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final OwnerStaffProfileRepository _staff;

  PrincipalAssignmentPermissions permissionsFor(SchoolMembership membership) =>
      PrincipalAssignmentPermissions(
        canManageSecondaryAssignments: membership.role == SchoolRole.principal,
        canCreateProvisionalTargets: false,
        canTransferWork: membership.role == SchoolRole.principal,
        canManagePrimary: false,
      );

  Future<List<_CurriculumOffering>> _secondaryCurriculum(
    SchoolMembership membership,
  ) async {
    final classRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    final secondaryClassIds = <String>{};
    for (final record in classRecords) {
      if (record.isDirty) continue;
      final section = record.payload['section'] as String? ?? '';
      final active = record.payload['isActive'] as bool? ?? true;
      if (section.toLowerCase() == 'secondary' && active) {
        secondaryClassIds.add(record.entityId);
      }
    }
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classSubjectType,
    );
    final values = <_CurriculumOffering>[];
    for (final record in records) {
      if (record.isDirty) continue;
      final payload = record.payload;
      final classId = payload['classId'] as String? ?? '';
      if (!secondaryClassIds.contains(classId)) continue;
      if (!(payload['isActive'] as bool? ?? true)) continue;
      final className = payload['className'] as String? ?? '';
      final subject = payload['subjectName'] as String? ?? '';
      if (className.isEmpty || subject.isEmpty) continue;
      values.add(
        _CurriculumOffering(
          id: record.entityId,
          className: className,
          subject: subject,
          periods: payload['periodsPerWeek'] as int? ?? 1,
        ),
      );
    }
    values.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return values;
  }

  Future<List<PrincipalAssignmentTeacher>> _secondaryTeachers(
    List<PrincipalTeachingAssignment> assignments,
    List<String> subjectOptions,
  ) async {
    final all = await _staff.people();
    return [
      for (final person in all)
        if (person.section == 'Secondary' && _teaches(person))
          PrincipalAssignmentTeacher(
            id: person.id,
            name: person.name,
            department: 'Staff profile',
            // SchoolOS does not infer professional qualification from a job title.
            // Until a verified subject-qualification domain is added, curriculum
            // assignment is an explicit Principal responsibility.
            qualifiedSubjects: subjectOptions,
            weeklyPeriods: assignments
                .where((item) => item.teacherId == person.id)
                .fold<int>(0, (sum, item) => sum + item.periodsPerWeek),
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<PrincipalAssignmentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final curriculum = await _secondaryCurriculum(membership);
    final offeringIds = {for (final item in curriculum) item.id};

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = <PrincipalTeachingAssignment>[];
    for (final record in assignmentRecords) {
      final value = PrincipalTeachingAssignment.fromJson(
        record.payload,
        pendingSync: record.isDirty,
      );
      if (!offeringIds.contains(value.classSubjectId)) continue;
      assignments.add(value);
    }
    assignments.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });

    final classOptions = {for (final item in curriculum) item.className}.toList()..sort();
    final subjectOptions = {for (final item in curriculum) item.subject}.toList()..sort();
    final teachers = await _secondaryTeachers(assignments, subjectOptions);
    final assignedOfferingIds = {for (final item in assignments) item.classSubjectId};
    final unassigned = [
      for (final item in curriculum)
        if (!assignedOfferingIds.contains(item.id))
          PrincipalUnassignedSubject(
            classSubjectId: item.id,
            className: item.className,
            subject: item.subject,
            periods: item.periods,
          ),
    ];

    final transferRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _transferType,
    );
    final transfers = transferRecords
        .map((record) => PrincipalAssignmentTransfer.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.transferredAt.compareTo(a.transferredAt));

    return PrincipalAssignmentsSnapshot(
      assignments: assignments,
      teachers: teachers,
      transfers: transfers,
      classOptions: classOptions,
      subjectOptions: subjectOptions,
      unassigned: unassigned,
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
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'This membership cannot manage Secondary teaching assignments.',
      );
    }
    final curriculum = await _secondaryCurriculum(membership);
    final offering = curriculum.where(
      (item) => item.className == className && item.subject == subject,
    ).firstOrNull;
    if (offering == null) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Choose a class-subject that exists in the canonical Secondary curriculum.',
      );
    }
    final snapshot = await load();
    final teacher = snapshot.teachers.where((item) => item.id == teacherId).firstOrNull;
    if (teacher == null) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Choose a real Secondary teacher in the staff directory.');
    }
    if (snapshot.assignments.any((item) => item.classSubjectId == offering.id)) {
      return PrincipalAssignmentActionResult(
        success: false,
        message: '$className · $subject already has a teaching responsibility. Transfer it instead.',
      );
    }
    final id = _newId();
    final assignment = PrincipalTeachingAssignment(
      id: id,
      className: className,
      subject: subject,
      teacherId: teacherId,
      periodsPerWeek: offering.periods,
      classSubjectId: offering.id,
      accessReady: false,
      pendingSync: true,
    );
    await _persist(membership, assignment, operation: SyncOperation.create);
    return PrincipalAssignmentActionResult(
      success: true,
      message: '${teacher.name} assigned to $subject for $className. ${offering.periods} periods/week comes from the canonical curriculum. Queued for server confirmation.',
    );
  }

  Future<PrincipalAssignmentActionResult> transferAssignment({
    required String assignmentId,
    String? existingTeacherId,
    String? newStaffName,
    String? newStaffDepartment,
    required String reason,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canTransferWork) {
      return const PrincipalAssignmentActionResult(success: false, message: 'This membership cannot transfer Secondary teaching work.');
    }
    if ((newStaffName ?? '').trim().isNotEmpty) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Onboard the new staff member first. Canonical teaching responsibility cannot be assigned to a provisional person.',
      );
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
    final targetId = (existingTeacherId ?? '').trim();
    final target = snapshot.teachers.where((item) => item.id == targetId).firstOrNull;
    if (target == null) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Choose a real receiving teacher.');
    }
    if (target.id == assignment.teacherId) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Choose a different receiving teacher.');
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
    );
    if (existing == null) {
      return const PrincipalAssignmentActionResult(success: false, message: 'Teaching assignment is not available locally. Sync and retry.');
    }
    final updated = assignment.copyWith(teacherId: target.id, pendingSync: true);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: updated.toJson(transferReason: normalizedReason),
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: SyncOperation.update,
      payload: updated.toJson(transferReason: normalizedReason),
      baseVersion: existing.serverVersion,
    );
    return PrincipalAssignmentActionResult(
      success: true,
      message: '${assignment.className} · ${assignment.subject} transfer to ${target.name} queued. Access moves only after server confirmation.',
    );
  }

  Future<void> _persist(
    SchoolMembership membership,
    PrincipalTeachingAssignment assignment, {
    required SyncOperation operation,
  }) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
    );
    final payload = assignment.toJson();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: operation,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  static String _newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
