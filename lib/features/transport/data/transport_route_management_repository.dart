import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_dashboard_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';
import '../domain/transport_route_management_models.dart';
import '../domain/transport_models.dart';
import 'transport_demo_data.dart';
import 'transport_route_plan_demo_data.dart';

class TransportRouteManagementRepository {
  TransportRouteManagementRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const routeEntityType = 'school_transport_route';
  static const planEntityType = 'transport_route_plan';
  static const eventEntityType = 'transport_route_event';
  static const assignmentEntityType = 'driver_transport_assignment';
  static const morningRunEntityType = 'driver_morning_run';
  static const afternoonRunEntityType = 'driver_afternoon_run';
  static const vehicleCheckEntityType = 'driver_vehicle_check';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  bool _canView(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
        SchoolRole.principal,
      }.contains(role);

  bool _canManage(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
      }.contains(role);

  Future<TransportRouteManagementSnapshot> load() async {
    final member = _schoolSession.requireActiveMembership();
    if (!_canView(member.role)) {
      throw StateError(
        'Routes & Stops Management requires a school management membership.',
      );
    }

    final routes = await _loadRoutes(member.schoolId);
    final assignments = await _loadAssignments(member.schoolId);
    final entries = <TransportRouteManagementEntry>[];

    for (final route in routes) {
      final plan = await loadPlanForRoute(route.id);
      final assignment = assignments.where(
        (item) => item.hasRoute && item.routeId == route.id,
      ).toList(growable: false);
      final locked = await _routeLockedToday(member.schoolId, route.id);
      entries.add(
        TransportRouteManagementEntry(
          route: route,
          plan: plan,
          assignedDriverName:
              assignment.length == 1 ? assignment.single.driverDisplayName : '',
          assignedMembershipId:
              assignment.length == 1 ? assignment.single.membershipId : '',
          lockedForToday: locked,
          lockReason: locked
              ? 'Today’s Driver manifest or vehicle check already exists for this route.'
              : '',
        ),
      );
    }

    return TransportRouteManagementSnapshot(
      routes: List.unmodifiable(entries),
      canManage: _canManage(member.role),
    );
  }

