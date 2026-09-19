import '../domain/finance_fee_structure_models.dart';

const financeFeeTerms = <String>[
  '2026/2027 · Term 1',
  '2026/2027 · Term 2',
  '2026/2027 · Term 3',
];

const financeFeeSections = <FinanceFeeSection>[
  FinanceFeeSection(
    section: 'Nursery / Early Years',
    students: 84,
    tuition: 95000,
    development: 10000,
    activities: 7500,
    technology: 5000,
    total: 117500,
  ),
  FinanceFeeSection(
    section: 'Primary School',
    students: 286,
    tuition: 115000,
    development: 12000,
    activities: 8000,
    technology: 10000,
    total: 145000,
  ),
  FinanceFeeSection(
    section: 'Secondary School',
    students: 278,
    tuition: 145000,
    development: 15000,
    activities: 10000,
    technology: 15000,
    total: 185000,
  ),
];

const financeOptionalCharges = <FinanceOptionalCharge>[
  FinanceOptionalCharge(
    charge: 'Transport',
    amount: 'Route-based',
    mode: 'Optional',
    rule: 'Assigned after route selection',
  ),
  FinanceOptionalCharge(
    charge: 'Meals / Feeding',
    amount: '₦35,000',
    mode: 'Optional',
    rule: 'Per term',
  ),
  FinanceOptionalCharge(
    charge: 'Boarding',
    amount: 'Configured separately',
    mode: 'Optional',
    rule: 'Where school offers boarding',
  ),
  FinanceOptionalCharge(
    charge: 'Books / Materials',
    amount: 'Class-based',
    mode: 'Optional / required by policy',
    rule: 'Itemized before billing',
  ),
  FinanceOptionalCharge(
    charge: 'Uniform',
    amount: 'Item-based',
    mode: 'Optional',
    rule: 'Not merged into tuition silently',
  ),
];

const financeBillingSequence = <FinanceBillingStep>[
  FinanceBillingStep(
    number: 1,
    title: 'Section fee structure',
    detail: 'Nursery, Primary or Secondary base charges.',
  ),
  FinanceBillingStep(
    number: 2,
    title: 'Optional services',
    detail: 'Transport, feeding, books and other enrolled services.',
  ),
  FinanceBillingStep(
    number: 3,
    title: 'Scholarships & discounts',
    detail: 'Approved concessions reduce the parent obligation.',
  ),
  FinanceBillingStep(
    number: 4,
    title: 'Net collectible',
    detail: 'Becomes the student term-account collection ceiling.',
  ),
  FinanceBillingStep(
    number: 5,
    title: 'Collections',
    detail: 'Partial deposits and mandates reduce the outstanding balance.',
  ),
];

const financeFeeBillingPopulation = 648;
const financeFeeAccountingDistinction =
    'Fee structure defines what the school charges. Scholarships, sibling/staff discounts and approved waivers reduce what the parent owes. Unpaid balances are calculated only after those concessions are applied.';

String financeMoney(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
    buffer.write(raw[i]);
  }
  return '₦$buffer';
}
