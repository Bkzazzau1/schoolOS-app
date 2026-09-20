import '../domain/parent_attendance_models.dart';

const parentAttendancePrinciple =
    'Attendance records show when a child was captured by the school’s authorized attendance process. The portal does not guess why a child was late or absent. If hardware was offline, a record may appear after synchronization or an approved correction.';

const parentAttendanceArrivalNote =
    'Today’s arrival record was captured by school attendance hardware and synchronized to the family portal.';

const parentDefaultAttendance = ParentAttendanceSnapshot(
  familyAccountId: 'FAM-BGA-0042',
  children: [
    ParentAttendanceChildSummary(
      childId: 'STU-001',
      name: 'Maryam Abdullahi',
      className: 'JSS 2A',
      attendancePercent: 96,
      presentDays: 24,
      totalSchoolDays: 25,
      lateArrivals: 1,
      latestCheckInLabel: 'Today · 07:41',
      captureDevice: 'Main Gate Face Terminal',
      checkedInToday: true,
    ),
    ParentAttendanceChildSummary(
      childId: 'PRI-003',
      name: 'Hafsa Abdullahi',
      className: 'Primary 3',
      attendancePercent: 92,
      presentDays: 23,
      totalSchoolDays: 25,
      lateArrivals: 2,
      latestCheckInLabel: 'Today · 07:44',
      captureDevice: 'Primary Gate NFC',
      checkedInToday: true,
    ),
  ],
  events: [
    ParentAttendanceEvent(
      dateLabel: '13 Sep 2026',
      childId: 'STU-001',
      childName: 'Maryam Abdullahi',
      checkIn: '07:41',
      checkOut: '—',
      gate: 'Main Gate',
      captureMethod: 'Face terminal',
      status: 'Present',
    ),
    ParentAttendanceEvent(
      dateLabel: '12 Sep 2026',
      childId: 'STU-001',
      childName: 'Maryam Abdullahi',
      checkIn: '07:38',
      checkOut: '15:19',
      gate: 'Main Gate',
      captureMethod: 'Face terminal',
      status: 'Present',
    ),
    ParentAttendanceEvent(
      dateLabel: '11 Sep 2026',
      childId: 'STU-001',
      childName: 'Maryam Abdullahi',
      checkIn: '08:01',
      checkOut: '15:16',
      gate: 'Main Gate',
      captureMethod: 'Face terminal',
      status: 'Late',
    ),
    ParentAttendanceEvent(
      dateLabel: '13 Sep 2026',
      childId: 'PRI-003',
      childName: 'Hafsa Abdullahi',
      checkIn: '07:44',
      checkOut: '—',
      gate: 'Primary Gate',
      captureMethod: 'NFC card',
      status: 'Present',
    ),
    ParentAttendanceEvent(
      dateLabel: '12 Sep 2026',
      childId: 'PRI-003',
      childName: 'Hafsa Abdullahi',
      checkIn: '07:49',
      checkOut: '14:46',
      gate: 'Primary Gate',
      captureMethod: 'NFC card',
      status: 'Present',
    ),
    ParentAttendanceEvent(
      dateLabel: '11 Sep 2026',
      childId: 'PRI-003',
      childName: 'Hafsa Abdullahi',
      checkIn: '07:52',
      checkOut: '14:41',
      gate: 'Primary Gate',
      captureMethod: 'NFC card',
      status: 'Present',
    ),
  ],
  notifications: [
    ParentAttendanceNotification(
      title: 'Maryam checked in at 07:41',
      detail: 'Main Gate · 13 Sep 2026',
    ),
    ParentAttendanceNotification(
      title: 'Hafsa checked in at 07:44',
      detail: 'Primary Gate · 13 Sep 2026',
    ),
    ParentAttendanceNotification(
      title: 'Maryam checked out at 15:19',
      detail: 'Main Gate · 12 Sep 2026',
    ),
  ],
);
