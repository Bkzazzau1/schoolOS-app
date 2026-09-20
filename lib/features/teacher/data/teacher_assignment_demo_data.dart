import '../domain/teacher_assignment_models.dart';

const teacherAssignmentKpis = <(String, String, String)>[
  ('Active assignments', '2', 'Across assigned classes'),
  ('Pending marking', '27', 'Student submissions'),
  ('Submission rate', '91%', 'Current term average'),
  ('Late submissions', '6', 'Needs follow-up'),
];

const teacherAssignmentClasses = <String>['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A'];
const teacherAssignmentTypes = <TeacherAssignmentType>[
  TeacherAssignmentType.homework,
  TeacherAssignmentType.classwork,
  TeacherAssignmentType.project,
  TeacherAssignmentType.revision,
];

const teacherAssignmentAiInstruction =
    'Solve 10 progressively difficult algebra questions. Show all steps. Include one short reflection explaining which question was most challenging and why.';

const teacherAssignmentDraft = TeacherAssignment(
  id: 'asg-draft-104',
  title: 'Algebra Revision Assignment',
  className: 'JSS 2A',
  type: TeacherAssignmentType.homework,
  instructions: 'Answer all questions. Show your working clearly and submit before the deadline.',
  dueDate: '2026-09-15',
  maximumScore: 20,
  submissions: 0,
  totalStudents: 42,
  marked: 0,
  lateSubmissions: 0,
  state: TeacherAssignmentState.draft,
);

const teacherAssignments = <TeacherAssignment>[
  TeacherAssignment(
    id: 'asg-101',
    title: 'Linear Equations Practice',
    className: 'JSS 2A',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '14 Sep',
    maximumScore: 20,
    submissions: 38,
    totalStudents: 42,
    marked: 24,
    lateSubmissions: 0,
    state: TeacherAssignmentState.open,
    publishedAt: 'server-confirmed',
  ),
  TeacherAssignment(
    id: 'asg-102',
    title: 'Word Problems',
    className: 'JSS 2B',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '15 Sep',
    maximumScore: 20,
    submissions: 31,
    totalStudents: 39,
    marked: 18,
    lateSubmissions: 0,
    state: TeacherAssignmentState.open,
    publishedAt: 'server-confirmed',
  ),
  TeacherAssignment(
    id: 'asg-103',
    title: 'Simultaneous Equations',
    className: 'JSS 3A',
    type: TeacherAssignmentType.homework,
    instructions: '',
    dueDate: '12 Sep',
    maximumScore: 20,
    submissions: 40,
    totalStudents: 41,
    marked: 40,
    lateSubmissions: 0,
    state: TeacherAssignmentState.closed,
    publishedAt: 'server-confirmed',
  ),
];

const teacherAssignmentPublishBoundary =
    'Saving or queuing an assignment on a device does not prove that students received it. The assignment becomes server-confirmed Open only after authoritative synchronization or publication acknowledgement.';
const teacherAssignmentMarkingBoundary =
    'Teacher AI may suggest rubric-aligned feedback and likely misconceptions, but it cannot assign or change a student score. The teacher must confirm every score and comment.';
const teacherAssignmentEvidenceBoundary =
    'Submission counts and late indicators are factual workflow evidence. They must not become automatic discipline, promotion, safeguarding or student-quality judgments.';
