import '../domain/teacher_weekly_learning_models.dart';

const teacherWeeklyTermLabel = '2026/2027 Term 1';
const teacherWeeklyDefaultClass = 'JSS 2A';
const teacherWeeklyDefaultWeek = 'Week 6';
const teacherWeeklyClassOptions = <String>['JSS 2A', 'JSS 2B', 'JSS 3A'];
const teacherWeeklyWeekOptions = <String>['Week 6', 'Week 7', 'Week 8'];

const teacherWeeklyInitialNote =
    'The class completed the major planned topics this week. Mathematics practice will continue before the next topic begins.';

const teacherWeeklySubjects = <TeacherWeeklySubjectUpdate>[
  TeacherWeeklySubjectUpdate(
    subject: 'Mathematics',
    planned: 'Linear equations and guided practice',
    covered: 'Linear equations completed with worked examples and short class assessment',
    next: 'Simultaneous equations',
    evidence: 'Classwork 82% · Assignment 79%',
    support: 'Fractions remain the main practice area for a small group',
    linkedPlanId: 'LP-206',
  ),
  TeacherWeeklySubjectUpdate(
    subject: 'English',
    planned: 'Narrative writing and comprehension',
    covered: 'Narrative writing and comprehension completed',
    next: 'Formal letter writing',
    evidence: 'Writing task completed · comprehension check 84%',
    support: 'Sentence structure practice continues',
  ),
  TeacherWeeklySubjectUpdate(
    subject: 'Basic Science',
    planned: 'Human digestive system',
    covered: 'Digestive system introduced and labelled diagram completed',
    next: 'Nutrition and balanced diet',
    evidence: 'Class diagram + 10-question check',
    support: 'Key vocabulary needs reinforcement for some learners',
  ),
];

const teacherWeeklyInitialUpdate = TeacherWeeklyLearningUpdate(
  id: 'WLU-JSS2A-W6-2026T1',
  className: teacherWeeklyDefaultClass,
  week: teacherWeeklyDefaultWeek,
  subjects: teacherWeeklySubjects,
  note: teacherWeeklyInitialNote,
  state: TeacherWeeklyPublicationState.draft,
);

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
