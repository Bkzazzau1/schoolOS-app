import '../domain/principal_dashboard_models.dart';

const principalNavigation = <PrincipalNavItem>[
  PrincipalNavItem(key: 'dashboard', label: 'Dashboard'),
  PrincipalNavItem(key: 'teachers', label: 'Teachers'),
  PrincipalNavItem(key: 'staff-profiles', label: 'Staff Profiles'),
  PrincipalNavItem(key: 'assignments', label: 'Teaching Assignments'),
  PrincipalNavItem(key: 'academics', label: 'Academics'),
  PrincipalNavItem(key: 'students', label: 'Students'),
  PrincipalNavItem(key: 'attendance', label: 'Attendance'),
  PrincipalNavItem(key: 'approvals', label: 'Approvals'),
  PrincipalNavItem(key: 'results', label: 'Results & Reports'),
  PrincipalNavItem(key: 'timetable', label: 'Timetable'),
  PrincipalNavItem(key: 'communication', label: 'Communication'),
  PrincipalNavItem(key: 'incidents', label: 'Incidents'),
  PrincipalNavItem(key: 'ai', label: 'Principal AI'),
  PrincipalNavItem(key: 'performance', label: 'School Performance'),
  PrincipalNavItem(key: 'profile', label: 'Profile'),
];

const principalScopeBoundary =
    'Principal authority is scoped to the Secondary School section. It may include Secondary academic approvals and interventions, but it does not confer Proprietor-wide governance or Primary/Early Years leadership authority.';
