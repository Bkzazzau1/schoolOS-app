const teacherLearningEvidenceFlow = <(String, String)>[
  ('Classwork', 'Daily understanding'),
  ('Assignments', 'Independent practice'),
  ('Assessments', 'Formal checks'),
  ('CBT', 'Question-level practice'),
  ('Learning Intelligence', 'Topic trend + next action'),
];

const teacherLearningInterpretationPrinciples = <(String, String)>[
  ('Classwork low, exam high', 'The learner may understand after revision; inspect timing and support before concluding.'),
  ('Assignment high, CBT low', 'Check independent recall and question format rather than assuming the topic is mastered.'),
  ('All evidence declining', 'This is a stronger signal for re-teaching and human follow-up.'),
  ('Attendance also weak', 'Review learning opportunity and missed lessons as context, without inferring a family cause.'),
];

const teacherLearningNoEvidenceNote =
    'No classwork, assignment, assessment or CBT evidence has been recorded for this student yet. Topic-level evidence will appear here once those modules produce topic-tagged results to combine.';

const teacherLearningNoActionsNote =
    'No support actions are suggested yet. Suggestions will appear here once real, topic-tagged evidence shows a pattern worth a teacher\'s attention — never from a single score.';

const teacherLearningGovernanceBoundary =
    'SchoolOS should describe current evidence and suggest support. It must not assign a permanent intelligence level, publicly rank children, diagnose a condition, or let AI make promotion, punishment or exclusion decisions.';

const teacherLearningEvidenceBoundary =
    'A low score, negative trend or attendance context is evidence for teacher review, not a deterministic label. Compare multiple sources, keep the learner within assigned-class scope and require human follow-up before any consequential school action.';

const teacherLearningOfflineBoundary =
    'The native Learning Progress page may cache assigned-student evidence for offline review, but it does not rewrite classwork, assignment, assessment, CBT or attendance source records. Source modules remain authoritative.';
