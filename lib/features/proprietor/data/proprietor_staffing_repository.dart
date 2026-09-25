import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../principal/data/principal_assignments_demo_data.dart' show principalTransferRecordScope;
import '../../principal/domain/class_teacher_models.dart';
import '../../principal/domain/principal_assignments_models.dart';
import 'owner_staff_profile_repository.dart';

class ProprietorStaffingPermissions {
  const ProprietorStaffingPermissions({required this.canManage});
  final bool canManage;
}

class ProprietorStaffingSnapshot {
  const ProprietorStaffingSnapshot({
    required this.assignments,
    required this.teachers,
    required this.transfers,
    required this.classOptions,
    required this.curriculumRequirements,
    required this.activeSessionId,
    required this.activeSessionName,
    required this.classTeachers,
    required this.permissions,
  });

  final List<PrincipalTeachingAssignment> assignments;
  final List<PrincipalAssignmentTeacher> teachers;
  final List<PrincipalAssignmentTransfer> transfers;

  /// School-wide, every section - unlike Principal's own screen, which is
  /// Secondary only.
  final List<String> classOptions;
  final List<PrincipalCurriculumRequirement> curriculumRequirements;
  final String activeSessionId;
  final String activeSessionName;
  final List<ClassTeacherAssignment> classTeachers;
  final ProprietorStaffingPermissions permissions;

  List<PrincipalCurriculumRequirement> curriculumForClass(String className) =>
      curriculumRequirements.where((item) => item.className == className && item.isActive).toList(growable: false);

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

  ClassTeacherAssignment? classTeacherFor(String classId) {
    for (final item in classTeachers) {
      if (item.classId == classId && item.sessionId == activeSessionId) return item;
    }
    return null;
  }
}

class ProprietorStaffingActionResult {
  const ProprietorStaffingActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// Proprietor's school-wide equivalent of Principal Teaching Assignments and
/// Principal Class Teachers - same canonical entities
/// (principal_teaching_assignment, class_teacher_assignment), same server
/// authority (Proprietor is school-wide where Principal is Secondary only:
/// see apps/academics/curriculum_services.py's _principal_secondary_scope
/// and apps.class_teachers' equivalent), just without the Secondary filter
/// this repository's Principal-side sibling applies everywhere it reads
/// classes, curriculum and teachers.
class ProprietorStaffingRepository {
  ProprietorStaffingRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _staff = staff;

  static const _assignmentType = 'principal_teaching_assignment';
  static const _transferType = 'principal_assignment_transfer';
  static const _classTeacherType = classTeacherAssignmentEntityType;
  static const _sessionType = 'academic_session';
  static const _classType = 'academic_class';
  static const _classSubjectType = 'academic_class_subject';
  static const _staffProfileType = 'owner_staff_profile';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final OwnerStaffProfileRepository _staff;

  ProprietorStaffingPermissions permissionsFor(SchoolMembership membership) =>
      ProprietorStaffingPermissions(canManage: membership.role == SchoolRole.proprietor);

  Future<(String, String)> _activeSession(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _sessionType);
    for (final record in records) {
      if (record.payload['status'] == 'active') {
        return (record.payload['id'] as String? ?? record.entityId, record.payload['name'] as String? ?? '');
      }
    }
    return ('', '');
  }

