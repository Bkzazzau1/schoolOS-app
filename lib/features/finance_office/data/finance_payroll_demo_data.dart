import '../domain/finance_payroll_models.dart';

const financePayrollRows = <FinancePayrollRow>[
  FinancePayrollRow(
    staffId: 'TCH-2048',
    name: 'Mrs. Amina Yusuf',
    expectedDays: 22,
    presentDays: 21,
    leaveDays: 1,
    unexplainedDays: 0,
    gross: 250000,
    deductions: 56000,
    net: 194000,
    status: FinancePayrollStatus.ready,
  ),
  FinancePayrollRow(
    staffId: 'TCH-2031',
    name: 'Mr. Ahmad Sani',
    expectedDays: 22,
    presentDays: 22,
    leaveDays: 0,
    unexplainedDays: 0,
    gross: 238000,
    deductions: 48000,
    net: 190000,
    status: FinancePayrollStatus.ready,
  ),
  FinancePayrollRow(
    staffId: 'TCH-2016',
    name: 'Mrs. Zainab Musa',
    expectedDays: 22,
    presentDays: 20,
    leaveDays: 1,
    unexplainedDays: 1,
    gross: 310000,
    deductions: 71000,
    net: 239000,
    status: FinancePayrollStatus.attendanceReview,
  ),
];

const financePayrollKpis = <FinancePayrollKpi>[
  FinancePayrollKpi('Payroll gross', '₦14.8m', 'August 2026 mock'),
  FinancePayrollKpi(
    'Deductions',
    '₦2.9m',
    'Approved payroll deductions only',
  ),
  FinancePayrollKpi('Net payroll', '₦11.9m', 'Payment batch value'),
  FinancePayrollKpi(
    'Attendance verified',
    '62 / 64',
    '2 records held for review',
  ),
  FinancePayrollKpi(
    'Payroll exceptions',
    '2',
    'Require human review',
  ),
];

const financePayrollAttendanceRule =
    'Finance may see expected work days, verified present days, approved leave and unresolved attendance exceptions. Raw HR notes, disciplinary records and device-level biometric details remain outside the payroll workspace.';

const financePayrollHumanReviewRule =
    'Late arrival or absence must not silently create a deduction. Any payroll adjustment requires the school’s authorized review and an explicit approved payroll instruction.';

const financePayrollAuthorityBoundary =
    'Finance receives HR-approved payroll figures and reviewed attendance context. HR/leadership retains responsibility for employment decisions, pay-policy decisions and the authorization of any attendance-related adjustment.';

const financePayrollBatchBoundary =
    'Prepare payment batch is a controlled preparation step only. It must not mark salaries Paid, send money, alter approved gross or deductions, or include a staff record that is still held for attendance review.';

const financePayrollSettlementBoundary =
    'A prepared or approved batch is not payment confirmation. Paid status requires authoritative bank/payment evidence, and failed or reversed payments must remain visible in the audit trail.';

const financePayrollCorrectionBoundary =
    'Payroll corrections are append-only adjustments or reversals linked to the original payroll instruction and payment evidence. Do not silently overwrite prior payroll history.';
