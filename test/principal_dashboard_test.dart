import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_dashboard_demo_data.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('principal workspace preserves exact fourteen website destinations', () {
    expect(principalNavigation.length, 14);
    expect(principalNavigation.map((item) => item.label).toList(), [
      'Dashboard',
      'Teachers',
      'Teaching Assignments',
      'Academics',
      'Students',
      'Attendance',
      'Approvals',
      'Results & Reports',
      'Timetable',
      'Communication',
      'Incidents',
      'Principal AI',
      'School Performance',
      'Profile',
    ]);
  });

  test('principal dashboard preserves exact website KPI snapshot', () {
    expect(principalKpis.length, 6);
    expect(principalKpis[0].value, '92%');
    expect(principalKpis[0].hint, '403 of 438');
    expect(principalKpis[1].value, '96%');
    expect(principalKpis[1].hint, '23 of 24');
    expect(principalKpis[2].value, '4');
    expect(principalKpis[3].value, '87%');
    expect(principalKpis[4].value, '18');
    expect(principalKpis[5].value, '3');
  });

  test('principal approval queue preserves four exact website items', () {
    expect(principalApprovals.length, 4);
    expect(principalApprovals.where((item) => item.priority == 'High').length, 2);
    expect(principalApprovals.first.type, 'Lesson Plan');
    expect(principalApprovals.last.type, 'Score Correction');
  });

  test('principal teacher and class indicators preserve website data', () {
    expect(principalTeachers.length, 4);
    expect(principalTeachers.first.name, 'Mrs. Amina Yusuf');
    expect(principalTeachers.first.compliance, 92);
    expect(principalTeachers[2].status, 'Watch');
    expect(principalClasses.length, 4);
    expect(principalClasses[1].name, 'JSS 2B');
    expect(principalClasses[1].attendance, 88);
    expect(principalClasses[1].status, 'Needs attention');
  });

  test('principal dashboard preserves alerts activity and AI brief focus', () {
    expect(principalAlerts.length, 4);
    expect(principalAlerts.where((item) => item.warning).length, 2);
    expect(principalActivity.length, 5);
    expect(principalAiBrief, contains('JSS 2B'));
    expect(principalAiBrief, contains('Secondary'));
  });

  test('teacher search follows website name subject and status behavior', () {
    expect(principalTeachers.where((item) => item.matches('mathematics')).length, 2);
    expect(principalTeachers.where((item) => item.matches('watch')).single.name, 'Mrs. Fatima Bello');
    expect(principalTeachers.where((item) => item.matches('amina')).single.subject, 'Mathematics');
  });

  test('principal authority is Secondary-scoped rather than whole-school governance', () {
    expect(principalPermissions.canLeadSecondary, isTrue);
    expect(principalPermissions.canApproveAcademicWork, isTrue);
    expect(principalPermissions.canGovernWholeSchool, isFalse);
    expect(principalPermissions.canLeadPrimary, isFalse);
    expect(principalScopeBoundary, contains('Secondary School'));
    expect(principalScopeBoundary, contains('Proprietor-wide'));
  });

  test('principal remains a serializable first-class membership role', () {
    const membership = SchoolMembership(
      id: 'membership-principal-001',
      schoolId: 'school-brightgate',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.principal);
    expect(restored.roleLabel, 'Principal');
  });
}
