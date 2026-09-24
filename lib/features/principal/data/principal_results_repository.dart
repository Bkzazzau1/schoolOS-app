import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
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

  /// The count of released assessments across every Secondary class - the
  /// real evidence available today. There is no separate report-card /
  /// approval workflow yet (see [pendingApproval]), so this is not a report
  /// count; it is labelled accordingly wherever it is shown.
  int get reportsReady => classes.fold<int>(0, (sum, c) => sum + c.complete);

  /// No report-approval workflow exists yet to have a pending queue.
  int get pendingApproval => 0;

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
        canReviewReports: false,
        canOpenPrintPreview: false,
        canReleaseToParents: false,
        canEditScores: false,
        canManageSchoolIdentity: false,
        canManagePrimary: false,
      );

  Future<PrincipalResultsSnapshot> load() async {
    final member = _session.requireActiveMembership();
    final counts = <String, int>{};
    if (permissionsFor(member).canViewSecondaryResults) {
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
    if (permissionsFor(member).canViewSecondaryResults) {
      final records = await _localDatabase.getLocalRecords(
        tenantId: member.schoolId,
        entityType: teacherAssessmentEntityType,
      );
      for (final record in records) {
        final item = TeacherAssessment.fromJson(record.payload);
        if (item.state != TeacherAssessmentState.released) continue;
        if (sectionOfClass(item.className) != 'Secondary') continue;
        releasedByClass.putIfAbsent(item.className, () => []).add(item);
      }
    }

    final names = <String>{...counts.keys, ...releasedByClass.keys}.toList()..sort();
    return PrincipalResultsSnapshot(
      classes: [
        for (final name in names) _classResult(name, counts[name] ?? 0, releasedByClass[name] ?? const []),
      ],
      students: const [],
      decisions: const [],
      permissions: permissionsFor(member),
    );
  }

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

  // No canonical term report card exists yet: Teacher assessments now carry a
  // real subject, type and grading scale, but a report card also needs a term
  // grade roll-up, position, conduct and Principal/Administrator sign-off,
  // which are a separate, not-yet-built feature. Nothing is fabricated here.
  Future<PrincipalResultsActionResult> reviewReport({
    required String studentId,
    required PrincipalReportReviewAction action,
    required String comment,
  }) async => const PrincipalResultsActionResult(
    success: false,
    message:
        'No official report card is available to review yet. Assessment results are recorded and released per assessment, not yet compiled into a term report card.',
  );
}
