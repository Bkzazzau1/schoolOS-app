import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('finance office preserves exact fifteen website destinations', () {
    expect(financeOfficeNavigation.length, 15);
    expect(financeOfficeNavigation.map((item) => item.label).toList(), [
      'Dashboard',
      'Fee Structure',
      'Scholarships & Discounts',
      'Smart Collections',
      'Fee Reminders',
      'School Store',
      'Payment Mandates',
      'Outstanding & Aging',
      'Receipts',
      'Student Accounts',
      'Reconciliation',
      'Expenses & Income',
      'Payroll Handoff',
      'Reports',
      'Finance AI',
    ]);
  });

  test('finance dashboard preserves exact website KPI snapshot', () {
    expect(financeOfficeKpis.length, 5);
    expect(financeOfficeKpis[0].value, '₦62.8m');
    expect(financeOfficeKpis[1].value, '₦59.1m');
    expect(financeOfficeKpis[1].hint, '94.1% collection');
    expect(financeOfficeKpis[2].value, '₦3.7m');
    expect(financeOfficeKpis[2].hint, '73 family accounts');
    expect(financeOfficeKpis[3].value, '7');
    expect(financeOfficeKpis[3].hint, '₦386,000 awaiting review');
    expect(financeOfficeKpis[4].value, '₦21.4m');
  });

  test('finance dashboard preserves collection and review evidence', () {
    expect(financeRecentCollections.length, 4);
    expect(financeRecentCollections.first.reference, 'PAY-260913-204');
    expect(financeRecentCollections[2].status, 'Review');
    expect(financeRecentCollections[2].amount, '₦80,000');
    expect(financeAttentionQueue.length, 4);
    expect(financeAttentionQueue.first.title, '7 unmatched receipts');
    expect(financeAttentionQueue.last.title, 'August payroll package ready');
  });

  test('finance dashboard preserves seven-week collection trend', () {
    expect(financeCollectionTrend.map((point) => point.rate).toList(), [
      72,
      78,
      81,
      84,
      88,
      91,
      94,
    ]);
    expect(financeOperationalPosition.length, 4);
    expect(financeOperationalPosition.first.title, '₦1.24m received today');
  });

  test('finance authority excludes academic and sensitive leadership data', () {
    expect(financeOfficePermissions.canAccessFeeData, isTrue);
    expect(financeOfficePermissions.canAccessTransactions, isTrue);
    expect(financeOfficePermissions.canProcessApprovedPayroll, isTrue);
    expect(financeOfficePermissions.canAccessAcademicGrades, isFalse);
    expect(financeOfficePermissions.canAccessPrivateTeacherNotes, isFalse);
    expect(financeOfficePermissions.canAccessSafeguardingRecords, isFalse);
    expect(financeOfficeScopeBoundary, contains('Academic grading'));
    expect(financeOfficeScopeBoundary, contains('safeguarding'));
  });

  test('finance officer remains a serializable tenant membership role', () {
    const membership = SchoolMembership(
      id: 'membership-finance-001',
      schoolId: 'school-brightgate',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.accountant,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.accountant);
    expect(restored.roleLabel, 'Finance Officer');
  });
}
