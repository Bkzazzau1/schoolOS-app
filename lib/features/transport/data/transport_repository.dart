import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_dashboard_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';
import '../domain/transport_control_models.dart';
import '../domain/transport_models.dart';
import 'transport_demo_data.dart';

class TransportSnapshot {
  const TransportSnapshot({required this.routes, required this.permissions});

  final List<SchoolTransportRoute> routes;
  final TransportPermissions permissions;
}

class TransportActionResult {
  const TransportActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class TransportRepository {
  TransportRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_transport_route';
  static const _assignmentEntityType = 'driver_transport_assignment';
  static const _morningRunEntityType = 'driver_morning_run';
  static const _afternoonRunEntityType = 'driver_afternoon_run';
  static const _incidentEntityType = 'driver_transport_incident';
  static const _vehicleDefectEntityType = 'driver_vehicle_defect';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TransportPermissions permissionsFor(SchoolMembership membership) {
    return TransportPermissions(
      canReviewRoutes: membership.role == SchoolRole.proprietor,
      canViewOperationsControl: const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
        SchoolRole.principal,
      }.contains(membership.role),
    );
  }

  Future<TransportSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final route in transportWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: route.id,
          payload: route.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final routes = records
        .map((record) => SchoolTransportRoute.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return TransportSnapshot(
      routes: routes,
      permissions: permissionsFor(membership),
    );
  }

