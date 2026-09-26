import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

void main() {
  test('finance office preserves exact sixteen website destinations', () {
    expect(financeOfficeNavigation.length, 16);
    expect(financeOfficeNavigation.map((item) => item.label).toList(), [
      'Dashboard',
      'Fee Structure',
      'Scholarships & Discounts',
      'Smart Money Collection',
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
      'Community',
    ]);
  });

  test('finance authority boundary excludes academic and sensitive leadership data', () {
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
