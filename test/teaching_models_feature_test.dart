import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teaching_models/data/teaching_model_demo_data.dart';
import 'package:schoolos_app/features/teaching_models/domain/teaching_model_models.dart';

void main() {
  test('website seed contains eight exact class and room configurations', () {
    expect(teachingModelWebsiteSeed, hasLength(8));
    expect(
      teachingModelWebsiteSeed.where((row) => row.section == 'Early Years'),
      hasLength(3),
    );
    expect(
      teachingModelWebsiteSeed.where((row) => row.section == 'Primary'),
      hasLength(3),
    );
    expect(
      teachingModelWebsiteSeed.where((row) => row.section == 'Secondary'),
      hasLength(2),
    );
  });

  test('initial website model mix is 3 class teacher, 3 hybrid and 2 subject teacher', () {
    expect(
      teachingModelWebsiteSeed
          .where((row) => row.model == TeachingModelType.classTeacher),
      hasLength(3),
    );
    expect(
      teachingModelWebsiteSeed
          .where((row) => row.model == TeachingModelType.hybrid),
      hasLength(3),
    );
    expect(
      teachingModelWebsiteSeed
          .where((row) => row.model == TeachingModelType.subjectTeacher),
      hasLength(2),
    );
    expect(teachingEarlyYearsRooms, 3);
    expect(teachingPrimaryOverrides, 2);
  });

  test('three teaching model types preserve website labels and summaries', () {
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

  test('website lead and specialist assignments are preserved', () {
    final reception = teachingModelWebsiteSeed
        .firstWhere((row) => row.id == 'TM-003');
    expect(reception.className, 'Reception A');
    expect(reception.leadTeacher, 'Mrs. Fatima Bello');
    expect(reception.specialistCoverage, 'Music, PE, early ICT');

    final jss2 = teachingModelWebsiteSeed.firstWhere((row) => row.id == 'TM-007');
    expect(jss2.model, TeachingModelType.subjectTeacher);
    expect(jss2.leadTeacher, 'Class Tutor: Mrs. Grace Audu');
    expect(jss2.specialistCoverage, 'All subjects assigned separately');
  });

  test('serialization preserves model, lead teacher and specialist coverage', () {
    final original = teachingModelWebsiteSeed[5];
    final restored = TeachingClassConfig.fromJson(original.toJson());
    expect(restored.id, 'TM-006');
    expect(restored.model, TeachingModelType.hybrid);
    expect(restored.leadTeacher, 'Mr. Kabiru Lawal');
    expect(restored.specialistCoverage, contains('Science practical'));
  });

  test('changing model does not silently alter lead or specialist assignments', () {
    final original = teachingModelWebsiteSeed.first;
    final changed = original.copyWith(model: TeachingModelType.subjectTeacher);
    expect(changed.model, TeachingModelType.subjectTeacher);
    expect(changed.leadTeacher, original.leadTeacher);
    expect(changed.specialistCoverage, original.specialistCoverage);
    expect(changed.note, original.note);
  });

  test('assignment and Early Years boundaries match website intent', () {
    expect(teachingAssignmentBoundary, contains('assignment expectations'));
    expect(teachingAssignmentBoundary, contains('not employment status'));
    expect(teachingEarlyYearsBoundary, contains('Do not force Nursery'));
    expect(teachingClassTeacherRule, contains('one lead teacher'));
    expect(teachingSubjectTeacherRule, contains('class tutor responsibility stays separate'));
    expect(teachingHybridRule, contains('specialists override selected subjects'));
  });
}
