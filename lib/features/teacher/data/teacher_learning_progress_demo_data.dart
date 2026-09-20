import '../domain/teacher_learning_progress_models.dart';

const teacherLearningProgressKpis = <(String, String, String)>[
  ('Students tracked', '150', 'Across assigned classes'),
  ('Evidence sources', '4', 'Classwork · Assignment · Assessment · CBT'),
  ('Topics needing review', '7', 'Across current classes'),
  ('Improving topics', '12', 'Positive multi-evidence trend'),
];

const teacherLearningEvidenceFlow = <(String, String)>[
  ('Classwork', 'Daily understanding'),
  ('Assignments', 'Independent practice'),
  ('Assessments', 'Formal checks'),
  ('CBT', 'Question-level practice'),
  ('Learning Intelligence', 'Topic trend + next action'),
];

const teacherLearningStudents = <TeacherLearningStudentEvidence>[
  TeacherLearningStudentEvidence(
    id: 'STU-001',
    name: 'Maryam Abdullahi',
    className: 'JSS 2A',
    subject: 'Mathematics',
    average: 86,
    attendance: 96,
    topics: [
      TeacherLearningTopicEvidence(name: 'Fractions', classwork: 58, assignment: 61, assessment: 60, cbt: 62, trend: 3),
      TeacherLearningTopicEvidence(name: 'Decimals', classwork: 82, assignment: 85, assessment: 84, cbt: 86, trend: 5),
      TeacherLearningTopicEvidence(name: 'Algebra', classwork: 88, assignment: 91, assessment: 89, cbt: 92, trend: 6),
      TeacherLearningTopicEvidence(name: 'Geometry', classwork: 66, assignment: 70, assessment: 68, cbt: 71, trend: 2),
    ],
  ),
  TeacherLearningStudentEvidence(
    id: 'STU-002',
    name: 'Ibrahim Sani',
    className: 'JSS 2A',
    subject: 'Mathematics',
    average: 61,
    attendance: 88,
    topics: [
      TeacherLearningTopicEvidence(name: 'Fractions', classwork: 49, assignment: 52, assessment: 47, cbt: 50, trend: -4),
      TeacherLearningTopicEvidence(name: 'Decimals', classwork: 68, assignment: 65, assessment: 64, cbt: 66, trend: -1),
      TeacherLearningTopicEvidence(name: 'Algebra', classwork: 63, assignment: 61, assessment: 58, cbt: 60, trend: -5),
      TeacherLearningTopicEvidence(name: 'Geometry', classwork: 71, assignment: 69, assessment: 67, cbt: 70, trend: 1),
    ],
  ),
  TeacherLearningStudentEvidence(
    id: 'STU-003',
    name: 'Yusuf Bello',
    className: 'JSS 2B',
    subject: 'Mathematics',
    average: 48,
    attendance: 79,
    topics: [
      TeacherLearningTopicEvidence(name: 'Fractions', classwork: 42, assignment: 40, assessment: 38, cbt: 41, trend: -7),
      TeacherLearningTopicEvidence(name: 'Decimals', classwork: 51, assignment: 49, assessment: 46, cbt: 48, trend: -5),
      TeacherLearningTopicEvidence(name: 'Algebra', classwork: 45, assignment: 43, assessment: 40, cbt: 42, trend: -8),
      TeacherLearningTopicEvidence(name: 'Geometry', classwork: 57, assignment: 54, assessment: 52, cbt: 55, trend: -3),
    ],
  ),
  TeacherLearningStudentEvidence(
    id: 'STU-004',
    name: 'Fatima Musa',
    className: 'JSS 3A',
    subject: 'Mathematics',
    average: 91,
    attendance: 98,
    topics: [
      TeacherLearningTopicEvidence(name: 'Fractions', classwork: 89, assignment: 92, assessment: 91, cbt: 93, trend: 5),
      TeacherLearningTopicEvidence(name: 'Decimals', classwork: 94, assignment: 95, assessment: 93, cbt: 94, trend: 4),
      TeacherLearningTopicEvidence(name: 'Algebra', classwork: 92, assignment: 94, assessment: 93, cbt: 96, trend: 6),
      TeacherLearningTopicEvidence(name: 'Geometry', classwork: 87, assignment: 89, assessment: 88, cbt: 90, trend: 3),
    ],
  ),
];

const teacherLearningInterpretationPrinciples = <(String, String)>[
  ('Classwork low, exam high', 'The learner may understand after revision; inspect timing and support before concluding.'),
  ('Assignment high, CBT low', 'Check independent recall and question format rather than assuming the topic is mastered.'),
  ('All evidence declining', 'This is a stronger signal for re-teaching and human follow-up.'),
  ('Attendance also weak', 'Review learning opportunity and missed lessons as context, without inferring a family cause.'),
];

const teacherLearningSupportActions = <TeacherLearningSupportAction>[
  TeacherLearningSupportAction(
    student: 'Maryam Abdullahi',
    topic: 'Fractions',
    detail: 'Continue targeted practice; trend is improving.',
    actionLabel: 'Create practice task',
    destination: 'assignments',
  ),
  TeacherLearningSupportAction(
    student: 'Ibrahim Sani',
    topic: 'Algebra',
    detail: 'Declining across assessment and CBT evidence.',
    actionLabel: 'Plan revision',
    destination: 'lesson-plans',
  ),
  TeacherLearningSupportAction(
    student: 'Yusuf Bello',
    topic: 'Algebra',
    detail: 'Low multi-source evidence plus reduced attendance.',
    actionLabel: 'Review support',
    destination: 'students',
  ),
];

const teacherLearningGovernanceBoundary =
    'SchoolOS should describe current evidence and suggest support. It must not assign a permanent intelligence level, publicly rank children, diagnose a condition, or let AI make promotion, punishment or exclusion decisions.';

const teacherLearningEvidenceBoundary =
    'A low score, negative trend or attendance context is evidence for teacher review, not a deterministic label. Compare multiple sources, keep the learner within assigned-class scope and require human follow-up before any consequential school action.';

const teacherLearningOfflineBoundary =
    'The native Learning Progress page may cache assigned-student evidence for offline review, but it does not rewrite classwork, assignment, assessment, CBT or attendance source records. Source modules remain authoritative.';
