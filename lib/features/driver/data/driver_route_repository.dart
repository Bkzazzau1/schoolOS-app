import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/data/transport_route_management_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_route_models.dart';
import 'driver_afternoon_run_demo_data.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_dashboard_repository.dart';
import 'driver_morning_run_demo_data.dart';
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
        _routeManagementRepository = TransportRouteManagementRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;
  final TransportRouteManagementRepository _routeManagementRepository;

  Future<DriverRouteSnapshot> loadToday() async {
    final member = _requireDriver();
    final assignment = await _loadAssignment(member);
    final route = await _loadAssignedRoute(assignment);
    final today = _todayKey();

    final morningRecord = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: DriverMorningRunRepository.entityType,
      entityId: '${member.id}:morning:$today',
    );
    final afternoonRecord = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: DriverAfternoonRunRepository.entityType,
      entityId: '${member.id}:afternoon:$today',
    );

    DriverMorningRun? morning;
    if (morningRecord != null) {
      morning = DriverMorningRun.fromJson(morningRecord.payload);
      if (morning.membershipId != member.id ||
          morning.routeId != assignment.routeId ||
          morning.serviceDate != today) {
        throw StateError(
          'Today\'s morning route record does not belong to the active Driver assignment.',
        );
      }
    }

    DriverAfternoonRun? afternoon;
    if (afternoonRecord != null) {
      afternoon = DriverAfternoonRun.fromJson(afternoonRecord.payload);
      if (afternoon.membershipId != member.id ||
          afternoon.routeId != assignment.routeId ||
          afternoon.serviceDate != today) {
        throw StateError(
          'Today\'s afternoon route record does not belong to the active Driver assignment.',
        );
      }
    }

    final plan = await _routeManagementRepository.loadPlanForRoute(route.id);
    final configuredStops = plan.activeStops;
    if (configuredStops.length != route.stops) {
      throw StateError(
        'The configured stop count does not match Transport Control.',
      );
    }

    final morningViews = morning == null
        ? _plannedMorningStops(route.id, configuredStops)
        : [for (final stop in morning.stops) _morningStop(stop)];
    final afternoonViews = afternoon == null
        ? _plannedAfternoonStops(route.id, configuredStops)
        : [
            for (final stop in afternoon.stops)
              _afternoonStop(stop, afternoon.status),
          ];

    return DriverRouteSnapshot(
      routeId: route.id,
      routeName: route.name,
      vehicle: route.vehicle,
      driverName: assignment.driverDisplayName,
      assistantName: route.assistant,
      serviceDate: today,
      totalAssignedRiders: route.riders,
      morningStops: List.unmodifiable(morningViews),
      afternoonStops: List.unmodifiable(afternoonViews),
    );
  }

  List<DriverRouteStopView> _plannedMorningStops(
    String routeId,
    List<dynamic> configuredStops,
  ) {
    final riderCounts = routeId == 'BUS-02'
        ? <String, int>{
            for (final stop in defaultBus02MorningStops())
              stop.id: stop.riders.length,
          }
        : const <String, int>{};
    return [
      for (final stop in configuredStops)
        DriverRouteStopView(
          id: stop.id as String,
          sequence: stop.sequence as int,
          name: stop.name as String,
          scheduledTime: stop.morningTime as String,
          assignedRiders: riderCounts[stop.id] ?? 0,
          state: DriverRouteStopState.pending,
          primaryCount: 0,
          secondaryCount: 0,
          primaryLabel: 'Boarded',
          secondaryLabel: 'Exceptions',
        ),
    ];
  }

  List<DriverRouteStopView> _plannedAfternoonStops(
    String routeId,
    List<dynamic> configuredStops,
  ) {
    final riderCounts = routeId == 'BUS-02'
        ? <String, int>{
            for (final stop in defaultBus02AfternoonStops())
              stop.id: stop.riders.length,
          }
        : const <String, int>{};
    final reversed = configuredStops.reversed.toList(growable: false);
    return [
      for (var index = 0; index < reversed.length; index++)
        DriverRouteStopView(
          id: reversed[index].id as String,
          sequence: index + 1,
          name: reversed[index].name as String,
          scheduledTime: reversed[index].afternoonTime as String,
          assignedRiders: riderCounts[reversed[index].id] ?? 0,
          state: DriverRouteStopState.pending,
          primaryCount: 0,
          secondaryCount: 0,
          primaryLabel: 'Released safely',
          secondaryLabel: 'Exceptions',
        ),
    ];
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

  DriverRouteStopView _afternoonStop(
    DriverAfternoonStop stop,
    DriverAfternoonRunStatus runStatus,
  ) {
    final boardedToday = stop.riders.where((rider) => rider.status.enteredBus).length;
    final routeHasDeparted = runStatus == DriverAfternoonRunStatus.inProgress ||
        runStatus == DriverAfternoonRunStatus.returnedSchool ||
        runStatus == DriverAfternoonRunStatus.completed;

    final state = stop.status == DriverAfternoonStopStatus.active
        ? DriverRouteStopState.active
        : stop.status == DriverAfternoonStopStatus.departed
            ? DriverRouteStopState.completed
            : routeHasDeparted && boardedToday == 0
                ? DriverRouteStopState.noService
                : DriverRouteStopState.pending;

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
    if (assignment.membershipId != member.id || !assignment.hasRoute) {
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
