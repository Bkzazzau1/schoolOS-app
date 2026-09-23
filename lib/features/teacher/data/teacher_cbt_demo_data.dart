import '../domain/teacher_cbt_models.dart';

const teacherCbtInstructions =
    'Answer all questions. You may move between questions before submitting. Use this practice to become comfortable with CBT navigation and timing.';

const _linearEquationsQuestions = <TeacherCbtQuestion>[
  TeacherCbtQuestion(
    id: 'CBT-MTH-026-Q1',
    prompt: 'If 3x + 4 = 19, what is the value of x?',
    options: ['3', '4', '5', '6'],
    correctIndex: 2,
    explanation: 'Subtract 4 from both sides to get 3x = 15, then divide by 3.',
  ),
  TeacherCbtQuestion(
    id: 'CBT-MTH-026-Q2',
    prompt: 'Solve for y: 2y - 6 = 10.',
    options: ['6', '7', '8', '9'],
    correctIndex: 2,
    explanation: 'Add 6 to both sides to get 2y = 16, then divide by 2.',
  ),
  TeacherCbtQuestion(
    id: 'CBT-MTH-026-Q3',
    prompt: 'Which value of x satisfies 5x + 2 = 3x + 10?',
    options: ['2', '3', '4', '5'],
    correctIndex: 2,
    explanation: 'Subtract 3x from both sides to get 2x + 2 = 10, then solve for x.',
  ),
];

const _fractionsQuestions = <TeacherCbtQuestion>[
  TeacherCbtQuestion(
    id: 'CBT-MTH-027-Q1',
    prompt: 'What is 1/4 + 1/2?',
    options: ['1/6', '2/6', '3/4', '1'],
    correctIndex: 2,
    explanation: '1/2 is the same as 2/4, so 1/4 + 2/4 = 3/4.',
  ),
];

const _week5Questions = <TeacherCbtQuestion>[
  TeacherCbtQuestion(
    id: 'CBT-MTH-021-Q1',
    prompt: 'Simplify: 4x + 3x.',
    options: ['7', '7x', '12x', 'x'],
    correctIndex: 1,
    explanation: 'Like terms add directly: 4x + 3x = 7x.',
  ),
  TeacherCbtQuestion(
    id: 'CBT-MTH-021-Q2',
    prompt: 'What is the value of 2² + 3²?',
    options: ['10', '12', '13', '25'],
    correctIndex: 2,
    explanation: '2² = 4 and 3² = 9; 4 + 9 = 13.',
  ),
];

// Sample practice sets so a new teacher does not start on a blank page. Each carries real, teacher-
// authored questions (never a fabricated question count with nothing behind it), and attempts/average
// accuracy always start at 0 in this seed: TeacherCbtRepository.load() recomputes both live from real
// student attempts, so a freshly seeded set can never claim evidence no student has actually produced.
const teacherCbtSets = <TeacherCbtPracticeSet>[
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-026',
    title: 'JSS 2 Mathematics · Linear Equations',
    className: 'JSS 2A',
    items: _linearEquationsQuestions,
    durationMinutes: 20,
    state: TeacherCbtSetState.published,
    attempts: 0,
    averageAccuracy: 0,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
    publishedAt: 'server-confirmed',
  ),
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-027',
    title: 'JSS 2 Mathematics · Fractions Review',
    className: 'JSS 2A',
    items: _fractionsQuestions,
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
    items: _week5Questions,
    durationMinutes: 20,
    state: TeacherCbtSetState.closed,
    attempts: 0,
    averageAccuracy: 0,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
    publishedAt: 'server-confirmed',
  ),
];

const teacherCbtDesignBoundary =
    'Each practice item should carry a topic tag so results show where learners need more practice instead of reporting only one total score.';
const teacherCbtPracticeBoundary =
    'CBT Practice is for learning and exam familiarity. It must not be treated as a permanent student ranking, a high-stakes examination result, a promotion decision or a disciplinary signal.';
const teacherCbtAiBoundary =
    'Teacher AI may summarize practice evidence and suggest temporary practice focus, but it cannot change scores, decide mastery, fail or promote a learner, or replace teacher judgment.';
const teacherCbtPublicationBoundary =
    'Saving or publishing while offline queues the practice set. Published status and student availability require authoritative server acknowledgement.';
const teacherCbtResultsUnavailable =
    'No practice attempts have been recorded yet. Real learner results will appear here once students complete a published practice set, with no student named or scored before that.';
