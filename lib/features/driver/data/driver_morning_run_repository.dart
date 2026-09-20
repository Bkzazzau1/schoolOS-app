import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import 'driver_dashboard_repository.dart';
import 'driver_morning_run_demo_data.dart';

class DriverMorningRunRepository {
  DriverMorningRunRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const entityType = 'driver_morning_run';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;

  Future<DriverMorningRun> loadToday() async {
    final member = _requireDriver();
    final assignment = await _loadAssignment(member);
    final route = await _assignedRoute(assignment);
    final id = _runId(member.id, _todayKey());
    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: id,
    );
    if (record != null) {
      final run = DriverMorningRun.fromJson(record.payload);
      _validateOwnership(run, member, assignment);
      return run;
    }

    if (assignment.routeId != 'BUS-02') {
      throw StateError(
        'The rider manifest for ${assignment.routeId} has not been downloaded to this device yet.',
      );
    }

    final run = DriverMorningRun(
      id: id,
      membershipId: member.id,
      routeId: route.id,
      serviceDate: _todayKey(),
      vehicle: route.vehicle,
      driverName: assignment.driverDisplayName,
      assistantName: route.assistant,
      stops: defaultBus02MorningStops(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: run.id,
      payload: run.toJson(),
      isDirty: false,
    );
    return run;
  }

