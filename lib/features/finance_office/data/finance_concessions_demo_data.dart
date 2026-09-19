import '../domain/finance_concessions_models.dart';

const financeConcessionSeed = <FinanceConcessionRequest>[
  FinanceConcessionRequest(
    id: 'CNC-2026-041',
    student: 'Yusuf Bello',
    className: 'JSS 2B',
    type: FinanceConcessionType.scholarship,
    grossFee: 185000,
    amount: 75000,
    reason: 'Founder Scholarship · BrightGate Founder Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '02 Sep 2026',
    status: FinanceConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '03 Sep 2026',
    decisionNote: 'Approved per founder fund allocation.',
  ),
  FinanceConcessionRequest(
    id: 'CNC-2026-042',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    type: FinanceConcessionType.discount,
    grossFee: 145000,
    amount: 10000,
    reason: 'Sibling Discount · school policy',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '10 Sep 2026',
    status: FinanceConcessionStatus.pendingApproval,
  ),
  FinanceConcessionRequest(
    id: 'CNC-2026-043',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    type: FinanceConcessionType.scholarship,
    grossFee: 145000,
    amount: 50000,
    reason: 'Academic Scholarship · BrightGate Scholarship Fund',
    requestedBy: 'Finance Office',
    requestedByRole: 'Finance Office',
    requestedAt: '05 Sep 2026',
    status: FinanceConcessionStatus.approved,
    decidedBy: 'Proprietor',
    decidedAt: '06 Sep 2026',
    decisionNote: 'Approved based on academic performance review.',
  ),
  FinanceConcessionRequest(
    id: 'CNC-2026-044',
    student: 'Aisha Ibrahim',
    className: 'Nursery 2',
    type: FinanceConcessionType.discount,
    grossFee: 117500,
    amount: 23500,
    reason: 'Staff Child Discount · staff benefit policy',
    requestedBy: 'Administrator',
    requestedByRole: 'Administrator',
    requestedAt: '12 Sep 2026',
    status: FinanceConcessionStatus.pendingApproval,
  ),
];

const financeConcessionFundingRows = <({String label, String value, int percent})>[
  (label: 'Founder / school fund', value: '₦125k', percent: 72),
  (label: 'Policy discounts', value: '₦33.5k', percent: 34),
  (label: 'External sponsors', value: '₦0 sample', percent: 18),
];

const financeConcessionControlPrinciple =
    'If a student has a ₦185,000 standard fee and receives a ₦75,000 scholarship, SchoolOS should normally set the parent obligation and term-account collection ceiling from ₦110,000—not continue treating ₦75,000 as unpaid school fees.';
