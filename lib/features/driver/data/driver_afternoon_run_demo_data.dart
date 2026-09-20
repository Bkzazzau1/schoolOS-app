import '../domain/driver_afternoon_run_models.dart';
import 'driver_morning_run_demo_data.dart';

const driverAfternoonRunBoundary =
    'The Driver sees only students assigned to the active transport route and only the information needed for safe boarding and drop-off. Academic, finance and unrelated family data are excluded.';

const driverAfternoonSafetyBoundary =
    'Reaching a stop never means a student was dropped off. Each boarded child requires an explicit safe-release status. Guardian-unavailable or drop-exception riders remain on the bus until a safe return to school is recorded.';

const driverAfternoonOfflineBoundary =
    'Afternoon transport actions save locally first and queue for synchronization. A queued boarding or drop event is not server-confirmed until synchronization succeeds.';

List<DriverAfternoonStop> defaultBus02AfternoonStops() {
  final morning = defaultBus02MorningStops().reversed.toList(growable: false);
  const times = <String>[
    '14:45',
    '14:55',
    '15:05',
    '15:15',
    '15:25',
    '15:35',
    '15:45',
  ];

  return [
    for (var index = 0; index < morning.length; index++)
      DriverAfternoonStop(
        id: morning[index].id,
        sequence: index + 1,
        name: morning[index].name,
        scheduledTime: times[index],
        riders: [
          for (final rider in morning[index].riders)
            DriverAfternoonRider(
              studentId: rider.studentId,
              name: rider.name,
              className: rider.className,
              stopId: rider.stopId,
            ),
        ],
      ),
  ];
}
