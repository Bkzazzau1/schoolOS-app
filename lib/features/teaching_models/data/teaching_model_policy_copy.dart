import '../domain/teaching_model_models.dart';

/// Static guidance copy for Flexible Teaching Models - not data about this school, so it never
/// needs a real backend source. Real activity (class configurations) lives in
/// [TeachingModelRepository] instead.
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

/// Computed entirely from [rows] - the real, locally-held class configurations a school has
/// actually set up, never fixed sample counts.
List<TeachingModelStat> teachingModelStats(List<TeachingClassConfig> rows) => [
      TeachingModelStat(
        'Configured classes',
        '${rows.length}',
        'Across every section',
      ),
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
    ];
