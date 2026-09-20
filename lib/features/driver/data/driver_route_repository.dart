import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_route_models.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_dashboard_repository.dart';
import 'driver_morning_run_repository.dart';

class DriverRouteRepository {
  DriverRouteRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _morningRepository = DriverMorningRunRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _afternoonRepository = DriverAfternoonRunRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;
  final DriverMorningRunRepository _morningRepository;
  final DriverAfternoonRunRepository _afternoonRepository;

  Future<DriverRouteSnapshot> loadToday() async {
    final member = _requireDriver();
    final assignment = await _loadAssignment(member);
    final route = await _loadAssignedRoute(assignment);
    final morning = await _morningRepository.loadToday();
    final afternoon = await _afternoonRepository.loadToday();

    if (morning.membershipId != member.id ||
        afternoon.membershipId != member.id ||
        morning.routeId != assignment.routeId ||
        afternoon.routeId != assignment.routeId) {
      throw StateError(
        'Today\'s route manifests do not belong to the active Driver assignment.',
      );
    }
    if (morning.serviceDate != afternoon.serviceDate) {
      throw StateError('Morning and afternoon route manifests are for different days.');
    }
    if (morning.stops.length != route.stops || afternoon.stops.length != route.stops) {
      throw StateError(
        'The downloaded route stop count does not match Transport Control.',
      );
    }

    return DriverRouteSnapshot(
      routeId: route.id,
      routeName: route.name,
      vehicle: route.vehicle,
      driverName: assignment.driverDisplayName,
      assistantName: route.assistant,
      serviceDate: morning.serviceDate,
      totalAssignedRiders: route.riders,
      morningStops: [
        for (final stop in morning.stops) _morningStop(stop),
      ],
      afternoonStops: [
        for (final stop in afternoon.stops) _afternoonStop(stop),
      ],
    );
  }

  DriverRouteStopView _morningStop(DriverMorningStop stop) {
    final state = switch (stop.status) {
      DriverMorningStopStatus.pending => DriverRouteStopState.pending,
      DriverMorningStopStatus.active => DriverRouteStopState.active,
      DriverMorningStopStatus.departed => DriverRouteStopState.completed,
    };
    return DriverRouteStopView(
      id: stop.id,
      sequence: stop.sequence,
      name: stop.name,
      scheduledTime: stop.scheduledTime,
      assignedRiders: stop.riders.length,
      state: state,
      primaryCount: stop.boardedCount,
      secondaryCount: stop.exceptionCount,
      primaryLabel: 'Boarded',
      secondaryLabel: 'Exceptions',
    );
  }

  DriverRouteStopView _afternoonStop(DriverAfternoonStop stop) {
    final boardedToday = stop.riders.where((rider) => rider.status.enteredBus).length;
    final state = boardedToday == 0
        ? DriverRouteStopState.noService
        : switch (stop.status) {
            DriverAfternoonStopStatus.pending => DriverRouteStopState.pending,
            DriverAfternoonStopStatus.active => DriverRouteStopState.active,
            DriverAfternoonStopStatus.departed => DriverRouteStopState.completed,
          };
    return DriverRouteStopView(
      id: stop.id,
      sequence: stop.sequence,
      name: stop.name,
      scheduledTime: stop.scheduledTime,
      assignedRiders: stop.riders.length,
      state: state,
      primaryCount: stop.safelyReleasedCount,
      secondaryCount: stop.exceptionCount,
      primaryLabel: 'Released safely',
      secondaryLabel: 'Exceptions',
    );
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only a Driver membership can view an assigned route.');
    }
    return member;
  }

  Future<DriverTransportAssignment> _loadAssignment(
    SchoolMembership member,
  ) async {
    var record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: DriverDashboardRepository.assignmentEntityType,
      entityId: member.id,
    );
    if (record == null) {
      await DriverDashboardRepository(
        localDatabase: _localDatabase,
        schoolSession: _schoolSession,
      ).load();
      record = await _localDatabase.getLocalRecord(
        tenantId: member.schoolId,
        entityType: DriverDashboardRepository.assignmentEntityType,
        entityId: member.id,
      );
    }
    if (record == null) {
      throw StateError('No transport route is assigned to this Driver membership.');
    }
    final assignment = DriverTransportAssignment.fromJson(record.payload);
    if (assignment.membershipId != member.id || assignment.routeId.isEmpty) {
      throw StateError('The Driver route assignment is invalid.');
    }
    return assignment;
  }

  Future<SchoolTransportRoute> _loadAssignedRoute(
    DriverTransportAssignment assignment,
  ) async {
    final transport = await _transportRepository.load();
    for (final route in transport.routes) {
      if (route.id == assignment.routeId) return route;
    }
    throw StateError('Assigned route ${assignment.routeId} is unavailable.');
  }
}
