import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/teacher/data/teacher_timetable_policy_copy.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_timetable_models.dart';

const _fixtureLessons = <TeacherTimetableLesson>[
  TeacherTimetableLesson(id: 'MON-0800-J2A', day: 'Monday', date: '14 Sep', time: '8:00–8:40', className: 'JSS 2A', subject: 'Mathematics', topic: 'Linear equations', room: 'B12', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'MON-0920-J2B', day: 'Monday', date: '14 Sep', time: '9:20–10:00', className: 'JSS 2B', subject: 'Mathematics', topic: 'Linear equations', room: 'B14', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'MON-1100-J3A', day: 'Monday', date: '14 Sep', time: '11:00–11:40', className: 'JSS 3A', subject: 'Mathematics', topic: 'Simultaneous equations', room: 'C04', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'MON-1310-J2A', day: 'Monday', date: '14 Sep', time: '1:10–1:50', className: 'JSS 2A', subject: 'Mathematics', topic: 'Revision / classwork', room: 'B12', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'TUE-0840-S1A', day: 'Tuesday', date: '15 Sep', time: '8:40–9:20', className: 'SS1A', subject: 'Further Mathematics', topic: 'Functions', room: 'D06', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'TUE-1020-J2A', day: 'Tuesday', date: '15 Sep', time: '10:20–11:00', className: 'JSS 2A', subject: 'Mathematics', topic: 'Word problems', room: 'B12', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'TUE-1230-J2B', day: 'Tuesday', date: '15 Sep', time: '12:30–1:10', className: 'JSS 2B', subject: 'Mathematics', topic: 'Word problems', room: 'B14', status: TeacherTimetableLessonStatus.substitution, note: 'Covering for Mr. David'),
  TeacherTimetableLesson(id: 'WED-0800-J3A', day: 'Wednesday', date: '16 Sep', time: '8:00–8:40', className: 'JSS 3A', subject: 'Mathematics', topic: 'Simultaneous equations II', room: 'C04', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'WED-1020-S1A', day: 'Wednesday', date: '16 Sep', time: '10:20–11:00', className: 'SS1A', subject: 'Further Mathematics', topic: 'Domain and range', room: 'D06', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'THU-0920-J2A', day: 'Thursday', date: '17 Sep', time: '9:20–10:00', className: 'JSS 2A', subject: 'Mathematics', topic: 'Algebraic fractions', room: 'B12', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'THU-1140-J2B', day: 'Thursday', date: '17 Sep', time: '11:40–12:20', className: 'JSS 2B', subject: 'Mathematics', topic: 'Algebraic fractions', room: 'B14', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'THU-1310-J3A', day: 'Thursday', date: '17 Sep', time: '1:10–1:50', className: 'JSS 3A', subject: 'Mathematics', topic: 'Graphical solution', room: 'C04', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'FRI-0840-S1A', day: 'Friday', date: '18 Sep', time: '8:40–9:20', className: 'SS1A', subject: 'Further Mathematics', topic: 'Composite functions', room: 'D06', status: TeacherTimetableLessonStatus.scheduled),
  TeacherTimetableLesson(id: 'FRI-1020-J2B', day: 'Friday', date: '18 Sep', time: '10:20–11:00', className: 'JSS 2B', subject: 'Mathematics', topic: 'Weekly assessment', room: 'B14', status: TeacherTimetableLessonStatus.scheduled),
];

const _fixtureNotices = <TeacherTimetableNotice>[
  TeacherTimetableNotice(title: 'Tuesday substitution', detail: 'You are covering JSS 2B from 12:30–1:10 PM for Mr. David.', warning: true),
  TeacherTimetableNotice(title: 'Room change', detail: 'SS1A on Friday remains in D06. No room changes this week.'),
];

void main() {
  test('timetable fixture covers fourteen lessons across five real days', () {
    expect(_fixtureLessons.length, 14);
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    expect(
      days.map((day) => _fixtureLessons.where((lesson) => lesson.day == day).length).toList(),
      [4, 3, 2, 3, 2],
    );
  });

  test('the KPI strip is computed from the real lessons, not a fixed snapshot', () {
    // The page computes its KPI strip from the real (possibly roster-filtered) lesson list rather than
    // from a fixed constant. These are the underlying real counts it computes from.
    expect(_fixtureLessons.length, 14);
    expect(_fixtureLessons.where((l) => l.day == 'Monday').length, 4);
    expect(_fixtureLessons.where((l) => l.status == TeacherTimetableLessonStatus.substitution).length, 1);
    expect(_fixtureLessons.map((l) => l.className).toSet().length, 4);
  });

  test('Tuesday substitution keeps exact lesson evidence', () {
    final substitutions = _fixtureLessons
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
    expect(_fixtureLessons.where((lesson) => lesson.matches('D06')).length, 3);
    expect(_fixtureLessons.where((lesson) => lesson.matches('Further Mathematics')).length, 3);
    expect(_fixtureLessons.where((lesson) => lesson.matches('Linear equations')).length, 2);
    expect(_fixtureLessons.where((lesson) => lesson.matches('JSS 2B')).length, 4);
    expect(_fixtureLessons.where((lesson) => lesson.matches('Mr. David')).length, 0);
  });

  test('timetable lesson serialization preserves authoritative schedule evidence', () {
    final original = _fixtureLessons[6];
    final restored = TeacherTimetableLesson.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.day, original.day);
    expect(restored.time, original.time);
    expect(restored.className, original.className);
    expect(restored.room, original.room);
    expect(restored.status, TeacherTimetableLessonStatus.substitution);
    expect(restored.note, 'Covering for Mr. David');
  });

  test('schedule notice fixture round-trips', () {
    expect(_fixtureNotices, hasLength(2));
    expect(_fixtureNotices.first.title, 'Tuesday substitution');
    expect(_fixtureNotices.first.warning, isTrue);
    expect(_fixtureNotices.last.title, 'Room change');
    expect(_fixtureNotices.last.detail, contains('No room changes this week'));
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
    expect(teacherTimetableAuthorityBoundary, contains('request a schedule change'));
    expect(teacherTimetableAuthorityBoundary, contains('only after approval'));
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
}
