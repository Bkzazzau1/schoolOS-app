import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../driver/domain/driver_incident_models.dart';
import '../domain/transport_incident_defect_control_models.dart';
import 'transport_repository.dart';

class TransportIncidentDefectControlRepository {
  TransportIncidentDefectControlRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const incidentEntityType = 'driver_transport_incident';
  static const defectEntityType = 'driver_vehicle_defect';
  static const driverAssignmentEntityType = 'driver_transport_assignment';
  static const eventEntityType = 'transport_case_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;

  bool _canView(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
        SchoolRole.principal,
      }.contains(role);

  bool _canManage(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
      }.contains(role);

  Future<TransportIncidentDefectSnapshot> load() async {
    final member = _schoolSession.requireActiveMembership();
    if (!_canView(member.role)) {
      throw StateError(
        'Incidents & Defects Control requires a school management membership.',
      );
    }

    final transport = await _transportRepository.load();
    final routeNames = {
      for (final route in transport.routes) route.id: route.name,
    };
    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: driverAssignmentEntityType,
    );
    final driverNames = <String, String>{};
    for (final record in assignmentRecords) {
      final payload = record.payload;
      final membershipId = payload['membershipId'] as String? ?? record.entityId;
      final driverName = payload['driverDisplayName'] as String? ?? '';
      if (membershipId.trim().isNotEmpty && driverName.trim().isNotEmpty) {
        driverNames[membershipId] = driverName.trim();
      }
    }

