import '../domain/teacher_performance_models.dart';

const teacherPerformanceScore = 88;
const teacherPerformanceScoreLabel = 'Very good';
const teacherPerformanceHeadline =
    'Strong consistency with one clear improvement area';
const teacherPerformanceSummary =
    'You are above target for attendance and lesson planning. The main opportunity in this demo view is assessment completion and JSS 2B syllabus pace.';

const teacherPerformanceMetrics = <TeacherPerformanceMetric>[
  TeacherPerformanceMetric(
    label: 'Attendance completion',
    value: 98,
    target: 95,
    note: 'Consistently completed on time',
  ),
  TeacherPerformanceMetric(
    label: 'Lesson-plan compliance',
    value: 92,
    target: 90,
    note: '11 of 12 plans submitted',
  ),
  TeacherPerformanceMetric(
    label: 'Assessment completion',
    value: 84,
    target: 90,
    note: 'One CA entry still incomplete',
  ),
  TeacherPerformanceMetric(
    label: 'Syllabus pace',
    value: 71,
    target: 75,
    note: 'JSS 2B needs recovery planning',
  ),
];

const teacherClassPerformance = <TeacherClassPerformance>[
  TeacherClassPerformance(
    name: 'JSS 2A',
    average: 74,
    change: '+3.2%',
    attendance: 94,
    syllabusPace: 72,
  ),
  TeacherClassPerformance(
    name: 'JSS 2B',
    average: 68,
    change: '-1.4%',
    attendance: 91,
    syllabusPace: 68,
  ),
  TeacherClassPerformance(
    name: 'JSS 3A',
    average: 79,
    change: '+6.4%',
    attendance: 96,
    syllabusPace: 81,
  ),
  TeacherClassPerformance(
    name: 'SS1A',
    average: 72,
    change: '+1.8%',
    attendance: 93,
    syllabusPace: 64,
  ),
];

const teacherDevelopmentLog = <TeacherDevelopmentLogItem>[
  TeacherDevelopmentLogItem(
    title: 'Revision strategy · JSS 2B',
    detail: 'Planned for Week 7',
  ),
  TeacherDevelopmentLogItem(
    title: 'Assessment marking backlog',
    detail: '32 of 41 CA scores entered',
  ),
  TeacherDevelopmentLogItem(
    title: 'Lesson-plan quality',
    detail: 'Latest plan approved without changes',
  ),
];

const teacherProfessionalFocusTitle = 'Improve JSS 2B curriculum recovery';
const teacherProfessionalFocusCopy =
    'Use the syllabus tracker and a short recovery lesson rather than rushing past an unfinished topic.';

const teacherPerformanceUsagePrinciples = <(String, String)>[
  (
    'Context matters',
    'Student results are affected by attendance, prior learning, class composition and many factors beyond one teacher.',
  ),
  (
    'Private by default',
    'Your detailed coaching dashboard should not be exposed broadly to colleagues.',
  ),
  (
    'Human review',
    'AI indicators should support leadership conversations, never automatically punish or reward a teacher.',
  ),
];

const teacherPerformanceBoundary =
    'Performance indicators support coaching and self-improvement. They are not an automatic disciplinary ranking, reward mechanism, or proof that one teacher caused a class outcome.';
const teacherPerformancePrivacyBoundary =
    'This detailed performance view is private to the teacher by default. Other teachers cannot inspect it, and any leadership use requires authorized human review.';
const teacherPerformanceReflectionBoundary =
    'Private reflections stay on the teacher device in this native workflow unless a future explicit share action is added. Adding a reflection does not create an HR record or notify leadership.';
