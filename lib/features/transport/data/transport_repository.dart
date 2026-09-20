import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../driver/data/driver_dashboard_demo_data.dart';
import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_dashboard_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';
import '../domain/transport_control_models.dart';
import '../domain/transport_driver_assignment_models.dart';
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
  static const _assignmentEventEntityType = 'transport_assignment_event';
  static const _morningRunEntityType = 'driver_morning_run';
  static const _afternoonRunEntityType = 'driver_afternoon_run';
  static const _incidentEntityType = 'driver_transport_incident';
  static const _vehicleDefectEntityType = 'driver_vehicle_defect';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TransportPermissions permissionsFor(SchoolMembership membership) {
    final management = const {
      SchoolRole.proprietor,
      SchoolRole.administrator,
      SchoolRole.principal,
    }.contains(membership.role);
    return TransportPermissions(
      canReviewRoutes: membership.role == SchoolRole.proprietor,
      canViewOperationsControl: management,
      canManageDriverAssignments: const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
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
      if (!assignment.hasRoute || assignment.membershipId.trim().isEmpty) {
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

  Future<TransportDriverAssignmentsSnapshot> loadDriverAssignments() async {
    final viewer = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(viewer);
    if (!permissions.canViewOperationsControl) {
      throw StateError(
        'Driver assignments require a school management membership.',
      );
    }

    final transport = await load();
    await _ensureDemoAssignmentIfNeeded(viewer);

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: viewer.schoolId,
      entityType: _assignmentEntityType,
    );
    final assignments = <DriverTransportAssignment>[
      for (final record in assignmentRecords)
        DriverTransportAssignment.fromJson(record.payload),
    ];
    final assignmentByMembership = <String, DriverTransportAssignment>{
      for (final assignment in assignments)
        if (assignment.membershipId.trim().isNotEmpty)
          assignment.membershipId: assignment,
    };
    final activeAssignmentsByRoute = <String, List<DriverTransportAssignment>>{};
    for (final assignment in assignments) {
      if (!assignment.hasRoute) continue;
      activeAssignmentsByRoute
          .putIfAbsent(assignment.routeId, () => <DriverTransportAssignment>[])
          .add(assignment);
    }

    final routeById = <String, SchoolTransportRoute>{
      for (final route in transport.routes) route.id: route,
    };

    final directoryRecords = await _localDatabase.getLocalRecords(
      tenantId: viewer.schoolId,
      entityType: AdministratorStaffRepository.directoryEntityType,
    );
    final peopleById = <String, AdministratorStaffRecord>{
      for (final record in directoryRecords)
        record.entityId: AdministratorStaffRecord.fromJson(record.payload),
    };
    final profileRecords = await _localDatabase.getLocalRecords(
      tenantId: viewer.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );

    final drivers = <TransportDriverRosterEntry>[];
    final representedMemberships = <String>{};
    for (final record in profileRecords) {
      final profile = StaffProfile.fromJson(record.payload);
      if (profile.systemRole != 'driver') continue;
      final person = peopleById[profile.staffId];
      final membershipId = profile.linkedMembershipId.trim();
      if (membershipId.isNotEmpty) representedMemberships.add(membershipId);
      final assignment = membershipId.isEmpty
          ? null
          : assignmentByMembership[membershipId];
      final assigned = assignment?.hasRoute == true;
      final route = assigned ? routeById[assignment!.routeId] : null;
      final conflict = assigned &&
          (activeAssignmentsByRoute[assignment!.routeId]?.length ?? 0) > 1;

      drivers.add(
        TransportDriverRosterEntry(
          staffId: profile.staffId,
          membershipId: membershipId,
          name: person?.name.trim().isNotEmpty == true
              ? person!.name
              : profile.onboardingEmail.trim().isNotEmpty
                  ? profile.onboardingEmail
                  : 'Approved driver',
          jobTitle: person?.role ?? 'Driver',
          workArea: person?.section ?? '',
          accountLinked: membershipId.isNotEmpty,
          onboardingStatus: profile.onboardingStatus.name,
          routeId: assigned ? assignment!.routeId : '',
          routeName: route?.name ?? '',
          vehicle: route?.vehicle ?? '',
          assignmentActive: assigned,
          isDemoMembership: false,
          routeConflict: conflict,
        ),
      );
    }

    for (final membership in _schoolSession.memberships) {
      if (membership.schoolId != viewer.schoolId ||
          membership.role != SchoolRole.driver ||
          representedMemberships.contains(membership.id)) {
        continue;
      }
      representedMemberships.add(membership.id);
      final assignment = assignmentByMembership[membership.id];
      final assigned = assignment?.hasRoute == true;
      final route = assigned ? routeById[assignment!.routeId] : null;
      final conflict = assigned &&
          (activeAssignmentsByRoute[assignment!.routeId]?.length ?? 0) > 1;
      drivers.add(
        TransportDriverRosterEntry(
          staffId: assignment?.staffId ?? '',
          membershipId: membership.id,
          name: assignment?.driverDisplayName.trim().isNotEmpty == true
              ? assignment!.driverDisplayName
              : 'Driver account',
          jobTitle: 'Driver',
          workArea: '',
          accountLinked: true,
          onboardingStatus: 'linked',
          routeId: assigned ? assignment!.routeId : '',
          routeName: route?.name ?? '',
          vehicle: route?.vehicle ?? '',
          assignmentActive: assigned,
          isDemoMembership: membership.id == 'membership-driver-001',
          routeConflict: conflict,
        ),
      );
    }

    for (final assignment in assignments) {
      if (assignment.membershipId.trim().isEmpty ||
          representedMemberships.contains(assignment.membershipId)) {
        continue;
      }
      representedMemberships.add(assignment.membershipId);
      final assigned = assignment.hasRoute;
      final route = assigned ? routeById[assignment.routeId] : null;
      final conflict = assigned &&
          (activeAssignmentsByRoute[assignment.routeId]?.length ?? 0) > 1;
      drivers.add(
        TransportDriverRosterEntry(
          staffId: assignment.staffId,
          membershipId: assignment.membershipId,
          name: assignment.driverDisplayName.trim().isEmpty
              ? 'Linked driver account'
              : assignment.driverDisplayName,
          jobTitle: 'Driver',
          workArea: '',
          accountLinked: true,
          onboardingStatus: 'linked',
          routeId: assigned ? assignment.routeId : '',
          routeName: route?.name ?? '',
          vehicle: route?.vehicle ?? '',
          assignmentActive: assigned,
          isDemoMembership: false,
          routeConflict: conflict,
        ),
      );
    }

    drivers.sort((a, b) {
      if (a.routeConflict != b.routeConflict) return a.routeConflict ? -1 : 1;
      if (a.assigned != b.assigned) return a.assigned ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    final routes = <TransportAssignableRoute>[];
    for (final route in transport.routes) {
      final active = activeAssignmentsByRoute[route.id] ?? const [];
      routes.add(
        TransportAssignableRoute(
          routeId: route.id,
          routeName: route.name,
          vehicle: route.vehicle,
          available: route.isAvailable,
          assignedMembershipId:
              active.length == 1 ? active.single.membershipId : '',
          assignedDriverName:
              active.length == 1 ? active.single.driverDisplayName : '',
          activeAssignmentCount: active.length,
        ),
      );
    }

    return TransportDriverAssignmentsSnapshot(
      drivers: List.unmodifiable(drivers),
      routes: List.unmodifiable(routes),
      canManageAssignments: permissions.canManageDriverAssignments,
    );
  }

  Future<TransportActionResult> assignDriver({
    required String membershipId,
    required String routeId,
  }) async {
    final manager = _requireAssignmentManager();
    final normalizedMembershipId = membershipId.trim();
    final normalizedRouteId = routeId.trim();
    if (normalizedMembershipId.isEmpty || normalizedRouteId.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Choose a linked Driver and a transport route.',
      );
    }

    final snapshot = await loadDriverAssignments();
    TransportDriverRosterEntry? driver;
    for (final item in snapshot.drivers) {
      if (item.membershipId == normalizedMembershipId) {
        driver = item;
        break;
      }
    }
    if (driver == null || !driver.canReceiveOperationalAssignment) {
      return const TransportActionResult(
        success: false,
        message: 'This Driver does not yet have an activated SchoolOS membership.',
      );
    }

    TransportAssignableRoute? route;
    for (final item in snapshot.routes) {
      if (item.routeId == normalizedRouteId) {
        route = item;
        break;
      }
    }
    if (route == null) {
      return const TransportActionResult(
        success: false,
        message: 'The selected transport route was not found.',
      );
    }
    if (route.hasConflict) {
      return const TransportActionResult(
        success: false,
        message: 'Resolve the existing duplicate assignment on this route first.',
      );
    }
    if (route.alreadyAssigned &&
        route.assignedMembershipId != normalizedMembershipId) {
      return TransportActionResult(
        success: false,
        message: '${route.routeName} is already assigned to ${route.assignedDriverName}.',
      );
    }

    final currentRecord = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
    );
    final current = currentRecord == null
        ? null
        : DriverTransportAssignment.fromJson(currentRecord.payload);
    if (current?.hasRoute == true && current!.routeId == normalizedRouteId) {
      return const TransportActionResult(
        success: true,
        message: 'This Driver is already assigned to the selected route.',
      );
    }

    if (await _driverHasActiveCustodyRun(manager.schoolId, normalizedMembershipId)) {
      return const TransportActionResult(
        success: false,
        message: 'This Driver has an active transport run. Finish the run before changing the route assignment.',
      );
    }
    if (await _routeHasActiveCustodyRun(
      manager.schoolId,
      normalizedRouteId,
      exceptMembershipId: normalizedMembershipId,
    )) {
      return const TransportActionResult(
        success: false,
        message: 'This route has an active transport run under another Driver.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final assignment = DriverTransportAssignment(
      membershipId: normalizedMembershipId,
      routeId: normalizedRouteId,
      driverDisplayName: driver.name,
      staffId: driver.staffId,
      active: true,
      assignedAt: now,
      assignedByMembershipId: manager.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
      payload: assignment.toJson(),
      serverVersion: currentRecord?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
      operation: currentRecord == null ? SyncOperation.create : SyncOperation.update,
      payload: assignment.toJson(),
      baseVersion: currentRecord?.serverVersion,
    );
    await _appendAssignmentEvent(
      manager: manager,
      driverMembershipId: normalizedMembershipId,
      driverName: driver.name,
      staffId: driver.staffId,
      previousRouteId: current?.hasRoute == true ? current!.routeId : '',
      newRouteId: normalizedRouteId,
      eventType: 'driver_route_assigned',
      at: now,
    );

    return TransportActionResult(
      success: true,
      message: '${driver.name} assigned to ${route.routeName}. Saved offline and queued for sync.',
    );
  }

  Future<TransportActionResult> unassignDriver(String membershipId) async {
    final manager = _requireAssignmentManager();
    final normalizedMembershipId = membershipId.trim();
    if (normalizedMembershipId.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Driver membership is required.',
      );
    }
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: true,
        message: 'This Driver has no active route assignment.',
      );
    }
    final current = DriverTransportAssignment.fromJson(record.payload);
    if (!current.hasRoute) {
      return const TransportActionResult(
        success: true,
        message: 'This Driver has no active route assignment.',
      );
    }
    if (await _driverHasActiveCustodyRun(manager.schoolId, normalizedMembershipId)) {
      return const TransportActionResult(
        success: false,
        message: 'This Driver has an active transport run. Finish the run before unassigning the Driver.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = current.copyWith(
      active: false,
      assignedAt: now,
      assignedByMembershipId: manager.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
      payload: updated.toJson(),
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: _assignmentEntityType,
      entityId: normalizedMembershipId,
      operation: SyncOperation.update,
      payload: updated.toJson(),
      baseVersion: record.serverVersion,
    );
    await _appendAssignmentEvent(
      manager: manager,
      driverMembershipId: normalizedMembershipId,
      driverName: current.driverDisplayName,
      staffId: current.staffId,
      previousRouteId: current.routeId,
      newRouteId: '',
      eventType: 'driver_route_unassigned',
      at: now,
    );

    return TransportActionResult(
      success: true,
      message: '${current.driverDisplayName} is now unassigned. Saved offline and queued for sync.',
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

  SchoolMembership _requireAssignmentManager() {
    final member = _schoolSession.requireActiveMembership();
    if (!permissionsFor(member).canManageDriverAssignments) {
      throw StateError(
        'Only the Proprietor or Administrator can change Driver route assignments.',
      );
    }
    return member;
  }

  Future<void> _ensureDemoAssignmentIfNeeded(SchoolMembership viewer) async {
    final demoMembership = _schoolSession.memberships.where(
      (membership) =>
          membership.schoolId == viewer.schoolId &&
          membership.id == 'membership-driver-001' &&
          membership.role == SchoolRole.driver,
    );
    if (demoMembership.isEmpty) return;

    final existing = await _localDatabase.getLocalRecord(
      tenantId: viewer.schoolId,
      entityType: _assignmentEntityType,
      entityId: 'membership-driver-001',
    );
    if (existing != null) return;

    final seeded = DriverTransportAssignment(
      membershipId: 'membership-driver-001',
      routeId: defaultDriverAssignment.routeId,
      driverDisplayName: defaultDriverAssignment.driverDisplayName,
      active: true,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: viewer.schoolId,
      entityType: _assignmentEntityType,
      entityId: seeded.membershipId,
      payload: seeded.toJson(),
      isDirty: false,
    );
  }

  Future<bool> _driverHasActiveCustodyRun(
    String tenantId,
    String membershipId,
  ) async {
    final today = _todayKey();
    final morning = await _localDatabase.getLocalRecord(
      tenantId: tenantId,
      entityType: _morningRunEntityType,
      entityId: '$membershipId:morning:$today',
    );
    if (morning != null) {
      final run = DriverMorningRun.fromJson(morning.payload);
      if (run.status == DriverMorningRunStatus.inProgress ||
          run.status == DriverMorningRunStatus.arrivedSchool) {
        return true;
      }
    }
    final afternoon = await _localDatabase.getLocalRecord(
      tenantId: tenantId,
      entityType: _afternoonRunEntityType,
      entityId: '$membershipId:afternoon:$today',
    );
    if (afternoon != null) {
      final run = DriverAfternoonRun.fromJson(afternoon.payload);
      if (run.status == DriverAfternoonRunStatus.boarding ||
          run.status == DriverAfternoonRunStatus.inProgress ||
          run.status == DriverAfternoonRunStatus.returnedSchool) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _routeHasActiveCustodyRun(
    String tenantId,
    String routeId, {
    required String exceptMembershipId,
  }) async {
    final today = _todayKey();
    final morningRecords = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: _morningRunEntityType,
    );
    for (final record in morningRecords) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.serviceDate != today ||
          run.routeId != routeId ||
          run.membershipId == exceptMembershipId) {
        continue;
      }
      if (run.status == DriverMorningRunStatus.inProgress ||
          run.status == DriverMorningRunStatus.arrivedSchool) {
        return true;
      }
    }
    final afternoonRecords = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: _afternoonRunEntityType,
    );
    for (final record in afternoonRecords) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.serviceDate != today ||
          run.routeId != routeId ||
          run.membershipId == exceptMembershipId) {
        continue;
      }
      if (run.status == DriverAfternoonRunStatus.boarding ||
          run.status == DriverAfternoonRunStatus.inProgress ||
          run.status == DriverAfternoonRunStatus.returnedSchool) {
        return true;
      }
    }
    return false;
  }

  Future<void> _appendAssignmentEvent({
    required SchoolMembership manager,
    required String driverMembershipId,
    required String driverName,
    required String staffId,
    required String previousRouteId,
    required String newRouteId,
    required String eventType,
    required String at,
  }) async {
    final eventId =
        '$driverMembershipId:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': eventId,
      'eventType': eventType,
      'driverMembershipId': driverMembershipId,
      'driverName': driverName,
      'staffId': staffId,
      'previousRouteId': previousRouteId,
      'newRouteId': newRouteId,
      'at': at,
      'actorMembershipId': manager.id,
      'actorRole': manager.role.name,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: _assignmentEventEntityType,
      entityId: eventId,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: _assignmentEventEntityType,
      entityId: eventId,
      operation: SyncOperation.create,
      payload: payload,
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
