import '../domain/teacher_profile_models.dart';

const teacherProfile = TeacherProfileSnapshotData(
  displayName: 'Mrs. Amina Yusuf',
  staffId: 'TCH-2048',
  payrollId: 'PAY-BGA-2048',
  department: 'Mathematics',
  jobTitle: 'Mathematics Teacher',
  employmentType: 'Full-time · Permanent',
  employmentStatus: 'Active',
  hireDate: '15 January 2022',
  qualification: 'B.Ed Mathematics',
  campus: 'Kaduna Campus',
  bank: 'Partner payroll bank · mock',
  account: '0123456789',
  pensionId: 'PEN-BGA-2048',
  taxId: 'TIN-XXXX-2048',
  contact: TeacherProfileContact(
    phone: '+234 800 000 0000',
    email: 'amina.yusuf@example.edu',
    address: 'Kaduna, Kaduna State',
    nextOfKin: 'Alhaji Yusuf Ibrahim',
    emergencyPhone: '+234 800 000 0101',
  ),
  payslips: [
    TeacherPayslip(
      month: 'August 2026',
      reference: 'PAY/TCH-2048/2026-08',
      basic: 185000,
      housing: 30000,
      transport: 20000,
      responsibility: 15000,
      pension: 14800,
      tax: 13200,
      loan: 25000,
      other: 3000,
      status: 'Paid',
    ),
    TeacherPayslip(
      month: 'July 2026',
      reference: 'PAY/TCH-2048/2026-07',
      basic: 185000,
      housing: 30000,
      transport: 20000,
      responsibility: 15000,
      pension: 14800,
      tax: 13200,
      loan: 25000,
      other: 0,
      status: 'Paid',
    ),
    TeacherPayslip(
      month: 'June 2026',
      reference: 'PAY/TCH-2048/2026-06',
      basic: 185000,
      housing: 30000,
      transport: 20000,
      responsibility: 15000,
      pension: 14800,
      tax: 13200,
      loan: 25000,
      other: 0,
      status: 'Paid',
    ),
  ],
);

const teacherProfileAttendance = (
  attendance: 96,
  lateArrivals: 2,
  approvedLeaveDays: 3,
  unapprovedAbsence: 0,
);

const teacherProfileLoanBalance = 75000;
const teacherProfileLoanPrincipal = 150000;
const teacherProfileLoanMonthlyRepayment = 25000;
const teacherProfileLoanCompletion = 'November 2026';
const teacherProfileCompleteness = 96;

const teacherProfileQualifications = [
  ('B.Ed Mathematics', 'Ahmadu Bello University · Verified', 'Primary qualification'),
  ('Teachers Registration Council record', 'Registration document · Mock verified', 'Professional'),
  ('Classroom Assessment Workshop', 'May 2026 · Internal professional development', 'CPD'),
  ('Digital Learning & Safety', 'February 2026 · School training', 'CPD'),
];

const teacherProfileTeachingLoad = [
  ('JSS 2A · Mathematics', '7 periods/week · Room B12', 'Class teacher support'),
  ('JSS 2B · Mathematics', '7 periods/week · Room B14', 'Subject teacher'),
  ('JSS 3A · Mathematics', '7 periods/week · Room C04', 'Subject teacher'),
  ('SS 1A · Further Mathematics', '7 periods/week · Room D06', 'Subject teacher'),
];

const teacherProfileLeaveHistory = [
  ('Annual leave', '12–13 August 2026', 'Approved · 2 days'),
  ('Personal leave', '3 June 2026', 'Approved · 1 day'),
];

const teacherProfileAllowances = [
  ('Housing allowance', 30000),
  ('Transport allowance', 20000),
  ('Responsibility allowance', 15000),
  ('Other recurring allowance', 0),
];

const teacherProfileDeductions = [
  ('Pension contribution', 14800, 'Statutory / configured'),
  ('PAYE / tax', 13200, 'Payroll tax'),
  ('Staff loan repayment', 25000, 'Ends Nov 2026'),
  ('Other deduction', 3000, 'Staff cooperative'),
];

const teacherProfileLoanHistory = [
  ('28 Aug 2026', 'LREP-260828-018', 25000, 75000, 'Repaid'),
  ('28 Jul 2026', 'LREP-260728-014', 25000, 100000, 'Repaid'),
  ('28 Jun 2026', 'LREP-260628-009', 25000, 125000, 'Repaid'),
];

const teacherProfileDocuments = [
  ('Appointment letter', 'Employment document · Verified', 'HR + Staff'),
  ('B.Ed certificate', 'Qualification document · Verified', 'HR + Staff'),
  ('TRCN record', 'Professional registration · Current', 'HR + Staff'),
  ('Bank / payroll mandate', 'Payroll setup record · Current', 'Payroll only'),
];

const teacherProfileTimeline = [
  ('28 Aug 2026', 'August payroll completed', 'Net salary ₦192,000 paid under payroll reference PAY/TCH-2048/2026-08.'),
  ('15 Aug 2026', 'Leave completed', 'Two days annual leave closed as approved.'),
  ('30 May 2026', 'Professional development recorded', 'Classroom Assessment Workshop completed.'),
  ('15 Jan 2022', 'Employment started', 'Joined BrightGate Academy as Mathematics Teacher.'),
];

const teacherProfileSecurityRows = [
  ('Password', 'Last changed 62 days ago', 'Change password'),
  ('Signed-in devices', '2 active sessions', 'Manage sessions'),
  ('Multi-factor authentication', 'Recommended for staff accounts', 'Set up MFA'),
];

const teacherProfileConnectedWork = [
  ('My Classes', 'classes'),
  ('Attendance', 'attendance'),
  ('My Performance', 'performance'),
];
