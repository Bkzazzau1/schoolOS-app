import '../domain/driver_morning_run_models.dart';

const driverMorningRunBoundary =
    'This manifest is limited to the driver\'s assigned route. It shows only transport information needed to complete the trip; academic, finance and unrelated family records are not available here.';

const driverMorningOfflineBoundary =
    'Every action is saved on this device first. Queued transport events are operationally visible offline but are not server-confirmed until synchronization succeeds.';

List<DriverMorningStop> defaultBus02MorningStops() => const [
      DriverMorningStop(
        id: 'BUS-02-STOP-01',
        sequence: 1,
        name: 'Barnawa Market Junction',
        scheduledTime: '06:35',
        riders: [
          DriverMorningRider(studentId: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', stopId: 'BUS-02-STOP-01'),
          DriverMorningRider(studentId: 'STU-014', name: 'Aisha Sani', className: 'JSS 1B', stopId: 'BUS-02-STOP-01'),
          DriverMorningRider(studentId: 'STU-027', name: 'Musa Bello', className: 'JSS 3A', stopId: 'BUS-02-STOP-01'),
          DriverMorningRider(studentId: 'STU-041', name: 'Fatima Ibrahim', className: 'Primary 6', stopId: 'BUS-02-STOP-01'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-02',
        sequence: 2,
        name: 'Barnawa Complex',
        scheduledTime: '06:45',
        riders: [
          DriverMorningRider(studentId: 'STU-052', name: 'Abubakar Yusuf', className: 'SS 1B', stopId: 'BUS-02-STOP-02'),
          DriverMorningRider(studentId: 'STU-063', name: 'Hauwa Mohammed', className: 'JSS 2B', stopId: 'BUS-02-STOP-02'),
          DriverMorningRider(studentId: 'STU-074', name: 'David John', className: 'Primary 5', stopId: 'BUS-02-STOP-02'),
          DriverMorningRider(studentId: 'STU-085', name: 'Zainab Aliyu', className: 'JSS 1A', stopId: 'BUS-02-STOP-02'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-03',
        sequence: 3,
        name: 'Kakuri Roundabout',
        scheduledTime: '06:55',
        riders: [
          DriverMorningRider(studentId: 'STU-096', name: 'Samuel Audu', className: 'SS 2A', stopId: 'BUS-02-STOP-03'),
          DriverMorningRider(studentId: 'STU-107', name: 'Khadija Musa', className: 'Primary 4', stopId: 'BUS-02-STOP-03'),
          DriverMorningRider(studentId: 'STU-118', name: 'Ibrahim Lawal', className: 'JSS 3B', stopId: 'BUS-02-STOP-03'),
          DriverMorningRider(studentId: 'STU-129', name: 'Grace Peter', className: 'Primary 6', stopId: 'BUS-02-STOP-03'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-04',
        sequence: 4,
        name: 'Kakuri Bus Stop',
        scheduledTime: '07:05',
        riders: [
          DriverMorningRider(studentId: 'STU-140', name: 'Amina Usman', className: 'JSS 2A', stopId: 'BUS-02-STOP-04'),
          DriverMorningRider(studentId: 'STU-151', name: 'Daniel Okoro', className: 'SS 1A', stopId: 'BUS-02-STOP-04'),
          DriverMorningRider(studentId: 'STU-162', name: 'Rukayya Abdullahi', className: 'Primary 5', stopId: 'BUS-02-STOP-04'),
          DriverMorningRider(studentId: 'STU-173', name: 'Joseph Terna', className: 'JSS 1B', stopId: 'BUS-02-STOP-04'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-05',
        sequence: 5,
        name: 'Television Garage',
        scheduledTime: '07:15',
        riders: [
          DriverMorningRider(studentId: 'STU-184', name: 'Safiya Bello', className: 'Primary 3', stopId: 'BUS-02-STOP-05'),
          DriverMorningRider(studentId: 'STU-195', name: 'Michael James', className: 'JSS 2B', stopId: 'BUS-02-STOP-05'),
          DriverMorningRider(studentId: 'STU-206', name: 'Umar Faruq', className: 'SS 1B', stopId: 'BUS-02-STOP-05'),
          DriverMorningRider(studentId: 'STU-217', name: 'Esther Emmanuel', className: 'Primary 6', stopId: 'BUS-02-STOP-05'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-06',
        sequence: 6,
        name: 'Nasarawa Junction',
        scheduledTime: '07:25',
        riders: [
          DriverMorningRider(studentId: 'STU-228', name: 'Bilal Sani', className: 'JSS 3A', stopId: 'BUS-02-STOP-06'),
          DriverMorningRider(studentId: 'STU-239', name: 'Mercy Audu', className: 'Primary 5', stopId: 'BUS-02-STOP-06'),
          DriverMorningRider(studentId: 'STU-250', name: 'Yusuf Ahmed', className: 'JSS 1A', stopId: 'BUS-02-STOP-06'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-07',
        sequence: 7,
        name: 'Command Junction',
        scheduledTime: '07:35',
        riders: [
          DriverMorningRider(studentId: 'STU-261', name: 'Deborah John', className: 'SS 2B', stopId: 'BUS-02-STOP-07'),
          DriverMorningRider(studentId: 'STU-272', name: 'Mustapha Ali', className: 'JSS 2A', stopId: 'BUS-02-STOP-07'),
          DriverMorningRider(studentId: 'STU-283', name: 'Rahma Ibrahim', className: 'Primary 4', stopId: 'BUS-02-STOP-07'),
        ],
      ),
    ];
