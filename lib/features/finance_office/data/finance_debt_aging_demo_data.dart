import '../domain/finance_debt_aging_models.dart';

const financeAgingTotalOpenReceivables = 18700000;

const financeAgingSummaries = <FinanceAgingSummary>[
  FinanceAgingSummary(bucket: FinanceAgingBucket.zeroTo30, amount: 8200000, progressPercent: 100, hint: 'Current / newly due'),
  FinanceAgingSummary(bucket: FinanceAgingBucket.thirtyOneTo60, amount: 5400000, progressPercent: 66, hint: 'Follow-up window'),
  FinanceAgingSummary(bucket: FinanceAgingBucket.sixtyOneTo90, amount: 3100000, progressPercent: 38, hint: 'Structured review'),
  FinanceAgingSummary(bucket: FinanceAgingBucket.ninetyPlus, amount: 2000000, progressPercent: 24, hint: 'Priority owner visibility'),
];

const financeArrangementQuality = <FinanceArrangementSummary>[
  FinanceArrangementSummary(label: 'Active mandates', amount: 6800000, description: 'Authorized future collection attempts scheduled.', guidance: 'Do not classify as unarranged debt.'),
  FinanceArrangementSummary(label: 'Payment plans', amount: 3400000, description: 'Families making agreed partial payments.', guidance: 'Monitor adherence.'),
  FinanceArrangementSummary(label: 'Education financing', amount: 1200000, description: 'Approved structured repayment.', guidance: 'Tracked separately from ordinary arrears.'),
  FinanceArrangementSummary(label: 'No active arrangement', amount: 7300000, description: 'Requires finance follow-up or school-approved action.', guidance: 'Primary collection attention.'),
];

const financeFamilyReceivables = <FinanceFamilyReceivable>[
  FinanceFamilyReceivable(family: 'Abdullahi Yusuf Family', children: 'Maryam · Hafsa', balance: 180000, age: FinanceAgingBucket.zeroTo30, plan: 'Mandate active', nextAction: '25 Sep', status: FinanceReceivableStatus.scheduled),
  FinanceFamilyReceivable(family: 'Musa Bello Family', children: 'Yusuf', balance: 50000, age: FinanceAgingBucket.thirtyOneTo60, plan: 'Partial payment', nextAction: 'Contacted 12 Sep', status: FinanceReceivableStatus.watch),
  FinanceFamilyReceivable(family: 'Sani Ibrahim Family', children: 'Ibrahim', balance: 100000, age: FinanceAgingBucket.sixtyOneTo90, plan: 'Financing active', nextAction: '25 Sep', status: FinanceReceivableStatus.structured),
  FinanceFamilyReceivable(family: 'Kabir Ahmad Family', children: 'Muhammad · Zainab', balance: 135000, age: FinanceAgingBucket.ninetyPlus, plan: 'No arrangement', nextAction: 'Finance follow-up', status: FinanceReceivableStatus.action),
  FinanceFamilyReceivable(family: 'Aliyu Umar Family', children: 'Aisha', balance: 35000, age: FinanceAgingBucket.zeroTo30, plan: 'Manual deposits', nextAction: 'Last paid 10 Sep', status: FinanceReceivableStatus.current),
];

const financeAgingActions = <String>[
  'Send payment reminder',
  'Review mandate',
  'Offer payment plan',
  'Record promise to pay',
  'Review financing',
  'Escalate to proprietor',
];

const financeAgingAccountingBoundary = 'Total open receivables are calculated after approved scholarships and discounts. Aging buckets describe timing, while collection arrangements describe the recovery path; age alone must not be treated as proof of unarranged debt.';

const financeAgingAcademicBoundary = 'No debt-aging status should automatically affect grades, classroom participation, academic support, awards or hidden student-risk scoring. The finance team manages the account; academic staff manage learning.';

const financeAgingPrototypeBoundary = 'The website exposes collection-action buttons without a persisted workflow contract. Native SchoolOS must not claim a reminder was delivered, a mandate changed, a payment plan was approved, a promise was accepted or a proprietor escalation occurred until the relevant governed workflow confirms it.';
