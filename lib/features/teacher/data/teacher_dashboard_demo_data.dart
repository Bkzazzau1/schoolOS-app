import '../domain/teacher_dashboard_models.dart';

const teacherName = 'Mrs. Amina Yusuf';
const teacherTitle = 'Mathematics Teacher';
const teacherCampusLabel = 'Kaduna Campus · Teacher';
const teacherDateLabel = 'MONDAY · 14 SEPTEMBER';
const teacherWeeklyCompliance = 92;
const teacherPerformanceScore = 88;

const teacherNavigation = <TeacherNavItem>[
  TeacherNavItem(key: 'dashboard', label: 'Dashboard'),
  TeacherNavItem(key: 'timetable', label: 'My Timetable'),
  TeacherNavItem(key: 'classes', label: 'My Classes'),
  TeacherNavItem(key: 'attendance', label: 'Attendance'),
  TeacherNavItem(key: 'lesson-plans', label: 'Lesson Plans'),
  TeacherNavItem(key: 'weekly-progress', label: 'Weekly Learning'),
  TeacherNavItem(key: 'syllabus', label: 'Syllabus'),
  TeacherNavItem(key: 'assignments', label: 'Assignments'),
  TeacherNavItem(key: 'assessments', label: 'Assessments'),
  TeacherNavItem(key: 'class-teacher', label: 'Class Teacher'),
  TeacherNavItem(key: 'cbt', label: 'CBT Practice'),
  TeacherNavItem(key: 'learning-progress', label: 'Learning Progress'),
  TeacherNavItem(key: 'students', label: 'Students'),
  TeacherNavItem(key: 'messages', label: 'Messages'),
  TeacherNavItem(key: 'ai', label: 'Teacher AI'),
  TeacherNavItem(key: 'performance', label: 'My Performance'),
  TeacherNavItem(key: 'profile', label: 'Profile'),
  TeacherNavItem(key: 'community', label: 'Community'),
];

const teacherKpis = <TeacherKpi>[
  TeacherKpi(label: "Today's lessons", value: '4', hint: '1 completed · 3 upcoming'),
  TeacherKpi(label: 'My students', value: '150', hint: 'Across 4 assigned classes'),
  TeacherKpi(label: 'Topics to review', value: '7', hint: 'Across current classes'),
  TeacherKpi(label: 'Syllabus progress', value: '71%', hint: '+4% from last week'),
];

const teacherClasses = <TeacherClassSummary>[
  TeacherClassSummary(name: 'JSS 2A', subject: 'Mathematics', students: 42, nextLesson: '9:20 AM', room: 'B12', progress: 72),
  TeacherClassSummary(name: 'JSS 2B', subject: 'Mathematics', students: 39, nextLesson: '11:00 AM', room: 'B14', progress: 68),
  TeacherClassSummary(name: 'JSS 3A', subject: 'Mathematics', students: 41, nextLesson: '1:10 PM', room: 'C04', progress: 81),
  TeacherClassSummary(name: 'SS 1A', subject: 'Further Mathematics', students: 28, nextLesson: 'Tomorrow', room: 'D06', progress: 64),
];

const teacherTodaySchedule = <TeacherScheduleItem>[
  TeacherScheduleItem(time: '8:00 AM', className: 'JSS 2A', topic: 'Linear equations', status: 'Completed'),
  TeacherScheduleItem(time: '9:20 AM', className: 'JSS 2B', topic: 'Linear equations', status: 'Next'),
  TeacherScheduleItem(time: '11:00 AM', className: 'JSS 3A', topic: 'Simultaneous equations', status: 'Upcoming'),
  TeacherScheduleItem(time: '1:10 PM', className: 'JSS 2A', topic: 'Revision / classwork', status: 'Upcoming'),
];

const teacherStudentReview = <TeacherStudentReview>[
  TeacherStudentReview(name: 'Maryam Abdullahi', className: 'JSS 2A', average: 86, attendance: 96, signal: 'Strong'),
  TeacherStudentReview(name: 'Ibrahim Sani', className: 'JSS 2A', average: 61, attendance: 88, signal: 'Watch'),
  TeacherStudentReview(name: 'Yusuf Bello', className: 'JSS 2B', average: 48, attendance: 79, signal: 'At risk'),
  TeacherStudentReview(name: 'Fatima Musa', className: 'JSS 3A', average: 91, attendance: 98, signal: 'Strong'),
];

const teacherTasks = <TeacherTask>[
  TeacherTask(title: 'Review JSS 2A learning evidence', meta: 'Fractions remains the lowest combined topic', tone: 'urgent', destination: 'learning-progress'),
  TeacherTask(title: 'Publish week 6 learning update', meta: 'JSS 2A · parent summary draft ready', tone: 'warn', destination: 'weekly-progress'),
  TeacherTask(title: 'Enter CA scores for JSS 3A', meta: '32 of 41 entered', tone: 'normal', destination: 'assessments'),
  TeacherTask(title: 'Review CBT practice', meta: '38 attempts · topic-level evidence available', tone: 'normal', destination: 'cbt'),
];

const teacherPerformanceMetrics = <TeacherPerformanceMetric>[
  TeacherPerformanceMetric(label: 'Attendance completion', value: 98),
  TeacherPerformanceMetric(label: 'Lesson-plan compliance', value: 92),
  TeacherPerformanceMetric(label: 'Assessment completion', value: 84),
  TeacherPerformanceMetric(label: 'Syllabus progress', value: 71),
];

const teacherAiBrief =
    'JSS 2B is slightly behind syllabus pace and three students show a combined attendance and assessment risk. JSS 2A evidence from classwork, assignments, assessments and CBT shows fractions as the most consistent practice area.';

const teacherConnectedWorkflow =
    'Plan the lesson, record what was covered, collect classwork and assignment evidence, add assessment/CBT results, then review the topic trend before deciding the next teaching action.';

const teacherReviewSignalBoundary =
    'Strong, Watch and At risk are teacher review signals built from limited classroom evidence. They are not automatic marks, punishments, promotion decisions, disciplinary findings or parent-facing labels.';

const teacherAiBoundary =
    'Teacher AI may summarize evidence and suggest teaching actions, but it cannot change marks, punish a student, make promotion decisions or convert attendance and assessment patterns into hidden student judgments.';

const teacherOfflineBoundary =
    'The dashboard may use tenant-scoped cached teaching evidence offline. Actual attendance, lesson-plan, assignment, assessment and message mutations remain local-first records with durable sync rather than being silently treated as server-confirmed.';
