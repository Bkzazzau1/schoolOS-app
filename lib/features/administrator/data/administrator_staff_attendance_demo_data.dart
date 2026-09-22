import '../domain/administrator_staff_attendance_models.dart';

const administratorStaffAttendanceWebsiteSeed = <StaffAttendanceRecord>[
  StaffAttendanceRecord(
    id: 'STAFF-001',
    name: 'Mrs. Amina Yusuf',
    role: 'Teacher',
    section: 'Secondary',
    expected: 22,
    present: 21,
    leave: 1,
    late: 2,
    unexplained: 0,
    status: StaffAttendanceReviewStatus.ready,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-009',
    name: 'Mrs. Khadija Musa',
    role: 'Class Teacher',
    section: 'Primary',
    expected: 22,
    present: 20,
    leave: 1,
    late: 1,
    unexplained: 1,
    status: StaffAttendanceReviewStatus.review,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-014',
    name: 'Mr. Ahmad Sani',
    role: 'Teacher',
    section: 'Secondary',
    expected: 22,
    present: 22,
    leave: 0,
    late: 3,
    unexplained: 0,
    status: StaffAttendanceReviewStatus.ready,
  ),
  StaffAttendanceRecord(
    id: 'STAFF-021',
    name: 'Mrs. Safiya Ahmad',
    role: 'Teacher',
    section: 'Primary',
    expected: 22,
    present: 19,
    leave: 2,
    late: 0,
    unexplained: 1,
    status: StaffAttendanceReviewStatus.review,
  ),
];

const administratorStaffAttendanceDevices = <StaffAttendanceDevice>[
  StaffAttendanceDevice(
    name: 'Staff Main Gate Face Terminal',
    location: 'Main entrance',
    method: 'Face recognition',
    state: 'Online · 63 scans today',
  ),
  StaffAttendanceDevice(
    name: 'Staff Office NFC Reader',
    location: 'Administration block',
    method: 'NFC / RFID',
    state: 'Online · 18 scans today',
  ),
  StaffAttendanceDevice(
    name: 'Primary Staff Gate',
    location: 'Primary entrance',
    method: 'Face + NFC',
    state: 'Syncing · 7 queued',
  ),
];

const administratorStaffAttendanceFlow = <List<String>>[
  ['1. Staff scan', 'Face · NFC · authorized device'],
  ['2. Attendance ledger', 'Arrival, departure, late, absent'],
  ['3. Review context', 'Approved leave · correction · exception'],
  ['4. Payroll readiness', 'Verified days and unresolved items'],
  ['5. Finance handoff', 'Summary only · human review retained'],
];
