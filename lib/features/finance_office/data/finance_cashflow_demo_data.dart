import '../domain/finance_cashflow_models.dart';

const financeCashflowEntries = <FinanceCashflowEntry>[
  FinanceCashflowEntry(
    date: '13 Sep 2026',
    description: 'Fuel & transport operations',
    type: FinanceCashflowType.expense,
    category: 'Operations',
    amount: 186000,
    status: FinanceCashflowStatus.approved,
  ),
  FinanceCashflowEntry(
    date: '13 Sep 2026',
    description: 'School fees collections',
    type: FinanceCashflowType.income,
    category: 'Operations',
    amount: 1240000,
    status: FinanceCashflowStatus.posted,
  ),
  FinanceCashflowEntry(
    date: '12 Sep 2026',
    description: 'Laboratory supplies',
    type: FinanceCashflowType.expense,
    category: 'Operations',
    amount: 72500,
    status: FinanceCashflowStatus.approved,
  ),
  FinanceCashflowEntry(
    date: '12 Sep 2026',
    description: 'After-school activity fees',
    type: FinanceCashflowType.income,
    category: 'Operations',
    amount: 215000,
    status: FinanceCashflowStatus.posted,
  ),
  FinanceCashflowEntry(
    date: '11 Sep 2026',
    description: 'Utilities',
    type: FinanceCashflowType.expense,
    category: 'Operations',
    amount: 128400,
    status: FinanceCashflowStatus.approved,
  ),
];

const financeCashflowKpis = <FinanceCashflowKpi>[
  FinanceCashflowKpi(
    label: 'Income this month',
    value: '₦18.6m',
    hint: 'Posted receipts',
  ),
  FinanceCashflowKpi(
    label: 'Expenses this month',
    value: '₦6.4m',
    hint: 'Approved/posting',
  ),
  FinanceCashflowKpi(
    label: 'Net operating inflow',
    value: '₦12.2m',
    hint: 'Prototype figure',
  ),
  FinanceCashflowKpi(
    label: 'Pending approvals',
    value: '9',
    hint: '₦742,000',
  ),
  FinanceCashflowKpi(
    label: 'Budget variance',
    value: '+3.8%',
    hint: 'Against monthly plan',
  ),
];

const financeExpenseControls = <FinanceExpenseControl>[
  FinanceExpenseControl(
    title: 'Supporting evidence',
    detail: 'Invoice/receipt and business purpose should accompany expense requests.',
  ),
  FinanceExpenseControl(
    title: 'Approval separation',
    detail: 'Requester and approver should be distinct where policy requires.',
  ),
  FinanceExpenseControl(
    title: 'Immutable posting trail',
    detail: 'Corrections use reversals/adjustments rather than deleting history.',
  ),
  FinanceExpenseControl(
    title: 'Budget context',
    detail: 'Show budget impact before approval without blocking emergency policy exceptions.',
  ),
];

const financeIncomeEntryBoundary =
    'A new income entry is a local draft until SchoolOS has authoritative receipt or settlement evidence and an accountable posting reference. Draft income must not increase posted cash, collections, or a family balance.';

const financeExpenseRequestBoundary =
    'A new expense request is not an approved expense and must not reduce cash. Approval records authorization; payment or bank settlement is a separate downstream event.';

const financeExpenseEvidenceBoundary =
    'Expense requests should retain supporting evidence, business purpose, requester, reviewer and timestamps. Emergency exceptions can follow policy without erasing the evidence trail.';

const financeCashflowCorrectionBoundary =
    'Posted or approved history is immutable. Corrections use reversal or adjustment entries linked to the original record; do not delete or silently rewrite financial history.';

const financeCashflowPrototypeBoundary =
    'The website buttons do not yet provide a production posting workflow. Native SchoolOS keeps both entry actions as controlled prototype drafts and does not fabricate approval, settlement or ledger posting.';
