import '../domain/finance_receipts_models.dart';

const financeReceipts = <FinanceReceipt>[
  FinanceReceipt(
    number: 'BGA/RCPT/2026/004819',
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    admissionNumber: 'BGA/2023/SEC/001',
    amount: 25000,
    date: '13 Sep 2026',
    method: 'Student Term Account',
    transactionReference: 'TRX-260913-94821',
    previousBalance: 150000,
    newBalance: 125000,
    status: FinanceReceiptStatus.confirmed,
  ),
  FinanceReceipt(
    number: 'BGA/RCPT/2026/004818',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    admissionNumber: 'BGA/2024/PRI/014',
    amount: 50000,
    date: '13 Sep 2026',
    method: 'Student Term Account',
    transactionReference: 'TRX-260913-94817',
    previousBalance: 100000,
    newBalance: 50000,
    status: FinanceReceiptStatus.confirmed,
  ),
  FinanceReceipt(
    number: 'BGA/RCPT/2026/004817',
    student: 'Zainab Aliyu',
    className: 'Nursery 2',
    admissionNumber: 'BGA/2025/NUR/007',
    amount: 15000,
    date: '13 Sep 2026',
    method: 'Student Term Account',
    transactionReference: 'TRX-260913-94811',
    previousBalance: 65000,
    newBalance: 50000,
    status: FinanceReceiptStatus.confirmed,
  ),
];

const financeReceiptSchoolName = 'BrightGate Academy';
const financeReceiptCampusLine = 'Kaduna Campus · Knowledge · Character · Excellence';
const financeReceiptTerm = '2026/2027 · Term 1';

const financeReceiptIssuanceBoundary =
    'A confirmed receipt may be created only after the authoritative collection event is confirmed and the credit is posted to the student fee ledger. Queued, pending, failed, unmatched or provider-attempt states must not create a confirmed receipt.';

const financeReceiptMutationBoundary =
    'Printing or exporting a receipt is a document action only. It must never post another payment, alter the student balance, change the collection status or create a duplicate receipt.';

const financeReceiptPrototypeBoundary =
    'The website uses browser print and exposes Export register without a persistence or export contract. Native SchoolOS keeps these as non-financial prototype document actions until a real print/export integration is connected.';
