import '../domain/administrator_attendance_models.dart';

const administratorAttendancePresentToday = 623;
const administratorAttendancePresentRate = 96.1;
const administratorAttendanceLateArrivals = 27;
const administratorAttendanceAbsentNotCheckedIn = 25;
const administratorAttendanceActiveDevices = '4 / 5';
const administratorAttendanceQueuedEvents = 42;

const administratorAttendanceWebsiteEvents = <AdministratorAttendanceEvent>[
  AdministratorAttendanceEvent(
    time: '07:41',
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    device: 'Main Gate Face Terminal',
    method: 'Face',
    status: AdministratorAttendanceEventStatus.checkedIn,
    parentState: 'Sent',
  ),
  AdministratorAttendanceEvent(
    time: '07:44',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    device: 'Primary Gate NFC',
    method: 'NFC Card',
    status: AdministratorAttendanceEventStatus.checkedIn,
    parentState: 'Sent',
  ),
  AdministratorAttendanceEvent(
    time: '07:58',
    student: 'Ibrahim Sani',
    className: 'JSS 2A',
    device: 'Main Gate Face Terminal',
    method: 'Face',
    status: AdministratorAttendanceEventStatus.late,
    parentState: 'Sent',
  ),
  AdministratorAttendanceEvent(
    time: '08:03',
    student: 'Muhammad Kabir',
    className: 'Primary 5',
    device: 'Primary Gate NFC',
    method: 'NFC Card',
    status: AdministratorAttendanceEventStatus.offlineSynced,
    parentState: 'Queued',
  ),
  AdministratorAttendanceEvent(
    time: '08:05',
    student: 'Unknown credential',
    className: '—',
    device: 'Main Gate Face Terminal',
    method: 'Face',
    status: AdministratorAttendanceEventStatus.unknownScan,
    parentState: 'Not sent',
  ),
];

const administratorAttendanceWebsiteDevices = <AdministratorAttendanceDevice>[
  AdministratorAttendanceDevice(
    name: 'Main Gate Face Terminal',
    location: 'Main entrance',
    type: 'Face recognition',
    status: AdministratorAttendanceDeviceStatus.online,
    lastEvent: '08:05',
    events: '281 events',
  ),
  AdministratorAttendanceDevice(
    name: 'Primary Gate NFC',
    location: 'Primary entrance',
    type: 'NFC / RFID',
    status: AdministratorAttendanceDeviceStatus.online,
    lastEvent: '08:03',
    events: '196 events',
  ),
  AdministratorAttendanceDevice(
    name: 'Early Years Check-in',
    location: 'Nursery reception',
    type: 'Guardian QR + staff confirm',
    status: AdministratorAttendanceDeviceStatus.online,
    lastEvent: '07:56',
    events: '83 events',
  ),
  AdministratorAttendanceDevice(
    name: 'Rear Gate Terminal',
    location: 'Transport / rear gate',
    type: 'Face + NFC',
    status: AdministratorAttendanceDeviceStatus.syncing,
    lastEvent: '07:49',
    events: '42 queued',
  ),
  AdministratorAttendanceDevice(
    name: 'Sports Exit Reader',
    location: 'Sports field gate',
    type: 'NFC / RFID',
    status: AdministratorAttendanceDeviceStatus.offline,
    lastEvent: 'Yesterday 16:18',
    events: '0 today',
  ),
];

const administratorAttendanceSections = <AdministratorAttendanceSection>[
  AdministratorAttendanceSection(name: 'Early Years', rate: 96, present: 83, late: 2, absent: 1),
  AdministratorAttendanceSection(name: 'Primary', rate: 93, present: 312, late: 11, absent: 7),
  AdministratorAttendanceSection(name: 'Secondary', rate: 91, present: 228, late: 14, absent: 9),
];

const administratorAttendanceCorrections = <AdministratorAttendanceCorrection>[
  AdministratorAttendanceCorrection(
    id: 'ATT-081',
    student: 'Maryam Abdullahi',
    className: 'JSS 2A',
    requestedChange: 'Absent → Present',
    evidence: 'Teacher submitted correction',
  ),
  AdministratorAttendanceCorrection(
    id: 'ATT-082',
    student: 'Hafsa Abdullahi',
    className: 'Primary 3',
    requestedChange: 'Late → Present',
    evidence: 'Arrival log attached',
  ),
  AdministratorAttendanceCorrection(
    id: 'ATT-083',
    student: 'Ibrahim Sani',
    className: 'JSS 2A',
    requestedChange: 'Present → Excused',
    evidence: 'Leadership review required',
  ),
];

const administratorAttendanceFlow = <String>[
  '1. Device scan|Face · NFC · QR',
  '2. Identify student|Match credential',
  '3. Record event|Time + device + direction',
  '4. Attendance rule|Present · Late · Exit',
  '5. SchoolOS ledger|Daily history',
  '6. Parent update|Arrival / departure',
];

const administratorAttendanceExceptions = <String>[
  '42 offline events waiting to sync|Rear Gate Terminal captured scans locally while connectivity was unavailable.|Do not mark these students absent until sync completes.',
  '1 unknown credential scan|Main Gate Face Terminal could not confidently match the credential.|Review manually; never guess the student identity.',
  '3 correction requests|Teacher/admin evidence conflicts with the current daily ledger.|Review with audit trail.',
];
