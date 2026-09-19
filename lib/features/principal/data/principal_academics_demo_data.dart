import '../domain/principal_academics_models.dart';

const principalAcademicClasses = <PrincipalAcademicClass>[
  PrincipalAcademicClass(name: 'JSS 1A', level: 'JSS 1', students: 44, average: 72, attendance: 94, syllabus: 78, assessments: 91, teachers: 8, trend: 3.2, status: PrincipalAcademicStatus.onTrack, concern: 'No major concern'),
  PrincipalAcademicClass(name: 'JSS 2A', level: 'JSS 2', students: 42, average: 76, attendance: 95, syllabus: 74, assessments: 89, teachers: 8, trend: 4.7, status: PrincipalAcademicStatus.strong, concern: 'Good improvement across Mathematics and Science'),
  PrincipalAcademicClass(name: 'JSS 2B', level: 'JSS 2', students: 39, average: 61, attendance: 86, syllabus: 63, assessments: 72, teachers: 8, trend: -6.8, status: PrincipalAcademicStatus.behind, concern: 'Mathematics pace and attendance need intervention'),
  PrincipalAcademicClass(name: 'JSS 3A', level: 'JSS 3', students: 41, average: 79, attendance: 96, syllabus: 84, assessments: 94, teachers: 9, trend: 6.4, status: PrincipalAcademicStatus.strong, concern: 'Maintaining strong performance'),
  PrincipalAcademicClass(name: 'SS 1A', level: 'SS 1', students: 37, average: 68, attendance: 91, syllabus: 69, assessments: 78, teachers: 10, trend: -1.9, status: PrincipalAcademicStatus.watch, concern: 'Physics and Further Mathematics below target'),
  PrincipalAcademicClass(name: 'SS 2A', level: 'SS 2', students: 35, average: 74, attendance: 93, syllabus: 77, assessments: 86, teachers: 10, trend: 2.1, status: PrincipalAcademicStatus.onTrack, concern: 'Minor marking backlog in two subjects'),
];

const principalSubjectPerformance = <PrincipalSubjectPerformance>[
  PrincipalSubjectPerformance(name: 'Mathematics', average: 67, target: 70, syllabus: 71, trend: -2.4, status: PrincipalAcademicStatus.watch),
  PrincipalSubjectPerformance(name: 'English Language', average: 75, target: 70, syllabus: 79, trend: 3.1, status: PrincipalAcademicStatus.strong),
  PrincipalSubjectPerformance(name: 'Basic Science', average: 73, target: 70, syllabus: 76, trend: 1.8, status: PrincipalAcademicStatus.onTrack),
  PrincipalSubjectPerformance(name: 'Social Studies', average: 78, target: 70, syllabus: 82, trend: 4.0, status: PrincipalAcademicStatus.strong),
  PrincipalSubjectPerformance(name: 'Computer Studies', average: 81, target: 75, syllabus: 85, trend: 5.6, status: PrincipalAcademicStatus.strong),
  PrincipalSubjectPerformance(name: 'Physics', average: 62, target: 70, syllabus: 66, trend: -4.7, status: PrincipalAcademicStatus.behind),
];

const principalAcademicRisks = <PrincipalAcademicRisk>[
  PrincipalAcademicRisk(title: 'JSS 2B Mathematics', detail: 'Average 58% · syllabus 61% · 7 students below intervention threshold', severity: 'High'),
  PrincipalAcademicRisk(title: 'SS 1A Physics', detail: 'Average 60% · assessment completion 68% · two topics behind', severity: 'High'),
  PrincipalAcademicRisk(title: 'JSS 2B attendance', detail: 'Class attendance 86%, below school target of 92%', severity: 'Medium'),
  PrincipalAcademicRisk(title: 'SS 2A marking backlog', detail: 'Two subjects have outstanding CA entries', severity: 'Medium'),
];

const principalAcademicsAiBrief =
    'JSS 2B is the clearest intervention priority: academic average is down 6.8%, attendance is below target, and syllabus coverage is only 63%. SS 1A also needs attention in Physics and Further Mathematics. Recommended action: review teacher support, run targeted revision, and monitor the next two assessment cycles before escalating.';

const principalAcademicsScopeBoundary =
    'Academic monitoring and intervention authority on this page is limited to the Secondary School section. Primary and Early Years remain under their own leadership memberships.';

const principalAcademicsPermissions = PrincipalAcademicsPermissions(
  canViewSecondaryAcademics: true,
  canLeadSecondaryInterventions: true,
  canManagePrimary: false,
  canManageEarlyYears: false,
);

const principalAcademicLevels = <String>['All levels', 'JSS 1', 'JSS 2', 'JSS 3', 'SS 1', 'SS 2'];
const principalAcademicStatuses = <String>['All statuses', 'Strong', 'On track', 'Watch', 'Behind'];

int principalSchoolAverage(List<PrincipalAcademicClass> rows) =>
    ((rows.fold<int>(0, (sum, row) => sum + row.average) / rows.length).round());

int principalSyllabusAverage(List<PrincipalAcademicClass> rows) =>
    ((rows.fold<int>(0, (sum, row) => sum + row.syllabus) / rows.length).round());

int principalAssessmentAverage(List<PrincipalAcademicClass> rows) =>
    ((rows.fold<int>(0, (sum, row) => sum + row.assessments) / rows.length).round());
