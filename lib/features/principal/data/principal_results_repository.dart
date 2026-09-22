import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
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
  int? get schoolAverage => null;
  int? get passRate => null;
  int get reportsReady => 0;
  int get pendingApproval => 0;
  int get releasedClasses => 0;
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
  }) : _session = schoolSession,
       _students =
           students ??
           AdministratorStudentsRepository(
             localDatabase: localDatabase,
             schoolSession: schoolSession,
           );
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
    final names = counts.keys.toList()..sort();
    return PrincipalResultsSnapshot(
      classes: [
        for (final name in names)
          PrincipalClassResult(
            className: name,
            students: counts[name]!,
            average: 0,
            passRate: 0,
            highest: 0,
            lowest: 0,
            complete: 0,
            reportsReady: 0,
            release: PrincipalResultReleaseState.draft,
            trend: 0,
          ),
      ],
      students: const [],
      decisions: const [],
      permissions: permissionsFor(member),
    );
  }

  // Legacy seeded reports are not real school documents.
  Future<PrincipalResultsActionResult> reviewReport({
    required String studentId,
    required PrincipalReportReviewAction action,
    required String comment,
  }) async => const PrincipalResultsActionResult(
    success: false,
    message:
        'No official report is available to review. Assessment records are not term report cards.',
  );
}