  Future<DriverMorningRun> startRun() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status != DriverMorningRunStatus.notStarted) return run;
    final assignment = await _loadAssignment(member);
    final route = await _assignedRoute(assignment);
    if (!route.isAvailable) {
      throw StateError(
        'This vehicle is not cleared for transport. Wait for Transport Control to release it.',
      );
    }
    if (run.stops.isEmpty || run.expectedRiders == 0) {
      throw StateError('The morning manifest is empty. Contact Transport Control.');
    }
    final updated = run.copyWith(
      status: DriverMorningRunStatus.inProgress,
      startedAt: _now(),
    );
    await _save(member, updated);
    return updated;
  }

  Future<DriverMorningRun> arriveAtStop(String stopId) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    if (run.activeStop != null) {
      throw StateError(
        'Depart ${run.activeStop!.name} before opening another stop.',
      );
    }

    final index = run.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[index];
    if (stop.status == DriverMorningStopStatus.departed) return run;
    if (stop.status != DriverMorningStopStatus.pending) {
      throw StateError('This stop cannot be opened from its current state.');
    }
    if (index > 0 &&
        run.stops[index - 1].status != DriverMorningStopStatus.departed) {
      throw StateError('Complete the previous stop before continuing.');
    }

    final stops = [...run.stops];
    stops[index] = stop.copyWith(
      status: DriverMorningStopStatus.active,
      arrivedAt: _now(),
    );
    final updated = run.copyWith(stops: stops);
    await _save(member, updated);
    return updated;
  }

  Future<DriverMorningRun> setRiderStatus({
    required String stopId,
    required String studentId,
    required DriverMorningRiderStatus status,
    String note = '',
  }) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    if (status == DriverMorningRiderStatus.pending ||
        status == DriverMorningRiderStatus.arrivedSchool) {
      throw ArgumentError('Choose a boarding, no-show, cancellation or exception status.');
    }
    if (status == DriverMorningRiderStatus.exception && note.trim().isEmpty) {
      throw ArgumentError('Add a short note explaining the transport exception.');
    }

    final stopIndex = run.stops.indexWhere((stop) => stop.id == stopId);
    if (stopIndex < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[stopIndex];
    if (stop.status != DriverMorningStopStatus.active) {
      throw StateError('Open this stop before recording rider status.');
    }
    final riderIndex =
        stop.riders.indexWhere((rider) => rider.studentId == studentId);
    if (riderIndex < 0) {
      throw ArgumentError('This student is not assigned to the selected stop.');
    }

    final riders = [...stop.riders];
    riders[riderIndex] = riders[riderIndex].copyWith(
      status: status,
      note: note.trim(),
      updatedAt: _now(),
    );
    final stops = [...run.stops];
    stops[stopIndex] = stop.copyWith(riders: riders);
    final updated = run.copyWith(stops: stops);
    await _save(member, updated);
    return updated;
  }

  Future<DriverMorningRun> departStop(String stopId) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    final index = run.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[index];
    if (stop.status == DriverMorningStopStatus.departed) return run;
    if (stop.status != DriverMorningStopStatus.active) {
      throw StateError('Arrive at this stop before departing it.');
    }
    if (!stop.allRidersResolved) {
      final unresolved = stop.riders
          .where((rider) => rider.status == DriverMorningRiderStatus.pending)
          .length;
      throw StateError(
        '$unresolved rider${unresolved == 1 ? '' : 's'} still need a status before departure.',
      );
    }

    final stops = [...run.stops];
    stops[index] = stop.copyWith(
      status: DriverMorningStopStatus.departed,
      departedAt: _now(),
    );
    final updated = run.copyWith(stops: stops);
    await _save(member, updated);
    return updated;
  }

  Future<DriverMorningRun> arriveAtSchool() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status == DriverMorningRunStatus.arrivedSchool ||
        run.status == DriverMorningRunStatus.completed) {
      return run;
    }
    _requireInProgress(run);
    if (!run.allStopsDeparted) {
      throw StateError('Complete every route stop before confirming school arrival.');
    }

    final at = _now();
    final stops = [
      for (final stop in run.stops)
        stop.copyWith(
          riders: [
            for (final rider in stop.riders)
              if (rider.status == DriverMorningRiderStatus.boarded)
                rider.copyWith(
                  status: DriverMorningRiderStatus.arrivedSchool,
                  updatedAt: at,
                )
              else
                rider,
          ],
        ),
    ];
    final updated = run.copyWith(
      stops: stops,
      status: DriverMorningRunStatus.arrivedSchool,
      arrivedSchoolAt: at,
    );
    await _save(member, updated);
    return updated;
  }

  Future<DriverMorningRun> completeRun() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status == DriverMorningRunStatus.completed) return run;
    if (run.status != DriverMorningRunStatus.arrivedSchool) {
      throw StateError('Confirm arrival at school before completing the morning run.');
    }
    if (run.pendingRiders > 0) {
      throw StateError('The rider manifest still has unresolved students.');
    }
    final updated = run.copyWith(
      status: DriverMorningRunStatus.completed,
      completedAt: _now(),
    );
    await _save(member, updated);
    return updated;
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError('Only the assigned Driver membership can operate this run.');
    }
    return member;
  }

  Future<DriverTransportAssignment> _loadAssignment(
    SchoolMembership member,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: DriverDashboardRepository.assignmentEntityType,
      entityId: member.id,
    );
    if (record == null) {
      await DriverDashboardRepository(
        localDatabase: _localDatabase,
        schoolSession: _schoolSession,
      ).load();
      final seeded = await _localDatabase.getLocalRecord(
        tenantId: member.schoolId,
        entityType: DriverDashboardRepository.assignmentEntityType,
        entityId: member.id,
      );
      if (seeded == null) throw StateError('No transport assignment is available.');
      return DriverTransportAssignment.fromJson(seeded.payload);
    }
    return DriverTransportAssignment.fromJson(record.payload);
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
    DriverMorningRun run,
    SchoolMembership member,
    DriverTransportAssignment assignment,
  ) {
    if (run.membershipId != member.id || run.routeId != assignment.routeId) {
      throw StateError('This morning run does not belong to the active Driver membership.');
    }
  }

  void _requireInProgress(DriverMorningRun run) {
    if (run.status != DriverMorningRunStatus.inProgress) {
      throw StateError('Start the morning run before recording route activity.');
    }
  }

  Future<void> _save(SchoolMembership member, DriverMorningRun run) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: run.id,
    );
    final payload = {
      ...run.toJson(),
      'updatedAt': _now(),
      'updatedByMembershipId': member.id,
    };
    await _localDatabase.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: run.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: run.id,
      operation: existing?.serverVersion == null
          ? SyncOperation.create
          : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _runId(String membershipId, String serviceDate) =>
      '$membershipId:morning:$serviceDate';

  String _now() => DateTime.now().toUtc().toIso8601String();
}
