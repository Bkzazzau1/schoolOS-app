import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_students_models.dart';
import 'principal_students_demo_data.dart';

class PrincipalStudentsSnapshot {
  const PrincipalStudentsSnapshot({
    required this.students,
    required this.permissions,
  });

  final List<PrincipalStudentSummary> students;
  final PrincipalStudentPermissions permissions;
}

class PrincipalStudentActionResult {
  const PrincipalStudentActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class PrincipalStudentsRepository {
  PrincipalStudentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _directoryType = 'principal_student_directory';
  static const _profileType = 'principal_student_profile';
  static const _noteType = 'principal_student_leadership_note';
  static const _lifecycleType = 'principal_student_lifecycle_proposal';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalStudentPermissions permissionsFor(SchoolMembership membership) => PrincipalStudentPermissions(
        canViewSecondaryStudents: membership.role == SchoolRole.principal,
        canAddLeadershipNote: membership.role == SchoolRole.principal,
        canCreateLifecycleProposal: membership.role == SchoolRole.principal,
        canManagePrimary: false,
        canViewConfidentialFinance: false,
      );

  Future<PrincipalStudentsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _directoryType,
    );
    final students = records
        .map((record) => PrincipalStudentSummary.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return PrincipalStudentsSnapshot(
      students: students,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalStudentProfile?> loadProfile(String studentId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canViewSecondaryStudents || !studentId.startsWith('STU-')) return null;
    await _seedIfNeeded(membership);
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _profileType,
      entityId: studentId,
    );
    return record == null ? null : PrincipalStudentProfile.fromJson(record.payload);
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

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final directory = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _directoryType);
    if (directory.isEmpty) {
      for (final student in principalStudentSummaries) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _directoryType,
          entityId: student.id,
          payload: student.toJson(),
        );
      }
    }
    final profiles = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _profileType);
    if (profiles.isEmpty) {
      for (final student in principalStudentSummaries) {
        final profile = principalStudentProfileFor(student);
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _profileType,
          entityId: student.id,
          payload: profile.toJson(),
        );
      }
    }
  }
}
