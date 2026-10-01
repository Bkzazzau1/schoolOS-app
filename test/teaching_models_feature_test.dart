import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teaching_models/data/teaching_model_policy_copy.dart';
import 'package:schoolos_app/features/teaching_models/domain/teaching_model_models.dart';

List<TeachingClassConfig> _rows() => const [
      TeachingClassConfig(
        id: 'TM-TEST-001',
        section: 'Early Years',
        className: 'Reception A',
        model: TeachingModelType.hybrid,
        leadTeacher: 'Mrs. Fatima Bello',
        specialistCoverage: 'Music, PE, early ICT',
        note: 'Lead teacher remains responsible while selected specialists deliver sessions.',
      ),
      TeachingClassConfig(
        id: 'TM-TEST-002',
        section: 'Primary',
        className: 'Primary 1',
        model: TeachingModelType.classTeacher,
        leadTeacher: 'Mrs. Ruth James',
        specialistCoverage: 'PE, Arabic, ICT',
        note: 'One class teacher handles core subjects; specialists cover configured extras.',
      ),
      TeachingClassConfig(
        id: 'TM-TEST-003',
        section: 'Secondary',
        className: 'JSS 2A',
        model: TeachingModelType.subjectTeacher,
        leadTeacher: 'Class Tutor: Mrs. Grace Audu',
        specialistCoverage: 'All subjects assigned separately',
        note: 'Subject teachers teach separate disciplines while the class tutor coordinates.',
      ),
    ];

void main() {
  test('teaching model stats are computed entirely from the real rows given, never a fixed sample', () {
    final stats = teachingModelStats(_rows());
    expect(stats[0].value, '3');
    expect(stats[1].value, '1', reason: 'one class teacher config');
    expect(stats[2].value, '1', reason: 'one hybrid config');
    expect(stats[3].value, '1', reason: 'one subject teacher config');

    final empty = teachingModelStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('three teaching model types preserve labels and summaries', () {
    expect(TeachingModelType.values, hasLength(3));
    expect(
      TeachingModelType.values.map((item) => item.label),
      containsAll(['Class Teacher', 'Subject Teacher', 'Hybrid']),
    );
    expect(teachingModelInfo, hasLength(3));
    expect(
      teachingModelInfo
          .firstWhere((item) => item.model == TeachingModelType.hybrid)
          .bestFit,
      contains('Primary'),
    );
  });

  test('lead and specialist assignments are preserved per real config', () {
    final reception = _rows().firstWhere((row) => row.id == 'TM-TEST-001');
    expect(reception.className, 'Reception A');
    expect(reception.leadTeacher, 'Mrs. Fatima Bello');
    expect(reception.specialistCoverage, 'Music, PE, early ICT');

    final jss2 = _rows().firstWhere((row) => row.id == 'TM-TEST-003');
    expect(jss2.model, TeachingModelType.subjectTeacher);
    expect(jss2.leadTeacher, 'Class Tutor: Mrs. Grace Audu');
    expect(jss2.specialistCoverage, 'All subjects assigned separately');
  });

  test('serialization preserves model, lead teacher and specialist coverage', () {
    final original = _rows()[1];
    final restored = TeachingClassConfig.fromJson(original.toJson());
    expect(restored.id, 'TM-TEST-002');
    expect(restored.model, TeachingModelType.classTeacher);
    expect(restored.leadTeacher, 'Mrs. Ruth James');
    expect(restored.specialistCoverage, contains('PE'));
  });

  test('changing model does not silently alter lead or specialist assignments', () {
    final original = _rows().first;
    final changed = original.copyWith(model: TeachingModelType.subjectTeacher);
    expect(changed.model, TeachingModelType.subjectTeacher);
    expect(changed.leadTeacher, original.leadTeacher);
    expect(changed.specialistCoverage, original.specialistCoverage);
    expect(changed.note, original.note);
  });

  test('copyWith can also change lead teacher and specialist coverage directly', () {
    final updated = _rows().first.copyWith(leadTeacher: 'New Teacher', specialistCoverage: 'New coverage');
    expect(updated.leadTeacher, 'New Teacher');
    expect(updated.specialistCoverage, 'New coverage');
    expect(updated.model, _rows().first.model);
  });

  test('assignment and Early Years boundaries match intent', () {
    expect(teachingAssignmentBoundary, contains('assignment expectations'));
    expect(teachingAssignmentBoundary, contains('not employment status'));
    expect(teachingEarlyYearsBoundary, contains('Do not force Nursery'));
    expect(teachingClassTeacherRule, contains('one lead teacher'));
    expect(teachingSubjectTeacherRule, contains('class tutor responsibility stays separate'));
    expect(teachingHybridRule, contains('specialists override selected subjects'));
  });
}