  Future<TransportControlSnapshot> loadControlOverview() async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canViewOperationsControl) {
      throw StateError(
        'Transport Operations Control requires a school management membership.',
      );
    }

    final transport = await load();
    final today = _todayKey();

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentEntityType,
    );
    final morningRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _morningRunEntityType,
    );
    final afternoonRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _afternoonRunEntityType,
    );
    final incidentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _incidentEntityType,
    );
    final defectRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _vehicleDefectEntityType,
    );

    final assignmentsByRoute = <String, DriverTransportAssignment>{};
    for (final record in assignmentRecords) {
      final assignment = DriverTransportAssignment.fromJson(record.payload);
      if (assignment.routeId.trim().isEmpty ||
          assignment.membershipId.trim().isEmpty) {
        continue;
      }
      assignmentsByRoute.putIfAbsent(assignment.routeId, () => assignment);
    }

    final morningsByRoute = <String, DriverMorningRun>{};
    for (final record in morningRecords) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.serviceDate != today || run.routeId.trim().isEmpty) continue;
      morningsByRoute.putIfAbsent(run.routeId, () => run);
    }

    final afternoonsByRoute = <String, DriverAfternoonRun>{};
    for (final record in afternoonRecords) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.serviceDate != today || run.routeId.trim().isEmpty) continue;
      afternoonsByRoute.putIfAbsent(run.routeId, () => run);
    }

    final incidentCounts = <String, int>{};
    final urgentIncidentCounts = <String, int>{};
    for (final record in incidentRecords) {
      final payload = record.payload;
      final routeId = payload['routeId'] as String? ?? '';
      final serviceDate = payload['serviceDate'] as String? ?? '';
      if (routeId.isEmpty || serviceDate != today) continue;
      incidentCounts[routeId] = (incidentCounts[routeId] ?? 0) + 1;
      final status = payload['status'] as String? ?? '';
      final urgent = payload['requiresImmediateEscalation'] as bool? ?? false;
      if (urgent && status != 'resolved') {
        urgentIncidentCounts[routeId] =
            (urgentIncidentCounts[routeId] ?? 0) + 1;
      }
    }

    final defectCounts = <String, int>{};
    final blockingDefectCounts = <String, int>{};
    for (final record in defectRecords) {
      final payload = record.payload;
      final routeId = payload['routeId'] as String? ?? '';
      final serviceDate = payload['serviceDate'] as String? ?? '';
      if (routeId.isEmpty || serviceDate != today) continue;
      defectCounts[routeId] = (defectCounts[routeId] ?? 0) + 1;

      final status = (payload['status'] as String? ?? '').toLowerCase();
      final closed = status == 'cleared' ||
          status == 'resolved' ||
          status == 'closed';
      final blocksTrip = payload['blocksTrip'] as bool? ?? false;
      if (blocksTrip && !closed) {
        blockingDefectCounts[routeId] =
            (blockingDefectCounts[routeId] ?? 0) + 1;
      }
    }

    final activities = <TransportControlRouteActivity>[];
    for (final route in transport.routes) {
      final morning = morningsByRoute[route.id];
      final afternoon = afternoonsByRoute[route.id];
      final assignment = assignmentsByRoute[route.id];
      final hasDriverActivity = morning != null ||
          afternoon != null ||
          (incidentCounts[route.id] ?? 0) > 0 ||
          (defectCounts[route.id] ?? 0) > 0;
      final driverName = assignment?.driverDisplayName.trim().isNotEmpty == true
          ? assignment!.driverDisplayName
          : morning?.driverName.trim().isNotEmpty == true
              ? morning!.driverName
              : afternoon?.driverName.trim().isNotEmpty == true
                  ? afternoon!.driverName
                  : route.driver;

      activities.add(
        TransportControlRouteActivity(
          routeId: route.id,
          routeName: route.name,
          vehicle: route.vehicle,
          driverName: driverName,
          driverMembershipId: assignment?.membershipId ??
              morning?.membershipId ??
              afternoon?.membershipId ??
              '',
          phase: _controlPhase(route, morning, afternoon, hasDriverActivity),
          morningSummary: _morningSummary(route, morning),
          afternoonSummary: _afternoonSummary(route, afternoon),
          expectedRiders:
              afternoon?.expectedRiders ?? morning?.expectedRiders ?? route.riders,
          currentlyOnBoard: _currentlyOnBoard(morning, afternoon),
          incidentCount: incidentCounts[route.id] ?? 0,
          urgentIncidentCount: urgentIncidentCounts[route.id] ?? 0,
          vehicleDefectCount: defectCounts[route.id] ?? 0,
          blockingVehicleDefectCount: blockingDefectCounts[route.id] ?? 0,
          hasDriverActivity: hasDriverActivity,
        ),
      );
    }

    return TransportControlSnapshot(
      serviceDate: today,
      routes: List.unmodifiable(activities),
    );
  }

  Future<TransportActionResult> toggleRouteReview(String routeId) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewRoutes) {
      return const TransportActionResult(
        success: false,
        message: 'This membership cannot review transport routes.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: routeId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: false,
        message: 'Transport route was not found for this school.',
      );
    }

    final current = SchoolTransportRoute.fromJson(record.payload);
    final updated = current.copyWith(reviewed: !current.reviewed);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    return TransportActionResult(
      success: true,
      message: updated.reviewed
          ? 'Route review saved offline.'
          : 'Route review reopened and queued for sync.',
    );
  }

  TransportControlPhase _controlPhase(
    SchoolTransportRoute route,
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
    bool hasDriverActivity,
  ) {
    if (!route.isAvailable) return TransportControlPhase.maintenance;

    if (afternoon != null) {
      return switch (afternoon.status) {
        DriverAfternoonRunStatus.inProgress =>
          TransportControlPhase.afternoonRoute,
        DriverAfternoonRunStatus.boarding =>
          TransportControlPhase.afternoonBoarding,
        DriverAfternoonRunStatus.returnedSchool =>
          TransportControlPhase.returnedSchool,
        DriverAfternoonRunStatus.completed => TransportControlPhase.completed,
        DriverAfternoonRunStatus.notStarted =>
          morning?.status == DriverMorningRunStatus.completed
              ? TransportControlPhase.atSchool
              : TransportControlPhase.preparing,
      };
    }

    if (morning != null) {
      return switch (morning.status) {
        DriverMorningRunStatus.inProgress => TransportControlPhase.morningRoute,
        DriverMorningRunStatus.arrivedSchool ||
        DriverMorningRunStatus.completed =>
          TransportControlPhase.atSchool,
        DriverMorningRunStatus.notStarted => TransportControlPhase.preparing,
      };
    }

    return hasDriverActivity
        ? TransportControlPhase.preparing
        : TransportControlPhase.baselineOnly;
  }

  int _currentlyOnBoard(
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
  ) {
    if (afternoon?.status == DriverAfternoonRunStatus.inProgress) {
      return afternoon!.stillOnBus;
    }
    if (morning?.status == DriverMorningRunStatus.inProgress) {
      return morning!.boardedRiders;
    }
    return 0;
  }

  String _morningSummary(
    SchoolTransportRoute route,
    DriverMorningRun? run,
  ) {
    if (run == null) {
      return 'No Driver Portal record today · baseline: ${route.morning}';
    }
    final checked = run.expectedRiders - run.pendingRiders;
    return '${run.status.label} · $checked/${run.expectedRiders} resolved · '
        '${run.arrivedSchoolRiders} arrived · ${run.exceptions} exceptions';
  }

  String _afternoonSummary(
    SchoolTransportRoute route,
    DriverAfternoonRun? run,
  ) {
    if (run == null) {
      return 'No Driver Portal record today · baseline: ${route.afternoon}';
    }
    return '${run.status.label} · ${run.boardedRiders} boarded · '
        '${run.safeDropCount} safely released · ${run.stillOnBus} onboard · '
        '${run.exceptions} exceptions';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
