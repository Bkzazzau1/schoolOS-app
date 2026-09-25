import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/parent/data/parent_dashboard_demo_data.dart';
import 'package:schoolos_app/features/parent/domain/parent_dashboard_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

const _sampleSnapshot = ParentDashboardSnapshot(
  guardianName: 'Guardian',
  familyAccountId: 'm-parent',
  children: [
    ParentChildSummary(
      id: 'STU-001',
      name: 'Maryam Abdullahi',
      className: 'JSS 2A',
      section: 'Secondary',
      attendancePercent: 100,
      academicPercent: 0,
      feeBalance: 0,
      initials: 'MA',
      presentToday: true,
    ),
  ],
  attentionItems: [],
  finance: ParentFinanceSnapshot(
    totalBilled: 0,
    totalPaid: 0,
    accounts: [],
    nextScheduledDebit: 0,
    nextScheduledDebitLabel: 'Not recorded yet',
  ),
  messages: [],
  notices: [],
);

void main() {
  test('parent workspace preserves exact thirteen website destinations', () {
    expect(parentNavigation.length, 13);
    expect(parentNavigation.map((item) => item.label).toList(), [
      'Home',
      'My Children',
      'Learning Progress',
      'Weekly Learning',
      'Assignments',
      'Attendance',
      'Finance & Payments',
      'Messages',
      'School Discussions',
      'School Life',
      'Documents & Consent',
      'Parent AI',
      'TransferVerify Case',
    ]);
  });

  test('parent snapshot round trips through encrypted-record JSON shape', () {
    final restored = ParentDashboardSnapshot.fromJson(
      Map<String, dynamic>.from(_sampleSnapshot.toJson()),
    );
    expect(restored.guardianName, _sampleSnapshot.guardianName);
    expect(restored.familyAccountId, _sampleSnapshot.familyAccountId);
    expect(restored.children.length, 1);
    expect(restored.children.first.name, 'Maryam Abdullahi');
    expect(restored.finance.nextScheduledDebitLabel, 'Not recorded yet');
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
