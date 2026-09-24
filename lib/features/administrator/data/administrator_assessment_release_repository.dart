import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';

class AdministratorAssessmentReleasePermissions {
  const AdministratorAssessmentReleasePermissions({required this.canManage});
  final bool canManage;
}

class AdministratorAssessmentReleaseSnapshot {
  const AdministratorAssessmentReleaseSnapshot({
    required this.awaitingLock,
    required this.awaitingRelease,
    required this.released,
    required this.permissions,
  });

  /// Submitted by a Teacher, not yet locked.
  final List<TeacherAssessment> awaitingLock;

  /// Locked, not yet released to Students/Parents.
  final List<TeacherAssessment> awaitingRelease;

  /// Already released, most recent first, for reference/undo-by-return.
  final List<TeacherAssessment> released;

  final AdministratorAssessmentReleasePermissions permissions;
}

class AdministratorAssessmentReleaseActionResult {
  const AdministratorAssessmentReleaseActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

/// Lock and release are a school-wide governance action, not a Teacher
/// self-service step - a Teacher device can submit scores for review, but
/// only Proprietor/Administrator can lock them (making further editing an
/// explicit, audited correction) and release them (making them visible to
/// Students and their linked Parents). This never edits a score itself.
class AdministratorAssessmentReleaseRepository {
  AdministratorAssessmentReleaseRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = teacherAssessmentEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorAssessmentReleasePermissions permissionsFor(SchoolMembership membership) =>
      AdministratorAssessmentReleasePermissions(
        canManage: membership.role == SchoolRole.administrator || membership.role == SchoolRole.proprietor,
      );

  Future<AdministratorAssessmentReleaseSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canManage) {
      return AdministratorAssessmentReleaseSnapshot(
        awaitingLock: const [],
        awaitingRelease: const [],
        released: const [],
        permissions: permissions,
      );
    }
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );
    final all = records.map((r) => TeacherAssessment.fromJson(r.payload)).toList();
    final awaitingLock = all.where((a) => a.state == TeacherAssessmentState.submitted).toList()
      ..sort((a, b) => (a.submittedAt ?? '').compareTo(b.submittedAt ?? ''));
    final awaitingRelease = all.where((a) => a.state == TeacherAssessmentState.locked).toList()
      ..sort((a, b) => (a.lockedAt ?? '').compareTo(b.lockedAt ?? ''));
    final released = all.where((a) => a.state == TeacherAssessmentState.released).toList()
      ..sort((a, b) => (b.releasedAt ?? '').compareTo(a.releasedAt ?? ''));
    return AdministratorAssessmentReleaseSnapshot(
      awaitingLock: awaitingLock,
      awaitingRelease: awaitingRelease,
      released: released,
      permissions: permissions,
    );
  }

  Future<AdministratorAssessmentReleaseActionResult> lock(TeacherAssessment assessment) =>
      _action(assessment, action: 'lock', requireState: TeacherAssessmentState.submitted);

  Future<AdministratorAssessmentReleaseActionResult> release(TeacherAssessment assessment) =>
      _action(assessment, action: 'release', requireState: TeacherAssessmentState.locked);

  Future<AdministratorAssessmentReleaseActionResult> returnForCorrection(
    TeacherAssessment assessment, {
    required String comment,
  }) =>
      _action(assessment, action: 'returnForCorrection', comment: comment);

  Future<AdministratorAssessmentReleaseActionResult> _action(
    TeacherAssessment assessment, {
    required String action,
    TeacherAssessmentState? requireState,
    String comment = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const AdministratorAssessmentReleaseActionResult(
        success: false,
        message: 'Only the Proprietor or Administrator can lock, release or return an assessment.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const AdministratorAssessmentReleaseActionResult(
        success: false,
        message: 'Locking and release are canonical server workflows in connected mode.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const AdministratorAssessmentReleaseActionResult(
        success: false,
        message: 'Synchronize this assessment before changing its release state.',
      );
    }
    final current = TeacherAssessment.fromJson(existing.payload);
    if (requireState != null && current.state != requireState) {
      return const AdministratorAssessmentReleaseActionResult(
        success: false,
        message: 'This assessment is no longer in the expected state. Refresh and try again.',
      );
    }

    final nextState = switch (action) {
      'lock' => TeacherAssessmentState.locked,
      'release' => TeacherAssessmentState.released,
      _ => TeacherAssessmentState.published,
    };
    final optimistic = current.copyWith(
      state: nextState,
      version: current.version + 1,
      pendingSync: true,
      serverVersion: existing.serverVersion,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
      payload: optimistic.toJson(),
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: assessment.id,
      operation: SyncOperation.update,
      payload: {'id': assessment.id, 'action': action, 'comment': comment},
      baseVersion: existing.serverVersion,
    );
    return AdministratorAssessmentReleaseActionResult(
      success: true,
      message: switch (action) {
        'lock' => 'Locking queued. Scores stay as submitted until the server acknowledges the change.',
        'release' => 'Release queued. Students and their linked Parents see it only after server acknowledgement.',
        _ => 'Return-for-correction queued and will reopen it for Teacher editing once acknowledged.',
      },
    );
  }
}
