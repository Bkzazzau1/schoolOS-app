import '../domain/finance_collections_models.dart';

const financeTermAccounts = <FinanceTermAccount>[
  FinanceTermAccount(
    id: 'BGA/2023/SEC/001',
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    guardian: 'Alhaji Abdullahi Yusuf',
    account: '1047263815',
    provider: 'Partner Bank A',
    gross: 185000,
    scholarship: 0,
    discount: 0,
    paid: 60000,
    limit: 125000,
    status: FinanceTermAccountStatus.active,
    lastPayment: '₦25,000 · 13 Sep',
  ),
  FinanceTermAccount(
    id: 'BGA/2022/PRI/003',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    guardian: 'Alhaji Abdullahi Yusuf',
    account: '1047263914',
    provider: 'Partner Bank A',
    gross: 145000,
    scholarship: 0,
    discount: 10000,
    paid: 80000,
    limit: 55000,
    status: FinanceTermAccountStatus.active,
    lastPayment: '₦20,000 · 12 Sep',
  ),
  FinanceTermAccount(
    id: 'BGA/2024/PRI/014',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    guardian: 'Alhaji Kabir Musa',
    account: '1047263948',
    provider: 'Partner Bank B',
    gross: 155000,
    scholarship: 30000,
    discount: 0,
    paid: 75000,
    limit: 50000,
    status: FinanceTermAccountStatus.active,
    lastPayment: '₦50,000 · Today',
  ),
  FinanceTermAccount(
    id: 'BGA/2025/NUR/007',
    student: 'Zainab Aliyu',
    className: 'Nursery 2',
    guardian: 'Hajiya Aisha Aliyu',
    account: '1047263999',
    provider: 'Partner Bank B',
    gross: 125000,
    scholarship: 25000,
    discount: 0,
    paid: 50000,
    limit: 50000,
    status: FinanceTermAccountStatus.review,
    lastPayment: '₦15,000 · Today',
  ),
];

const financeCollectionFeed = <FinanceCollectionEvent>[
  FinanceCollectionEvent(
    time: '10:42 AM',
    student: 'Maryam Abdullahi',
    amount: 25000,
    account: '1047263815',
    status: FinanceCollectionStatus.confirmed,
    reference: 'TRX-260913-94821',
  ),
  FinanceCollectionEvent(
    time: '10:37 AM',
    student: 'Muhammad Kabir',
    amount: 50000,
    account: '1047263948',
    status: FinanceCollectionStatus.confirmed,
    reference: 'TRX-260913-94817',
  ),
  FinanceCollectionEvent(
    time: '10:31 AM',
    student: 'Zainab Aliyu',
    amount: 15000,
    account: '1047263999',
    status: FinanceCollectionStatus.confirmed,
    reference: 'TRX-260913-94811',
  ),
  FinanceCollectionEvent(
    time: '09:58 AM',
    student: 'Hafsa Abdullahi',
    amount: 20000,
    account: '1047263914',
    status: FinanceCollectionStatus.confirmed,
    reference: 'TRX-260913-94790',
  ),
];

const financeCollectionLimitReasons = <String>[
  'Term fee + approved charges',
  'Transport + tuition',
  'Books + tuition',
  'Previous-term arrears',
  'Advance payment',
  'Other approved arrangement',
];

const financeCollectionValidityOptions = <String>[
  'Until term closes',
  '24 hours',
  '72 hours',
  '7 days',
];

const financeCollectionStatusItems = <({String title, String detail})>[
  (title: '7 failed mandate attempts', detail: 'Retry, reschedule or contact guardian.'),
  (title: '2 unmatched bank transactions', detail: 'Need reference/account investigation.'),
  (title: '1 over-limit attempt', detail: 'Awaiting special arrangement approval.'),
  (title: '11 accounts nearly cleared', detail: 'Outstanding balance below ₦20,000.'),
];

const financeCollectionsDepositBoundary =
    'Parents may deposit smaller amounts at any time. SchoolOS treats this as amount paid toward fees, not money stored in a wallet.';

const financeCollectionsCeilingBoundary =
    'Payments above the authorized collection ceiling require a school-arranged limit change.';

const financeCollectionsPrototypeBoundary =
    'The website currently models collection-limit authorization as a UI prototype only. Native SchoolOS must not claim a bank-side ceiling changed until a real provider-backed workflow exists.';
