import '../domain/finance_family_accounts_models.dart';

const financeFamilyAccounts = <FinanceFamilyAccount>[
  FinanceFamilyAccount(
    id: 'FAM-ABD-001',
    guardian: 'Alhaji Abdullahi Yusuf',
    accountNumber: '1047263815',
    provider: 'Partner Bank A',
    status: FinanceFamilyAccountStatus.active,
    children: [
      FinanceChildFeeLedger(
        id: 'STU-001',
        student: 'Maryam Abdullahi',
        className: 'JSS 2A',
        billed: 185000,
        paid: 135000,
      ),
      FinanceChildFeeLedger(
        id: 'PRI-003',
        student: 'Hafsa Abdullahi',
        className: 'Primary 3',
        billed: 145000,
        paid: 95000,
      ),
    ],
  ),
  FinanceFamilyAccount(
    id: 'FAM-SAN-002',
    guardian: 'Alhaji Sani Ibrahim',
    accountNumber: '1047263823',
    provider: 'Partner Bank A',
    status: FinanceFamilyAccountStatus.active,
    children: [
      FinanceChildFeeLedger(
        id: 'STU-002',
        student: 'Ibrahim Sani',
        className: 'JSS 2A',
        billed: 185000,
        paid: 85000,
      ),
    ],
  ),
  FinanceFamilyAccount(
    id: 'FAM-BEL-003',
    guardian: 'Alhaji Musa Bello',
    accountNumber: '1047263831',
    provider: 'Partner Bank A',
    status: FinanceFamilyAccountStatus.active,
    children: [
      FinanceChildFeeLedger(
        id: 'STU-003',
        student: 'Yusuf Bello',
        className: 'JSS 2B',
        billed: 185000,
        paid: 65000,
      ),
    ],
  ),
];

const financeAccountsKpis = <({String label, String value, String hint})>[
  (label: 'Enrolled students', value: '648', hint: 'Linked to family finance accounts'),
  (label: 'Term billed', value: '₦62.8m', hint: 'Current term'),
  (label: 'Collected', value: '₦59.1m', hint: '94.1%'),
  (label: 'Open balances', value: '73', hint: 'Family accounts'),
  (label: 'Payment plans', value: '118', hint: 'Guardian-authorized'),
];

const financeFamilyAccountBoundary =
    'One responsible parent or guardian receives one family collection account for the term. Children do not each need a separate bank account. Every child still keeps a separate fee ledger under that family account for billing, concessions, allocations, balances and receipts.';

const financeFamilyAllocationBoundary =
    'A payment received into a family account must be allocated to one or more linked child fee ledgers before child balances or receipts change. An unallocated family credit must never be silently assigned to the wrong child.';

const financeFamilyAcademicBoundary =
    'Finance staff may manage billing and payment records, but family balances must not alter academic grades, awards, classroom treatment or student-risk scoring.';

const financeFamilyPrototypeBoundary =
    'Open detailed Finance Center remains a navigation concept from the website. Native SchoolOS does not invent account-level mutations that are not backed by a governed workflow.';
