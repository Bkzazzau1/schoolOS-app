import '../domain/teacher_dashboard_models.dart';

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
  TeacherNavItem(key: 'excursions', label: 'Excursions'),
  TeacherNavItem(key: 'gallery', label: 'Media Gallery'),
  TeacherNavItem(key: 'messages', label: 'Messages'),
  TeacherNavItem(key: 'family-messages', label: 'Family Messages'),
  TeacherNavItem(key: 'ai', label: 'Teacher AI'),
  TeacherNavItem(key: 'performance', label: 'My Performance'),
  TeacherNavItem(key: 'profile', label: 'Profile'),
  TeacherNavItem(key: 'community', label: 'Community'),
];

const teacherConnectedWorkflow =
    'Plan the lesson, record what was covered, collect classwork and assignment evidence, add assessment/CBT results, then review the topic trend before deciding the next teaching action.';

const teacherReviewSignalBoundary =
    'Strong, Watch and At risk are teacher review signals built from limited classroom evidence. They are not automatic marks, punishments, promotion decisions, disciplinary findings or parent-facing labels.';

const teacherAiBoundary =
    'Teacher AI may summarize evidence and suggest teaching actions, but it cannot change marks, punish a student, make promotion decisions or convert attendance and assessment patterns into hidden student judgments.';

const teacherOfflineBoundary =
    'Offline changes remain pending until sync confirms them.';
