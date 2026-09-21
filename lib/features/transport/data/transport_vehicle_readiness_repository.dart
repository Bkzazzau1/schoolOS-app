import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../driver/domain/driver_vehicle_check_models.dart';
import '../domain/transport_models.dart';
import '../domain/transport_vehicle_readiness_models.dart';
import 'transport_demo_data.dart';
import 'transport_repository.dart';

class TransportVehicleReadinessRepository {
  TransportVehicleReadinessRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const routeEntityType = 'school_transport_route';
  static const clearanceEntityType = 'transport_vehicle_clearance';
  static const eventEntityType = 'transport_vehicle_event';
  static const checkEntityType = 'driver_vehicle_check';
  static const defectEntityType = 'driver_vehicle_defect';
  static const driverAssignmentEntityType = 'driver_transport_assignment';

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

  Future<TransportVehicleReadinessSnapshot> load() async {
    final member = _schoolSession.requireActiveMembership();
    if (!_canView(member.role)) {
      throw StateError(
        'Vehicles & Readiness requires a school management membership.',
      );
    }

    final routes = await _loadRoutes(member.schoolId);
    final today = _todayKey();
    final checks = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: checkEntityType,
    );
    final defects = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: defectEntityType,
    );
    final assignments = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: driverAssignmentEntityType,
    );

    final driverByRoute = <String, String>{};
    for (final record in assignments) {
      final payload = record.payload;
      final active = payload['active'] as bool? ?? true;
      final routeId = active ? payload['routeId'] as String? ?? '' : '';
      final name = payload['driverDisplayName'] as String? ?? '';
      if (routeId.isNotEmpty && name.trim().isNotEmpty) {
        driverByRoute.putIfAbsent(routeId, () => name.trim());
      }
    }

    final entries = <TransportVehicleReadinessEntry>[];
    for (final route in routes) {
      final clearance = await _ensureClearance(member.schoolId, route);

      DriverVehicleCheck? morning;
      DriverVehicleCheck? afternoon;
      for (final record in checks) {
        final check = DriverVehicleCheck.fromJson(record.payload);
        if (check.routeId != route.id || check.serviceDate != today) continue;
        if (check.period == DriverVehicleCheckPeriod.morning) {
          morning = _newerCheck(morning, check);
        } else {
          afternoon = _newerCheck(afternoon, check);
        }
      }

      var openDefects = 0;
      var blockingDefects = 0;
      for (final record in defects) {
        final payload = record.payload;
        if ((payload['routeId'] as String? ?? '') != route.id ||
            (payload['serviceDate'] as String? ?? '') != today) {
          continue;
        }
        final status = (payload['status'] as String? ?? '').toLowerCase();
        final closed = status == 'cleared' ||
            status == 'resolved' ||
            status == 'closed';
        if (closed) continue;
        openDefects++;
        if (payload['blocksTrip'] as bool? ?? false) blockingDefects++;
      }

      entries.add(
        TransportVehicleReadinessEntry(
          routeId: route.id,
          routeName: route.name,
          vehicle: route.vehicle,
          driverName: driverByRoute[route.id] ?? route.driver,
          clearance: clearance,
          morningCheckStatus: morning?.status,
          afternoonCheckStatus: afternoon?.status,
          morningSubmittedAt: morning?.submittedAt ?? '',
          afternoonSubmittedAt: afternoon?.submittedAt ?? '',
          openDefectCount: openDefects,
          blockingDefectCount: blockingDefects,
        ),
      );
    }

    return TransportVehicleReadinessSnapshot(
      serviceDate: today,
      vehicles: List.unmodifiable(entries),
      canManage: _canManage(member.role),
    );
  }

  Future<TransportActionResult> setClearance({
    required String routeId,
    required TransportVehicleClearanceStatus status,
    String note = '',
  }) async {
    final manager = _requireManager();
    final cleanRouteId = routeId.trim();
    if (cleanRouteId.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Choose a transport route vehicle.',
      );
    }
    final routes = await _loadRoutes(manager.schoolId);
    SchoolTransportRoute? route;
    for (final item in routes) {
      if (item.id == cleanRouteId) {
        route = item;
        break;
      }
    }
    if (route == null) {
      return const TransportActionResult(
        success: false,
        message: 'The selected route vehicle was not found.',
      );
    }

    final cleanNote = note.trim();
    if (status != TransportVehicleClearanceStatus.released &&
        cleanNote.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Add a short operational reason before holding this vehicle.',
      );
    }

    if (status == TransportVehicleClearanceStatus.released) {
      final blocking = await _openBlockingDefects(
        manager.schoolId,
        cleanRouteId,
        _todayKey(),
      );
      if (blocking > 0) {
        return TransportActionResult(
          success: false,
          message:
              'This vehicle still has $blocking open trip-blocking safety defect${blocking == 1 ? '' : 's'}. Clear the defect before releasing it.',
        );
      }
    }

    final currentRecord = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: clearanceEntityType,
      entityId: cleanRouteId,
    );
    final now = _now();
    final updated = TransportVehicleClearance(
      routeId: cleanRouteId,
      vehicle: route.vehicle,
      status: status,
      note: cleanNote,
      updatedAt: now,
      updatedByMembershipId: manager.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: clearanceEntityType,
      entityId: cleanRouteId,
      payload: updated.toJson(),
      serverVersion: currentRecord?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: clearanceEntityType,
      entityId: cleanRouteId,
      operation: currentRecord == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: updated.toJson(),
      baseVersion: currentRecord?.serverVersion,
    );

    await _syncLegacyRouteAvailability(manager, route, status);
    await _appendEvent(
      manager: manager,
      route: route,
      eventType: 'vehicle_clearance_changed',
      details: {
        'status': status.name,
        if (cleanNote.isNotEmpty) 'note': cleanNote,
      },
    );

    return TransportActionResult(
      success: true,
      message: status == TransportVehicleClearanceStatus.released
          ? '${route.vehicle} released for service locally and queued for sync.'
          : '${route.vehicle} marked ${status.label.toLowerCase()} locally and queued for sync.',
    );
  }

  /// Driver-side safety gate. The caller must be the active Driver membership
  /// assigned to [routeId]. Critical/open defects override a release flag.
  Future<void> requireOperationalRelease({
    required String routeId,
    required String vehicle,
  }) async {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only a Driver membership can consume vehicle clearance.');
    }
    await _requireDriverRoute(member, routeId);

    final routeRecord = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: routeEntityType,
      entityId: routeId,
    );
    if (routeRecord == null) {
      throw StateError('The assigned transport route is unavailable.');
    }
    final route = SchoolTransportRoute.fromJson(routeRecord.payload);
    final clearance = await _ensureClearance(member.schoolId, route);
    if (clearance.vehicle != vehicle || clearance.vehicle != route.vehicle) {
      throw StateError(
        'Vehicle clearance no longer matches the assigned vehicle. Transport Control must review the replacement vehicle.',
      );
    }

    final blocking = await _openBlockingDefects(
      member.schoolId,
      routeId,
      _todayKey(),
    );
    if (blocking > 0) {
      throw StateError(
        'This vehicle has $blocking open trip-blocking safety defect${blocking == 1 ? '' : 's'}. Transport Control clearance is required after the defect is resolved.',
      );
    }
    if (!clearance.released) {
      throw StateError(
        'This vehicle is ${clearance.status.label.toLowerCase()}. Transport Control must release it before service can start.',
      );
    }
  }

  Future<TransportVehicleClearance> _ensureClearance(
    String tenantId,
    SchoolTransportRoute route,
  ) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: tenantId,
      entityType: clearanceEntityType,
      entityId: route.id,
    );
    if (existing == null) {
      final seeded = TransportVehicleClearance(
        routeId: route.id,
        vehicle: route.vehicle,
        status: route.status == TransportRouteStatus.maintenance
            ? TransportVehicleClearanceStatus.maintenance
            : TransportVehicleClearanceStatus.released,
        note: route.status == TransportRouteStatus.maintenance
            ? route.note
            : 'Baseline route vehicle available.',
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: tenantId,
        entityType: clearanceEntityType,
        entityId: route.id,
        payload: seeded.toJson(),
        isDirty: false,
      );
      return seeded;
    }

    final clearance = TransportVehicleClearance.fromJson(existing.payload);
    if (clearance.vehicle == route.vehicle) return clearance;

    // A route vehicle replacement must never inherit the previous vehicle's
    // release decision. Hold locally until management explicitly reviews it.
    final reset = TransportVehicleClearance(
      routeId: route.id,
      vehicle: route.vehicle,
      status: TransportVehicleClearanceStatus.held,
      note: 'Vehicle changed on this route; Transport Control review required.',
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: tenantId,
      entityType: clearanceEntityType,
      entityId: route.id,
      payload: reset.toJson(),
      isDirty: false,
    );
    return reset;
  }

  DriverVehicleCheck _newerCheck(
    DriverVehicleCheck? current,
    DriverVehicleCheck candidate,
  ) {
    if (current == null) return candidate;
    final currentAt = DateTime.tryParse(current.submittedAt);
    final candidateAt = DateTime.tryParse(candidate.submittedAt);
    if (candidateAt == null) return current;
    if (currentAt == null || candidateAt.isAfter(currentAt)) return candidate;
    return current;
  }

  Future<int> _openBlockingDefects(
    String tenantId,
    String routeId,
    String serviceDate,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: defectEntityType,
    );
    var count = 0;
    for (final record in records) {
      final payload = record.payload;
      if ((payload['routeId'] as String? ?? '') != routeId ||
          (payload['serviceDate'] as String? ?? '') != serviceDate) {
        continue;
      }
      final status = (payload['status'] as String? ?? '').toLowerCase();
      final closed = status == 'cleared' ||
          status == 'resolved' ||
          status == 'closed';
      if (!closed && (payload['blocksTrip'] as bool? ?? false)) count++;
    }
    return count;
  }

  Future<void> _requireDriverRoute(
    SchoolMembership member,
    String routeId,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: driverAssignmentEntityType,
      entityId: member.id,
    );
    if (record == null) {
      throw StateError('No active transport route is assigned to this Driver.');
    }
    final payload = record.payload;
    final active = payload['active'] as bool? ?? true;
    final membershipId = payload['membershipId'] as String? ?? '';
    final assignedRouteId = active ? payload['routeId'] as String? ?? '' : '';
    if (!active || membershipId != member.id || assignedRouteId != routeId) {
      throw StateError(
        'This vehicle clearance is outside the active Driver assignment.',
      );
    }
  }

  SchoolMembership _requireManager() {
    final member = _schoolSession.requireActiveMembership();
    if (!_canManage(member.role)) {
      throw StateError(
        'Only the Proprietor or Administrator can change vehicle clearance.',
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

  Future<void> _syncLegacyRouteAvailability(
    SchoolMembership manager,
    SchoolTransportRoute route,
    TransportVehicleClearanceStatus clearance,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: route.id,
    );
    if (record == null) return;

    var nextStatus = route.status;
    if (clearance == TransportVehicleClearanceStatus.maintenance) {
      nextStatus = TransportRouteStatus.maintenance;
    } else if (clearance == TransportVehicleClearanceStatus.released &&
        route.status == TransportRouteStatus.maintenance) {
      nextStatus = TransportRouteStatus.preparing;
    }
    if (nextStatus == route.status) return;

    final updated = route.copyWith(status: nextStatus);
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: routeEntityType,
      entityId: route.id,
      payload: updated.toJson(),
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: routeEntityType,
      entityId: route.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
      baseVersion: record.serverVersion,
    );
  }

  Future<void> _appendEvent({
    required SchoolMembership manager,
    required SchoolTransportRoute route,
    required String eventType,
    Map<String, Object?> details = const {},
  }) async {
    final id =
        '${route.id}:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': id,
      'routeId': route.id,
      'vehicle': route.vehicle,
      'eventType': eventType,
      'at': _now(),
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
