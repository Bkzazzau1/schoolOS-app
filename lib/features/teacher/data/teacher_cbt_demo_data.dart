import '../domain/teacher_cbt_models.dart';

const teacherCbtKpis = <(String, String, String)>[
  ('Question sets', '12', '8 published · 4 draft'),
  ('Practice attempts', '286', 'this term'),
  ('Average accuracy', '74%', 'across assigned practice'),
  ('Topics needing review', '3', 'Fractions · Geometry · Word problems'),
];

const teacherCbtInstructions =
    'Answer all questions. You may move between questions before submitting. Use this practice to become comfortable with CBT navigation and timing.';

const teacherCbtSets = <TeacherCbtPracticeSet>[
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-026',
    title: 'JSS 2 Mathematics · Linear Equations',
    className: 'JSS 2A',
    questions: 20,
    durationMinutes: 20,
    state: TeacherCbtSetState.published,
    attempts: 38,
    averageAccuracy: 78,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
    publishedAt: 'server-confirmed',
  ),
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-027',
    title: 'JSS 2 Mathematics · Fractions Review',
    className: 'JSS 2A',
    questions: 15,
    durationMinutes: 15,
    state: TeacherCbtSetState.draft,
    attempts: 0,
    averageAccuracy: 0,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
  ),
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-021',
    title: 'JSS 2B Mathematics · Week 5 Practice',
    className: 'JSS 2B',
    questions: 20,
    durationMinutes: 20,
    state: TeacherCbtSetState.closed,
    attempts: 36,
    averageAccuracy: 64,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
    publishedAt: 'server-confirmed',
  ),
];

const teacherCbtResults = <TeacherCbtResult>[
  TeacherCbtResult(
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    score: '16/20',
    accuracy: '80%',
    time: '14m 12s',
    focus: 'Fractions · Geometry',
  ),
  TeacherCbtResult(
    student: 'Ibrahim Sani',
    className: 'JSS 2A',
    score: '12/20',
    accuracy: '60%',
    time: '19m 08s',
    focus: 'Linear equations',
  ),
  TeacherCbtResult(
    student: 'Yusuf Bello',
    className: 'JSS 2B',
    score: '9/20',
    accuracy: '45%',
    time: '20m 00s',
    focus: 'Fractions · Word problems',
  ),
];

const teacherCbtQuestionTopic = 'Linear Equations';
const teacherCbtQuestionText = 'If 3x + 4 = 19, what is the value of x?';
const teacherCbtQuestionOptions = <String>['A. 3', 'B. 4', 'C. 5', 'D. 6'];

const teacherCbtDesignBoundary =
    'Each practice item should carry a topic tag so results show where learners need more practice instead of reporting only one total score.';
const teacherCbtPracticeBoundary =
    'CBT Practice is for learning and exam familiarity. It must not be treated as a permanent student ranking, a high-stakes examination result, a promotion decision or a disciplinary signal.';
const teacherCbtAiBoundary =
    'Teacher AI may summarize practice evidence and suggest temporary practice focus, but it cannot change scores, decide mastery, fail or promote a learner, or replace teacher judgment.';
const teacherCbtPublicationBoundary =
    'Saving or publishing while offline queues the practice set. Published status and student availability require authoritative server acknowledgement.';
const teacherCbtLearningHandoff =
    'Maryam Abdullahi scored 80% overall, but missed 3 of 4 fractions questions. Add fractions as a temporary practice focus in Student 360 while keeping her overall Mathematics trend separate.';
