import '../domain/finance_office_dashboard_models.dart';

const financeOfficeLeaderTitle = 'Bursar / Finance Officer';

const financeOfficeNavigation = <FinanceOfficeNavItem>[
  FinanceOfficeNavItem(key: 'dashboard', label: 'Dashboard'),
  FinanceOfficeNavItem(key: 'fee-structure', label: 'Fee Structure'),
  FinanceOfficeNavItem(key: 'scholarships', label: 'Scholarships & Discounts'),
  FinanceOfficeNavItem(key: 'collections', label: 'Smart Money Collection'),
  FinanceOfficeNavItem(key: 'reminders', label: 'Fee Reminders'),
  FinanceOfficeNavItem(key: 'store', label: 'School Store'),
  FinanceOfficeNavItem(key: 'mandates', label: 'Payment Mandates'),
  FinanceOfficeNavItem(key: 'debt-aging', label: 'Outstanding & Aging'),
  FinanceOfficeNavItem(key: 'receipts', label: 'Receipts'),
  FinanceOfficeNavItem(key: 'accounts', label: 'Student Accounts'),
  FinanceOfficeNavItem(key: 'reconciliation', label: 'Reconciliation'),
  FinanceOfficeNavItem(key: 'expenses', label: 'Expenses & Income'),
  FinanceOfficeNavItem(key: 'payroll', label: 'Payroll Handoff'),
  FinanceOfficeNavItem(key: 'reports', label: 'Reports'),
  FinanceOfficeNavItem(key: 'ai', label: 'Finance AI'),
  FinanceOfficeNavItem(key: 'community', label: 'Community'),
];

const financeOfficeScopeBoundary =
    'Finance Office access is limited to fee, transaction, approved financing and payroll-processing data. Academic grading, private teacher notes and safeguarding records remain outside this workspace.';
