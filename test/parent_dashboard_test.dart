import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/parent/data/parent_dashboard_demo_data.dart';
import 'package:schoolos_app/features/parent/domain/parent_dashboard_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('parent workspace preserves exact eleven website destinations', () {
    expect(parentNavigation.length, 11);
    expect(parentNavigation.map((item) => item.label).toList(), [
      'Home',
      'My Children',
      'Learning Progress',
      'Weekly Learning',
      'Attendance',
      'Finance & Payments',
      'Messages',
      'School Discussions',
      'School Life',
      'Documents & Consent',
      'Parent AI',
    ]);
  });

  test('parent dashboard derives family KPIs from source records', () {
    expect(parentDefaultDashboard.linkedChildrenCount, 2);
    expect(parentDefaultDashboard.presentTodayCount, 2);
    expect(parentDefaultDashboard.unreadMessageCount, 2);
    expect(parentDefaultDashboard.totalCurrentBalance, 65000);
    expect(parentDefaultDashboard.finance.nextScheduledDebit, 25000);
  });

  test('parent dashboard preserves linked child website snapshot', () {
    expect(parentDefaultDashboard.children.length, 2);
    expect(parentDefaultDashboard.children.first.name, 'Maryam Abdullahi');
    expect(parentDefaultDashboard.children.first.className, 'JSS 2A');
    expect(parentDefaultDashboard.children.first.attendancePercent, 96);
    expect(parentDefaultDashboard.children.first.academicPercent, 86);
    expect(parentDefaultDashboard.children.last.name, 'Hafsa Abdullahi');
    expect(parentDefaultDashboard.children.last.className, 'Primary 3');
    expect(parentDefaultDashboard.children.last.attendancePercent, 82);
    expect(parentDefaultDashboard.children.last.academicLabel, 'Learning');
  });

  test('parent dashboard finance values reconcile', () {
    final finance = parentDefaultDashboard.finance;
    expect(finance.totalBilled, 420000);
    expect(finance.totalPaid, 355000);
    expect(finance.balance, 65000);
    expect(finance.totalBilled - finance.totalPaid, finance.balance);
    expect(finance.accounts.map((item) => item.balance).toList(), [40000, 25000]);
  });

  test('parent snapshot round trips through encrypted-record JSON shape', () {
    final restored = ParentDashboardSnapshot.fromJson(
      Map<String, dynamic>.from(parentDefaultDashboard.toJson()),
    );
    expect(restored.guardianName, parentDefaultDashboard.guardianName);
    expect(restored.familyAccountId, 'FAM-BGA-0042');
    expect(restored.children.length, 2);
    expect(restored.finance.balance, 65000);
    expect(restored.messages.length, 3);
    expect(restored.notices.length, 3);
  });

  test('parent privacy boundary explicitly protects unrelated records', () {
    expect(parentPrivacyBoundary, contains('linked children'));
    expect(parentPrivacyBoundary, contains('Other families'));
    expect(parentPrivacyBoundary, contains('staff-private notes'));
    expect(parentPrivacyBoundary, contains('restricted safeguarding'));
  });

  test('parent remains a serializable first-class membership role', () {
    const membership = SchoolMembership(
      id: 'membership-parent-001',
      schoolId: 'school-brightgate',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.parent,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.parent);
    expect(restored.roleLabel, 'Parent');
  });
}
