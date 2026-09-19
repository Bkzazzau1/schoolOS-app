import '../domain/proprietor_finance_models.dart';

const proprietorFinanceKpis = <OwnerFinanceKpi>[
  OwnerFinanceKpi(label: 'Gross term fees', value: '₦102.77m', note: 'Before concessions'),
  OwnerFinanceKpi(label: 'Scholarships & discounts', value: '₦7.40m', note: 'Approved reductions'),
  OwnerFinanceKpi(label: 'Net collectible', value: '₦95.37m', note: 'Actual parent/sponsor obligation'),
  OwnerFinanceKpi(label: 'Collected', value: '₦81.60m', note: '85.6% of net collectible'),
  OwnerFinanceKpi(label: 'Open receivables', value: '₦13.77m', note: 'Before future mandate attempts'),
];

const proprietorFinanceSections = <OwnerFinanceSectionRow>[
  OwnerFinanceSectionRow(section: 'Nursery / Early Years', grossFees: '₦9.87m', concessions: '₦0.42m', netCollectible: '₦9.45m', collected: '₦8.91m', rate: 94),
  OwnerFinanceSectionRow(section: 'Primary School', grossFees: '₦41.47m', concessions: '₦2.36m', netCollectible: '₦39.11m', collected: '₦32.95m', rate: 84),
  OwnerFinanceSectionRow(section: 'Secondary School', grossFees: '₦51.43m', concessions: '₦4.62m', netCollectible: '₦46.81m', collected: '₦39.74m', rate: 85),
];

const proprietorRevenueBridge = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: 'Gross billed · ₦102.77m', detail: 'Nursery, Primary and Secondary standard fees plus enrolled services.', note: 'Starting billing base'),
  OwnerFinanceListItem(title: 'Less scholarships & discounts · ₦7.40m', detail: 'Founder awards, academic support, sibling discounts and staff-child benefits.', note: 'Not debt'),
  OwnerFinanceListItem(title: 'Net collectible · ₦95.37m', detail: 'The amount families and sponsors are actually expected to pay.', note: 'Collection ceiling base'),
  OwnerFinanceListItem(title: 'Collected · ₦81.60m', detail: 'Confirmed bank/API collections and other reconciled payments.', note: 'Receipts issued automatically in the UI model'),
];

const proprietorFinanceAttention = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: '₦6.8m backed by active mandates', detail: 'Authorized future deductions already have a collection path.', note: 'Monitor success/failure rate'),
  OwnerFinanceListItem(title: '₦7.3m has no active arrangement', detail: 'These balances need finance follow-up, payment plans or owner-approved action.', note: 'Highest collection priority', isWarning: true),
  OwnerFinanceListItem(title: '11 failed mandate attempts', detail: 'Retry, reschedule or contact guardians rather than treating them as ordinary unpaid promises.', note: 'Finance action queue', isWarning: true),
  OwnerFinanceListItem(title: '2 over-limit attempts', detail: 'Student term accounts blocked unusually large payments until Finance authorizes a higher collection ceiling.', note: 'Control working as designed'),
];

const proprietorFinanceAging = <OwnerFinanceAgingRow>[
  OwnerFinanceAgingRow(band: '0–30 days', amount: '₦8.2m', status: 'Current / newly due'),
  OwnerFinanceAgingRow(band: '31–60 days', amount: '₦5.4m', status: 'Follow-up window'),
  OwnerFinanceAgingRow(band: '61–90 days', amount: '₦3.1m', status: 'Structured review'),
  OwnerFinanceAgingRow(band: '90+ days', amount: '₦2.0m', status: 'Priority owner visibility'),
];

const proprietorCollectionArrangements = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: 'Active bank/salary mandates · ₦6.8m', detail: 'Consent-backed scheduled deductions.', note: '412 active mandates'),
  OwnerFinanceListItem(title: 'Manual payment plans · ₦3.4m', detail: 'Families paying agreed amounts over time.', note: 'Partial deposits supported'),
  OwnerFinanceListItem(title: 'Education financing · ₦1.2m', detail: 'Structured financed school-fee obligations.', note: 'Separate repayment ledger'),
  OwnerFinanceListItem(title: 'No arrangement · ₦7.3m', detail: 'Requires collection follow-up.', note: 'Owner attention', isWarning: true),
];

const proprietorStoreRevenue = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: 'Books · ₦4.8m', detail: 'Order-linked store payments only.', note: 'Separate store receipts'),
  OwnerFinanceListItem(title: 'Uniforms · ₦3.2m', detail: 'Linked to inventory issue records.', note: 'Stock movement monitored'),
  OwnerFinanceListItem(title: 'Sportswear & other items · ₦1.1m', detail: 'Dynamic order accounts with exact payment ceilings.', note: 'No school-fee balance impact'),
  OwnerFinanceListItem(title: 'Total store revenue · ₦9.1m', detail: 'Reported outside tuition collections.', note: 'Open School Store'),
];

const proprietorStoreControl = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: '486 orders issued', detail: 'Books, uniforms and other school-store requests.', note: 'Current-term sample'),
  OwnerFinanceListItem(title: '419 paid', detail: 'Payments reconciled through order-specific accounts.', note: 'Separate from tuition'),
  OwnerFinanceListItem(title: '9 paid but not issued', detail: 'Money received, goods still pending collection/fulfillment.', note: 'Priority proprietor exception', isWarning: true),
  OwnerFinanceListItem(title: '7 partially issued', detail: 'Some items supplied while others remain pending.', note: 'Inventory follow-up required', isWarning: true),
];

const proprietorTermCollectionTrend = <int>[32, 45, 57, 66, 74, 80, 86];

const proprietorExpenseWatch = <OwnerFinanceListItem>[
  OwnerFinanceListItem(title: 'Operating expenses · ₦52.8m', detail: 'Utilities, transport, feeding, materials, maintenance and administration.', note: 'Current-term sample'),
  OwnerFinanceListItem(title: 'Payroll · ₦21.8m', detail: 'Processed through restricted payroll workflow.', note: 'Finance sees payment batch, not unrelated HR records'),
  OwnerFinanceListItem(title: 'Expected next 30 days · ₦11.3m', detail: 'Mandates, payment plans and scheduled family commitments.', note: 'Forecast, not guaranteed cash'),
];

const proprietorFinanceQuickActions = <OwnerFinanceQuickAction>[
  OwnerFinanceQuickAction(key: 'fee-structure', title: 'Fee Structure', description: 'Review Nursery, Primary and Secondary billing rules.'),
  OwnerFinanceQuickAction(key: 'concessions', title: 'Scholarships & Discounts', description: 'See how much support reduces parent obligations.'),
  OwnerFinanceQuickAction(key: 'store', title: 'School Store', description: 'Review orders, dynamic accounts, inventory and paid-but-not-issued exceptions.'),
  OwnerFinanceQuickAction(key: 'aging', title: 'Outstanding & Aging', description: 'Separate scheduled collections from genuinely unarranged debt.'),
];
