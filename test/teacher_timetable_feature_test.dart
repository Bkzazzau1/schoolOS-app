import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_timetable_demo_data.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_timetable_models.dart';

void main() {
  test('teacher timetable preserves exact fourteen website lessons', () {
    expect(teacherTimetableLessons.length, 14);
    expect(
      teacherTimetableDays
          .map((day) => teacherTimetableLessons.where((lesson) => lesson.day == day).length)
          .toList(),
      [4, 3, 2, 3, 2],
    );
  });

  test('teacher timetable preserves exact website KPI snapshot', () {
    expect(teacherTimetableKpis.map((item) => item.value).toList(), ['14', '4', '1', '9']);
    expect(teacherTimetableKpis.first.hint, 'Across 4 assigned classes');
    expect(teacherTimetableKpis[2].hint, 'Tuesday · JSS 2B');
    expect(teacherTimetableKpis.last.hint, 'Available planning blocks');
  });

  test('Tuesday substitution keeps exact lesson evidence', () {
    final substitutions = teacherTimetableLessons
        .where((lesson) => lesson.status == TeacherTimetableLessonStatus.substitution)
        .toList();
    expect(substitutions, hasLength(1));
    final lesson = substitutions.single;
    expect(lesson.day, 'Tuesday');
    expect(lesson.time, '12:30–1:10');
    expect(lesson.className, 'JSS 2B');
    expect(lesson.subject, 'Mathematics');
    expect(lesson.topic, 'Word problems');
    expect(lesson.room, 'B14');
    expect(lesson.note, 'Covering for Mr. David');
  });

  test('teacher timetable search covers class subject topic and room', () {
    expect(teacherTimetableLessons.where((lesson) => lesson.matches('D06')).length, 3);
    expect(teacherTimetableLessons.where((lesson) => lesson.matches('Further Mathematics')).length, 3);
    expect(teacherTimetableLessons.where((lesson) => lesson.matches('Linear equations')).length, 2);
    expect(teacherTimetableLessons.where((lesson) => lesson.matches('JSS 2B')).length, 4);
    expect(teacherTimetableLessons.where((lesson) => lesson.matches('Mr. David')).length, 0);
  });

  test('timetable lesson serialization preserves authoritative schedule evidence', () {
    final original = teacherTimetableLessons[6];
    final restored = TeacherTimetableLesson.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.day, original.day);
    expect(restored.time, original.time);
    expect(restored.className, original.className);
    expect(restored.room, original.room);
    expect(restored.status, TeacherTimetableLessonStatus.substitution);
    expect(restored.note, 'Covering for Mr. David');
  });

  test('website schedule notices are preserved exactly', () {
    expect(teacherTimetableNotices, hasLength(2));
    expect(teacherTimetableNotices.first.title, 'Tuesday substitution');
    expect(teacherTimetableNotices.first.warning, isTrue);
    expect(teacherTimetableNotices.last.title, 'Room change');
    expect(teacherTimetableNotices.last.detail, contains('No room changes this week'));
  });

  test('queued timetable intent is review evidence not schedule mutation', () {
    const intent = TeacherTimetableIntent(
      id: 'change-1',
      type: TeacherTimetableIntentType.changeRequest,
      status: TeacherTimetableIntentStatus.queuedForReview,
      actorMembershipId: 'membership-teacher-1',
      createdAt: '2026-09-20T03:00:00.000Z',
      detail: 'Request review only',
    );
    final restored = TeacherTimetableIntent.fromJson(intent.toJson());
    expect(restored.type, TeacherTimetableIntentType.changeRequest);
    expect(restored.status, TeacherTimetableIntentStatus.queuedForReview);
    expect(restored.lessonId, isNull);
    expect(teacherTimetableAuthorityBoundary, contains('does not edit'));
    expect(teacherTimetableAuthorityBoundary, contains('server accepted'));
  });

  test('teacher timetable permissions can explicitly deny direct editing and sync authority', () {
    const permissions = TeacherTimetablePermissions(
      canViewAssignedTimetable: true,
      canTakeAttendance: true,
      canRequestChange: true,
      canEditTimetableDirectly: false,
      canConfirmServerSync: false,
    );
    expect(permissions.canViewAssignedTimetable, isTrue);
    expect(permissions.canTakeAttendance, isTrue);
    expect(permissions.canRequestChange, isTrue);
    expect(permissions.canEditTimetableDirectly, isFalse);
    expect(permissions.canConfirmServerSync, isFalse);
  });

  test('teacher timetable retains exact week labels', () {
    expect(teacherTimetableTermLabel, 'WEEK 6 · FIRST TERM');
    expect(teacherTimetableWeekLabel, '14–18 September 2026');
  });
}