  /// Available to Driver repositories as a read-only source of the configured
  /// stop plan. It does not grant route-management authority.
  Future<TransportRoutePlan> loadPlanForRoute(String routeId) async {
    final member = _schoolSession.requireActiveMembership();
    final normalized = routeId.trim();
    if (normalized.isEmpty) throw ArgumentError('Route id is required.');

    var record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: planEntityType,
      entityId: normalized,
    );
    if (record == null) {
      final seed = seededTransportRoutePlan(normalized) ??
          TransportRoutePlan(routeId: normalized, stops: const []);
      await _localDatabase.upsertLocalRecord(
        tenantId: member.schoolId,
        entityType: planEntityType,
        entityId: normalized,
        payload: seed.toJson(),
        isDirty: false,
      );
      record = await _localDatabase.getLocalRecord(
        tenantId: member.schoolId,
        entityType: planEntityType,
        entityId: normalized,
      );
    }
    if (record == null) {
      throw StateError('Route stop plan could not be loaded.');
    }
    final plan = TransportRoutePlan.fromJson(record.payload);
    if (plan.routeId != normalized) {
      throw StateError('Route stop plan does not match the requested route.');
    }
    return plan;
  }

  Future<TransportActionResult> createRoute({
    required String name,
    required String vehicle,
    required String assistant,
    String note = '',
  }) async {
    final manager = _requireManager();
    final cleanName = name.trim();
    final cleanVehicle = vehicle.trim();
    final cleanAssistant = assistant.trim();
    if (cleanName.isEmpty || cleanVehicle.isEmpty || cleanAssistant.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Enter the route name, assigned vehicle and assistant.',
      );
    }

    final routes = await _loadRoutes(manager.schoolId);
    if (routes.any(
      (route) => route.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      return const TransportActionResult(
        success: false,
        message: 'A transport route with this name already exists.',
      );
    }
    final id = _nextRouteId(routes);
    final route = SchoolTransportRoute(
      id: id,
      name: cleanName,
      vehicle: cleanVehicle,
      driver: 'Unassigned',
      assistant: cleanAssistant,
      riders: 0,
      stops: 0,
      morning: 'Not configured',
      afternoon: 'Not configured',
      status: TransportRouteStatus.preparing,
      note: note.trim().isEmpty
          ? 'New route awaiting stop and rider configuration.'
          : note.trim(),
    );
    await _saveRoute(manager, route, SyncOperation.create);
    final plan = TransportRoutePlan(
      routeId: id,
      stops: const [],
      updatedAt: _now(),
      updatedByMembershipId: manager.id,
    );
    await _savePlan(manager, plan, SyncOperation.create);
    await _appendEvent(
      manager: manager,
      routeId: id,
      eventType: 'route_created',
      details: {
        'name': cleanName,
        'vehicle': cleanVehicle,
        'assistant': cleanAssistant,
      },
    );
    return TransportActionResult(
      success: true,
      message: '$id · $cleanName created offline and queued for sync.',
    );
  }

  Future<TransportActionResult> updateRoute({
    required String routeId,
    required String name,
    required String vehicle,
    required String assistant,
    required String note,
  }) async {
    final manager = _requireManager();
    final locked = await _routeLockedToday(manager.schoolId, routeId);
    if (locked) return _lockedResult();

    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: routeId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: false,
        message: 'Transport route was not found.',
      );
    }
    final cleanName = name.trim();
    final cleanVehicle = vehicle.trim();
    final cleanAssistant = assistant.trim();
    if (cleanName.isEmpty || cleanVehicle.isEmpty || cleanAssistant.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Route name, vehicle and assistant cannot be empty.',
      );
    }

    final routes = await _loadRoutes(manager.schoolId);
    if (routes.any(
      (route) =>
          route.id != routeId &&
          route.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      return const TransportActionResult(
        success: false,
        message: 'Another route already uses this name.',
      );
    }

    final current = SchoolTransportRoute.fromJson(record.payload);
    final updated = current.copyWith(
      name: cleanName,
      vehicle: cleanVehicle,
      assistant: cleanAssistant,
      note: note.trim(),
    );
    await _saveRoute(manager, updated, SyncOperation.update, existing: record);
    await _appendEvent(
      manager: manager,
      routeId: routeId,
      eventType: 'route_details_updated',
      details: {
        'name': cleanName,
        'vehicle': cleanVehicle,
        'assistant': cleanAssistant,
      },
    );
    return const TransportActionResult(
      success: true,
      message: 'Route details saved offline and queued for sync.',
    );
  }

  Future<TransportActionResult> addStop({
    required String routeId,
    required String name,
    required String morningTime,
    required String afternoonTime,
  }) async {
    final manager = _requireManager();
    if (await _routeLockedToday(manager.schoolId, routeId)) {
      return _lockedResult();
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty ||
        !_validTime(morningTime) ||
        !_validTime(afternoonTime)) {
      return const TransportActionResult(
        success: false,
        message: 'Enter a stop name and valid HH:mm morning/afternoon times.',
      );
    }

    final plan = await loadPlanForRoute(routeId);
    if (plan.activeStops.any(
      (stop) => stop.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      return const TransportActionResult(
        success: false,
        message: 'This route already contains a stop with that name.',
      );
    }
    final sequence = plan.activeStops.length + 1;
    final stopId = '$routeId-STOP-${sequence.toString().padLeft(2, '0')}-${DateTime.now().microsecondsSinceEpoch}';
    final updated = plan.copyWith(
      stops: [
        ...plan.stops,
        TransportStopDefinition(
          id: stopId,
          sequence: sequence,
          name: cleanName,
          morningTime: morningTime,
          afternoonTime: afternoonTime,
        ),
      ],
      updatedAt: _now(),
      updatedByMembershipId: manager.id,
    );
    await _savePlan(manager, updated, SyncOperation.update);
    await _syncRouteStopCount(manager, routeId, updated.activeStops.length);
    await _appendEvent(
      manager: manager,
      routeId: routeId,
      eventType: 'route_stop_added',
      details: {
        'stopId': stopId,
        'name': cleanName,
        'sequence': sequence,
      },
    );
    return const TransportActionResult(
      success: true,
      message: 'Stop added offline and queued for sync.',
    );
  }

  Future<TransportActionResult> updateStop({
    required String routeId,
    required String stopId,
    required String name,
    required String morningTime,
    required String afternoonTime,
  }) async {
    final manager = _requireManager();
    if (await _routeLockedToday(manager.schoolId, routeId)) {
      return _lockedResult();
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty ||
        !_validTime(morningTime) ||
        !_validTime(afternoonTime)) {
      return const TransportActionResult(
        success: false,
        message: 'Enter a stop name and valid HH:mm morning/afternoon times.',
      );
    }

    final plan = await loadPlanForRoute(routeId);
    final index = plan.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) {
      return const TransportActionResult(
        success: false,
        message: 'Route stop was not found.',
      );
    }
    if (plan.activeStops.any(
      (stop) =>
          stop.id != stopId &&
          stop.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      return const TransportActionResult(
        success: false,
        message: 'Another stop on this route already uses this name.',
      );
    }
    final stops = [...plan.stops];
    stops[index] = stops[index].copyWith(
      name: cleanName,
      morningTime: morningTime,
      afternoonTime: afternoonTime,
    );
    final updated = plan.copyWith(
      stops: stops,
      updatedAt: _now(),
      updatedByMembershipId: manager.id,
    );
    await _savePlan(manager, updated, SyncOperation.update);
    await _appendEvent(
      manager: manager,
      routeId: routeId,
      eventType: 'route_stop_updated',
      details: {'stopId': stopId, 'name': cleanName},
    );
    return const TransportActionResult(
      success: true,
      message: 'Stop details saved offline and queued for sync.',
    );
  }

  Future<TransportActionResult> moveStop({
    required String routeId,
    required String stopId,
    required int direction,
  }) async {
    final manager = _requireManager();
    if (await _routeLockedToday(manager.schoolId, routeId)) {
      return _lockedResult();
    }
    if (direction != -1 && direction != 1) {
      throw ArgumentError('Direction must be -1 or 1.');
    }

    final plan = await loadPlanForRoute(routeId);
    final active = plan.activeStops;
    final index = active.indexWhere((stop) => stop.id == stopId);
    if (index < 0) {
      return const TransportActionResult(
        success: false,
        message: 'Route stop was not found.',
      );
    }
    final target = index + direction;
    if (target < 0 || target >= active.length) {
      return const TransportActionResult(
        success: true,
        message: 'Stop is already at the end of this route sequence.',
      );
    }

    final reordered = [...active];
    final moving = reordered.removeAt(index);
    reordered.insert(target, moving);
    final sequenceById = <String, int>{
      for (var i = 0; i < reordered.length; i++) reordered[i].id: i + 1,
    };
    final allStops = [
      for (final stop in plan.stops)
        stop.active
            ? stop.copyWith(sequence: sequenceById[stop.id])
            : stop,
    ];
    final updated = plan.copyWith(
      stops: allStops,
      updatedAt: _now(),
      updatedByMembershipId: manager.id,
    );
    await _savePlan(manager, updated, SyncOperation.update);
    await _appendEvent(
      manager: manager,
      routeId: routeId,
      eventType: 'route_stop_reordered',
      details: {
        'stopId': stopId,
        'newSequence': sequenceById[stopId] ?? index + 1,
      },
    );
    return const TransportActionResult(
      success: true,
      message: 'Stop order updated offline and queued for sync.',
    );
  }

  Future<TransportActionResult> deactivateStop({
    required String routeId,
    required String stopId,
  }) async {
    final manager = _requireManager();
    if (await _routeLockedToday(manager.schoolId, routeId)) {
      return _lockedResult();
    }
    final routeRecord = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: routeId,
    );
    if (routeRecord == null) {
      return const TransportActionResult(
        success: false,
        message: 'Transport route was not found.',
      );
    }
    final route = SchoolTransportRoute.fromJson(routeRecord.payload);
    if (route.riders > 0) {
      return const TransportActionResult(
        success: false,
        message: 'This route still has registered riders. Reassign riders from the stop before removing it.',
      );
    }

    final plan = await loadPlanForRoute(routeId);
    final index = plan.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) {
      return const TransportActionResult(
        success: false,
        message: 'Route stop was not found.',
      );
    }
    final stops = [...plan.stops];
    stops[index] = stops[index].copyWith(active: false);
    final active = stops.where((stop) => stop.active).toList(growable: false)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final sequenceById = <String, int>{
      for (var i = 0; i < active.length; i++) active[i].id: i + 1,
    };
    final normalized = [
      for (final stop in stops)
        stop.active
            ? stop.copyWith(sequence: sequenceById[stop.id])
            : stop,
    ];
    final updated = plan.copyWith(
      stops: normalized,
      updatedAt: _now(),
      updatedByMembershipId: manager.id,
    );
    await _savePlan(manager, updated, SyncOperation.update);
    await _syncRouteStopCount(manager, routeId, updated.activeStops.length);
    await _appendEvent(
      manager: manager,
      routeId: routeId,
      eventType: 'route_stop_deactivated',
      details: {'stopId': stopId},
    );
    return const TransportActionResult(
      success: true,
      message: 'Stop removed from the future route plan and queued for sync.',
    );
  }

  SchoolMembership _requireManager() {
    final member = _schoolSession.requireActiveMembership();
    if (!_canManage(member.role)) {
      throw StateError(
        'Only the Proprietor or Administrator can change transport routes and stops.',
      );
    }
    return member;
  }

  Future<List<SchoolTransportRoute>> _loadRoutes(String tenantId) async {
    var records = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: routeEntityType,
    );
    if (records.isEmpty) {
      for (final route in transportWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: tenantId,
          entityType: routeEntityType,
          entityId: route.id,
          payload: route.toJson(),
          isDirty: false,
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: tenantId,
        entityType: routeEntityType,
      );
    }
    return records
        .map((record) => SchoolTransportRoute.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<List<DriverTransportAssignment>> _loadAssignments(String tenantId) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: assignmentEntityType,
    );
    return [
      for (final record in records)
        DriverTransportAssignment.fromJson(record.payload),
    ];
  }

  Future<bool> _routeLockedToday(String tenantId, String routeId) async {
    final today = _todayKey();
    final mornings = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: morningRunEntityType,
    );
    for (final record in mornings) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.routeId == routeId && run.serviceDate == today) return true;
    }
    final afternoons = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: afternoonRunEntityType,
    );
    for (final record in afternoons) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.routeId == routeId && run.serviceDate == today) return true;
    }
    final checks = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: vehicleCheckEntityType,
    );
    for (final record in checks) {
      if ((record.payload['routeId'] as String? ?? '') == routeId &&
          (record.payload['serviceDate'] as String? ?? '') == today) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveRoute(
    SchoolMembership manager,
    SchoolTransportRoute route,
    SyncOperation operation, {
    LocalRecord? existing,
  }) async {
    final current = existing ??
        await _localDatabase.getLocalRecord(
          tenantId: manager.schoolId,
          entityType: routeEntityType,
          entityId: route.id,
        );
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: route.id,
      payload: route.toJson(),
      serverVersion: current?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: routeEntityType,
      entityId: route.id,
      operation: current == null ? SyncOperation.create : operation,
      payload: route.toJson(),
      baseVersion: current?.serverVersion,
    );
  }

  Future<void> _savePlan(
    SchoolMembership manager,
    TransportRoutePlan plan,
    SyncOperation operation,
  ) async {
    final current = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: planEntityType,
      entityId: plan.routeId,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: planEntityType,
      entityId: plan.routeId,
      payload: plan.toJson(),
      serverVersion: current?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: planEntityType,
      entityId: plan.routeId,
      operation: current == null ? SyncOperation.create : operation,
      payload: plan.toJson(),
      baseVersion: current?.serverVersion,
    );
  }

  Future<void> _syncRouteStopCount(
    SchoolMembership manager,
    String routeId,
    int stopCount,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: routeId,
    );
    if (record == null) return;
    final route = SchoolTransportRoute.fromJson(record.payload);
    final updated = route.copyWith(stops: stopCount);
    await _saveRoute(
      manager,
      updated,
      SyncOperation.update,
      existing: record,
    );
  }

  Future<void> _appendEvent({
    required SchoolMembership manager,
    required String routeId,
    required String eventType,
    Map<String, Object?> details = const {},
  }) async {
    final at = _now();
    final id = '$routeId:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': id,
      'routeId': routeId,
      'eventType': eventType,
      'at': at,
      'actorMembershipId': manager.id,
      'actorRole': manager.role.name,
      ...details,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: eventEntityType,
      entityId: id,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: eventEntityType,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );
  }

  TransportActionResult _lockedResult() => const TransportActionResult(
        success: false,
        message: 'This route already has today’s Driver manifest or vehicle check. Route and stop changes are locked for the service day.',
      );

  String _nextRouteId(List<SchoolTransportRoute> routes) {
    var maxNumber = 0;
    for (final route in routes) {
      final match = RegExp(r'^BUS-(\d+)$').firstMatch(route.id);
      final number = match == null ? null : int.tryParse(match.group(1)!);
      if (number != null && number > maxNumber) maxNumber = number;
    }
    return 'BUS-${(maxNumber + 1).toString().padLeft(2, '0')}';
  }

  bool _validTime(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return false;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
