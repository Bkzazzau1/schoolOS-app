import '../domain/teaching_model_models.dart';

const teachingModelWebsiteSeed = <TeachingClassConfig>[
  TeachingClassConfig(
    id: 'TM-001',
    section: 'Early Years',
    className: 'Nursery 1',
    model: TeachingModelType.classTeacher,
    leadTeacher: 'Mrs. Aisha Musa',
    specialistCoverage: 'Music / movement support',
    note:
        'Lead educator owns the group day; assistants and specialists support specific routines or activities.',
  ),
  TeachingClassConfig(
    id: 'TM-002',
    section: 'Early Years',
    className: 'Nursery 2',
    model: TeachingModelType.classTeacher,
    leadTeacher: 'Mrs. Halima Yusuf',
    specialistCoverage: 'Creative / movement support',
    note:
        'Group-led Early Years model with room lead plus supporting educators.',
  ),
  TeachingClassConfig(
    id: 'TM-003',
    section: 'Early Years',
    className: 'Reception A',
    model: TeachingModelType.hybrid,
    leadTeacher: 'Mrs. Fatima Bello',
    specialistCoverage: 'Music, PE, early ICT',
    note:
        'Lead teacher remains responsible for the group while selected specialists deliver configured sessions.',
  ),
  TeachingClassConfig(
    id: 'TM-004',
    section: 'Primary',
    className: 'Primary 1',
    model: TeachingModelType.classTeacher,
    leadTeacher: 'Mrs. Ruth James',
    specialistCoverage: 'PE, Arabic, ICT',
    note:
        'One class teacher handles core subjects; specialists cover configured extras.',
  ),
  TeachingClassConfig(
    id: 'TM-005',
    section: 'Primary',
    className: 'Primary 4',
    model: TeachingModelType.hybrid,
    leadTeacher: 'Mr. David Joseph',
    specialistCoverage: 'ICT, French, PE',
    note:
        'Class teacher owns core learning and pastoral responsibility; selected subjects use specialists.',
  ),
  TeachingClassConfig(
    id: 'TM-006',
    section: 'Primary',
    className: 'Primary 6',
    model: TeachingModelType.hybrid,
    leadTeacher: 'Mr. Kabiru Lawal',
    specialistCoverage: 'Science practical, ICT, French, PE',
    note:
        'Primary leadership can mix class ownership with subject specialists as pupils progress.',
  ),
  TeachingClassConfig(
    id: 'TM-007',
    section: 'Secondary',
    className: 'JSS 2A',
    model: TeachingModelType.subjectTeacher,
    leadTeacher: 'Class Tutor: Mrs. Grace Audu',
    specialistCoverage: 'All subjects assigned separately',
    note:
        'Subject teachers teach separate disciplines while the class tutor coordinates pastoral/class responsibility.',
  ),
  TeachingClassConfig(
    id: 'TM-008',
    section: 'Secondary',
    className: 'SS 2A',
    model: TeachingModelType.subjectTeacher,
    leadTeacher: 'Class Tutor: Mr. Samuel Ter',
    specialistCoverage: 'All subjects assigned separately',
    note: 'Department/subject structure with a separate class-tutor role.',
  ),
];

const teachingModelInfo = <TeachingModelInfo>[
  TeachingModelInfo(
    model: TeachingModelType.classTeacher,
    summary: 'One main teacher owns most or all subjects for a class or room.',
    bestFit: 'Nursery / Early Years and many Primary schools',
  ),
  TeachingModelInfo(
    model: TeachingModelType.subjectTeacher,
    summary:
        'Different teachers are assigned by subject while a tutor may own class coordination.',
    bestFit: 'Secondary and specialist-heavy schools',
  ),
  TeachingModelInfo(
    model: TeachingModelType.hybrid,
    summary:
        'A class teacher owns core learning while specialists teach configured subjects or activities.',
    bestFit: 'Primary, Reception and flexible school structures',
  ),
];

const teachingEarlyYearsRooms = 3;
const teachingPrimaryOverrides = 2;

const teachingAssignmentBoundary =
    'Changing a teaching model changes assignment expectations, not employment status or authority beyond configured class/subject scope.';

const teachingEarlyYearsBoundary =
    'Do not force Nursery into Secondary-style subject assignment.';

const teachingClassTeacherRule =
    'Assign one lead teacher to the class, then mark which subjects that teacher owns by default.';
const teachingSubjectTeacherRule =
    'Assign each subject to a teacher; class tutor responsibility stays separate.';
const teachingHybridRule =
    'Lead teacher owns core subjects and pastoral/class responsibility; specialists override selected subjects.';

List<TeachingModelStat> teachingModelStats(List<TeachingClassConfig> rows) => [
      TeachingModelStat(
        'Class-teacher classes',
        '${rows.where((row) => row.model == TeachingModelType.classTeacher).length}',
        'Single lead for core teaching',
      ),
      TeachingModelStat(
        'Hybrid classes',
        '${rows.where((row) => row.model == TeachingModelType.hybrid).length}',
        'Lead teacher + specialists',
      ),
      TeachingModelStat(
        'Subject-teacher classes',
        '${rows.where((row) => row.model == TeachingModelType.subjectTeacher).length}',
        'Separate subject assignments',
      ),
      const TeachingModelStat(
        'Early Years rooms',
        '$teachingEarlyYearsRooms',
        'Room/group-led structure',
      ),
      const TeachingModelStat(
        'Primary overrides',
        '$teachingPrimaryOverrides',
        'Class-level model overrides',
      ),
    ];
