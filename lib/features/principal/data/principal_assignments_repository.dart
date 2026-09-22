import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../domain/principal_assignments_models.dart';
import 'principal_assignments_demo_data.dart';

class PrincipalAssignmentsSnapshot {
  const PrincipalAssignmentsSnapshot({
    required this.assignments,
    required this.teachers,
    required this.transfers,
    required this.classOptions,
    required this.permissions,
  });

  final List<PrincipalTeachingAssignment> assignments;
  final List<PrincipalAssignmentTeacher> teachers;
  final List<PrincipalAssignmentTransfer> transfers;

  /// The real Secondary class names drawn from the school's one real student register.
  final List<String> classOptions;

  final PrincipalAssignmentPermissions permissions;
}

class PrincipalAssignmentActionResult {
  const PrincipalAssignmentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

bool _teaches(AdministratorStaffRecord record) => record.role.toLowerCase().contains('teacher');

class PrincipalAssignmentsRepository {
  PrincipalAssignmentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required OwnerStaffProfileRepository staff,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students,
        _staff = staff;

  static const _assignmentType = 'principal_teaching_assignment';
  static const _teacherType = 'principal_assignment_teacher';
  static const _transferType = 'principal_assignment_transfer';
  static const _historyType = 'principal_assignment_history';
  static const _accessType = 'teaching_record_access_grant';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final OwnerStaffProfileRepository _staff;

  PrincipalAssignmentPermissions permissionsFor(SchoolMembership membership) => PrincipalAssignmentPermissions(
        canManageSecondaryAssignments: membership.role == SchoolRole.principal,
        canCreateProvisionalTargets: membership.role == SchoolRole.principal,
        canTransferWork: membership.role == SchoolRole.principal,
        canManagePrimary: false,
      );

  Future<List<String>> _secondaryClassOptions() async {
    final register = (await _students.load()).students;
    final names = {
      for (final s in register)
        if (s.status != AdministratorStudentStatus.transferredOut && sectionOfClass(s.className) == 'Secondary') s.className,
    };
    return names.toList()..sort();
  }

  /// Real Secondary teaching staff, plus any provisional target created through a transfer (a real local
  /// record). There is no real per-subject qualification record anywhere yet, so every real teacher is
  /// treated as assignable to any subject; the principal remains responsible for that judgment, the same
  /// way the website's fixed qualification list never verified anything either.
  Future<List<PrincipalAssignmentTeacher>> _secondaryTeachers(
    SchoolMembership membership,
    List<PrincipalTeachingAssignment> assignments,
  ) async {
    final all = await _staff.people();
    final real = [
      for (final s in all)
        if (s.section == 'Secondary' && _teaches(s))
          PrincipalAssignmentTeacher(
            id: s.id,
            name: s.name,
            department: 'Not recorded yet',
            qualifiedSubjects: principalAssignmentSubjects,
            weeklyPeriods: assignments.where((a) => a.teacherId == s.id).fold<int>(0, (sum, a) => sum + a.periodsPerWeek),
          ),
    ];
    final teacherRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _teacherType);
    final provisional = teacherRecords
        .map((record) => PrincipalAssignmentTeacher.fromJson(record.payload))
        .where((t) => t.provisional)
        .toList();
    return [...real, ...provisional]..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<PrincipalAssignmentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = assignmentRecords
        .map((record) => PrincipalTeachingAssignment.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    final teachers = await _secondaryTeachers(membership, assignments);
    final classOptions = await _secondaryClassOptions();

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
    if (!(await _secondaryClassOptions()).contains(className)) {
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