    final incidentRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: incidentEntityType,
    );
    final incidents = <TransportIncidentControlEntry>[];
    for (final record in incidentRecords) {
      final incident = DriverTransportIncident.fromJson(record.payload);
      if (incident.routeId.trim().isEmpty) continue;
      incidents.add(
        TransportIncidentControlEntry(
          id: incident.id,
          routeId: incident.routeId,
          routeName: routeNames[incident.routeId] ?? incident.routeId,
          vehicle: incident.vehicle,
          serviceDate: incident.serviceDate,
          category: incident.category,
          severity: incident.severity,
          phase: incident.phase,
          description: incident.description,
          reportedAt: incident.reportedAt,
          status: incident.status,
          requiresImmediateEscalation: incident.requiresImmediateEscalation,
          driverMembershipId: incident.membershipId,
          driverName: driverNames[incident.membershipId] ?? 'Driver',
          locationNote: incident.locationNote,
          studentId: incident.studentId,
          studentName: incident.studentName,
          managementNote: record.payload['managementNote'] as String? ?? '',
          updatedAt: record.payload['updatedAt'] as String? ?? incident.reportedAt,
          updatedByMembershipId:
              record.payload['updatedByMembershipId'] as String? ?? '',
        ),
      );
    }
    incidents.sort((a, b) {
      if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return b.reportedAt.compareTo(a.reportedAt);
    });

    final defectRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: defectEntityType,
    );
    final defects = <TransportVehicleDefectControlEntry>[];
    for (final record in defectRecords) {
      final payload = record.payload;
      final routeId = payload['routeId'] as String? ?? '';
      if (routeId.trim().isEmpty) continue;
      final reporter = payload['reportedByMembershipId'] as String? ?? '';
      defects.add(
        TransportVehicleDefectControlEntry(
          id: payload['id'] as String? ?? record.entityId,
          routeId: routeId,
          routeName: routeNames[routeId] ?? routeId,
          vehicle: payload['vehicle'] as String? ?? '',
          serviceDate: payload['serviceDate'] as String? ?? '',
          period: payload['period'] as String? ?? '',
          itemLabel: payload['itemLabel'] as String? ?? 'Vehicle defect',
          severity: payload['severity'] as String? ?? 'critical',
          blocksTrip: payload['blocksTrip'] as bool? ?? false,
          note: payload['note'] as String? ?? '',
          status: payload['status'] as String? ?? 'reported',
          reportedAt: payload['reportedAt'] as String? ?? '',
          reportedByMembershipId: reporter,
          driverName: driverNames[reporter] ?? 'Driver',
          managementNote: payload['managementNote'] as String? ?? '',
          updatedAt: payload['updatedAt'] as String? ?? '',
          updatedByMembershipId:
              payload['updatedByMembershipId'] as String? ?? '',
        ),
      );
    }
    defects.sort((a, b) {
      if (a.blocksService != b.blocksService) return a.blocksService ? -1 : 1;
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return b.reportedAt.compareTo(a.reportedAt);
    });

    return TransportIncidentDefectSnapshot(
      incidents: List.unmodifiable(incidents),
      defects: List.unmodifiable(defects),
      canManage: _canManage(member.role),
    );
  }

  Future<TransportActionResult> acknowledgeIncident(String incidentId) =>
      _updateIncident(
        incidentId: incidentId,
        status: DriverIncidentStatus.acknowledged,
        eventType: 'transport_incident_acknowledged',
      );

  Future<TransportActionResult> reviewIncident(
    String incidentId, {
    String note = '',
  }) =>
      _updateIncident(
        incidentId: incidentId,
        status: DriverIncidentStatus.underReview,
        eventType: 'transport_incident_review_started',
        note: note,
      );

  Future<TransportActionResult> resolveIncident({
    required String incidentId,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Add a resolution note before closing this incident.',
      );
    }
    return _updateIncident(
      incidentId: incidentId,
      status: DriverIncidentStatus.resolved,
      eventType: 'transport_incident_resolved',
      note: note,
    );
  }

  Future<TransportActionResult> acknowledgeDefect(String defectId) =>
      _updateDefect(
        defectId: defectId,
        status: 'acknowledged',
        eventType: 'vehicle_defect_acknowledged',
      );

  Future<TransportActionResult> reviewDefect(
    String defectId, {
    String note = '',
  }) =>
      _updateDefect(
        defectId: defectId,
        status: 'under_review',
        eventType: 'vehicle_defect_review_started',
        note: note,
      );

  Future<TransportActionResult> clearDefect({
    required String defectId,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Add a clearance note describing the completed safety action.',
      );
    }
    return _updateDefect(
      defectId: defectId,
      status: 'cleared',
      eventType: 'vehicle_defect_cleared',
      note: note,
    );
  }

  Future<TransportActionResult> _updateIncident({
    required String incidentId,
    required DriverIncidentStatus status,
    required String eventType,
    String note = '',
  }) async {
    final manager = _requireManager();
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: incidentEntityType,
      entityId: incidentId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: false,
        message: 'The transport incident was not found.',
      );
    }
    final current = DriverTransportIncident.fromJson(record.payload);
    if (current.status == DriverIncidentStatus.resolved) {
      return const TransportActionResult(
        success: true,
        message: 'This incident is already resolved.',
      );
    }

    final at = _now();
    final payload = <String, Object?>{
      ...record.payload,
      'status': status.name,
      'managementNote': note.trim().isEmpty
          ? record.payload['managementNote'] as String? ?? ''
          : note.trim(),
      'updatedAt': at,
      'updatedByMembershipId': manager.id,
      'requiresTransportReview': status != DriverIncidentStatus.resolved,
    };
    await _saveCase(
      manager: manager,
      record: record,
      entityType: incidentEntityType,
      payload: payload,
    );
    await _appendEvent(
      manager: manager,
      caseId: incidentId,
      caseType: 'incident',
      routeId: current.routeId,
      vehicle: current.vehicle,
      eventType: eventType,
      status: status.name,
      note: note,
    );

    return TransportActionResult(
      success: true,
      message: status == DriverIncidentStatus.resolved
          ? 'Incident resolved locally and queued for sync.'
          : 'Incident marked ${status.label.toLowerCase()} locally and queued for sync.',
    );
  }

  Future<TransportActionResult> _updateDefect({
    required String defectId,
    required String status,
    required String eventType,
    String note = '',
  }) async {
    final manager = _requireManager();
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: defectEntityType,
      entityId: defectId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: false,
        message: 'The vehicle defect was not found.',
      );
    }
    final currentStatus =
        (record.payload['status'] as String? ?? 'reported').toLowerCase();
    if (const {'cleared', 'resolved', 'closed'}.contains(currentStatus)) {
      return const TransportActionResult(
        success: true,
        message: 'This vehicle defect is already closed.',
      );
    }

    final at = _now();
    final payload = <String, Object?>{
      ...record.payload,
      'status': status,
      'managementNote': note.trim().isEmpty
          ? record.payload['managementNote'] as String? ?? ''
          : note.trim(),
      'updatedAt': at,
      'updatedByMembershipId': manager.id,
      'requiresTransportReview': status != 'cleared',
      if (status == 'cleared') 'clearedAt': at,
      if (status == 'cleared') 'clearedByMembershipId': manager.id,
    };
    await _saveCase(
      manager: manager,
      record: record,
      entityType: defectEntityType,
      payload: payload,
    );
    await _appendEvent(
      manager: manager,
      caseId: defectId,
      caseType: 'vehicle_defect',
      routeId: record.payload['routeId'] as String? ?? '',
      vehicle: record.payload['vehicle'] as String? ?? '',
      eventType: eventType,
      status: status,
      note: note,
    );

    return TransportActionResult(
      success: true,
      message: status == 'cleared'
          ? 'Vehicle defect cleared locally. Vehicle release still requires Transport Control.'
          : 'Vehicle defect marked ${status == 'under_review' ? 'under review' : status} locally and queued for sync.',
    );
  }

  Future<void> _saveCase({
    required SchoolMembership manager,
    required LocalRecord record,
    required String entityType,
    required Map<String, Object?> payload,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: entityType,
      entityId: record.entityId,
      payload: payload,
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: entityType,
      entityId: record.entityId,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: record.serverVersion,
    );
  }

  Future<void> _appendEvent({
    required SchoolMembership manager,
    required String caseId,
    required String caseType,
    required String routeId,
    required String vehicle,
    required String eventType,
    required String status,
    String note = '',
  }) async {
    final at = _now();
    final id = '$caseId:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': id,
      'caseId': caseId,
      'caseType': caseType,
      'routeId': routeId,
      'vehicle': vehicle,
      'eventType': eventType,
      'status': status,
      'at': at,
      'actorMembershipId': manager.id,
      'actorRole': manager.role.name,
      if (note.trim().isNotEmpty) 'note': note.trim(),
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

  SchoolMembership _requireManager() {
    final member = _schoolSession.requireActiveMembership();
    if (!_canManage(member.role)) {
      throw StateError(
        'Only the Proprietor or Administrator can manage transport incidents and defects.',
      );
    }
    return member;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
