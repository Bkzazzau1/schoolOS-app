import '../domain/finance_reconciliation_models.dart';

const financeReconciliationRows = <FinanceReconciliationRow>[
  FinanceReconciliationRow(
    reference: 'BNK-260913-881',
    sender: 'A. Abdullahi',
    amount: 50000,
    channel: 'Bank transfer',
    matchLabel: 'Maryam Abdullahi',
    status: FinanceReconciliationStatus.matched,
    familyAccountId: 'FAM-ABD-001',
    familyAccountNumber: '1047263815',
    childLedgerId: 'STU-001',
  ),
  FinanceReconciliationRow(
    reference: 'BNK-260913-879',
    sender: 'Unknown sender',
    amount: 80000,
    channel: 'Bank transfer',
    matchLabel: 'Unmatched',
    status: FinanceReconciliationStatus.review,
  ),
  FinanceReconciliationRow(
    reference: 'MON-260913-412',
    sender: 'Hajiya Aisha Musa',
    amount: 25000,
    channel: 'Monthly debit',
    matchLabel: 'Fatima Musa',
    status: FinanceReconciliationStatus.matched,
  ),
  FinanceReconciliationRow(
    reference: 'BNK-260913-865',
    sender: 'Sani Ibrahim',
    amount: 20000,
    channel: 'Term account',
    matchLabel: 'Ibrahim Sani',
    status: FinanceReconciliationStatus.matched,
    familyAccountId: 'FAM-SAN-002',
    familyAccountNumber: '1047263823',
    childLedgerId: 'STU-002',
  ),
];

const financeReconciliationKpis = <FinanceReconciliationKpi>[
  FinanceReconciliationKpi(
    label: 'Today received',
    value: '₦1.24m',
    hint: '38 payment events',
  ),
  FinanceReconciliationKpi(
    label: 'Auto-matched',
    value: '31',
    hint: 'Family accounts / references',
  ),
  FinanceReconciliationKpi(
    label: 'Unmatched',
    value: '7',
    hint: '₦386,000',
  ),
  FinanceReconciliationKpi(
    label: 'Reversals',
    value: '3',
    hint: 'Awaiting evidence',
  ),
  FinanceReconciliationKpi(
    label: 'Match rate',
    value: '81.6%',
    hint: 'Today',
  ),
];

const financeReconciliationSignals = <({String title, String detail})>[
  (
    title: 'Dedicated family term account',
    detail: 'Strongest deterministic family-level match.',
  ),
  (
    title: 'Payment reference',
    detail: 'Exact verified reference supports allocation.',
  ),
  (
    title: 'Sender name alone',
    detail: 'Insufficient when ambiguous; requires human review.',
  ),
];

const financeReconciliationFamilyBoundary =
    'Reconciliation first identifies the correct family collection account, then the correct child fee ledger. A family-account match alone must not silently change one child balance when several children share that account.';

const financeReconciliationMatchBoundary =
    'An ambiguous transfer must never be marked Matched solely from sender-name similarity. Human review must use stronger evidence such as the family account, verified payment reference, guardian evidence or other auditable records.';

const financeReconciliationPostingBoundary =
    'Matched means the payment identity has been reconciled. Ledger posting and receipt issuance remain downstream steps. A review action must not fabricate a posted credit or a receipt.';

const financeReconciliationReversalBoundary =
    'Refunds and reversals preserve the original transaction, reason, evidence, approver, timestamp and resulting balance. Do not silently edit ledger history.';

const financeReconciliationImportBoundary =
    'Import bank statement remains a website prototype action until a secure statement-import and validation contract is connected. Native SchoolOS must not invent imported bank evidence.';
