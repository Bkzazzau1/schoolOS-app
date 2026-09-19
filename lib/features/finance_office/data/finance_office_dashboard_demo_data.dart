import '../domain/finance_office_dashboard_models.dart';

const financeOfficeLeaderName = 'Mr. Ahmad Bello';
const financeOfficeLeaderTitle = 'Bursar / Finance Officer';
const financeOfficeCampusLabel = 'Kaduna Campus · 2026/2027 Term 1';

const financeOfficeNavigation = <FinanceOfficeNavItem>[
  FinanceOfficeNavItem(key: 'dashboard', label: 'Dashboard'),
  FinanceOfficeNavItem(key: 'fee-structure', label: 'Fee Structure'),
  FinanceOfficeNavItem(key: 'scholarships', label: 'Scholarships & Discounts'),
  FinanceOfficeNavItem(key: 'collections', label: 'Smart Collections'),
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
];

const financeOfficeKpis = <FinanceKpi>[
  FinanceKpi(
    label: 'Term billed',
    value: '₦62.8m',
    hint: 'All active student accounts',
  ),
  FinanceKpi(
    label: 'Collected',
    value: '₦59.1m',
    hint: '94.1% collection',
  ),
  FinanceKpi(
    label: 'Outstanding',
    value: '₦3.7m',
    hint: '73 family accounts',
  ),
  FinanceKpi(
    label: 'Unmatched receipts',
    value: '7',
    hint: '₦386,000 awaiting review',
  ),
  FinanceKpi(
    label: 'Cash & bank position',
    value: '₦21.4m',
    hint: 'Mock operational balance',
  ),
];

const financeRecentCollections = <FinanceCollectionActivity>[
  FinanceCollectionActivity(
    reference: 'PAY-260913-204',
    account: 'Maryam Abdullahi',
    channel: 'Term account transfer',
    amount: '₦50,000',
    status: 'Matched',
  ),
  FinanceCollectionActivity(
    reference: 'PAY-260913-198',
    account: 'Hafsa Abdullahi',
    channel: 'Parent monthly debit',
    amount: '₦25,000',
    status: 'Matched',
  ),
  FinanceCollectionActivity(
    reference: 'PAY-260913-191',
    account: 'Unmatched transfer',
    channel: 'Bank transfer',
    amount: '₦80,000',
    status: 'Review',
  ),
  FinanceCollectionActivity(
    reference: 'PAY-260912-177',
    account: 'Yusuf Bello',
    channel: 'Term account transfer',
    amount: '₦35,000',
    status: 'Matched',
  ),
];

const financeAttentionQueue = <FinanceAttentionItem>[
  FinanceAttentionItem(
    title: '7 unmatched receipts',
    detail: 'Verify sender/reference before allocation.',
    caption: 'Bank reconciliation',
  ),
  FinanceAttentionItem(
    title: '3 reversal requests',
    detail: 'Require supporting evidence and approval trail.',
    caption: 'Payments',
  ),
  FinanceAttentionItem(
    title: '₦150k financing outstanding',
    detail: 'Two active education-financing facilities.',
    caption: 'No automated eligibility decision',
  ),
  FinanceAttentionItem(
    title: 'August payroll package ready',
    detail: 'HR-approved figures awaiting finance payment confirmation.',
    caption: 'Payroll handoff',
  ),
];

const financeCollectionTrend = <FinanceTrendPoint>[
  FinanceTrendPoint(week: 'W1', rate: 72),
  FinanceTrendPoint(week: 'W2', rate: 78),
  FinanceTrendPoint(week: 'W3', rate: 81),
  FinanceTrendPoint(week: 'W4', rate: 84),
  FinanceTrendPoint(week: 'W5', rate: 88),
  FinanceTrendPoint(week: 'W6', rate: 91),
  FinanceTrendPoint(week: 'W7', rate: 94),
];

const financeOperationalPosition = <FinanceAttentionItem>[
  FinanceAttentionItem(
    title: '₦1.24m received today',
    detail: '31 matched payment events.',
  ),
  FinanceAttentionItem(
    title: '₦286k expenses posted',
    detail: 'Utilities, transport fuel and supplies.',
  ),
  FinanceAttentionItem(
    title: '118 recurring parent plans',
    detail: 'Guardian-authorized schedules only.',
  ),
  FinanceAttentionItem(
    title: '5 approval items',
    detail: 'Refunds, reversals and financing actions.',
  ),
];

const financeOfficePermissions = FinanceOfficePermissions(
  canAccessFeeData: true,
  canAccessTransactions: true,
  canProcessApprovedPayroll: true,
  canAccessAcademicGrades: false,
  canAccessPrivateTeacherNotes: false,
  canAccessSafeguardingRecords: false,
);

const financeOfficeScopeBoundary =
    'Finance Office access is limited to fee, transaction, approved financing and payroll-processing data. Academic grading, private teacher notes and safeguarding records remain outside this workspace.';
