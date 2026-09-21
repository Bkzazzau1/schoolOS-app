import '../domain/administrator_dashboard_models.dart';

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
