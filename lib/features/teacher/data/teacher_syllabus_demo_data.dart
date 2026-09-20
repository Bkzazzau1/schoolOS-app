import '../domain/teacher_syllabus_models.dart';

const teacherSyllabusClassOptions = <String>['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A'];
const teacherSyllabusCurrentWeek = 6;

const teacherSyllabusProgressByClass = <String, int>{
  'JSS 2A': 72,
  'JSS 2B': 68,
  'JSS 3A': 81,
  'SS 1A': 64,
};

const teacherSyllabusRows = <TeacherSyllabusRow>[
  TeacherSyllabusRow(className: 'JSS 2A', week: 1, topic: 'Whole Numbers Review', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 2),
  TeacherSyllabusRow(className: 'JSS 2A', week: 2, topic: 'Fractions and Decimals', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 3, topic: 'Ratio and Proportion', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 4, topic: 'Algebraic Expressions', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 5, topic: 'Linear Equations', approvedStatus: TeacherSyllabusStatus.inProgress, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 6, topic: 'Linear Equations', approvedStatus: TeacherSyllabusStatus.current, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 7, topic: 'Word Problems', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2A', week: 8, topic: 'Graphs of Linear Equations', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),

  TeacherSyllabusRow(className: 'JSS 2B', week: 1, topic: 'Whole Numbers Review', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 2),
  TeacherSyllabusRow(className: 'JSS 2B', week: 2, topic: 'Fractions and Decimals', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 3, topic: 'Ratio and Proportion', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 4, topic: 'Algebraic Expressions', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 5, topic: 'Linear Equations', approvedStatus: TeacherSyllabusStatus.inProgress, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 6, topic: 'Linear Equations', approvedStatus: TeacherSyllabusStatus.behind, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 7, topic: 'Word Problems', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 2B', week: 8, topic: 'Graphs of Linear Equations', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),

  TeacherSyllabusRow(className: 'JSS 3A', week: 1, topic: 'Algebra Review', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 2, topic: 'Simultaneous Equations', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 3, topic: 'Simultaneous Equations', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 4, topic: 'Quadratic Expressions', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 5, topic: 'Quadratic Equations', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 6, topic: 'Quadratic Equations', approvedStatus: TeacherSyllabusStatus.current, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 7, topic: 'Variation', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),
  TeacherSyllabusRow(className: 'JSS 3A', week: 8, topic: 'Statistics Review', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 2),

  TeacherSyllabusRow(className: 'SS 1A', week: 1, topic: 'Sets', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 2, topic: 'Surds', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 3, topic: 'Indices', approvedStatus: TeacherSyllabusStatus.completed, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 4, topic: 'Functions', approvedStatus: TeacherSyllabusStatus.inProgress, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 5, topic: 'Functions', approvedStatus: TeacherSyllabusStatus.current, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 6, topic: 'Graphs', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 7, topic: 'Sequences and Series', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 3),
  TeacherSyllabusRow(className: 'SS 1A', week: 8, topic: 'Revision', approvedStatus: TeacherSyllabusStatus.upcoming, plannedLessons: 2),
];

String teacherSyllabusNextTopic(String className) => switch (className) {
      'JSS 2A' || 'JSS 2B' => 'Word Problems',
      'JSS 3A' => 'Variation',
      'SS 1A' => 'Graphs',
      _ => '',
    };

String teacherSyllabusPacingLabel(String className) =>
    className == 'JSS 2B' ? 'Behind' : 'On track';

String teacherSyllabusPacingHint(String className) => className == 'JSS 2B'
    ? '2 lessons behind expected pace'
    : 'On track with school pacing';

String teacherSyllabusAiInsight(String className) => className == 'JSS 2B'
    ? 'Recent timetable completion suggests the class may remain behind unless one lesson is recovered during the next two weeks. Prioritize core equation-solving skills before moving into word problems.'
    : 'Current lesson completion and topic updates indicate that this class is broadly aligned with the school scheme of work.';

const teacherSyllabusAuthorityBoundary =
    'Teachers may report what has been taught for their assigned classes, but they cannot silently change the school-approved scheme of work. Topic reordering, removal or curriculum replacement requires authorized academic approval.';

const teacherSyllabusAiBoundary =
    'Teacher AI may explain pacing evidence and suggest recovery ideas, but it cannot rewrite the approved scheme, skip prerequisite material, change curriculum order, or mark a topic completed without teacher evidence.';

const teacherSyllabusOfflineBoundary =
    'Offline syllabus progress is a teacher-reported local record queued for synchronization. It is not leadership approval and must not overwrite the approved curriculum definition.';
