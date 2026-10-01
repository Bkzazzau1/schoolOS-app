const teacherWeeklyFlow = <(String, String)>[
  ('Approved lesson plan', 'What was intended'),
  ('Actual classroom delivery', 'What was covered'),
  ('Evidence', 'Classwork / assignment'),
  ('Parent update', 'What happened + what is next'),
];

const teacherWeeklyPublicationBoundary =
    'Parents receive classroom learning information relevant to their linked child. Internal teacher notes, other children\'s records, private safeguarding information and staff-only comments must never be included in the parent version.';

const teacherWeeklyDeliveryBoundary =
    'Saving a draft or queuing publication offline does not prove that a parent received the update. Parent delivery/read status requires authoritative messaging or server acknowledgement.';

const teacherWeeklyEvidenceBoundary =
    'Weekly learning updates summarize approved plans, actual classroom coverage and class-level evidence. They must not invent individual learner results, expose another child\'s record, or turn class support notes into disciplinary, promotion or safeguarding decisions.';
