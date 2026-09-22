import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_students_models.dart';
import 'principal_students_demo_data.dart';

class PrincipalStudentsSnapshot {
  const PrincipalStudentsSnapshot({
    required this.students,
    required this.classOptions,
    required this.permissions,
  });

  final List<PrincipalStudentSummary> students;

  /// The real Secondary classes represented in [students].
  final List<String> classOptions;

  final PrincipalStudentPermissions permissions;
}

class PrincipalStudentActionResult {
  const PrincipalStudentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// A class belongs to the Principal's Secondary scope unless its name marks it as Early Years or Primary.
/// Mirrors administrator_attendance_desk.dart's sectionOfClass so the two leadership views agree on scope.
bool _isSecondary(String className) {
  final c = className.trim().toLowerCase();
  if (c.startsWith('nursery') || c.startsWith('creche') || c.startsWith('kg') || c.startsWith('reception')) return false;
  if (c.startsWith('primary') || c.startsWith('basic')) return false;
  return true;
}

class PrincipalStudentsRepository {
  PrincipalStudentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students;

  static const _noteType = 'principal_student_leadership_note';
  static const _lifecycleType = 'principal_student_lifecycle_proposal';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;

  PrincipalStudentPermissions permissionsFor(SchoolMembership membership) => PrincipalStudentPermissions(
        canViewSecondaryStudents: membership.role == SchoolRole.principal,
        canAddLeadershipNote: membership.role == SchoolRole.principal,
        canCreateLifecycleProposal: membership.role == SchoolRole.principal,
        canManagePrimary: false,
        canViewConfidentialFinance: false,
      );

  Future<List<AdministratorStudentRecord>> _secondaryRegister() async {
    final all = (await _students.load()).students;
    return [
      for (final s in all)
        if (s.status != AdministratorStudentStatus.transferredOut && _isSecondary(s.className)) s,
    ];
  }

  PrincipalStudentSummary _summaryOf(AdministratorStudentRecord s) => PrincipalStudentSummary(
        id: s.id,
        name: s.name,
        className: s.className,
        average: 0,
        attendance: 0,
        trend: 0,
        behaviour: PrincipalStudentBehaviour.good,
        risk: PrincipalStudentRisk.stable,
        incidents: 0,
        interventions: 0,
        guardian: s.primaryGuardian,
        concern: 'No assessment, attendance or incident history has been recorded for this student yet.',
      );

  Future<PrincipalStudentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final register = await _secondaryRegister();
    final summaries = register.map(_summaryOf).toList()..sort((a, b) => a.id.compareTo(b.id));
    final classOptions = {for (final s in summaries) s.className}.toList()..sort();
    return PrincipalStudentsSnapshot(
      students: summaries,
      classOptions: classOptions,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalStudentProfile?> loadProfile(String studentId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryStudents) return null;
    final register = await _secondaryRegister();
    final matches = register.where((s) => s.id == studentId);
    if (matches.isEmpty) return null;
    final s = matches.first;
    return PrincipalStudentProfile(
      summary: _summaryOf(s),
      admissionNo: 'Not recorded yet',
      campus: 'Not recorded yet',
      enrollmentStatus: s.status == AdministratorStudentStatus.transferPending
          ? PrincipalStudentEnrollmentStatus.transferPending
          : PrincipalStudentEnrollmentStatus.active,
      classTeacher: 'Not recorded yet',
      guardianPhone: 'Not recorded yet',
      familyAccountId: 'Not recorded yet',
      admissionDate: 'Not recorded yet',
      dateOfBirth: 'Not recorded yet',
      gender: 'Not recorded yet',
      house: 'Not recorded yet',
      medicalInstruction: 'No medical information has been recorded.',
      healthRecordLabel: 'Restricted',
      transport: 'Not recorded yet',
      meals: 'Not recorded yet',
      boarding: 'Not recorded yet',
      feeVisibility: 'Finance team + authorized guardian only',
      previousSchool: 'Not recorded yet',
      activities: const [],
      awards: const [],
      subjects: const [],
      attendanceSummary: const [],
      promotionHistory: const [],
      documents: const [],
      timeline: const [],
    );
  }

  Future<String> loadLeadershipNote(String studentId) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteType,
      entityId: '${membership.id}:$studentId',
    );
    return record?.payload['note'] as String? ?? '';
  }

  Future<PrincipalStudentActionResult> saveLeadershipNote({
    required String studentId,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canAddLeadershipNote) {
      return const PrincipalStudentActionResult(success: false, message: 'This membership cannot add Principal student notes.');
    }
    final profile = await loadProfile(studentId);
    if (profile == null) {
      return const PrincipalStudentActionResult(success: false, message: 'Student is outside the active Secondary leadership scope.');
    }
    final normalized = note.trim();
    if (normalized.isEmpty) {
      return const PrincipalStudentActionResult(success: false, message: 'Add a factual follow-up note first.');
    }
    final id = '${membership.id}:$studentId';
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'id': id,
      'studentId': studentId,
      'note': normalized,
      'visibility': 'Principal / authorized leadership only',
      'membershipId': membership.id,
      'updatedAt': now,
    };
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteType,
      entityId: id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _noteType,
      entityId: id,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _noteType,
      entityId: id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
    );
    return const PrincipalStudentActionResult(success: true, message: 'Leadership note saved offline and queued for sync.');
  }

  Future<PrincipalStudentActionResult> createLifecycleProposal({
    required String studentId,
    required String actionType,
    required String nextClassOrDestination,
    required String effectiveSession,
    required String reason,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateLifecycleProposal) {
      return const PrincipalStudentActionResult(success: false, message: 'This membership cannot create a Secondary lifecycle proposal.');
    }
    final profile = await loadProfile(studentId);
    if (profile == null) {
      return const PrincipalStudentActionResult(success: false, message: 'Student is outside the active Secondary leadership scope.');
    }
    if (!principalStudentLifecycleActions.contains(actionType)) {
      return const PrincipalStudentActionResult(success: false, message: 'Choose a valid lifecycle action.');
    }
    if (reason.trim().isEmpty) {
      return const PrincipalStudentActionResult(success: false, message: 'Add a reason so the lifecycle action remains auditable.');
    }
    if ((actionType == 'Promote' || actionType == 'Move class' || actionType == 'Transfer out') && nextClassOrDestination.trim().isEmpty) {
      return const PrincipalStudentActionResult(success: false, message: 'Add the next class or destination.');
    }

    final now = DateTime.now().toUtc();
    final id = 'LIFE-$studentId-${now.microsecondsSinceEpoch}';
    final proposal = PrincipalStudentLifecycleProposal(
      id: id,
      studentId: studentId,
      actionType: actionType,
      nextClassOrDestination: nextClassOrDestination.trim(),
      effectiveSession: effectiveSession,
      reason: reason.trim(),
      requestedByMembershipId: membership.id,
      requestedAt: now.toIso8601String(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _lifecycleType,
      entityId: proposal.id,
      payload: proposal.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _lifecycleType,
      entityId: proposal.id,
      operation: SyncOperation.create,
      payload: proposal.toJson(),
    );
    return const PrincipalStudentActionResult(
      success: true,
      message: 'Lifecycle proposal saved offline and queued for governed execution. Current enrollment was not overwritten.',
    );
  }
}
