import '../domain/administrator_dashboard_models.dart';

const administratorKpis = <AdministratorKpi>[
  AdministratorKpi(
    label: 'Active students',
    value: '648',
    detail: 'Across Early Years, Primary and Secondary',
  ),
  AdministratorKpi(
    label: 'Admissions in progress',
    value: '17',
    detail: '5 awaiting documents',
  ),
  AdministratorKpi(
    label: 'Records tasks',
    value: '12',
    detail: 'Needs admin follow-up',
  ),
  AdministratorKpi(
    label: 'Transfers / withdrawals',
    value: '4',
    detail: 'Current term requests',
  ),
  AdministratorKpi(
    label: 'Staff files',
    value: '64',
    detail: '3 incomplete records',
  ),
];

const administratorWorkQueue = <AdministratorQueueItem>[
  AdministratorQueueItem(
    title: 'New admission form awaiting document review',
    detail: 'ADM-26041 · Aisha Sani · Primary 2',
    area: 'Registration',
  ),
  AdministratorQueueItem(
    title: 'Guardian link needs verification',
    detail: 'FAM-BGA-0081 · Umar Faruq',
    area: 'Family account',
  ),
  AdministratorQueueItem(
    title: 'Transfer-out request awaiting records pack',
    detail: 'STU-003 · Yusuf Bello',
    area: 'Lifecycle',
  ),
  AdministratorQueueItem(
    title: 'Two attendance correction requests',
    detail: 'Secondary · Sep 12',
    area: 'Attendance',
  ),
  AdministratorQueueItem(
    title: 'Staff file missing qualification document',
    detail: 'STAFF-021 · Mr. Ahmad Sani',
    area: 'Staff records',
  ),
];

const administratorTodayActivities = <AdministratorDeskActivity>[
  AdministratorDeskActivity(
    title: '6 new applications received',
    detail: '3 Primary · 2 Secondary · 1 Early Years',
  ),
  AdministratorDeskActivity(
    title: '4 student IDs prepared',
    detail: 'Admission numbers and ID previews generated',
  ),
  AdministratorDeskActivity(
    title: '9 documents verified',
    detail: 'Birth certificates, previous-school records and guardian IDs',
  ),
  AdministratorDeskActivity(
    title: '3 family accounts updated',
    detail: 'Guardian-child relationships confirmed',
  ),
];

const administratorQuickActions = <AdministratorQuickAction>[
  AdministratorQuickAction(
    key: 'registration',
    title: 'Student Registration',
    description:
        'Create admission record, guardian links, admission number and class placement.',
  ),
  AdministratorQuickAction(
    key: 'students',
    title: 'Students & Families',
    description: 'Search and maintain student and guardian records.',
  ),
  AdministratorQuickAction(
    key: 'lifecycle',
    title: 'Transfers & Promotion',
    description:
        'Process transfers, withdrawals, promotion and alumni transitions.',
  ),
  AdministratorQuickAction(
    key: 'records',
    title: 'Records & Documents',
    description: 'Verify, store and track official school documents.',
  ),
  AdministratorQuickAction(
    key: 'scholarships',
    title: 'Request Scholarship / Discount',
    description:
        'Submit a concession for a student. Only the Proprietor can approve it.',
  ),
];

const administratorNavigation = <AdministratorNavItem>[
  AdministratorNavItem(key: 'dashboard', label: 'Dashboard'),
  AdministratorNavItem(key: 'admissions', label: 'Admissions Pipeline'),
  AdministratorNavItem(key: 'website', label: 'Website Manager'),
  AdministratorNavItem(key: 'registration', label: 'Student Registration'),
  AdministratorNavItem(key: 'students', label: 'Students & Families'),
  AdministratorNavItem(key: 'staff', label: 'Staff Records'),
  AdministratorNavItem(key: 'staff-profiles', label: 'Staff Profiles'),
  AdministratorNavItem(key: 'staff-attendance', label: 'Staff Attendance'),
  AdministratorNavItem(key: 'records', label: 'Records & Documents'),
  AdministratorNavItem(key: 'lifecycle', label: 'Transfers & Promotion'),
  AdministratorNavItem(key: 'attendance', label: 'Attendance Desk'),
  AdministratorNavItem(key: 'operations', label: 'Operations'),
  AdministratorNavItem(key: 'notices', label: 'Notices'),
];

const administratorAuthorityBoundary =
    'Administrator manages operational records and workflows. The role can create and maintain operational records and request scholarships or discounts, but cannot finalize academic results, override section leadership, expose confidential payroll, approve safeguarding outcomes, approve a scholarship or discount, or make other proprietor governance decisions.';

const administratorAcademicYear = '2026/2027 · Term 1';
const administratorCampusLabel = 'Kaduna Campus · Whole-school administration';
