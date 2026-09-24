import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/principal_assignments_models.dart';
import 'principal_assignments_demo_data.dart';

class PrincipalAssignmentsSnapshot {
  const PrincipalAssignmentsSnapshot({
    required this.assignments,
    required this.teachers,
    required this.transfers,
    required this.classOptions,
    required this.curriculumRequirements,
    required this.activeSessionId,
    required this.permissions,
  });

  final List<PrincipalTeachingAssignment> assignments;
  final List<PrincipalAssignmentTeacher> teachers;
  final List<PrincipalAssignmentTransfer> transfers;
  final List<String> classOptions;
  final List<PrincipalCurriculumRequirement> curriculumRequirements;
  final String activeSessionId;
  final PrincipalAssignmentPermissions permissions;

  List<PrincipalCurriculumRequirement> curriculumForClass(String className) =>
      curriculumRequirements
          .where((item) => item.className == className && item.isActive)
          .toList(growable: false);

  List<PrincipalUnassignedSubject> get unassigned {
    final assignedIds = {
      for (final item in assignments)
        if (item.classSubjectId.isNotEmpty) item.classSubjectId,
    };
    return [
      for (final item in curriculumRequirements)
        if (item.isActive && !assignedIds.contains(item.id))
          PrincipalUnassignedSubject(
            className: item.className,
            subject: item.subject,
            periods: item.periodsPerWeek,
            classSubjectId: item.id,
          ),
    ];
  }
}

class PrincipalAssignmentActionResult {
  const PrincipalAssignmentActionResult({
    required this.success,
    required this.message,
  });
  final bool success;
  final String message;
}

bool _teaches(AdministratorStaffRecord record) =>
    record.role.toLowerCase().contains('teacher');

class PrincipalAssignmentsRepository {
  PrincipalAssignmentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _staff = staff;

  static const _assignmentType = 'principal_teaching_assignment';
  static const _transferType = 'principal_assignment_transfer';
  static const _sessionType = 'academic_session';
  static const _classType = 'academic_class';
  static const _classSubjectType = 'academic_class_subject';
  static const _staffProfileType = 'owner_staff_profile';

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

