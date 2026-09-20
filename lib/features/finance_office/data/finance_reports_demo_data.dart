import '../domain/finance_reports_models.dart';

const financeReportLibrary = <FinanceReportDefinition>[
  FinanceReportDefinition(
    title: 'Collection Summary',
    period: 'Current term',
    detail: 'Fees billed, received, balances, collection rate',
  ),
  FinanceReportDefinition(
    title: 'Outstanding Accounts',
    period: 'Current term',
    detail: 'Open family balances by section and age',
  ),
  FinanceReportDefinition(
    title: 'Bank Reconciliation',
    period: 'Daily / monthly',
    detail: 'Matched, unmatched, reversed and adjusted receipts',
  ),
  FinanceReportDefinition(
    title: 'Income & Expense Statement',
    period: 'Monthly',
    detail: 'Operational income, expense categories and net position',
  ),
  FinanceReportDefinition(
    title: 'Education Financing Ledger',
    period: 'Current / historical',
    detail: 'Principal, repayments, outstanding and status',
  ),
  FinanceReportDefinition(
    title: 'Payroll Payment Register',
    period: 'Monthly',
    detail: 'Approved payroll batch and payment confirmation',
  ),
];

const financeReportKpis = <FinanceReportKpi>[
  FinanceReportKpi(
    label: 'Collection rate',
    value: '94.1%',
    hint: 'Current term',
  ),
  FinanceReportKpi(
    label: 'Outstanding',
    value: '₦3.7m',
    hint: '73 family accounts',
  ),
  FinanceReportKpi(
    label: 'Monthly expenses',
    value: '₦6.4m',
    hint: 'September mock',
  ),
  FinanceReportKpi(
    label: 'Bank exceptions',
    value: '7',
    hint: 'Unmatched receipts',
  ),
  FinanceReportKpi(
    label: 'Report pack',
    value: '6',
    hint: 'Core finance reports',
  ),
];

const financeManagementSnapshots = <FinanceManagementSnapshot>[
  FinanceManagementSnapshot(
    section: 'Nursery / Early Years',
    collectionRate: 96,
    status: 'Healthy',
  ),
  FinanceManagementSnapshot(
    section: 'Primary School',
    collectionRate: 91,
    status: 'Healthy',
  ),
  FinanceManagementSnapshot(
    section: 'Secondary School',
    collectionRate: 86,
    status: 'Watch',
  ),
];

const financeReportsMinimumNecessaryBoundary =
    'Finance reports expose the minimum necessary detail for the intended audience. Owner-level summaries must not include parent bank credentials, raw payment credentials, private staff notes, safeguarding records or unrelated family data.';

const financeReportsReadOnlyBoundary =
    'Generating, previewing, printing or exporting a report is read-only. Report actions must not post money, alter a family or child ledger, approve an expense, change reconciliation state, approve payroll, mark payroll Paid or issue a receipt.';

const financeReportsSourceBoundary =
    'Reports summarize authoritative finance ledgers and approved evidence. They must not create a second accounting truth or silently recalculate operational records independently of their source modules.';

const financeReportsSectionRateBoundary =
    'The website section collection percentages are preserved as a management snapshot. Their weighting and denominator are not specified, so they must not be averaged to derive or replace the overall 94.1% collection rate.';

const financeReportsExportBoundary =
    'The website export and report-pack buttons have no production export contract. Native SchoolOS keeps them as non-financial document actions until a secure export/share implementation is connected.';
