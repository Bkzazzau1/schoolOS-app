import '../domain/teacher_ai_models.dart';

const teacherAiPromptSuggestions = <String>[
  'Create a 40-minute revision activity for JSS 2B linear equations',
  'Generate 10 mixed-difficulty questions on simultaneous equations',
  'Summarize students who may need intervention in my assigned classes',
  'Draft parent-friendly feedback for a learner who is improving but still below target',
];

const teacherAiTools = <TeacherAiTool>[
  TeacherAiTool(
    title: 'Lesson planner',
    description:
        'Draft objectives, activities, assessment and resources from an approved syllabus topic.',
    destination: 'lesson-plans',
  ),
  TeacherAiTool(
    title: 'Quiz generator',
    description:
        'Create classwork, homework, revision questions and answer guides for assigned classes.',
    destination: 'assignments',
  ),
  TeacherAiTool(
    title: 'Assessment analyst',
    description:
        'Interpret class performance and identify concepts that may need reteaching.',
    destination: 'assessments',
  ),
  TeacherAiTool(
    title: 'Student support',
    description:
        'Surface patterns from attendance, assessment and teacher notes within your authorized classes.',
    destination: 'students',
  ),
];

const teacherAiInitialResponse =
    'Your AI workspace is ready. Ask about your assigned classes, lesson preparation, assessments, interventions or communication.';

const teacherAiInitialHistory = <TeacherAiPromptHistoryItem>[
  TeacherAiPromptHistoryItem(
    id: 'teacher-ai-history-1',
    prompt: 'Why is JSS 2B behind the syllabus pace?',
    context: TeacherAiContext.jss2bMathematics,
    createdAt: '2026-09-20T02:00:00Z',
  ),
  TeacherAiPromptHistoryItem(
    id: 'teacher-ai-history-2',
    prompt: 'Create a short revision activity for Week 6',
    context: TeacherAiContext.jss2bMathematics,
    createdAt: '2026-09-20T01:00:00Z',
  ),
];

String teacherAiResponseFor({
  required TeacherAiContext context,
  required String prompt,
}) =>
    'For ${context.className}, I would first use the teacher-authorized class context only. Suggested action: review the current syllabus position, recent attendance and assessment completion, then prepare a focused teaching activity for “$prompt”. Any draft should be reviewed by you before it is saved, sent or submitted.';
