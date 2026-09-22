import '../domain/teacher_cbt_models.dart';

const teacherCbtInstructions =
    'Answer all questions. You may move between questions before submitting. Use this practice to become comfortable with CBT navigation and timing.';

// Sample practice sets so a new teacher does not start on a blank page. Attempts and average accuracy start at 0:
// there is no real student CBT-taking pipeline feeding this yet, so no attempt evidence is invented for them.
const teacherCbtSets = <TeacherCbtPracticeSet>[
  TeacherCbtPracticeSet(
    id: 'CBT-MTH-026',
    title: 'JSS 2 Mathematics · Linear Equations',
    className: 'JSS 2A',
    questions: 20,
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
    attempts: 0,
    averageAccuracy: 0,
    resultMode: 'Show score + topic feedback',
    instructions: teacherCbtInstructions,
    publishedAt: 'server-confirmed',
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
const teacherCbtResultsUnavailable =
    'No practice attempts have been recorded yet. Real learner results will appear here once students complete a published practice set, with no student named or scored before that.';
