import '../domain/principal_dashboard_models.dart';

const principalAcademicYear = '2026/2027 Academic Year';
const principalCampusLabel = 'Kaduna Campus · Secondary School · Principal';
const principalLeaderName = 'Mr. Ibrahim Danladi';

const principalNavigation = <PrincipalNavItem>[
  PrincipalNavItem(key: 'dashboard', label: 'Dashboard'),
  PrincipalNavItem(key: 'teachers', label: 'Teachers'),
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

const principalKpis = <PrincipalKpi>[
  PrincipalKpi(label: 'Secondary students present', value: '92%', hint: '403 of 438'),
  PrincipalKpi(label: 'Secondary teachers present', value: '96%', hint: '23 of 24'),
  PrincipalKpi(label: 'Pending approvals', value: '4', hint: '2 high priority'),
  PrincipalKpi(label: 'Classes on track', value: '87%', hint: 'Academics + syllabus'),
  PrincipalKpi(label: 'Student risk alerts', value: '18', hint: '6 require follow-up'),
  PrincipalKpi(label: 'Open incidents', value: '3', hint: '1 escalated'),
];

const principalApprovals = <PrincipalApprovalItem>[
  PrincipalApprovalItem(type: 'Lesson Plan', title: 'JSS 2A · Linear Equations', teacher: 'Mrs. Amina Yusuf', age: '18 min', priority: 'Normal'),
  PrincipalApprovalItem(type: 'Assessment', title: 'JSS 3A · Topic Test', teacher: 'Mr. Daniel John', age: '42 min', priority: 'Normal'),
  PrincipalApprovalItem(type: 'Report Card', title: 'JSS 2B · First Term Reports', teacher: 'Mrs. Fatima Bello', age: '1 hr', priority: 'High'),
  PrincipalApprovalItem(type: 'Score Correction', title: 'SS 1A · CA 1', teacher: 'Mr. Peter James', age: '2 hrs', priority: 'High'),
];

const principalTeachers = <PrincipalTeacherIndicator>[
  PrincipalTeacherIndicator(name: 'Mrs. Amina Yusuf', subject: 'Mathematics', compliance: 92, syllabus: 71, status: 'Good'),
  PrincipalTeacherIndicator(name: 'Mr. Daniel John', subject: 'Basic Science', compliance: 96, syllabus: 78, status: 'Strong'),
  PrincipalTeacherIndicator(name: 'Mrs. Fatima Bello', subject: 'English', compliance: 84, syllabus: 66, status: 'Watch'),
  PrincipalTeacherIndicator(name: 'Mr. Peter James', subject: 'Further Mathematics', compliance: 89, syllabus: 73, status: 'Good'),
];

const principalClasses = <PrincipalClassIndicator>[
  PrincipalClassIndicator(name: 'JSS 2A', average: 76, attendance: 94, syllabus: 72, status: 'On track'),
  PrincipalClassIndicator(name: 'JSS 2B', average: 63, attendance: 88, syllabus: 61, status: 'Needs attention'),
  PrincipalClassIndicator(name: 'JSS 3A', average: 81, attendance: 96, syllabus: 79, status: 'Strong'),
  PrincipalClassIndicator(name: 'SS 1A', average: 69, attendance: 91, syllabus: 67, status: 'On track'),
];

const principalAlerts = <PrincipalAlert>[
  PrincipalAlert(title: 'JSS 2B attendance', detail: '88% · below 92% target', warning: true),
  PrincipalAlert(title: 'Syllabus delay', detail: '2 classes behind expected pace', warning: true),
  PrincipalAlert(title: 'Teaching assignments', detail: '3 class-subjects still unassigned'),
  PrincipalAlert(title: 'Report approval', detail: 'JSS 2B report cards waiting'),
];

const principalActivity = <String>[
  'Mrs. Amina Yusuf submitted a lesson plan for JSS 2A.',
  'JSS 2B attendance fell below the weekly Secondary School target.',
  '34 JSS 3A assessment scores were submitted for review.',
  'A guardian communication was escalated to Secondary School leadership.',
  'SS 1A timetable substitution was accepted for Period 4.',
];

const principalAiBrief =
    'JSS 2B remains the highest-priority class today: attendance is below target, Mathematics syllabus pace is behind, and recent assessment performance is weaker than parallel classes. The section also has unassigned or high-load teaching responsibilities that should be checked before timetable finalization.';

const principalScopeBoundary =
    'Principal authority is scoped to the Secondary School section. It may include Secondary academic approvals and interventions, but it does not confer Proprietor-wide governance or Primary/Early Years leadership authority.';

const principalPermissions = PrincipalPermissions(
  canLeadSecondary: true,
  canApproveAcademicWork: true,
  canGovernWholeSchool: false,
  canLeadPrimary: false,
);
