import '../domain/teacher_classes_models.dart';

const teacherClassAssignments = <TeacherClassAssignment>[
  TeacherClassAssignment(
    id: 'jss2a',
    name: 'JSS 2A',
    subject: 'Mathematics',
    students: 42,
    room: 'B12',
    progress: 72,
    attendance: 94,
    classAverage: 74,
    nextLesson: 'Mon · 8:00 AM',
    topic: 'Linear equations',
    pendingMarking: 8,
  ),
  TeacherClassAssignment(
    id: 'jss2b',
    name: 'JSS 2B',
    subject: 'Mathematics',
    students: 39,
    room: 'B14',
    progress: 68,
    attendance: 91,
    classAverage: 69,
    nextLesson: 'Mon · 9:20 AM',
    topic: 'Linear equations',
    pendingMarking: 12,
  ),
  TeacherClassAssignment(
    id: 'jss3a',
    name: 'JSS 3A',
    subject: 'Mathematics',
    students: 41,
    room: 'C04',
    progress: 81,
    attendance: 96,
    classAverage: 78,
    nextLesson: 'Mon · 11:00 AM',
    topic: 'Simultaneous equations',
    pendingMarking: 5,
  ),
  TeacherClassAssignment(
    id: 'ss1a',
    name: 'SS 1A',
    subject: 'Further Mathematics',
    students: 28,
    room: 'D06',
    progress: 64,
    attendance: 93,
    classAverage: 71,
    nextLesson: 'Tue · 8:40 AM',
    topic: 'Functions',
    pendingMarking: 4,
  ),
];

const teacherClassActivity = <String>[
  'Attendance completed for 3 lessons',
  '2 lesson plans submitted',
  '1 assignment awaiting marking',
  'Syllabus updated after last lesson',
];

const teacherClassesBoundary =
    'My Classes is an assigned-teaching workspace. Class health, attendance, averages, syllabus progress and pending marking are review evidence only. This page cannot change class membership, marks, promotion, discipline, timetable ownership, finance records or safeguarding decisions.';

const teacherClassAiBoundary =
    'Teacher AI may suggest preparation or recap activities from authorized class evidence, but it cannot change marks, label students, make promotion or disciplinary decisions, or expose records outside the teacher’s assigned scope.';
