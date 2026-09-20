import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/auth/app_capability.dart';
import 'package:schoolos_app/features/administrator/data/administrator_dashboard_demo_data.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('administrator dashboard preserves exact website KPI values', () {
    expect(administratorKpis, hasLength(5));
    expect(administratorKpis[0].value, '648');
    expect(administratorKpis[1].value, '17');
    expect(administratorKpis[2].value, '12');
    expect(administratorKpis[3].value, '4');
    expect(administratorKpis[4].value, '64');
  });

  test('administrator work queue and today activity match website structure', () {
    expect(administratorWorkQueue, hasLength(5));
    expect(administratorTodayActivities, hasLength(4));
    expect(
      administratorWorkQueue.first.detail,
      'ADM-26041 · Aisha Sani · Primary 2',
    );
    expect(administratorWorkQueue.last.area, 'Staff records');
  });

  test('administrator workspace exposes the twelve website destinations plus Staff Profiles', () {
    expect(administratorNavigation, hasLength(13));
    expect(
      administratorNavigation.map((item) => item.label).toList(),
      [
        'Dashboard',
        'Admissions Pipeline',
        'Website Manager',
        'Student Registration',
        'Students & Families',
        'Staff Records',
        'Staff Profiles',
        'Staff Attendance',
        'Records & Documents',
        'Transfers & Promotion',
        'Attendance Desk',
        'Operations',
        'Notices',
      ],
    );
  });

  test('administrator quick actions preserve proprietor approval boundary', () {
    expect(administratorQuickActions, hasLength(5));
    final concession = administratorQuickActions
        .firstWhere((action) => action.key == 'scholarships');
    expect(concession.description, contains('Only the Proprietor can approve'));
  });

  test('administrator is a first-class serializable school membership role', () {
    const membership = SchoolMembership(
      id: 'admin-1',
      schoolId: 'school-a',
      schoolName: 'School A',
      role: SchoolRole.administrator,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.administrator);
    expect(restored.roleLabel, 'Administrator');
  });

  test('administrator receives operations access without governance powers', () {
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.administration),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.students),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.attendance),
      isTrue,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.academics),
      isFalse,
    );
    expect(
      RolePermissions.can(SchoolRole.administrator, AppCapability.finance),
      isFalse,
    );
    expect(administratorAuthorityBoundary, contains('cannot finalize academic results'));
    expect(administratorAuthorityBoundary, contains('cannot finalize academic results'));
    expect(administratorAuthorityBoundary, contains('approve a scholarship or discount'));
  });
}
