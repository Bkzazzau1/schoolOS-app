import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/data/transport_vehicle_readiness_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_vehicle_check_models.dart';
import 'driver_dashboard_repository.dart';
import 'driver_vehicle_check_demo_data.dart';

class DriverVehicleCheckRepository {
  DriverVehicleCheckRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _vehicleReadinessRepository = TransportVehicleReadinessRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const entityType = 'driver_vehicle_check';
  static const defectEntityType = 'driver_vehicle_defect';
  static const eventEntityType = 'driver_transport_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;
  final TransportVehicleReadinessRepository _vehicleReadinessRepository;

  Future<DriverVehicleCheck> loadToday(DriverVehicleCheckPeriod period) async {
    final member = _requireDriver();
    final assignment = await _loadAssignment(member);
    final route = await _assignedRoute(assignment);
    final id = checkId(member.id, _todayKey(), period);
    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: id,
    );

    if (record != null) {
      final check = DriverVehicleCheck.fromJson(record.payload);
      _validateOwnership(check, member, assignment, period);
      if (check.vehicle != route.vehicle) {
        throw StateError(
          'The saved vehicle check is for ${check.vehicle}, but ${route.vehicle} is now assigned. Start a new check for the assigned vehicle.',
        );
      }
      return check;
    }

    final check = DriverVehicleCheck(
      id: id,
      membershipId: member.id,
      routeId: assignment.routeId,
      vehicle: route.vehicle,
      serviceDate: _todayKey(),
      period: period,
      items: defaultDriverVehicleCheckItems(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: check.id,
      payload: check.toJson(),
      isDirty: false,
    );
    return check;
  }

  Future<DriverVehicleCheck> setItemStatus({
    required DriverVehicleCheckPeriod period,
    required String itemId,
    required DriverVehicleCheckItemStatus status,
    String note = '',
  }) async {
    final member = _requireDriver();
    if (status == DriverVehicleCheckItemStatus.unchecked) {
      throw ArgumentError('Choose Pass or Fail for the vehicle check item.');
    }
    if (status == DriverVehicleCheckItemStatus.failed && note.trim().isEmpty) {
      throw ArgumentError('Add a short note describing the observed defect.');
    }

    final check = await loadToday(period);
    await _ensureEditable(member, check);
    final index = check.items.indexWhere((item) => item.id == itemId);
    if (index < 0) throw ArgumentError('Vehicle check item was not found.');

    final items = [...check.items];
    items[index] = items[index].copyWith(
      status: status,
      note: status == DriverVehicleCheckItemStatus.failed ? note.trim() : '',
      updatedAt: _now(),
    );
    final updated = check.copyWith(
      items: items,
      status: DriverVehicleCheckStatus.inProgress,
      submittedAt: '',
    );
    await _saveCheck(
      member,
      updated,
      eventType: 'vehicle_check_item_recorded',
      details: {
        'period': period.name,
        'itemId': itemId,
        'status': status.name,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return updated;
  }

  Future<DriverVehicleCheck> submit(DriverVehicleCheckPeriod period) async {
    final member = _requireDriver();
    final check = await loadToday(period);
    await _ensureEditable(member, check);
    if (!check.allChecked) {
      final remaining = check.items.where((item) => !item.isChecked).length;
      throw StateError(
        '$remaining vehicle check item${remaining == 1 ? '' : 's'} still need Pass or Fail before submission.',
      );
    }

    final blocked = check.blockingFailureCount > 0;
    final submittedAt = _now();
    final updated = check.copyWith(
      status: blocked
          ? DriverVehicleCheckStatus.blocked
          : DriverVehicleCheckStatus.ready,
      submittedAt: submittedAt,
    );

    await _saveCheck(
      member,
      updated,
      eventType: blocked
          ? 'vehicle_check_blocked'
          : 'vehicle_check_ready',
      details: {
        'period': period.name,
        'vehicle': updated.vehicle,
        'failedItems': updated.failedCount,
        'blockingFailures': updated.blockingFailureCount,
      },
    );

    for (final item in updated.items.where((item) => item.failed)) {
      await _queueDefect(member, updated, item, submittedAt);
    }
    return updated;
  }

  Future<void> requireReadyFor(DriverVehicleCheckPeriod period) async {
    final check = await loadToday(period);
    await _vehicleReadinessRepository.requireOperationalRelease(
      routeId: check.routeId,
      vehicle: check.vehicle,
    );
    if (check.status == DriverVehicleCheckStatus.ready) return;
    if (check.status == DriverVehicleCheckStatus.blocked) {
      throw StateError(
        '${period.label} vehicle check is blocked by ${check.blockingFailureCount} safety defect${check.blockingFailureCount == 1 ? '' : 's'}. Recheck the vehicle after the issue is corrected.',
      );
    }
    throw StateError(
      'Complete and submit the ${period.label.toLowerCase()} vehicle check before starting this transport run.',
    );
  }

  Future<void> _ensureEditable(
    SchoolMembership member,
    DriverVehicleCheck check,
  ) async {
    if (check.period == DriverVehicleCheckPeriod.morning) {
      final record = await _localDatabase.getLocalRecord(
        tenantId: member.schoolId,
        entityType: 'driver_morning_run',
        entityId: '${member.id}:morning:${check.serviceDate}',
      );
      if (record == null) return;
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.status != DriverMorningRunStatus.notStarted) {
        throw StateError(
          'The morning vehicle check is locked because the morning run has already started.',
        );
      }
      return;
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: 'driver_afternoon_run',
      entityId: '${member.id}:afternoon:${check.serviceDate}',
    );
    if (record == null) return;
    final run = DriverAfternoonRun.fromJson(record.payload);
    if (run.status != DriverAfternoonRunStatus.notStarted) {
      throw StateError(
        'The afternoon vehicle check is locked because afternoon service has already started.',
      );
    }
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
      throw StateError('No vehicle route is assigned to this Driver membership.');
    }
    final assignment = DriverTransportAssignment.fromJson(record.payload);
    if (assignment.membershipId != member.id || assignment.routeId.isEmpty) {
      throw StateError('The Driver vehicle assignment is invalid.');
    }
    return assignment;
  }

