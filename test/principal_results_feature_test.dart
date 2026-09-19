import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_results_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_results_models.dart';

void main() {
  test('principal results preserve exact website class and KPI state', () {
    expect(principalClassResults.length, 6);
    expect(principalClassResults.map((row) => row.className).toList(), ['JSS 1A', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A', 'SS 2A']);
    expect(principalResultsSchoolAverage, 72);
    expect(principalResultsPassRate, 89);
    expect(principalReportsReady, 231);
    expect(principalResultsPendingApproval, 1);
    expect(principalResultsReleasedClasses, 1);
  });

  test('class result release states and JSS 2B concern are exact', () {
    final jss2b = principalClassResults.firstWhere((row) => row.className == 'JSS 2B');
    expect(jss2b.students, 39);
    expect(jss2b.average, 61);
    expect(jss2b.passRate, 74);
    expect(jss2b.complete, 92);
    expect(jss2b.reportsReady, 35);
    expect(jss2b.release, PrincipalResultReleaseState.awaitingApproval);
    expect(jss2b.trend, -6.8);
    expect(principalClassResults.firstWhere((row) => row.className == 'JSS 2A').release, PrincipalResultReleaseState.released);
    expect(principalClassResults.firstWhere((row) => row.className == 'SS 1A').release, PrincipalResultReleaseState.draft);
  });

  test('student report cards and exact selected website report evidence are preserved', () {
    expect(principalStudentResults.length, 5);
    expect(principalStudentResults.map((row) => row.id).toList(), ['STU-001', 'STU-002', 'STU-003', 'STU-004', 'STU-005']);
    final gamma = principalStudentResults.firstWhere((row) => row.id == 'STU-003');
    expect(gamma.name, 'Student Gamma');
    expect(gamma.className, 'JSS 2B');
    expect(gamma.average, 48);
    expect(gamma.position, '31st of 39');
    expect(gamma.attendance, 79);
    expect(gamma.reportStatus, PrincipalResultReleaseState.awaitingApproval);
    expect(gamma.teacherComment, contains('targeted revision'));
  });

  test('official report preserves exact five subject rows and school identity', () {
    expect(principalReportSubjects.length, 5);
    expect(principalReportSubjects.map((row) => row.subject).toList(), ['Mathematics', 'English Language', 'Basic Science', 'Social Studies', 'Computer Studies']);
    expect(principalReportSubjects.first.total, 82);
    expect(principalReportSubjects.last.total, 86);
    expect(principalReportSchoolName, 'BrightGate Academy');
    expect(principalReportMotto, 'Knowledge · Character · Excellence');
    expect(principalReportRegistration, 'School Reg. No: BGA/EDU/2026/001');
    expect(principalReportTerm, 'First Term · 2026/2027 Academic Session');
    expect(principalReportPrincipalName, 'Mr. Ibrahim Danladi');
  });

  test('student report serialization keeps Principal review without changing release state', () {
    final original = principalStudentResults[2].copyWith(
      principalComment: 'Reviewed carefully.',
      principalApproved: true,
      lastReviewedByMembershipId: 'MEM-PRINCIPAL-01',
      lastReviewedAt: '2026-09-19T17:00:00Z',
    );
    final restored = PrincipalStudentResult.fromJson(original.toJson());
    expect(restored.reportStatus, PrincipalResultReleaseState.awaitingApproval);
    expect(restored.displayStatus, PrincipalResultReleaseState.approved);
    expect(restored.principalComment, 'Reviewed carefully.');
    expect(restored.lastReviewedByMembershipId, 'MEM-PRINCIPAL-01');
  });

  test('report review decision is append-only audit evidence', () {
    const decision = PrincipalReportReviewDecision(
      id: 'STU-003-1',
      studentId: 'STU-003',
      action: PrincipalReportReviewAction.approve,
      previousReleaseState: PrincipalResultReleaseState.awaitingApproval,
      reviewerMembershipId: 'MEM-PRINCIPAL-01',
      reviewedAt: '2026-09-19T17:00:00Z',
      comment: 'Approved after review.',
    );
    final restored = PrincipalReportReviewDecision.fromJson(decision.toJson());
    expect(restored.studentId, 'STU-003');
    expect(restored.action, PrincipalReportReviewAction.approve);
    expect(restored.previousReleaseState, PrincipalResultReleaseState.awaitingApproval);
    expect(restored.reviewerMembershipId, 'MEM-PRINCIPAL-01');
    expect(decision.toJson()['doesNotRelease'], isTrue);
    expect(decision.toJson()['doesNotRewriteScores'], isTrue);
  });

  test('Principal result permissions remain Secondary scoped and downstream safe', () {
    expect(principalResultsPermissions.canViewSecondaryResults, isTrue);
    expect(principalResultsPermissions.canReviewReports, isTrue);
    expect(principalResultsPermissions.canOpenPrintPreview, isTrue);
    expect(principalResultsPermissions.canReleaseToParents, isFalse);
    expect(principalResultsPermissions.canEditScores, isFalse);
    expect(principalResultsPermissions.canManageSchoolIdentity, isFalse);
    expect(principalResultsPermissions.canManagePrimary, isFalse);
    expect(principalResultsAuthorityBoundary, contains('Secondary'));
    expect(principalResultsReleaseBoundary, contains('not publication'));
    expect(principalResultsScoreBoundary, contains('never rewrites'));
    expect(principalResultsOfflineBoundary, contains('synchronize later'));
  });

  test('AI remains advisory and cannot change results or release state', () {
    expect(principalResultsAiBoundary, contains('must not autonomously change scores'));
    expect(principalResultsAiBoundary, contains('publish reports'));
  });
}
