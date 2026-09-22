import '../domain/teacher_lesson_plan_models.dart';

const teacherLessonPlanWeeks = <String>['Week 6', 'Week 7', 'Week 8'];
const teacherLessonPlanTopics = <String>[
  'Linear Equations',
  'Word Problems',
  'Graphs of Linear Equations',
];

const teacherLessonPlans = <TeacherLessonPlan>[
  TeacherLessonPlan(
    id: 'LP-206',
    className: 'JSS 2A',
    week: 'Week 6',
    topic: 'Linear Equations',
    status: TeacherLessonPlanStatus.draft,
    updatedLabel: 'Today, 9:10 AM',
  ),
  TeacherLessonPlan(
    id: 'LP-205',
    className: 'JSS 2B',
    week: 'Week 6',
    topic: 'Linear Equations',
    status: TeacherLessonPlanStatus.submitted,
    updatedLabel: 'Yesterday',
  ),
  TeacherLessonPlan(
    id: 'LP-201',
    className: 'JSS 3A',
    week: 'Week 5',
    topic: 'Simultaneous Equations',
    status: TeacherLessonPlanStatus.approved,
    updatedLabel: '3 days ago',
  ),
  TeacherLessonPlan(
    id: 'LP-198',
    className: 'SS1A',
    week: 'Week 5',
    topic: 'Functions',
    status: TeacherLessonPlanStatus.needsChanges,
    updatedLabel: '4 days ago',
  ),
];

const teacherLessonPlanAiObjectives =
    'By the end of the lesson, learners should be able to define a linear equation, identify variables and constants, and solve simple one-step linear equations.';
const teacherLessonPlanAiStarter =
    'Use two quick balance-scale examples to connect equality with keeping both sides balanced.';
const teacherLessonPlanAiActivities =
    'Teacher models two examples, class solves guided examples in pairs, then learners complete a five-question independent task.';
const teacherLessonPlanAiAssessment =
    'Exit ticket: solve 3x + 4 = 19 and explain the operation used at each step.';
const teacherLessonPlanAiResources =
    'Whiteboard, marker, learner notebooks, printed practice sheet.';

const teacherLessonPlanGuide = <(String, String)>[
  ('1. Follow syllabus', 'The class, week and topic should come from the school-approved scheme of work.'),
  ('2. Make outcomes measurable', 'Use clear actions such as solve, compare, explain, construct or identify.'),
  ('3. Plan evidence', 'Every lesson should include a way to check whether learning actually happened.'),
  ('4. AI assists, teacher decides', 'AI suggestions are drafts. The teacher reviews content and keeps responsibility for the final plan.'),
];

const teacherLessonPlanAuthorityBoundary =
    'Teachers may create, edit and submit lesson-plan drafts for assigned classes. Submission means pending review only. Teachers cannot approve their own plans, overwrite reviewer decisions, or turn an AI draft into an approved plan automatically.';

const teacherLessonPlanOfflineBoundary =
    'Drafts save locally first and queue for synchronization. A locally submitted plan remains pending synchronization until acknowledged by the server; offline state must not be presented as approved or reviewer-confirmed.';
