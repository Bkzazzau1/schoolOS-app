import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_academics_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_academics_models.dart';

void main() {
  test('website academics seed preserves six exact classes', () {
    expect(principalAcademicClasses.length, 6);
    expect(principalAcademicClasses.first.name, 'JSS 1A');
    expect(principalAcademicClasses[2].name, 'JSS 2B');
    expect(principalAcademicClasses[2].average, 61);
    expect(principalAcademicClasses[2].attendance, 86);
    expect(principalAcademicClasses[2].syllabus, 63);
    expect(principalAcademicClasses[2].assessments, 72);
    expect(principalAcademicClasses[2].trend, -6.8);
    expect(principalAcademicClasses[2].status, PrincipalAcademicStatus.behind);
    expect(principalAcademicClasses.last.name, 'SS 2A');
  });

  test('website computed headline academics KPIs are preserved', () {
    expect(principalSchoolAverage(principalAcademicClasses), 72);
    expect(principalSyllabusAverage(principalAcademicClasses), 74);
    expect(principalAssessmentAverage(principalAcademicClasses), 85);
    expect(principalAcademicClasses.where((row) => row.status == PrincipalAcademicStatus.behind).length, 1);
    expect(principalAcademicClasses.where((row) => row.status == PrincipalAcademicStatus.watch).length, 1);
  });

  test('website subject performance preserves six exact rows', () {
    expect(principalSubjectPerformance.length, 6);
    expect(principalSubjectPerformance.first.name, 'Mathematics');
    expect(principalSubjectPerformance.first.average, 67);
    expect(principalSubjectPerformance.first.target, 70);
    expect(principalSubjectPerformance.first.status, PrincipalAcademicStatus.watch);
    expect(principalSubjectPerformance.last.name, 'Physics');
    expect(principalSubjectPerformance.last.average, 62);
    expect(principalSubjectPerformance.last.status, PrincipalAcademicStatus.behind);
  });

  test('website academic risk queue preserves four exact issues', () {
    expect(principalAcademicRisks.length, 4);
    expect(principalAcademicRisks[0].title, 'JSS 2B Mathematics');
    expect(principalAcademicRisks[0].severity, 'High');
    expect(principalAcademicRisks[1].title, 'SS 1A Physics');
    expect(principalAcademicRisks[2].title, 'JSS 2B attendance');
    expect(principalAcademicRisks[3].title, 'SS 2A marking backlog');
  });

  test('class filtering matches website level status and search behavior', () {
    final jss2 = principalAcademicClasses.where((row) => row.matches(query: '', levelFilter: 'JSS 2', statusFilter: 'All statuses')).toList();
    expect(jss2.length, 2);
    final behind = principalAcademicClasses.where((row) => row.matches(query: '', levelFilter: 'All levels', statusFilter: 'Behind')).single;
    expect(behind.name, 'JSS 2B');
    final issueSearch = principalAcademicClasses.where((row) => row.matches(query: 'Physics', levelFilter: 'All levels', statusFilter: 'All statuses')).single;
    expect(issueSearch.name, 'SS 1A');
  });

  test('class serialization preserves academic evidence', () {
    final row = principalAcademicClasses[2];
    final restored = PrincipalAcademicClass.fromJson(row.toJson());
    expect(restored.name, row.name);
    expect(restored.trend, row.trend);
    expect(restored.status, row.status);
    expect(restored.concern, row.concern);
  });

  test('subject serialization preserves target syllabus and trend', () {
    final row = principalSubjectPerformance.last;
    final restored = PrincipalSubjectPerformance.fromJson(row.toJson());
    expect(restored.name, 'Physics');
    expect(restored.target, 70);
    expect(restored.syllabus, 66);
    expect(restored.trend, -4.7);
  });

  test('AI brief keeps intervention as monitored support before escalation', () {
    expect(principalAcademicsAiBrief, contains('JSS 2B'));
    expect(principalAcademicsAiBrief, contains('review teacher support'));
    expect(principalAcademicsAiBrief, contains('targeted revision'));
    expect(principalAcademicsAiBrief, contains('monitor the next two assessment cycles'));
    expect(principalAcademicsAiBrief, contains('before escalating'));
  });

  test('Principal academics permissions remain Secondary scoped', () {
    expect(principalAcademicsPermissions.canViewSecondaryAcademics, isTrue);
    expect(principalAcademicsPermissions.canLeadSecondaryInterventions, isTrue);
    expect(principalAcademicsPermissions.canManagePrimary, isFalse);
    expect(principalAcademicsPermissions.canManageEarlyYears, isFalse);
    expect(principalAcademicsScopeBoundary, contains('Secondary School'));
    expect(principalAcademicsScopeBoundary, contains('Primary'));
    expect(principalAcademicsScopeBoundary, contains('Early Years'));
  });
}
