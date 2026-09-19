import '../domain/principal_attendance_models.dart';

const principalAttendanceClasses = <PrincipalClassAttendance>[
  PrincipalClassAttendance(className: 'JSS 1A', total: 44, present: 42, absent: 1, late: 1, excused: 0, rate: 95, trend: 1.4, status: PrincipalAttendanceHealth.strong),
  PrincipalClassAttendance(className: 'JSS 2A', total: 42, present: 40, absent: 1, late: 1, excused: 0, rate: 95, trend: 0.8, status: PrincipalAttendanceHealth.strong),
  PrincipalClassAttendance(className: 'JSS 2B', total: 39, present: 33, absent: 4, late: 2, excused: 0, rate: 85, trend: -5.7, status: PrincipalAttendanceHealth.needsAttention),
  PrincipalClassAttendance(className: 'JSS 3A', total: 41, present: 39, absent: 1, late: 0, excused: 1, rate: 95, trend: 2.0, status: PrincipalAttendanceHealth.strong),
  PrincipalClassAttendance(className: 'SS 1A', total: 37, present: 34, absent: 1, late: 2, excused: 0, rate: 92, trend: -1.2, status: PrincipalAttendanceHealth.watch),
  PrincipalClassAttendance(className: 'SS 2A', total: 35, present: 33, absent: 1, late: 1, excused: 0, rate: 94, trend: 0.4, status: PrincipalAttendanceHealth.strong),
];

const principalAttendanceStaff = <PrincipalStaffAttendance>[
  PrincipalStaffAttendance(id: 'STAFF-001', name: 'Mrs. Amina Yusuf', role: 'Teacher · Mathematics', status: PrincipalAttendanceStaffStatus.present, checkIn: '7:31 AM', punctuality: PrincipalAttendancePunctuality.onTime),
  PrincipalStaffAttendance(id: 'STAFF-002', name: 'Mr. Daniel John', role: 'Teacher · Mathematics', status: PrincipalAttendanceStaffStatus.present, checkIn: '7:26 AM', punctuality: PrincipalAttendancePunctuality.onTime),
  PrincipalStaffAttendance(id: 'STAFF-003', name: 'Mrs. Fatima Bello', role: 'Teacher · English', status: PrincipalAttendanceStaffStatus.present, checkIn: '7:44 AM', punctuality: PrincipalAttendancePunctuality.late),
  PrincipalStaffAttendance(id: 'STAFF-004', name: 'Mr. Peter James', role: 'Teacher · Science', status: PrincipalAttendanceStaffStatus.absent, checkIn: '—', punctuality: PrincipalAttendancePunctuality.followUp),
  PrincipalStaffAttendance(id: 'STAFF-005', name: 'Mrs. Grace Musa', role: 'Teacher · Humanities', status: PrincipalAttendanceStaffStatus.present, checkIn: '7:20 AM', punctuality: PrincipalAttendancePunctuality.onTime),
];

const principalAttendanceFollowUps = <PrincipalAttendanceFollowUp>[
  PrincipalAttendanceFollowUp(id: 'ATT-001', person: 'Student Gamma', type: PrincipalAttendancePersonType.student, classOrRole: 'JSS 2B', issue: 'Repeated absence', count: '4 absences in 10 school days', severity: PrincipalAttendanceSeverity.high),
  PrincipalAttendanceFollowUp(id: 'ATT-002', person: 'Student Beta', type: PrincipalAttendancePersonType.student, classOrRole: 'JSS 2A', issue: 'Repeated lateness', count: '3 late arrivals this week', severity: PrincipalAttendanceSeverity.medium),
  PrincipalAttendanceFollowUp(id: 'ATT-003', person: 'Mr. Peter James', type: PrincipalAttendancePersonType.staff, classOrRole: 'Science Department', issue: 'Staff absence', count: 'Absent today · 2nd this month', severity: PrincipalAttendanceSeverity.high),
  PrincipalAttendanceFollowUp(id: 'ATT-004', person: 'Student Epsilon', type: PrincipalAttendancePersonType.student, classOrRole: 'SS 1A', issue: 'Attendance decline', count: '91% term attendance', severity: PrincipalAttendanceSeverity.low),
];

const principalAttendanceWeekTrend = <PrincipalAttendanceTrendPoint>[
  PrincipalAttendanceTrendPoint(day: 'Mon', rate: 94),
  PrincipalAttendanceTrendPoint(day: 'Tue', rate: 93),
  PrincipalAttendanceTrendPoint(day: 'Wed', rate: 92),
  PrincipalAttendanceTrendPoint(day: 'Thu', rate: 91),
  PrincipalAttendanceTrendPoint(day: 'Fri', rate: 93),
];

