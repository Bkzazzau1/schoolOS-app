import '../domain/teacher_attendance_models.dart';

const teacherAttendanceDateLabel = 'TODAY · MONDAY 14 SEPTEMBER';
const teacherAttendanceCompletion = 98;

const teacherAttendanceLessons = <TeacherAttendanceLesson>[
  TeacherAttendanceLesson(
    id: 'MON-0800-J2A',
    className: 'JSS 2A',
    subject: 'Mathematics',
    time: '8:00–8:40',
    room: 'B12',
    topic: 'Linear equations',
  ),
  TeacherAttendanceLesson(
    id: 'MON-0920-J2B',
    className: 'JSS 2B',
    subject: 'Mathematics',
    time: '9:20–10:00',
    room: 'B14',
    topic: 'Linear equations',
  ),
  TeacherAttendanceLesson(
    id: 'MON-1100-J3A',
    className: 'JSS 3A',
    subject: 'Mathematics',
    time: '11:00–11:40',
    room: 'C04',
    topic: 'Simultaneous equations',
  ),
];

const teacherAttendanceInitialStudents = <TeacherAttendanceStudentEntry>[
  TeacherAttendanceStudentEntry(
    id: 1,
    code: 'Student 001',
    studentId: 'STU-0001',
    status: TeacherAttendanceStatus.present,
    note: '',
    attendanceRate: 96,
  ),
  TeacherAttendanceStudentEntry(
    id: 2,
    code: 'Student 002',
    studentId: 'STU-0002',
    status: TeacherAttendanceStatus.present,
    note: '',
    attendanceRate: 88,
  ),
  TeacherAttendanceStudentEntry(
    id: 3,
    code: 'Student 003',
    studentId: 'STU-0003',
    status: TeacherAttendanceStatus.absent,
    note: 'Follow-up pending',
    attendanceRate: 79,
  ),
  TeacherAttendanceStudentEntry(
    id: 4,
    code: 'Student 004',
    studentId: 'STU-0004',
    status: TeacherAttendanceStatus.present,
    note: '',
    attendanceRate: 98,
  ),
  TeacherAttendanceStudentEntry(
    id: 5,
    code: 'Student 005',
    studentId: 'STU-0005',
    status: TeacherAttendanceStatus.late,
    note: 'Arrived after lesson start',
    attendanceRate: 92,
  ),
  TeacherAttendanceStudentEntry(
    id: 6,
    code: 'Student 006',
    studentId: 'STU-0006',
    status: TeacherAttendanceStatus.present,
    note: '',
    attendanceRate: 95,
  ),
  TeacherAttendanceStudentEntry(
    id: 7,
    code: 'Student 007',
    studentId: 'STU-0007',
    status: TeacherAttendanceStatus.excused,
    note: 'Approved absence',
    attendanceRate: 90,
  ),
  TeacherAttendanceStudentEntry(
    id: 8,
    code: 'Student 008',
    studentId: 'STU-0008',
    status: TeacherAttendanceStatus.present,
    note: '',
    attendanceRate: 94,
  ),
];

const teacherAttendanceHistory = <TeacherAttendanceHistoryItem>[
  TeacherAttendanceHistoryItem(
    className: 'JSS 2B',
    subject: 'Mathematics',
    day: 'Friday',
    presentSummary: '37/39 present',
    rate: '94.9%',
  ),
  TeacherAttendanceHistoryItem(
    className: 'JSS 3A',
    subject: 'Mathematics',
    day: 'Thursday',
    presentSummary: '40/41 present',
    rate: '97.6%',
  ),
  TeacherAttendanceHistoryItem(
    className: 'SS 1A',
    subject: 'Further Mathematics',
    day: 'Wednesday',
    presentSummary: '27/28 present',
    rate: '96.4%',
  ),
];

const teacherAttendanceDraftBoundary =
    'Attendance edits are local-first draft evidence tied to the selected scheduled lesson. A teacher may edit only an assigned register; changing a status does not change student identity, class membership, marks, discipline or promotion.';

const teacherAttendanceSyncBoundary =
    'Submitting attendance stores the register locally and queues the same register for synchronization. Until the authoritative service acknowledges it, absent or late entries must not be treated as final school-wide absence evidence or trigger automatic sanctions.';

const teacherAttendanceInsightBoundary =
    'Attendance patterns may be surfaced for authorized human review, but the system must not infer motives, punish a learner, alter grades or make promotion decisions from attendance alone.';
