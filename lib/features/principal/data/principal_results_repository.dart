import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../administrator/domain/report_card_models.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';
import '../domain/principal_results_models.dart';

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

  List<PrincipalClassResult> get _withEvidence =>
      classes.where((c) => c.complete > 0).toList(growable: false);

  int? get schoolAverage => _withEvidence.isEmpty
      ? null
      : (_withEvidence.fold<int>(0, (sum, c) => sum + c.average) / _withEvidence.length).round();
  int? get passRate => _withEvidence.isEmpty
      ? null
      : (_withEvidence.fold<int>(0, (sum, c) => sum + c.passRate) / _withEvidence.length).round();

  /// The count of released assessments across every Secondary class.
  int get reportsReady => students.where((s) => s.reportStatus == PrincipalResultReleaseState.released).length;

  int get pendingApproval =>
      students.where((s) => s.reportStatus == PrincipalResultReleaseState.awaitingApproval).length;

  int get releasedClasses => classes.where((c) => c.complete > 0).length;
}

class PrincipalResultsActionResult {
  const PrincipalResultsActionResult({
    required this.success,
    required this.message,
  });
  final bool success;
  final String message;
}

class PrincipalResultsRepository {
  PrincipalResultsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    AdministratorStudentsRepository? students,
  }) : _localDatabase = localDatabase,
       _session = schoolSession,
       _students =
           students ??
           AdministratorStudentsRepository(
             localDatabase: localDatabase,
             schoolSession: schoolSession,
           );
  final LocalDatabase _localDatabase;
  final SchoolSessionController _session;
  final AdministratorStudentsRepository _students;
  PrincipalResultsPermissions permissionsFor(SchoolMembership m) =>
      PrincipalResultsPermissions(
        canViewSecondaryResults: m.role == SchoolRole.principal,
        canReviewReports: m.role == SchoolRole.principal,
        canOpenPrintPreview: false,
        canReleaseToParents: false,
        canEditScores: false,
        canManageSchoolIdentity: false,
        canManagePrimary: false,
      );

  Future<PrincipalResultsSnapshot> load() async {
    final member = _session.requireActiveMembership();
    final permissions = permissionsFor(member);
    final counts = <String, int>{};
    if (permissions.canViewSecondaryResults) {
      for (final student in (await _students.load()).students) {
        if (student.status != AdministratorStudentStatus.transferredOut &&
            sectionOfClass(student.className) == 'Secondary') {
          counts.update(
            student.className,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    // Only RELEASED assessments count as recorded evidence for Secondary
    // leadership oversight, matching the same release gate Student/Parent
    // visibility already uses - Principal reviews readiness, never a mark
    // the school has not itself released yet.
    final releasedByClass = <String, List<TeacherAssessment>>{};
    // Report cards visible to Principal review: submitted, reviewed or
    // released, Secondary only. Draft compilations are the Administrator's
    // own working state, not yet ready for Principal eyes.
    final students = <PrincipalStudentResult>[];
    if (permissions.canViewSecondaryResults) {
      final assessmentRecords = await _localDatabase.getLocalRecords(
        tenantId: member.schoolId,
        entityType: teacherAssessmentEntityType,
      );
      for (final record in assessmentRecords) {
        final item = TeacherAssessment.fromJson(record.payload);
        if (item.state != TeacherAssessmentState.released) continue;
        if (sectionOfClass(item.className) != 'Secondary') continue;
        releasedByClass.putIfAbsent(item.className, () => []).add(item);
      }

      final reportCardRecords = await _localDatabase.getLocalRecords(
        tenantId: member.schoolId,
        entityType: reportCardEntityType,
      );
      for (final record in reportCardRecords) {
        final card = ReportCard.fromJson(record.payload);
        if (!card.isSecondary) continue;
        if (card.state == ReportCardState.draft) continue;
        students.add(_studentResult(card));
      }
      students.sort((a, b) => a.name.compareTo(b.name));
    }

    final names = <String>{...counts.keys, ...releasedByClass.keys}.toList()..sort();
    return PrincipalResultsSnapshot(
      classes: [
        for (final name in names) _classResult(name, counts[name] ?? 0, releasedByClass[name] ?? const []),
      ],
      students: students,
      decisions: const [],
      permissions: permissions,
    );
  }

  PrincipalStudentResult _studentResult(ReportCard card) => PrincipalStudentResult(
        id: card.id,
        name: card.studentName,
        className: card.className,
        average: card.overallAverage?.round() ?? 0,
        position: card.classPosition == null ? '' : '${card.classPosition}/${card.classSize}',
        attendance: card.attendancePercent ?? 0,
        reportStatus: switch (card.state) {
          ReportCardState.draft => PrincipalResultReleaseState.draft,
          ReportCardState.submitted => PrincipalResultReleaseState.awaitingApproval,
          ReportCardState.reviewed => PrincipalResultReleaseState.approved,
          ReportCardState.released => PrincipalResultReleaseState.released,
        },
        // No class-teacher/form-teacher role exists yet to author this (see
        // apps.report_cards' own documented gap); left honestly empty rather
        // than fabricated.
        teacherComment: '',
        principalComment: card.principalComment.isEmpty ? null : card.principalComment,
        principalApproved: card.state == ReportCardState.reviewed || card.state == ReportCardState.released,
      );

  PrincipalClassResult _classResult(String className, int students, List<TeacherAssessment> released) {
    final percents = <double>[
      for (final item in released)
        for (final entry in item.entries)
          if (entry.percent != null) entry.percent!,
    ];
    final average = percents.isEmpty ? 0 : (percents.reduce((a, b) => a + b) / percents.length).round();
    final passRate = percents.isEmpty
        ? 0
        : (percents.where((p) => p >= 40).length * 100 / percents.length).round();
    final highest = percents.isEmpty ? 0 : percents.reduce((a, b) => a > b ? a : b).round();
    final lowest = percents.isEmpty ? 0 : percents.reduce((a, b) => a < b ? a : b).round();
    return PrincipalClassResult(
      className: className,
      students: students,
      average: average,
      passRate: passRate,
      highest: highest,
      lowest: lowest,
      complete: released.length,
      reportsReady: 0,
      release: released.isEmpty
          ? PrincipalResultReleaseState.draft
          : PrincipalResultReleaseState.released,
      // No real longitudinal series exists to compute a trend from.
      trend: 0,
    );
  }

  /// [studentId] is the report card's own id (`PrincipalStudentResult.id`),
  /// not the canonical student code - the name is kept for API stability.
  /// This never releases the report card itself, matching the existing
  /// product boundary that Principal approval is a review decision, not
  /// publication - release stays a separate Administrator/Proprietor action.
  Future<PrincipalResultsActionResult> reviewReport({
    required String studentId,
    required PrincipalReportReviewAction action,
    required String comment,
  }) async {
    final member = _session.requireActiveMembership();
    if (!permissionsFor(member).canReviewReports) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'This membership cannot review report cards.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'Report-card review is a canonical server workflow in connected mode.',
      );
    }
    if (action == PrincipalReportReviewAction.returnWithComment && comment.trim().isEmpty) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'Add a comment before returning a report card with concerns.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: reportCardEntityType,
      entityId: studentId,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'Synchronize this report card before reviewing it.',
      );
    }
    final card = ReportCard.fromJson(existing.payload);
    if (card.state != ReportCardState.submitted) {
      return const PrincipalResultsActionResult(
        success: false,
        message: 'Only a submitted report card can be reviewed.',
      );
    }

    final actionName = action == PrincipalReportReviewAction.approve ? 'principalReview' : 'principalReturn';
    final nextState = action == PrincipalReportReviewAction.approve ? ReportCardState.reviewed : ReportCardState.draft;
    final optimistic = card.copyWith(state: nextState, version: card.version + 1, pendingSync: true, serverVersion: existing.serverVersion);
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: reportCardEntityType,
      entityId: studentId,
      payload: _toJson(optimistic),
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: reportCardEntityType,
      entityId: studentId,
      operation: SyncOperation.update,
      payload: {'id': studentId, 'action': actionName, 'comment': comment.trim()},
      baseVersion: existing.serverVersion,
    );
    return PrincipalResultsActionResult(
      success: true,
      message: action == PrincipalReportReviewAction.approve
          ? 'Review recorded and queued. This does not release the report card.'
          : 'Returned for correction, queued for synchronization.',
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
        'generatedAt': card.generatedAt,
        'submittedAt': card.submittedAt,
        'reviewedAt': card.reviewedAt,
        'releasedAt': card.releasedAt,
        'version': card.version,
      };
}
