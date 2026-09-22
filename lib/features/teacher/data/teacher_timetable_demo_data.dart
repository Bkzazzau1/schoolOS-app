import '../domain/teacher_timetable_models.dart';

const teacherTimetableWeekLabel = '14–18 September 2026';
const teacherTimetableTermLabel = 'WEEK 6 · FIRST TERM';
const teacherTimetableDays = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

const teacherTimetableLessons = <TeacherTimetableLesson>[
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

const teacherTimetableNotices = <TeacherTimetableNotice>[
  TeacherTimetableNotice(title: 'Tuesday substitution', detail: 'You are covering JSS 2B from 12:30–1:10 PM for Mr. David.', warning: true),
  TeacherTimetableNotice(title: 'Room change', detail: 'SS1A on Friday remains in D06. No room changes this week.'),
];

const teacherTimetableAuthorityBoundary =
    'Teachers may view their assigned timetable, take attendance, report lesson issues and request timetable changes. A local request or sync intent does not edit the authoritative school timetable or prove that a server accepted a change.';
