import '../domain/teacher_assessment_models.dart';

const teacherAssessmentKpis = <(String, String, String)>[
  ('CA completion', '84%', 'Across assigned classes'),
  ('Assessments this term', '7', 'Tests + continuous assessment'),
  ('Average score', '68%', 'Across recorded assessments'),
  ('Needs intervention', '11', 'Demo students below threshold'),
];

const teacherAssessmentRegister = <TeacherAssessmentRegisterItem>[
  TeacherAssessmentRegisterItem(
    id: 'ca-201',
    title: 'CA 1',
    className: 'JSS 2A',
    maximumScore: 20,
    entered: 42,
    total: 42,
    average: 14.8,
    state: TeacherAssessmentRegisterState.complete,
  ),
  TeacherAssessmentRegisterItem(
    id: 'ca-202',
    title: 'CA 1',
    className: 'JSS 2B',
    maximumScore: 20,
    entered: 34,
    total: 39,
    average: 12.6,
    state: TeacherAssessmentRegisterState.inProgress,
  ),
  TeacherAssessmentRegisterItem(
    id: 'ca-203',
    title: 'Topic Test',
    className: 'JSS 3A',
    maximumScore: 30,
    entered: 41,
    total: 41,
    average: 22.4,
    state: TeacherAssessmentRegisterState.complete,
  ),
];

const teacherAssessmentInitialScores = <TeacherAssessmentScoreEntry>[
  TeacherAssessmentScoreEntry(studentId: 'STU-DEMO-001', score: 16),
  TeacherAssessmentScoreEntry(studentId: 'STU-DEMO-002', score: 12),
  TeacherAssessmentScoreEntry(studentId: 'STU-DEMO-003', score: 9),
  TeacherAssessmentScoreEntry(studentId: 'STU-DEMO-004', score: 18),
  TeacherAssessmentScoreEntry(studentId: 'STU-DEMO-005', score: 14),
];

const teacherAssessmentInitialSheet = TeacherAssessmentScoreSheet(
  id: 'score-sheet-jss2b-ca1-2026t1',
  className: 'JSS 2B',
  assessmentLabel: 'CA 1 · 20 marks',
  maximumScore: 20,
  entries: teacherAssessmentInitialScores,
  state: TeacherAssessmentSheetState.draft,
);

const teacherAssessmentClassOptions = <String>['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A'];
const teacherAssessmentOptions = <String>['CA 1 · 20 marks', 'CA 2 · 20 marks', 'Topic Test · 30 marks'];

const teacherAssessmentCurrentAverage = 63;
const teacherAssessmentMetrics = <(String, int)>[
  ('Concept mastery', 66),
  ('Question completion', 81),
  ('Algebra accuracy', 59),
  ('Improvement vs previous', 72),
];

const teacherAssessmentAiObservation =
    'Errors are concentrated around translating word problems into equations. Consider a short targeted revision activity before the next test.';

const teacherAssessmentSaveBoundary =
    'Saving score-entry progress writes an auditable local draft and queues synchronization. It does not lock marks, release results or confirm server receipt.';

const teacherAssessmentSubmissionBoundary =
    'Submitting scores means submitted for review or locking according to school policy. A teacher device cannot self-lock, release or make results parent-visible without authoritative school workflow acknowledgement.';

const teacherAssessmentAiBoundary =
    'Teacher AI may summarize class-level patterns, suggest revision activities and draft feedback, but it cannot create, alter, round, normalize or release student marks. The teacher remains responsible for every entered score.';

const teacherAssessmentInterventionBoundary =
    'Below-threshold counts are review cues from limited assessment evidence. They are not automatic failure, promotion, discipline, safeguarding or ability labels.';
