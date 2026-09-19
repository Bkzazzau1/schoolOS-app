import '../domain/finance_reminders_models.dart';

const financeReminderSeed = <FinanceReminderRow>[
  FinanceReminderRow(
    id: 'REM-26091',
    student: 'Maryam Abdullahi',
    guardian: 'Alhaji Abdullahi Yusuf',
    className: 'JSS 2A',
    balance: 125000,
    arrangement: 'Active mandate',
    nextAmount: 30000,
    nextDate: '25 Sep 2026',
    channels: 'Portal · WhatsApp',
    status: FinanceReminderStatus.scheduled,
    reason: 'Upcoming authorized deduction',
  ),
  FinanceReminderRow(
    id: 'REM-26092',
    student: 'Hafsa Abdullahi',
    guardian: 'Alhaji Abdullahi Yusuf',
    className: 'Primary 3',
    balance: 55000,
    arrangement: 'Manual partial payment',
    nextAmount: 20000,
    nextDate: '20 Sep 2026',
    channels: 'Portal · SMS',
    status: FinanceReminderStatus.scheduled,
    reason: 'Agreed next payment',
  ),
  FinanceReminderRow(
    id: 'REM-26093',
    student: 'Ibrahim Sani',
    guardian: 'Alhaji Sani Ibrahim',
    className: 'JSS 2A',
    balance: 100000,
    arrangement: 'Payment plan',
    nextAmount: 25000,
    nextDate: '18 Sep 2026',
    channels: 'Portal · WhatsApp',
    status: FinanceReminderStatus.sent,
    reason: '3 days before agreed payment',
  ),
  FinanceReminderRow(
    id: 'REM-26094',
    student: 'Yusuf Bello',
    guardian: 'Alhaji Musa Bello',
    className: 'JSS 2B',
    balance: 120000,
    arrangement: 'No arrangement',
    nextAmount: 120000,
    nextDate: 'Overdue',
    channels: 'Portal · SMS · Finance call',
    status: FinanceReminderStatus.needsReview,
    reason: 'No active collection arrangement',
  ),
  FinanceReminderRow(
    id: 'REM-26095',
    student: 'Muhammad Kabir',
    guardian: 'Hajiya Amina Kabir',
    className: 'Primary 5',
    balance: 85000,
    arrangement: 'Education financing',
    nextAmount: 0,
    nextDate: 'Partner schedule',
    channels: 'Portal',
    status: FinanceReminderStatus.skipped,
    reason: 'Financing workflow already active',
  ),
];

const financeReminderStages = <FinanceReminderStage>[
  FinanceReminderStage('7 days before', 'Gentle upcoming-payment notice'),
  FinanceReminderStage('3 days before', 'Reminder with amount, date and payment account'),
  FinanceReminderStage('Due date', 'Due-today notice or mandate-scheduled notice'),
  FinanceReminderStage('3 days overdue', 'Outstanding-payment follow-up'),
  FinanceReminderStage('7 days overdue', 'Finance Office review queue'),
];

const financeReminderSuppressionRules = <FinanceSuppressionRule>[
  FinanceSuppressionRule(
    title: 'Recent payment received',
    detail: 'Pause a scheduled reminder when a new credit already reduced the balance.',
    hint: 'Recalculate before sending',
  ),
  FinanceSuppressionRule(
    title: 'Active mandate pending',
    detail: 'Tell the guardian that a deduction is scheduled instead of asking them to pay twice.',
    hint: 'Mandate-aware wording',
  ),
  FinanceSuppressionRule(
    title: 'Education financing active',
    detail: 'Use the financing schedule rather than ordinary school-fee reminders.',
    hint: 'Separate repayment workflow',
  ),
  FinanceSuppressionRule(
    title: 'Manual finance pause',
    detail: 'Authorized Finance staff can temporarily suppress contact while an arrangement is being reviewed.',
    hint: 'Reason should remain visible in audit history',
  ),
];

const financeReminderHistory = <FinanceReminderHistoryEntry>[
  FinanceReminderHistoryEntry(
    when: '13 Sep · 10:30',
    recipient: 'Ibrahim Sani · WhatsApp + Portal',
    summary: '₦25,000 due 18 Sep',
    status: 'Delivered',
  ),
  FinanceReminderHistoryEntry(
    when: '12 Sep · 09:15',
    recipient: 'Maryam Abdullahi · Portal',
    summary: 'Mandate scheduled 25 Sep',
    status: 'Viewed',
  ),
  FinanceReminderHistoryEntry(
    when: '11 Sep · 14:05',
    recipient: 'Yusuf Bello · SMS',
    summary: 'Finance arrangement requested',
    status: 'Delivered',
  ),
];

const financeReminderDueIn7Days = 84;
const financeReminderMandateBacked = 39;
const financeReminderPaymentPlanFamilies = 21;
const financeReminderNoArrangement = 17;
const financeReminderSuppressedToday = 11;

const financeReminderAcademicBoundary =
    'Reminder status must never affect a pupil’s grades, classroom support, teacher treatment or academic profile. The reminder engine is a finance communication tool only.';

const financeReminderDeliveryBoundary =
    'Marking a reminder Sent in this prototype records a local finance action only. Delivered or Viewed must only come from a provider/server acknowledgement; queued or locally sent is not the same as delivered.';

const financeReminderPrototypeBoundary =
    'Reminder rules, campaign creation and family-account opening remain website prototype actions until their destination workflows are implemented. Do not invent delivery or account mutations.';