  Future<String> _activeSessionId(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _sessionType,
    );
    for (final record in records) {
      if (record.payload['status'] == 'active') {
        return record.payload['id'] as String? ?? record.entityId;
      }
    }
    return '';
  }

  Future<Map<String, String>> _secondaryClassNames(
    SchoolMembership membership,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    final result = <String, String>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload['isActive'] != true) continue;
      if ((payload['section'] as String? ?? '').trim().toLowerCase() !=
          'secondary') {
        continue;
      }
      final id = payload['id'] as String? ?? record.entityId;
      final name = payload['name'] as String? ?? '';
      if (id.isNotEmpty && name.isNotEmpty) result[id] = name;
    }
    return result;
  }

  Future<List<PrincipalCurriculumRequirement>> _curriculum(
    SchoolMembership membership,
    String activeSessionId,
    Map<String, String> classNames,
  ) async {
    if (activeSessionId.isEmpty) return const [];
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classSubjectType,
    );
    final result = <PrincipalCurriculumRequirement>[];
    for (final record in records) {
      final payload = record.payload;
      final sessionId = payload['sessionId'] as String? ?? '';
      final classId = payload['classId'] as String? ?? '';
      if (sessionId != activeSessionId || !classNames.containsKey(classId)) {
        continue;
      }
      if (payload['isActive'] == false) continue;
      result.add(
        PrincipalCurriculumRequirement.fromJson({
          ...payload,
          'id': payload['id'] as String? ?? record.entityId,
          'className': payload['className'] as String? ?? classNames[classId]!,
        }),
      );
    }
    result.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return result;
  }

  Future<List<PrincipalAssignmentTeacher>> _secondaryTeachers(
    SchoolMembership membership,
    List<PrincipalTeachingAssignment> assignments,
  ) async {
    final all = await _staff.people();
    final teachers = <PrincipalAssignmentTeacher>[];
    for (final person in all) {
      if (person.section != 'Secondary' || !_teaches(person)) continue;
      final profile = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _staffProfileType,
        entityId: person.id,
      );
      final payload = profile?.payload;
      final linkedMembershipId =
          payload?['linkedMembershipId'] as String? ?? '';
      final systemRole = payload?['systemRole'] as String? ?? '';
      if (linkedMembershipId.isEmpty || systemRole != 'teacher') continue;
      final periods = assignments
          .where((item) => item.teacherId == linkedMembershipId)
          .fold<int>(0, (sum, item) => sum + item.periodsPerWeek);
      teachers.add(
        PrincipalAssignmentTeacher(
          id: linkedMembershipId,
          name: person.name,
          department: 'Subject qualification not classified',
          qualifiedSubjects: const [],
          weeklyPeriods: periods,
          qualificationRecorded: false,
        ),
      );
    }
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }

  Future<PrincipalAssignmentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final activeSessionId = await _activeSessionId(membership);
    final classNames = await _secondaryClassNames(membership);
    final curriculum = await _curriculum(
      membership,
      activeSessionId,
      classNames,
    );

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = <PrincipalTeachingAssignment>[];
    for (final record in assignmentRecords) {
      final item = PrincipalTeachingAssignment.fromJson(record.payload);
      if (item.sessionId.isNotEmpty &&
          activeSessionId.isNotEmpty &&
          item.sessionId != activeSessionId) {
        continue;
      }
      assignments.add(item);
    }
    assignments.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });

    final teachers = await _secondaryTeachers(membership, assignments);
    final transferRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _transferType,
    );
    final transfers = transferRecords
        .map((record) => PrincipalAssignmentTransfer.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.transferredAt.compareTo(a.transferredAt));

    final classOptions = classNames.values.toSet().toList()..sort();
    return PrincipalAssignmentsSnapshot(
      assignments: assignments,
      teachers: teachers,
      transfers: transfers,
      classOptions: classOptions,
      curriculumRequirements: curriculum,
      activeSessionId: activeSessionId,
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
    final snapshot = await load();
    final requirements = snapshot.curriculumRequirements.where(
      (item) => item.className == className && item.subject == subject && item.isActive,
    );
    final requirement = requirements.isEmpty ? null : requirements.first;
    if (requirement == null) {
      return PrincipalAssignmentActionResult(
        success: false,
        message:
            '$className · $subject is not in the canonical active curriculum. Configure the class curriculum first.',
      );
    }
    final teacher = snapshot.teachers.where((item) => item.id == teacherId).firstOrNull;
    if (teacher == null) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message:
            'Choose a staff member whose Teacher account has been activated and linked.',
      );
    }
    if (snapshot.assignments.any(
      (item) => item.classSubjectId == requirement.id ||
          (item.className == className && item.subject == subject),
    )) {
      return PrincipalAssignmentActionResult(
        success: false,
        message:
            '$className already has a $subject teacher. Transfer the existing responsibility instead.',
      );
    }

    final id = 'ASN-${DateTime.now().microsecondsSinceEpoch}';
    final assignment = PrincipalTeachingAssignment(
      id: id,
      className: className,
      subject: subject,
      teacherId: teacher.id,
      periodsPerWeek: requirement.periodsPerWeek,
      sessionId: requirement.sessionId,
      classSubjectId: requirement.id,
      subjectId: requirement.subjectId,
    );
    await _persistAssignment(membership, assignment, create: true);
    return PrincipalAssignmentActionResult(
      success: true,
      message:
          '${teacher.name} assigned to $subject for $className. ${requirement.periodsPerWeek} periods/week comes from the canonical curriculum. Saved offline and queued for server validation.',
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
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'This membership cannot transfer Secondary teaching work.',
      );
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Add a transfer reason so the handover remains auditable.',
      );
    }
    if ((newStaffName ?? '').trim().isNotEmpty ||
        (newStaffDepartment ?? '').trim().isNotEmpty) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message:
            'Onboard and activate the staff member as a Teacher first. Canonical teaching responsibility cannot be assigned to a provisional identity.',
      );
    }

    final snapshot = await load();
    final assignment = snapshot.assignments.where((item) => item.id == assignmentId).firstOrNull;
    if (assignment == null) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Teaching assignment not found.',
      );
    }
    final targetId = (existingTeacherId ?? '').trim();
    final target = snapshot.teachers.where((item) => item.id == targetId).firstOrNull;
    if (target == null) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Choose an activated Teacher account in this school.',
      );
    }
    if (target.id == assignment.teacherId) {
      return const PrincipalAssignmentActionResult(
        success: false,
        message: 'Choose a different receiving teacher.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final transferId = 'TRN-${DateTime.now().microsecondsSinceEpoch}';
    final oldVersion = assignment.version;
    final updated = assignment.copyWith(
      teacherId: target.id,
      version: oldVersion + 1,
      handoverReason: normalizedReason,
    );
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
      newAssignmentVersion: oldVersion + 1,
    );

    // Queue the assignment change first. The server accepts the handover history
    // only after that canonical teacher change exists.
    await _persistAssignment(membership, updated, create: false);
    await _persistTransfer(membership, transfer);
    return PrincipalAssignmentActionResult(
      success: true,
      message:
          '${assignment.className} · ${assignment.subject} queued for transfer to ${target.name}. The server will validate the new Teacher membership and canonicalize the handover history.',
    );
  }

  Future<void> _persistAssignment(
    SchoolMembership membership,
    PrincipalTeachingAssignment assignment, {
    required bool create,
  }) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: assignment.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: create || existing?.serverVersion == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: assignment.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<void> _persistTransfer(
    SchoolMembership membership,
    PrincipalAssignmentTransfer transfer,
  ) async {
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
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
