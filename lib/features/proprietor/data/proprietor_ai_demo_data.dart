import '../domain/proprietor_ai_models.dart';

const proprietorAiPrompts = <ProprietorAiPrompt>[
  ProprietorAiPrompt(
    id: 'secondary-attendance',
    question: 'Why is Secondary attendance below target?',
    category: 'Attendance',
  ),
  ProprietorAiPrompt(
    id: 'fee-collection',
    question: 'Compare fee collection by section',
    category: 'Finance',
  ),
  ProprietorAiPrompt(
    id: 'owner-priorities',
    question: 'Which owner priorities need action this week?',
    category: 'Executive',
  ),
  ProprietorAiPrompt(
    id: 'enrollment-risk',
    question: 'Summarize enrollment and retention risk',
    category: 'Enrollment',
  ),
  ProprietorAiPrompt(
    id: 'staffing-change',
    question: 'What changed in staffing this term?',
    category: 'People',
  ),
];

const proprietorExecutiveBriefSections = <ExecutiveBriefSection>[
  ExecutiveBriefSection(
    title: 'Owner priorities',
    items: [
      'Secondary attendance is 90% against a 94% target.',
      'Outstanding fees total ₦3.7m across 73 family accounts.',
      'Two Secondary curriculum pacing gaps need leadership follow-up.',
      'Primary 6 has one unfilled class-teacher responsibility.',
    ],
  ),
  ExecutiveBriefSection(
    title: 'Finance & enrollment',
    items: [
      'Whole-school fee collection is 94% in the current prototype.',
      'Active enrollment is 648 students.',
      'Current retention estimate is 96%.',
      'Secondary has the strongest current intake demand.',
    ],
  ),
  ExecutiveBriefSection(
    title: 'People & operations',
    items: [
      'Teaching staff sample is 64 across three sections.',
      'Five staff are flagged for heavy workload review.',
      'Two vacancies remain open.',
      'Seven contracts are due within the next 60 days.',
    ],
  ),
];

const proprietorAiContextBoundary =
    'Before any model receives context, SchoolOS must filter by tenant, campus, section, role and record sensitivity. The AI must never receive data merely because a user can type a question about it.';

const proprietorAiDecisionBoundary =
    'Proprietor AI may summarize evidence, identify inconsistencies and suggest questions for human review. It must not autonomously fire staff, approve or deny loans, diagnose children, rank families, decide safeguarding outcomes or take financial action.';
