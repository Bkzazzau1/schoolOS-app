import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_vehicle_check_models.dart';
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
  static const afternoonRunEntityType = 'driver_afternoon_run';
  static const vehicleCheckEntityType = 'driver_vehicle_check';

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

    final today = _todayKey();
    final morningRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: morningRunEntityType,
      entityId: '${membership.id}:morning:$today',
    );
    final afternoonRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: afternoonRunEntityType,
      entityId: '${membership.id}:afternoon:$today',
    );

    DriverMorningRun? morningRun;
    if (morningRecord != null) {
      morningRun = DriverMorningRun.fromJson(morningRecord.payload);
      _validateMorning(morningRun, membership, assignment);
    }

    DriverAfternoonRun? afternoonRun;
    if (afternoonRecord != null) {
      afternoonRun = DriverAfternoonRun.fromJson(afternoonRecord.payload);
      _validateAfternoon(afternoonRun, membership, assignment);
    }

    final morningExpected = morningRun?.expectedRiders ?? assignedRoute.riders;
    final morningChecked = morningRun == null
        ? 0
        : morningRun.expectedRiders - morningRun.pendingRiders;
    final morningExceptions = morningRun?.exceptions ?? 0;
    final morningSummary = morningRun == null
        ? 'Not started · 0/$morningExpected checked'
        : '${morningRun.status.label} · ${morningRun.boardedRiders} boarded · ${morningRun.arrivedSchoolRiders} arrived';

    final afternoonExpected = afternoonRun?.expectedRiders ?? assignedRoute.riders;
    final afternoonBoarded = afternoonRun?.boardedRiders ?? 0;
    final afternoonSafeReleased = afternoonRun?.safeDropCount ?? 0;
    final afternoonStillOnBus = afternoonRun?.stillOnBus ?? 0;
    final afternoonSummary = afternoonRun == null
        ? 'Not started · 0/$afternoonExpected boarded'
        : '${afternoonRun.status.label} · $afternoonBoarded boarded · $afternoonSafeReleased safely released';

    final routeStatus = _displayRouteStatus(
      assignedRoute,
      morningRun,
      afternoonRun,
    );
    final displayRoute = assignedRoute.copyWith(
      morning: morningSummary,
      afternoon: afternoonSummary,
      status: routeStatus,
    );

    final nextCheckPeriod = _nextVehicleCheckPeriod(morningRun, afternoonRun);
    DriverVehicleCheck? nextCheck;
    if (nextCheckPeriod != null) {
      final checkRecord = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: vehicleCheckEntityType,
        entityId:
            '${membership.id}:vehicle-check:$today:${nextCheckPeriod.name}',
      );
      if (checkRecord != null) {
        nextCheck = DriverVehicleCheck.fromJson(checkRecord.payload);
        if (nextCheck.membershipId != membership.id ||
            nextCheck.routeId != assignment.routeId ||
            nextCheck.period != nextCheckPeriod ||
            nextCheck.serviceDate != today) {
          throw StateError(
            'Today\'s vehicle check is not valid for this Driver assignment.',
          );
        }
      }
    }

    final vehicleCheckRequired = nextCheckPeriod != null &&
        nextCheck?.status != DriverVehicleCheckStatus.ready;
    final vehicleCheckSummary = nextCheckPeriod == null
        ? 'No pre-trip check currently pending'
        : '${nextCheckPeriod.label} · ${nextCheck?.status.label ?? DriverVehicleCheckStatus.notStarted.label}';

    final operationalNextAction = _nextAction(
      displayRoute,
      morningRun,
      afternoonRun,
    );
    final nextAction = vehicleCheckRequired && nextCheckPeriod != null
        ? _vehicleCheckAction(nextCheckPeriod, nextCheck)
        : operationalNextAction;

    return DriverDashboardSnapshot(
      assignment: assignment,
      route: displayRoute,
      morningChecked: morningChecked,
      morningExpected: morningExpected,
      morningExceptions: morningExceptions,
      morningSummary: morningSummary,
      afternoonExpected: afternoonExpected,
      afternoonBoarded: afternoonBoarded,
      afternoonSafeReleased: afternoonSafeReleased,
      afternoonStillOnBus: afternoonStillOnBus,
      afternoonSummary: afternoonSummary,
      vehicleCheckRequired: vehicleCheckRequired,
      vehicleCheckSummary: vehicleCheckSummary,
      nextAction: nextAction,
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

  void _validateMorning(
    DriverMorningRun run,
    SchoolMembership member,
    DriverTransportAssignment assignment,
  ) {
    if (run.membershipId != member.id || run.routeId != assignment.routeId) {
      throw StateError(
        'Today\'s morning run is not valid for this Driver assignment.',
      );
    }
  }

  void _validateAfternoon(
    DriverAfternoonRun run,
    SchoolMembership member,
    DriverTransportAssignment assignment,
  ) {
    if (run.membershipId != member.id || run.routeId != assignment.routeId) {
      throw StateError(
        'Today\'s afternoon run is not valid for this Driver assignment.',
      );
    }
  }

  DriverVehicleCheckPeriod? _nextVehicleCheckPeriod(
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
  ) {
    if (morning == null || morning.status == DriverMorningRunStatus.notStarted) {
      return DriverVehicleCheckPeriod.morning;
    }
    if (morning.status != DriverMorningRunStatus.completed) {
      return null;
    }
    if (afternoon == null ||
        afternoon.status == DriverAfternoonRunStatus.notStarted) {
      return DriverVehicleCheckPeriod.afternoon;
    }
    return null;
  }

  String _vehicleCheckAction(
    DriverVehicleCheckPeriod period,
    DriverVehicleCheck? check,
  ) {
    if (check?.status == DriverVehicleCheckStatus.blocked) {
      return '${period.label} vehicle check is blocked by ${check!.blockingFailureCount} safety defect${check.blockingFailureCount == 1 ? '' : 's'}.';
    }
    if (check?.status == DriverVehicleCheckStatus.inProgress) {
      return 'Finish and submit the ${period.label.toLowerCase()} vehicle check before departure.';
    }
    return 'Complete the ${period.label.toLowerCase()} vehicle check before starting this transport run.';
  }

  TransportRouteStatus _displayRouteStatus(
    SchoolTransportRoute route,
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
  ) {
    if (!route.isAvailable) return TransportRouteStatus.maintenance;

    if (morning != null && morning.status != DriverMorningRunStatus.completed) {
      return switch (morning.status) {
        DriverMorningRunStatus.notStarted => TransportRouteStatus.preparing,
        DriverMorningRunStatus.inProgress => TransportRouteStatus.onRoute,
        DriverMorningRunStatus.arrivedSchool => TransportRouteStatus.arrived,
        DriverMorningRunStatus.completed => TransportRouteStatus.arrived,
      };
    }

    if (afternoon != null) {
      return switch (afternoon.status) {
        DriverAfternoonRunStatus.notStarted => TransportRouteStatus.preparing,
        DriverAfternoonRunStatus.boarding => TransportRouteStatus.preparing,
        DriverAfternoonRunStatus.inProgress => TransportRouteStatus.onRoute,
        DriverAfternoonRunStatus.returnedSchool => TransportRouteStatus.arrived,
        DriverAfternoonRunStatus.completed => TransportRouteStatus.arrived,
      };
    }

    return morning?.status == DriverMorningRunStatus.completed
        ? TransportRouteStatus.arrived
        : TransportRouteStatus.preparing;
  }

  String _nextAction(
    SchoolTransportRoute route,
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
  ) {
    if (!route.isAvailable) {
      return 'Vehicle unavailable — wait for transport clearance.';
    }

    if (morning != null && morning.status != DriverMorningRunStatus.completed) {
      return _nextActionForMorning(morning);
    }

    if (afternoon != null) {
      return _nextActionForAfternoon(afternoon);
    }

    if (morning?.status == DriverMorningRunStatus.completed) {
      return 'Morning service complete. Open Afternoon Run before dismissal.';
    }

    return 'Open Morning Run to begin today\'s pickup workflow.';
  }

  String _nextActionForMorning(DriverMorningRun run) {
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

  String _nextActionForAfternoon(DriverAfternoonRun run) {
    return switch (run.status) {
      DriverAfternoonRunStatus.notStarted =>
        'Open afternoon boarding and reconcile the dismissal manifest.',
      DriverAfternoonRunStatus.boarding => run.unresolvedBoarding > 0
          ? '${run.unresolvedBoarding} afternoon riders still need a boarding status.'
          : 'Boarding reconciled. Confirm the physical count and depart school.',
      DriverAfternoonRunStatus.inProgress => run.activeStop != null
          ? 'Complete safe drop-off at ${run.activeStop!.name}.'
          : run.nextPendingStop != null
              ? 'Proceed to ${run.nextPendingStop!.name} for the next drop-off.'
              : run.stillOnBus > 0
                  ? '${run.stillOnBus} students remain onboard and must return safely to school.'
                  : 'All afternoon riders are safely resolved. Complete the run.',
      DriverAfternoonRunStatus.returnedSchool =>
        'Safe return to school recorded. Complete the afternoon run.',
      DriverAfternoonRunStatus.completed =>
        'Afternoon service complete. No active transport run remains.',
    };
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