const principalBiometricScanners = <PrincipalBiometricScanner>[
  PrincipalBiometricScanner(
    id: 'SCN-PALM-01',
    name: 'Secondary Main Gate Palm Scanner',
    location: 'Secondary main gate',
    modality: PrincipalBiometricModality.palm,
    transport: PrincipalScannerTransport.lan,
    status: PrincipalScannerStatus.ready,
    enrolledTemplates: 438,
    pendingEvents: 0,
    lastEventAt: '7:53 AM',
  ),
  PrincipalBiometricScanner(
    id: 'SCN-FP-01',
    name: 'Staff Office Fingerprint Reader',
    location: 'Secondary staff office',
    modality: PrincipalBiometricModality.fingerprint,
    transport: PrincipalScannerTransport.usb,
    status: PrincipalScannerStatus.ready,
    enrolledTemplates: 24,
    pendingEvents: 0,
    lastEventAt: '7:44 AM',
  ),
  PrincipalBiometricScanner(
    id: 'SCN-FP-02',
    name: 'JSS Block Fingerprint Terminal',
    location: 'JSS block entrance',
    modality: PrincipalBiometricModality.fingerprint,
    transport: PrincipalScannerTransport.lan,
    status: PrincipalScannerStatus.syncPending,
    enrolledTemplates: 166,
    pendingEvents: 12,
    lastEventAt: '7:48 AM',
  ),
];

const principalBiometricSeedEvents = <PrincipalBiometricAttendanceEvent>[
  PrincipalBiometricAttendanceEvent(
    id: 'BIO-0001',
    personReference: 'STU-001',
    personType: PrincipalAttendancePersonType.student,
    classOrRole: 'JSS 2A',
    scannerId: 'SCN-PALM-01',
    modality: PrincipalBiometricModality.palm,
    capturedAt: '2026-09-13T07:28:13+01:00',
    localSequence: 101,
    templateReference: 'tpl:student:STU-001:palm:v1',
    matchScore: 0.982,
    matchStatus: PrincipalBiometricMatchStatus.matched,
    synced: true,
  ),
  PrincipalBiometricAttendanceEvent(
    id: 'BIO-0002',
    personReference: 'STAFF-001',
    personType: PrincipalAttendancePersonType.staff,
    classOrRole: 'Teacher · Mathematics',
    scannerId: 'SCN-FP-01',
    modality: PrincipalBiometricModality.fingerprint,
    capturedAt: '2026-09-13T07:31:02+01:00',
    localSequence: 44,
    templateReference: 'tpl:staff:STAFF-001:fingerprint:v1',
    matchScore: 0.974,
    matchStatus: PrincipalBiometricMatchStatus.matched,
    synced: true,
  ),
  PrincipalBiometricAttendanceEvent(
    id: 'BIO-0003',
    personReference: 'STU-003',
    personType: PrincipalAttendancePersonType.student,
    classOrRole: 'JSS 2B',
    scannerId: 'SCN-FP-02',
    modality: PrincipalBiometricModality.fingerprint,
    capturedAt: '2026-09-13T07:48:21+01:00',
    localSequence: 12,
    templateReference: 'tpl:student:STU-003:fingerprint:v1',
    matchScore: 0.951,
    matchStatus: PrincipalBiometricMatchStatus.matched,
    synced: false,
  ),
];

const principalAttendancePermissions = PrincipalAttendancePermissions(
  canViewSecondaryAttendance: true,
  canResolveFollowUps: true,
  canIngestOfflineBiometricEvents: true,
  canManagePrimary: false,
);

int get principalAttendanceTotalStudents => principalAttendanceClasses.fold(0, (sum, row) => sum + row.total);
int get principalAttendancePresentStudents => principalAttendanceClasses.fold(0, (sum, row) => sum + row.present);
int get principalAttendanceAbsentStudents => principalAttendanceClasses.fold(0, (sum, row) => sum + row.absent);
int get principalAttendanceLateStudents => principalAttendanceClasses.fold(0, (sum, row) => sum + row.late);
int get principalAttendanceOverallRate => ((principalAttendancePresentStudents / principalAttendanceTotalStudents) * 100).round();
int get principalAttendanceStaffPresent => principalAttendanceStaff.where((row) => row.status == PrincipalAttendanceStaffStatus.present).length;
int get principalAttendanceStaffLate => principalAttendanceStaff.where((row) => row.punctuality == PrincipalAttendancePunctuality.late).length;