  Future<Map<String, String>> _allClassNames(SchoolMembership membership) async {
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classType);
    final result = <String, String>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload['isActive'] != true) continue;
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
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classSubjectType);
    final result = <PrincipalCurriculumRequirement>[];
    for (final record in records) {
      final payload = record.payload;
      final sessionId = payload['sessionId'] as String? ?? '';
      final classId = payload['classId'] as String? ?? '';
      if (sessionId != activeSessionId || !classNames.containsKey(classId)) continue;
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

  Future<List<PrincipalAssignmentTeacher>> _allTeachers(
    SchoolMembership membership,
    List<PrincipalTeachingAssignment> assignments,
  ) async {
    final all = await _staff.people();
    final teachers = <PrincipalAssignmentTeacher>[];
    for (final person in all) {
      if (!person.role.toLowerCase().contains('teacher')) continue;
      final profile = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _staffProfileType,
        entityId: person.id,
      );
      final linkedMembershipId = profile?.payload['linkedMembershipId'] as String? ?? '';
      final systemRole = profile?.payload['systemRole'] as String? ?? '';
      if (linkedMembershipId.isEmpty || systemRole != 'teacher') continue;
      final periods = assignments.where((item) => item.teacherId == linkedMembershipId).fold<int>(0, (sum, item) => sum + item.periodsPerWeek);
      teachers.add(
        PrincipalAssignmentTeacher(
          id: linkedMembershipId,
          name: person.name,
          department: person.section,
          qualifiedSubjects: const [],
          weeklyPeriods: periods,
          qualificationRecorded: false,
        ),
      );
    }
    teachers.sort((a, b) => a.name.compareTo(b.name));
    return teachers;
  }

  Future<ProprietorStaffingSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    final session = await _activeSession(membership);
    final classNames = await _allClassNames(membership);
    final curriculum = await _curriculum(membership, session.$1, classNames);

    final assignmentRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _assignmentType);
    final assignments = <PrincipalTeachingAssignment>[];
    for (final record in assignmentRecords) {
      final item = PrincipalTeachingAssignment.fromJson(record.payload);
      if (item.sessionId.isNotEmpty && session.$1.isNotEmpty && item.sessionId != session.$1) continue;
      assignments.add(item);
    }
    assignments.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });

    final teachers = permissions.canManage ? await _allTeachers(membership, assignments) : const <PrincipalAssignmentTeacher>[];

    final transferRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _transferType);
    final transfers = transferRecords.map((r) => PrincipalAssignmentTransfer.fromJson(r.payload)).toList(growable: false)
      ..sort((a, b) => b.transferredAt.compareTo(a.transferredAt));

    final classTeacherRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _classTeacherType);
    final classTeachers = classTeacherRecords
        .map((r) => ClassTeacherAssignment.fromJson(r.payload))
        .where((item) => item.isActive && classNames.containsKey(item.classId))
        .toList(growable: false);

    return ProprietorStaffingSnapshot(
      assignments: assignments,
      teachers: teachers,
      transfers: transfers,
      classOptions: classNames.values.toSet().toList()..sort(),
      curriculumRequirements: curriculum,
      activeSessionId: session.$1,
      activeSessionName: session.$2,
      classTeachers: classTeachers,
      permissions: permissions,
    );
  }

  Future<ProprietorStaffingActionResult> addAssignment({
    required String className,
    required String subject,
    required String teacherId,
    required int periodsPerWeek,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const ProprietorStaffingActionResult(success: false, message: 'This membership cannot manage teaching assignments.');
    }
    final snapshot = await load();
    final requirements = snapshot.curriculumRequirements.where((item) => item.className == className && item.subject == subject && item.isActive);
    final requirement = requirements.isEmpty ? null : requirements.first;
    if (requirement == null) {
      return ProprietorStaffingActionResult(
        success: false,
        message: '$className · $subject is not in the canonical active curriculum. Configure the class curriculum first.',
      );
    }
    final teacher = snapshot.teachers.where((item) => item.id == teacherId).firstOrNull;
    if (teacher == null) {
      return const ProprietorStaffingActionResult(success: false, message: 'Choose a staff member whose Teacher account has been activated and linked.');
    }
    if (snapshot.assignments.any((item) => item.classSubjectId == requirement.id || (item.className == className && item.subject == subject))) {
      return ProprietorStaffingActionResult(success: false, message: '$className already has a $subject teacher. Transfer the existing responsibility instead.');
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
    return ProprietorStaffingActionResult(
      success: true,
      message: '${teacher.name} assigned to $subject for $className. Saved offline and queued for server validation.',
    );
  }

  Future<ProprietorStaffingActionResult> transferAssignment({
    required String assignmentId,
    required String newTeacherId,
    required String reason,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const ProprietorStaffingActionResult(success: false, message: 'This membership cannot transfer teaching work.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      return const ProprietorStaffingActionResult(success: false, message: 'Add a transfer reason so the handover remains auditable.');
    }
    final snapshot = await load();
    final assignment = snapshot.assignments.where((item) => item.id == assignmentId).firstOrNull;
    if (assignment == null) {
      return const ProprietorStaffingActionResult(success: false, message: 'Teaching assignment not found.');
    }
    final target = snapshot.teachers.where((item) => item.id == newTeacherId).firstOrNull;
    if (target == null) {
      return const ProprietorStaffingActionResult(success: false, message: 'Choose an activated Teacher account in this school.');
    }
    if (target.id == assignment.teacherId) {
      return const ProprietorStaffingActionResult(success: false, message: 'Choose a different receiving teacher.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final transferId = 'TRN-${DateTime.now().microsecondsSinceEpoch}';
    final oldVersion = assignment.version;
    final updated = assignment.copyWith(teacherId: target.id, version: oldVersion + 1, handoverReason: normalizedReason);
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

    await _persistAssignment(membership, updated, create: false);
    await _persistTransfer(membership, transfer);
    return ProprietorStaffingActionResult(
      success: true,
      message: '${assignment.className} · ${assignment.subject} queued for transfer to ${target.name}.',
    );
  }

  Future<ProprietorStaffingActionResult> assignClassTeacher({
    required String classId,
    required String className,
    required String section,
    required String teacherId,
    required String teacherName,
    String handoverReason = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const ProprietorStaffingActionResult(success: false, message: 'This membership cannot assign a class teacher.');
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const ProprietorStaffingActionResult(success: false, message: 'Assigning a class teacher is a canonical server workflow in connected mode.');
    }
    final session = await _activeSession(membership);
    if (session.$1.isEmpty) {
      return const ProprietorStaffingActionResult(success: false, message: 'No active academic session.');
    }
    final entityId = 'clsteach-$classId-${session.$1}';
    final existing = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: _classTeacherType, entityId: entityId);
    final draft = ClassTeacherAssignment(
      id: entityId,
      classId: classId,
      className: className,
      section: section,
      sessionId: session.$1,
      session: session.$2,
      teacherId: teacherId,
      teacherName: teacherName,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classTeacherType,
      entityId: entityId,
      payload: draft.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _classTeacherType,
      entityId: entityId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: draft.toMutationJson(handoverReason: handoverReason),
      baseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return const ProprietorStaffingActionResult(success: true, message: 'Class-teacher assignment queued for synchronization.');
  }

  Future<void> _persistAssignment(SchoolMembership membership, PrincipalTeachingAssignment assignment, {required bool create}) async {
    final existing = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: _assignmentType, entityId: assignment.id);
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
      operation: create || existing?.serverVersion == null ? SyncOperation.create : SyncOperation.update,
      payload: assignment.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }

  Future<void> _persistTransfer(SchoolMembership membership, PrincipalAssignmentTransfer transfer) async {
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
