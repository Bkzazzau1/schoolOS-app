import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_riders_models.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_morning_run_repository.dart';

class DriverRidersRepository {
  DriverRidersRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _schoolSession = schoolSession,
        _morningRepository = DriverMorningRunRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _afternoonRepository = DriverAfternoonRunRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  final SchoolSessionController _schoolSession;
  final DriverMorningRunRepository _morningRepository;
  final DriverAfternoonRunRepository _afternoonRepository;

  Future<DriverRidersSnapshot> loadToday() async {
    final member = _requireDriver();
    final morning = await _morningRepository.loadToday();
    final afternoon = await _afternoonRepository.loadToday();

    if (morning.membershipId != member.id || afternoon.membershipId != member.id) {
      throw StateError('The rider manifests do not belong to this Driver membership.');
    }
    if (morning.routeId != afternoon.routeId) {
      throw StateError('Morning and afternoon manifests are not for the same route.');
    }
    if (morning.serviceDate != afternoon.serviceDate) {
      throw StateError('Morning and afternoon manifests are not for the same service day.');
    }

    final afternoonByStudent = <String, ({DriverAfternoonRider rider, DriverAfternoonStop stop})>{};
    for (final stop in afternoon.stops) {
      for (final rider in stop.riders) {
        if (afternoonByStudent.containsKey(rider.studentId)) {
          throw StateError('Duplicate student ${rider.studentId} in afternoon transport manifest.');
        }
        afternoonByStudent[rider.studentId] = (rider: rider, stop: stop);
      }
    }

    final riders = <DriverRiderOperationalView>[];
    final seen = <String>{};
    for (final morningStop in morning.stops) {
      for (final morningRider in morningStop.riders) {
        if (!seen.add(morningRider.studentId)) {
          throw StateError('Duplicate student ${morningRider.studentId} in morning transport manifest.');
        }
        final afternoonEntry = afternoonByStudent[morningRider.studentId];
        if (afternoonEntry == null) {
          throw StateError(
            '${morningRider.name} is missing from the afternoon transport manifest.',
          );
        }
        if (afternoonEntry.rider.stopId != morningRider.stopId ||
            afternoonEntry.stop.id != morningStop.id) {
          throw StateError(
            'Transport stop assignment does not match for ${morningRider.name}.',
          );
        }

        riders.add(
          DriverRiderOperationalView(
            studentId: morningRider.studentId,
            name: morningRider.name,
            className: morningRider.className,
            stopId: morningStop.id,
            stopSequence: morningStop.sequence,
            stopName: morningStop.name,
            morningScheduledTime: morningStop.scheduledTime,
            afternoonScheduledTime: afternoonEntry.stop.scheduledTime,
            morningStatus: morningRider.status,
            afternoonStatus: afternoonEntry.rider.status,
            morningNote: morningRider.note,
            afternoonNote: afternoonEntry.rider.note,
          ),
        );
      }
    }

    if (riders.length != afternoonByStudent.length) {
      throw StateError('The morning and afternoon rider manifests do not reconcile.');
    }

    riders.sort((a, b) {
      final stopCompare = a.stopSequence.compareTo(b.stopSequence);
      if (stopCompare != 0) return stopCompare;
      return a.name.compareTo(b.name);
    });

    return DriverRidersSnapshot(
      routeId: morning.routeId,
      vehicle: morning.vehicle,
      serviceDate: morning.serviceDate,
      riders: List.unmodifiable(riders),
    );
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only a Driver membership can view assigned transport riders.');
    }
    return member;
  }
}
