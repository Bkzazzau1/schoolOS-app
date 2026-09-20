import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_incident_models.dart';
import '../domain/driver_morning_run_models.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_dashboard_repository.dart';
import 'driver_morning_run_repository.dart';
import 'driver_riders_repository.dart';

class DriverIncidentRepository {
  DriverIncidentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _dashboardRepository = DriverDashboardRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _ridersRepository = DriverRidersRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const entityType = 'driver_transport_incident';
  static const eventEntityType = 'driver_transport_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final DriverDashboardRepository _dashboardRepository;
  final DriverRidersRepository _ridersRepository;

  Future<DriverIncidentSnapshot> loadToday() async {
    final member = _requireDriver();
    final context = await _loadContext(member);
    final records = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: entityType,
    );

    final incidents = <DriverTransportIncident>[];
    for (final record in records) {
      final incident = DriverTransportIncident.fromJson(record.payload);
      if (incident.membershipId != member.id ||
          incident.routeId != context.routeId ||
          incident.serviceDate != context.serviceDate) {
        continue;
      }
      incidents.add(incident);
    }
    incidents.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

    final riderSnapshot = await _ridersRepository.loadToday();
    final students = [
      for (final rider in riderSnapshot.riders)
        DriverIncidentStudentOption(
          studentId: rider.studentId,
          name: rider.name,
          className: rider.className,
          stopName: rider.stopName,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));

    return DriverIncidentSnapshot(
      context: context,
      incidents: List.unmodifiable(incidents),
      assignedStudents: List.unmodifiable(students),
    );
  }

  Future<DriverTransportIncident> report({
    required DriverIncidentCategory category,
    required DriverIncidentSeverity severity,
    required String description,
    String locationNote = '',
    String studentId = '',
  }) async {
    final member = _requireDriver();
    final trimmedDescription = description.trim();
    if (trimmedDescription.length < 10) {
      throw ArgumentError(
        'Add a short factual description of at least 10 characters.',
      );
    }

    final context = await _loadContext(member);
    var linkedStudentId = '';
    var linkedStudentName = '';
    if (studentId.trim().isNotEmpty) {
      final riders = await _ridersRepository.loadToday();
      final match = riders.riders.where(
        (rider) => rider.studentId == studentId.trim(),
      );
      if (match.isEmpty) {
        throw StateError(
          'The selected student is not on this Driver\'s assigned route manifest.',
        );
      }
      linkedStudentId = match.first.studentId;
      linkedStudentName = match.first.name;
    }

    final at = _now();
    final incident = DriverTransportIncident(
      id: '${member.id}:incident:${context.serviceDate}:${DateTime.now().microsecondsSinceEpoch}',
      membershipId: member.id,
      routeId: context.routeId,
      vehicle: context.vehicle,
      serviceDate: context.serviceDate,
      category: category,
      severity: severity,
      phase: context.phase,
      description: trimmedDescription,
      reportedAt: at,
      locationNote: locationNote.trim(),
      studentId: linkedStudentId,
      studentName: linkedStudentName,
      status: DriverIncidentStatus.queued,
      requiresImmediateEscalation:
          _requiresImmediateEscalation(category, severity),
    );

    final payload = <String, Object?>{
      ...incident.toJson(),
      'reportedByMembershipId': member.id,
      'requiresTransportReview': true,
      'updatedAt': at,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: incident.id,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: incident.id,
      operation: SyncOperation.create,
      payload: payload,
    );

    final eventId =
        '${incident.id}:reported:${DateTime.now().microsecondsSinceEpoch}';
    final eventPayload = <String, Object?>{
      'id': eventId,
      'incidentId': incident.id,
      'routeId': incident.routeId,
      'vehicle': incident.vehicle,
      'serviceDate': incident.serviceDate,
      'eventType': 'driver_incident_reported',
      'category': incident.category.name,
      'severity': incident.severity.name,
      'phase': incident.phase.name,
      'requiresImmediateEscalation': incident.requiresImmediateEscalation,
      'at': at,
      'actorMembershipId': member.id,
      if (incident.hasStudent) 'studentId': incident.studentId,
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

    return incident;
  }

  Future<DriverIncidentContext> _loadContext(SchoolMembership member) async {
    final dashboard = await _dashboardRepository.load();
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
    }
    DriverAfternoonRun? afternoon;
    if (afternoonRecord != null) {
      afternoon = DriverAfternoonRun.fromJson(afternoonRecord.payload);
    }

    return DriverIncidentContext(
      routeId: dashboard.assignment.routeId,
      vehicle: dashboard.route.vehicle,
      serviceDate: today,
      phase: _phaseFor(morning, afternoon),
    );
  }

  DriverIncidentTripPhase _phaseFor(
    DriverMorningRun? morning,
    DriverAfternoonRun? afternoon,
  ) {
    if (afternoon?.status == DriverAfternoonRunStatus.inProgress) {
      return DriverIncidentTripPhase.afternoonRoute;
    }
    if (morning?.status == DriverMorningRunStatus.inProgress) {
      return DriverIncidentTripPhase.morningRoute;
    }
    if (afternoon?.status == DriverAfternoonRunStatus.returnedSchool ||
        afternoon?.status == DriverAfternoonRunStatus.completed) {
      return DriverIncidentTripPhase.afterService;
    }
    if (afternoon?.status == DriverAfternoonRunStatus.boarding) {
      return DriverIncidentTripPhase.beforeAfternoonRun;
    }
    if (morning?.status == DriverMorningRunStatus.arrivedSchool) {
      return DriverIncidentTripPhase.atSchool;
    }
    if (morning?.status == DriverMorningRunStatus.completed) {
      return DriverIncidentTripPhase.beforeAfternoonRun;
    }
    return DriverIncidentTripPhase.beforeMorningRun;
  }

  bool _requiresImmediateEscalation(
    DriverIncidentCategory category,
    DriverIncidentSeverity severity,
  ) {
    if (severity == DriverIncidentSeverity.critical ||
        severity == DriverIncidentSeverity.high) {
      return true;
    }
    return category == DriverIncidentCategory.accident;
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only a Driver membership can report transport incidents.');
    }
    return member;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
