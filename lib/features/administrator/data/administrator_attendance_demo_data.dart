import '../domain/administrator_attendance_models.dart';

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

const administratorAttendanceFlow = <String>[
  '1. Device scan|Face · NFC · QR',
  '2. Identify student|Match credential',
  '3. Record event|Time + device + direction',
  '4. Attendance rule|Present · Late · Exit',
  '5. SchoolOS ledger|Daily history',
  '6. Parent update|Arrival / departure',
];
