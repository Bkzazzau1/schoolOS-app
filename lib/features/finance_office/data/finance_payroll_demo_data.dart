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
