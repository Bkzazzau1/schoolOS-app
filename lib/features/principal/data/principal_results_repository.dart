import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_results_models.dart';
import 'principal_results_demo_data.dart';

class PrincipalResultsSnapshot {
  const PrincipalResultsSnapshot({
    required this.classes,
    required this.students,
    required this.decisions,
    required this.permissions,
  });

  final List<PrincipalClassResult> classes;
  final List<PrincipalStudentResult> students;
  final List<PrincipalReportReviewDecision> decisions;
  final PrincipalResultsPermissions permissions;

  int get schoolAverage => (classes.fold<int>(0, (sum, row) => sum + row.average) / classes.length).round();
  int get passRate => (classes.fold<int>(0, (sum, row) => sum + row.passRate) / classes.length).round();
  int get reportsReady => classes.fold<int>(0, (sum, row) => sum + row.reportsReady);
  int get pendingApproval => classes.where((row) => row.release == PrincipalResultReleaseState.awaitingApproval).length;
  int get releasedClasses => classes.where((row) => row.release == PrincipalResultReleaseState.released).length;
}

class PrincipalResultsActionResult {
  const PrincipalResultsActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class PrincipalResultsRepository {
  PrincipalResultsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _classType = 'principal_result_class';
  static const _studentType = 'principal_student_report';
  static const _decisionType = 'principal_report_review_decision';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalResultsPermissions permissionsFor(SchoolMembership membership) => PrincipalResultsPermissions(
        canViewSecondaryResults: membership.role == SchoolRole.principal,
        canReviewReports: membership.role == SchoolRole.principal,
        canOpenPrintPreview: membership.role == SchoolRole.principal,
        canReleaseToParents: false,
        canEditScores: false,
        canManageSchoolIdentity: false,
        canManagePrimary: false,
      );

  Future<PrincipalResultsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final classRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    final studentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _studentType,
    );
    final decisionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _decisionType,
    );

    final classOrder = {for (var i = 0; i < principalClassResults.length; i++) principalClassResults[i].className: i};
    final studentOrder = {for (var i = 0; i < principalStudentResults.length; i++) principalStudentResults[i].id: i};

    final classes = classRecords.map((record) => PrincipalClassResult.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => (classOrder[a.className] ?? 999).compareTo(classOrder[b.className] ?? 999));
    final students = studentRecords.map((record) => PrincipalStudentResult.fromJson(record.payload)).toList(growable: false)
      ..sort((a, b) => (studentOrder[a.id] ?? 999).compareTo(studentOrder[b.id] ?? 999));
    final decisions = decisionRecords
        .map((record) => PrincipalReportReviewDecision.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));

    return PrincipalResultsSnapshot(
      classes: classes,
      students: students,
      decisions: decisions,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalResultsActionResult> reviewReport({
    required String studentId,
    required PrincipalReportReviewAction action,
    required String comment,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewReports) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'This membership cannot review Secondary report cards.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _studentType,
      entityId: studentId,
    );
    if (record == null) {
      return const PrincipalResultsActionResult(success: false, message: 'Student report not found.');
    }

    final current = PrincipalStudentResult.fromJson(record.payload);
    final reviewedAt = DateTime.now().toUtc().toIso8601String();
    final normalizedComment = comment.trim().isEmpty
        ? (action == PrincipalReportReviewAction.returnWithComment ? principalReturnComment : principalDefaultComment)
        : comment.trim();
    final updated = current.copyWith(
      principalComment: normalizedComment,
      principalApproved: action == PrincipalReportReviewAction.approve,
      lastReviewedByMembershipId: membership.id,
      lastReviewedAt: reviewedAt,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _studentType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _studentType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    final decision = PrincipalReportReviewDecision(
      id: '${updated.id}-${DateTime.now().microsecondsSinceEpoch}',
      studentId: updated.id,
      action: action,
      previousReleaseState: current.reportStatus,
      reviewerMembershipId: membership.id,
      reviewedAt: reviewedAt,
      comment: normalizedComment,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _decisionType,
      entityId: decision.id,
      payload: decision.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _decisionType,
      entityId: decision.id,
      operation: SyncOperation.create,
      payload: decision.toJson(),
    );

    return PrincipalResultsActionResult(
      success: true,
      message: action == PrincipalReportReviewAction.approve
          ? 'Report review approved offline and queued for synchronization. Parent/student release remains unchanged.'
          : 'Report returned with comment offline and queued for synchronization. Scores and release state remain unchanged.',
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final classes = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _classType,
    );
    if (classes.isEmpty) {
      for (final row in principalClassResults) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _classType,
          entityId: row.className,
          payload: row.toJson(),
        );
      }
    }

    final students = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _studentType,
    );
    if (students.isEmpty) {
      for (final row in principalStudentResults) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _studentType,
          entityId: row.id,
          payload: row.toJson(),
        );
      }
    }
  }
}
