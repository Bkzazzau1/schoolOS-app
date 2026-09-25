import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/report_card_models.dart';

class AdministratorReportCardPermissions {
  const AdministratorReportCardPermissions({required this.canManage});
  final bool canManage;
}

class AdministratorReportCardSnapshot {
  const AdministratorReportCardSnapshot({
    required this.awaitingReview,
    required this.awaitingRelease,
    required this.released,
    required this.permissions,
  });

  /// Submitted, not yet Principal-reviewed (Secondary) or ready to release
  /// directly (non-Secondary).
  final List<ReportCard> awaitingReview;

  /// Reviewed (or non-Secondary and submitted), ready to release.
  final List<ReportCard> awaitingRelease;
  final List<ReportCard> released;
  final AdministratorReportCardPermissions permissions;
}

class AdministratorReportCardActionResult {
  const AdministratorReportCardActionResult({required this.success, required this.message, this.compiledCount});
  final bool success;
  final String message;
  final int? compiledCount;
}

/// Compiling and ranking are always class-wide (see [reportCardBatchEntityType]);
/// submit/release act on one student's own report card at a time. Standalone
/// demo mode has no canonical Assessment evidence to compile from in a
/// meaningful class-wide way, so this whole workflow is canonical-only,
/// matching the same precedent as Assessment locking/release.
class AdministratorReportCardRepository {
  AdministratorReportCardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = reportCardEntityType;
  static const _batchEntityType = reportCardBatchEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorReportCardPermissions permissionsFor(SchoolMembership membership) =>
      AdministratorReportCardPermissions(
        canManage: membership.role == SchoolRole.administrator || membership.role == SchoolRole.proprietor,
      );

  Future<AdministratorReportCardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canManage) {
      return AdministratorReportCardSnapshot(
        awaitingReview: const [],
        awaitingRelease: const [],
        released: const [],
        permissions: permissions,
      );
    }
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _entityType);
    final all = records.map((r) => ReportCard.fromJson(r.payload)).toList();
    final awaitingReview = all.where((c) => c.state == ReportCardState.submitted && c.isSecondary).toList()
      ..sort((a, b) => a.className.compareTo(b.className));
    final awaitingRelease = all.where((c) => c.canRelease).toList()
      ..sort((a, b) => a.className.compareTo(b.className));
    final released = all.where((c) => c.state == ReportCardState.released).toList()
      ..sort((a, b) => (b.releasedAt ?? '').compareTo(a.releasedAt ?? ''));
    return AdministratorReportCardSnapshot(
      awaitingReview: awaitingReview,
      awaitingRelease: awaitingRelease,
      released: released,
      permissions: permissions,
    );
  }

  Future<AdministratorReportCardActionResult> compileClass({
    required String classId,
    required String termId,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const AdministratorReportCardActionResult(
        success: false,
        message: 'Only the Proprietor or Administrator can compile report cards.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const AdministratorReportCardActionResult(
        success: false,
        message: 'Compiling report cards is a canonical server workflow in connected mode.',
      );
    }
    if (classId.isEmpty || termId.isEmpty) {
      return const AdministratorReportCardActionResult(success: false, message: 'Choose a class and a term.');
    }
    final entityId = '$classId:$termId';
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _batchEntityType,
      entityId: entityId,
    );
    final payload = {'id': entityId, 'action': 'compile', 'classId': classId, 'termId': termId};
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _batchEntityType,
      entityId: entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _batchEntityType,
      entityId: entityId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return const AdministratorReportCardActionResult(
      success: true,
      message: 'Compilation queued. Each roster student\'s report card and class position appear once the server acknowledges it.',
    );
  }

  Future<AdministratorReportCardActionResult> submit(ReportCard card) => _action(card, action: 'submit');

  Future<AdministratorReportCardActionResult> release(ReportCard card) => _action(card, action: 'release');

  Future<AdministratorReportCardActionResult> _action(ReportCard card, {required String action}) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManage) {
      return const AdministratorReportCardActionResult(
        success: false,
        message: 'Only the Proprietor or Administrator can submit or release a report card.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: card.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const AdministratorReportCardActionResult(
        success: false,
        message: 'Synchronize this report card before changing its state.',
      );
    }
    final nextState = action == 'submit' ? ReportCardState.submitted : ReportCardState.released;
    final optimistic = card.copyWith(
      state: nextState,
      version: card.version + 1,
      pendingSync: true,
      serverVersion: existing.serverVersion,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: card.id,
      payload: _toJson(optimistic),
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: card.id,
      operation: SyncOperation.update,
      payload: {'id': card.id, 'action': action},
      baseVersion: existing.serverVersion,
    );
    return AdministratorReportCardActionResult(
      success: true,
      message: action == 'submit'
          ? 'Submission queued for review.'
          : 'Release queued. The Student and their linked Parents see it only after server acknowledgement.',
    );
  }

  Map<String, Object?> _toJson(ReportCard card) => {
        'id': card.id,
        'studentId': card.studentId,
        'studentName': card.studentName,
        'admissionNumber': card.admissionNumber,
        'termId': card.termId,
        'term': card.term,
        'className': card.className,
        'section': card.section,
        'state': card.state.name,
        'subjects': [
          for (final line in card.subjects)
            {
              'classSubjectId': line.classSubjectId,
              'subject': line.subject,
              'percent': line.percent,
              'grade': line.grade,
              'assessmentsIncluded': line.assessmentsIncluded,
            },
        ],
        'overallAverage': card.overallAverage,
        'overallGrade': card.overallGrade,
        'classPosition': card.classPosition,
        'classSize': card.classSize,
        'attendancePercent': card.attendancePercent,
        'principalComment': card.principalComment,
        'classTeacherComment': card.classTeacherComment,
        'events': [
          for (final event in card.events)
            {
              'revision': event.revision,
              'action': event.action,
              'actorMembershipId': event.actorMembershipId,
              'actor': event.actor,
              'comment': event.comment,
              'occurredAt': event.occurredAt,
            },
        ],
        'generatedAt': card.generatedAt,
        'submittedAt': card.submittedAt,
        'reviewedAt': card.reviewedAt,
        'releasedAt': card.releasedAt,
        'version': card.version,
      };
}
