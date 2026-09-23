import '../domain/driver_morning_run_models.dart';

const driverMorningRunBoundary =
    'This manifest is limited to the driver\'s assigned route. It shows only transport information needed to complete the trip; academic, finance and unrelated family records are not available here.';

const driverMorningOfflineBoundary =
    'Every action is saved on this device first. Queued transport events are operationally visible offline but are not server-confirmed until synchronization succeeds.';

// Only real students from the school's real register (`administratorStudentsWebsiteSeed`) ride this
// route. Earlier this listed 26 riders across these 7 stops, but only one of them (STU-001) was ever
// a real student — the other 25 were invented ids/names Administrator never actually registered, the
// same "fabricated evidence about a person" problem this whole app-wide audit exists to remove, just
// applied to entire invented people instead of invented facts about a real one. The stop names and
// times are real-flavored route geography, not a claim about any specific person, so they stay; every
// stop with no real registered rider honestly stays empty rather than being padded to look busier.
List<DriverMorningStop> defaultBus02MorningStops() => const [
      DriverMorningStop(
        id: 'BUS-02-STOP-01',
        sequence: 1,
        name: 'Barnawa Market Junction',
        scheduledTime: '06:35',
        riders: [
          DriverMorningRider(studentId: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', stopId: 'BUS-02-STOP-01'),
        ],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-02',
        sequence: 2,
        name: 'Barnawa Complex',
        scheduledTime: '06:45',
        riders: [],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-03',
        sequence: 3,
        name: 'Kakuri Roundabout',
        scheduledTime: '06:55',
        riders: [],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-04',
        sequence: 4,
        name: 'Kakuri Bus Stop',
        scheduledTime: '07:05',
        riders: [],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-05',
        sequence: 5,
        name: 'Television Garage',
        scheduledTime: '07:15',
        riders: [],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-06',
        sequence: 6,
        name: 'Nasarawa Junction',
        scheduledTime: '07:25',
        riders: [],
      ),
      DriverMorningStop(
        id: 'BUS-02-STOP-07',
        sequence: 7,
        name: 'Command Junction',
        scheduledTime: '07:35',
        riders: [],
      ),
    ];
