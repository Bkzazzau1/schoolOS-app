import '../domain/proprietor_ai_models.dart';

const proprietorAiPrompts = <ProprietorAiPrompt>[
  ProprietorAiPrompt(id: 'owner-priorities', question: 'Which owner priorities need action this week?', category: 'Executive'),
  ProprietorAiPrompt(id: 'waiting-decisions', question: 'What is waiting for my decision?', category: 'Executive'),
  ProprietorAiPrompt(id: 'staffing', question: 'Summarize staffing and staff files', category: 'People'),
  ProprietorAiPrompt(id: 'money', question: 'Summarize scholarships, discounts and payroll', category: 'Finance'),
  ProprietorAiPrompt(id: 'leadership', question: 'Who leads each section?', category: 'Leadership'),
  ProprietorAiPrompt(id: 'not-available', question: 'What can not be reported yet?', category: 'Data'),
  ProprietorAiPrompt(id: 'fee-collection', question: 'Compare fee collection by section', category: 'Finance'),
  ProprietorAiPrompt(id: 'secondary-attendance', question: 'Why is Secondary attendance below target?', category: 'Attendance'),
];

const proprietorAiContextBoundary =
    'Before any model receives context, SchoolOS must filter by tenant, campus, section, role and record sensitivity. The AI '
    'must never receive data merely because a user can type a question about it.';

const proprietorAiDecisionBoundary =
    'Proprietor AI may summarize evidence, identify inconsistencies and suggest questions for human review. It must not '
    'autonomously fire staff, approve or deny loans, diagnose children, rank families, decide safeguarding outcomes or take '
    'financial action.';
