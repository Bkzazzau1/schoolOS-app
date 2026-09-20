import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import 'driver_dashboard_demo_data.dart';

class DriverDashboardRepository {
  DriverDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const assignmentEntityType = 'driver_transport_assignment';
  static const morningRunEntityType = 'driver_morning_run';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;

  Future<DriverDashboardSnapshot> load() async {
    final membership = _requireDriver();
    final assignment = await _loadAssignment(membership);
    final transport = await _transportRepository.load();

    SchoolTransportRoute? assignedRoute;
    for (final route in transport.routes) {
      if (route.id == assignment.routeId) {
        assignedRoute = route;
        break;
      }
    }

    if (assignedRoute == null) {
      throw StateError(
        'Your assigned transport route is not available on this device yet.',
      );
    }

    final morningRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: morningRunEntityType,
      entityId: '${membership.id}:morning:${_todayKey()}',
    );

    if (morningRecord != null) {
      final run = DriverMorningRun.fromJson(morningRecord.payload);
      if (run.membershipId != membership.id || run.routeId != assignment.routeId) {
        throw StateError('Today\'s morning run is not valid for this Driver assignment.');
      }
      final checked = run.expectedRiders - run.pendingRiders;
      final summary =
          '${run.status.label} · ${run.boardedRiders} boarded · ${run.arrivedSchoolRiders} arrived';
      final displayRoute = assignedRoute.copyWith(
        morning: summary,
        status: switch (run.status) {
          DriverMorningRunStatus.notStarted => TransportRouteStatus.preparing,
          DriverMorningRunStatus.inProgress => TransportRouteStatus.onRoute,
          DriverMorningRunStatus.arrivedSchool => TransportRouteStatus.arrived,
          DriverMorningRunStatus.completed => TransportRouteStatus.arrived,
        },
      );
      return DriverDashboardSnapshot(
        assignment: assignment,
        route: displayRoute,
        morningChecked: checked,
        morningExpected: run.expectedRiders,
        morningExceptions: run.exceptions,
        morningSummary: summary,
        vehicleCheckRequired: true,
        nextAction: _nextActionForRun(run, assignedRoute),
      );
    }

    final summary = 'Not started · 0/${assignedRoute.riders} checked';
    final displayRoute = assignedRoute.copyWith(
      morning: summary,
      status: assignedRoute.isAvailable
          ? TransportRouteStatus.preparing
          : TransportRouteStatus.maintenance,
    );
    return DriverDashboardSnapshot(
      assignment: assignment,
      route: displayRoute,
      morningChecked: 0,
      morningExpected: assignedRoute.riders,
      morningExceptions: 0,
      morningSummary: summary,
      vehicleCheckRequired: true,
      nextAction: _nextActionFor(displayRoute),
    );
  }

  SchoolMembership _requireDriver() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.driver) {
      throw StateError('This workspace is available only to a Driver membership.');
    }
    return membership;
  }

  Future<DriverTransportAssignment> _loadAssignment(
    SchoolMembership membership,
  ) async {
    var record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: assignmentEntityType,
      entityId: membership.id,
    );

    if (record == null) {
      final seeded = DriverTransportAssignment(
        membershipId: membership.id,
        routeId: defaultDriverAssignment.routeId,
        driverDisplayName: defaultDriverAssignment.driverDisplayName,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentEntityType,
        entityId: membership.id,
        payload: seeded.toJson(),
      );
      record = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentEntityType,
        entityId: membership.id,
      );
    }

    if (record == null) {
      throw StateError('Driver assignment could not be loaded.');
    }

    final assignment = DriverTransportAssignment.fromJson(record.payload);
    if (assignment.membershipId != membership.id ||
        assignment.routeId.trim().isEmpty) {
      throw StateError('Driver assignment is not valid for this membership.');
    }
    return assignment;
  }

  String _nextActionForRun(
    DriverMorningRun run,
    SchoolTransportRoute route,
  ) {
    if (!route.isAvailable && run.status == DriverMorningRunStatus.notStarted) {
      return 'Vehicle unavailable — wait for transport clearance.';
    }
    return switch (run.status) {
      DriverMorningRunStatus.notStarted =>
        'Start the morning run when the vehicle and manifest are ready.',
      DriverMorningRunStatus.inProgress => run.activeStop != null
          ? 'Resolve riders at ${run.activeStop!.name} before departure.'
          : run.nextPendingStop != null
              ? 'Proceed to ${run.nextPendingStop!.name} and open the stop on arrival.'
              : 'All pickup stops are closed. Confirm arrival at school.',
      DriverMorningRunStatus.arrivedSchool =>
        'School arrival recorded. Complete the morning run after reconciliation.',
      DriverMorningRunStatus.completed =>
        'Morning service complete. Prepare the afternoon rider manifest.',
    };
  }

  String _nextActionFor(SchoolTransportRoute route) {
    if (!route.isAvailable) {
      return 'Vehicle unavailable — wait for transport clearance.';
    }
    return switch (route.status) {
      TransportRouteStatus.preparing => 'Open Morning Run to begin today\'s pickup workflow.',
      TransportRouteStatus.onRoute => 'Continue the active route and reconcile riders.',
      TransportRouteStatus.arrived => 'Prepare the afternoon rider manifest before dismissal.',
      TransportRouteStatus.maintenance =>
        'Vehicle unavailable — wait for transport clearance.',
    };
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
