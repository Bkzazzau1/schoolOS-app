import '../domain/finance_mandates_models.dart';

const financeMandates = <FinanceMandate>[
  FinanceMandate(
    id: 'MDT-26041',
    guardian: 'Alhaji Abdullahi Yusuf',
    children: 'Maryam + Hafsa',
    method: 'Bank direct debit',
    provider: 'Remita / partner rail',
    amount: 30000,
    day: '25th monthly',
    nextAttempt: '25 Sep 2026',
    status: FinanceMandateStatus.active,
    latestAttempt: FinanceMandateAttempt.successful,
  ),
  FinanceMandate(
    id: 'MDT-26042',
    guardian: 'Alhaji Musa Bello',
    children: 'Yusuf Bello',
    method: 'Salary-linked',
    provider: 'Lendsqr / partner rail',
    amount: 30000,
    day: '28th monthly',
    nextAttempt: '28 Sep 2026',
    status: FinanceMandateStatus.active,
    latestAttempt: FinanceMandateAttempt.failed,
  ),
  FinanceMandate(
    id: 'MDT-26043',
    guardian: 'Hajiya Aisha Aliyu',
    children: 'Zainab Aliyu',
    method: 'Bank direct debit',
    provider: 'Partner Bank B',
    amount: 20000,
    day: '20th monthly',
    nextAttempt: '20 Sep 2026',
    status: FinanceMandateStatus.pendingConsent,
    latestAttempt: FinanceMandateAttempt.notStarted,
  ),
];

const financeMandateActiveCount = 412;
const financeMandateExpectedNext30Days = '₦11.3M';
const financeMandateSuccessfulThisMonth = 286;
const financeMandateFailedAttempts = 7;
const financeMandatePendingConsent = 19;

const financeMandateWorkflow = <FinanceMandateWorkflowStep>[
  FinanceMandateWorkflowStep('Parent chooses plan', 'Amount + frequency'),
  FinanceMandateWorkflowStep('Consent captured', 'Mandate reference'),
  FinanceMandateWorkflowStep('Provider attempts debit', 'Bank / salary rail'),
  FinanceMandateWorkflowStep('SchoolOS posts payment', 'Student fee ledger'),
  FinanceMandateWorkflowStep('Receipt issued', 'Parent portal'),
];

const financeMandateConsentBoundary =
    'A pending-consent mandate is not active and must not trigger a debit attempt.';
const financeMandateProviderBoundary =
    'Retry, pause and reschedule actions require provider-side acknowledgement; a local UI action must not claim that the bank or salary rail changed.';
const financeMandatePostingBoundary =
    'SchoolOS may post a fee payment only after an authoritative provider confirmation of a successful debit.';
const financeMandateReceiptBoundary =
    'A receipt is issued only after the confirmed payment is posted to the student fee ledger.';