  Future<SchoolTransportRoute> _assignedRoute(
    DriverTransportAssignment assignment,
  ) async {
    final transport = await _transportRepository.load();
    for (final route in transport.routes) {
      if (route.id == assignment.routeId) return route;
    }
    throw StateError('Assigned route ${assignment.routeId} is unavailable.');
  }

  void _validateOwnership(
    DriverVehicleCheck check,
    SchoolMembership member,
    DriverTransportAssignment assignment,
    DriverVehicleCheckPeriod period,
  ) {
    if (check.membershipId != member.id ||
        check.routeId != assignment.routeId ||
        check.period != period ||
        check.serviceDate != _todayKey()) {
      throw StateError('This vehicle check does not belong to the active Driver assignment.');
    }
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only a Driver membership can perform vehicle checks.');
    }
    return member;
  }

  Future<void> _saveCheck(
    SchoolMembership member,
    DriverVehicleCheck check, {
    required String eventType,
    Map<String, Object?> details = const {},
  }) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: check.id,
    );
    final at = _now();
    final payload = <String, Object?>{
      ...check.toJson(),
      'updatedAt': at,
      'updatedByMembershipId': member.id,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: check.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: check.id,
      operation: existing?.serverVersion == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );

    final eventId = '${check.id}:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final eventPayload = <String, Object?>{
      'id': eventId,
      'routeId': check.routeId,
      'vehicle': check.vehicle,
      'serviceDate': check.serviceDate,
      'period': check.period.name,
      'eventType': eventType,
      'at': at,
      'actorMembershipId': member.id,
      ...details,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: eventEntityType,
      entityId: eventId,
      payload: eventPayload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: eventEntityType,
      entityId: eventId,
      operation: SyncOperation.create,
      payload: eventPayload,
    );
  }

  Future<void> _queueDefect(
    SchoolMembership member,
    DriverVehicleCheck check,
    DriverVehicleCheckItem item,
    String reportedAt,
  ) async {
    final defectId = '${check.id}:${item.id}';
    final existing = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: defectEntityType,
      entityId: defectId,
    );
    final payload = <String, Object?>{
      'id': defectId,
      'checkId': check.id,
      'routeId': check.routeId,
      'vehicle': check.vehicle,
      'serviceDate': check.serviceDate,
      'period': check.period.name,
      'itemId': item.id,
      'itemLabel': item.label,
      'severity': item.severity.name,
      'blocksTrip': item.blocksTrip,
      'note': item.note,
      'status': 'reported',
      'reportedAt': reportedAt,
      'reportedByMembershipId': member.id,
      'requiresTransportReview': true,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: defectEntityType,
      entityId: defectId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: defectEntityType,
      entityId: defectId,
      operation: existing?.serverVersion == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  static String checkId(
    String membershipId,
    String serviceDate,
    DriverVehicleCheckPeriod period,
  ) => '$membershipId:vehicle-check:$serviceDate:${period.name}';

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
