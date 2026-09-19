import '../domain/principal_performance_models.dart';

const principalPerformancePeriods = <String>[
  '1st Term 2026/27',
  '3rd Term 2025/26',
  '2nd Term 2025/26',
];

const principalPerformanceComparisons = <String>[
  'Previous term',
  'Same term last year',
  'School target',
];

const principalPerformanceMetrics = <PrincipalPerformanceMetric>[
  PrincipalPerformanceMetric(label: 'Academic average', current: 72, previous: 69, target: 75, suffix: '%', routeKey: 'academics'),
  PrincipalPerformanceMetric(label: 'Student attendance', current: 92, previous: 90, target: 95, suffix: '%', routeKey: 'attendance'),
  PrincipalPerformanceMetric(label: 'Teacher attendance', current: 94, previous: 92, target: 96, suffix: '%', routeKey: 'teachers'),
  PrincipalPerformanceMetric(label: 'Lesson-plan compliance', current: 89, previous: 84, target: 95, suffix: '%', routeKey: 'teachers'),
  PrincipalPerformanceMetric(label: 'Syllabus coverage', current: 75, previous: 70, target: 82, suffix: '%', routeKey: 'academics'),
  PrincipalPerformanceMetric(label: 'Assessment completion', current: 86, previous: 80, target: 95, suffix: '%', routeKey: 'results'),
  PrincipalPerformanceMetric(label: 'Guardian response', current: 84, previous: 77, target: 90, suffix: '%', routeKey: 'communication'),
  PrincipalPerformanceMetric(label: 'Resolved incidents', current: 81, previous: 74, target: 90, suffix: '%', routeKey: 'incidents'),
];

const principalPerformanceTrend = <PrincipalPerformanceTrend>[
  PrincipalPerformanceTrend(term: '3rd Term 2024/25', academics: 67, attendance: 89, teacher: 88, operations: 76),
  PrincipalPerformanceTrend(term: '1st Term 2025/26', academics: 69, attendance: 90, teacher: 90, operations: 79),
  PrincipalPerformanceTrend(term: '2nd Term 2025/26', academics: 71, attendance: 91, teacher: 92, operations: 82),
  PrincipalPerformanceTrend(term: '3rd Term 2025/26', academics: 69, attendance: 90, teacher: 91, operations: 81),
  PrincipalPerformanceTrend(term: '1st Term 2026/27', academics: 72, attendance: 92, teacher: 94, operations: 85),
];

const principalClassHealth = <PrincipalClassHealth>[
  PrincipalClassHealth(className: 'JSS 2A', score: 89, trend: 5, status: 'Strong'),
  PrincipalClassHealth(className: 'JSS 3A', score: 91, trend: 7, status: 'Strong'),
  PrincipalClassHealth(className: 'SS 2A', score: 83, trend: 2, status: 'On track'),
  PrincipalClassHealth(className: 'JSS 1A', score: 81, trend: 3, status: 'On track'),
  PrincipalClassHealth(className: 'SS 1A', score: 72, trend: -2, status: 'Watch'),
  PrincipalClassHealth(className: 'JSS 2B', score: 64, trend: -7, status: 'Needs attention'),
];

const principalPerformancePriorities = <PrincipalPerformancePriority>[
  PrincipalPerformancePriority(title: 'JSS 2B intervention', area: 'Academics + Attendance', detail: 'Average, attendance and syllabus pace are declining together.', routeKey: 'academics', severity: 'High'),
  PrincipalPerformancePriority(title: 'Science staffing continuity', area: 'Teachers + Timetable', detail: 'Recent staff absence is creating coverage pressure in Science.', routeKey: 'timetable', severity: 'High'),
  PrincipalPerformancePriority(title: 'Report release backlog', area: 'Results', detail: 'One monitored class still has report cards awaiting principal approval.', routeKey: 'results', severity: 'Medium'),
  PrincipalPerformancePriority(title: 'Guardian engagement', area: 'Communication', detail: 'Response rate improved but remains below the school target.', routeKey: 'communication', severity: 'Medium'),
];

const principalPerformanceSnapshot = PrincipalPerformanceSnapshot(
  metrics: principalPerformanceMetrics,
  termTrend: principalPerformanceTrend,
  classHealth: principalClassHealth,
  priorities: principalPerformancePriorities,
);

const principalPerformanceAiSummary = 'The school is improving overall, especially in teacher compliance, attendance and operational follow-through. However, the average hides concentrated weakness in JSS 2B and some Science delivery pressure. The recommended management approach is targeted intervention rather than a school-wide policy change.';
