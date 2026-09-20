import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_vehicle_check_models.dart';
import 'driver_afternoon_run_demo_data.dart';
import 'driver_dashboard_repository.dart';
import 'driver_vehicle_check_repository.dart';

class DriverAfternoonRunRepository {
  DriverAfternoonRunRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _vehicleCheckRepository = DriverVehicleCheckRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const entityType = 'driver_afternoon_run';
  static const eventEntityType = 'driver_transport_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;
  final DriverVehicleCheckRepository _vehicleCheckRepository;

  Future<DriverAfternoonRun> loadToday() async {
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
      final run = DriverAfternoonRun.fromJson(record.payload);
      _validateOwnership(run, member, assignment);
      return run;
    }

    if (assignment.routeId != 'BUS-02') {
      throw StateError(
        'The afternoon rider manifest for ${assignment.routeId} has not been downloaded to this device yet.',
      );
    }

    final run = DriverAfternoonRun(
      id: id,
      membershipId: member.id,
      routeId: route.id,
      serviceDate: _todayKey(),
      vehicle: route.vehicle,
      driverName: assignment.driverDisplayName,
      assistantName: route.assistant,
      stops: defaultBus02AfternoonStops(),
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

  Future<DriverAfternoonRun> startBoarding() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status != DriverAfternoonRunStatus.notStarted) return run;

    final assignment = await _loadAssignment(member);
    final route = await _assignedRoute(assignment);
    if (!route.isAvailable) {
      throw StateError(
        'This vehicle is not cleared for transport. Wait for Transport Control to release it.',
      );
    }
    await _vehicleCheckRepository.requireReadyFor(
      DriverVehicleCheckPeriod.afternoon,
    );
    if (run.expectedRiders == 0) {
      throw StateError('The afternoon manifest is empty. Contact Transport Control.');
    }

    final updated = run.copyWith(
      status: DriverAfternoonRunStatus.boarding,
      startedAt: _now(),
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_boarding_started',
      details: {'expectedRiders': updated.expectedRiders},
    );
    return updated;
  }

  Future<DriverAfternoonRun> setBoardingStatus({
    required String studentId,
    required DriverAfternoonRiderStatus status,
    String note = '',
  }) async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status != DriverAfternoonRunStatus.boarding) {
      throw StateError('Open afternoon boarding before recording rider status.');
    }
    if (!const {
      DriverAfternoonRiderStatus.boarded,
      DriverAfternoonRiderStatus.guardianPickup,
      DriverAfternoonRiderStatus.notRiding,
      DriverAfternoonRiderStatus.boardingException,
    }.contains(status)) {
      throw ArgumentError('Choose a valid school boarding status.');
    }
    if (status == DriverAfternoonRiderStatus.boardingException &&
        note.trim().isEmpty) {
      throw ArgumentError('Add a short note explaining the boarding exception.');
    }

    final location = _findRider(run, studentId);
    final current = location.rider;
    if (current.status != DriverAfternoonRiderStatus.expected &&
        current.status != DriverAfternoonRiderStatus.boarded &&
        current.status != DriverAfternoonRiderStatus.guardianPickup &&
        current.status != DriverAfternoonRiderStatus.notRiding &&
        current.status != DriverAfternoonRiderStatus.boardingException) {
      throw StateError('This rider has already entered the route drop-off workflow.');
    }

    final updated = _replaceRider(
      run,
      location.stopIndex,
      location.riderIndex,
      current.copyWith(
        status: status,
        note: note.trim(),
        updatedAt: _now(),
      ),
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_boarding_status_recorded',
      details: {
        'studentId': studentId,
        'stopId': current.stopId,
        'status': status.name,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return updated;
  }

  Future<DriverAfternoonRun> departSchool() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status == DriverAfternoonRunStatus.inProgress) return run;
    if (run.status != DriverAfternoonRunStatus.boarding) {
      throw StateError('Start afternoon boarding before departing school.');
    }
    if (run.unresolvedBoarding > 0) {
      throw StateError(
        '${run.unresolvedBoarding} rider${run.unresolvedBoarding == 1 ? '' : 's'} still need a boarding status.',
      );
    }
    if (run.boardedRiders == 0) {
      throw StateError(
        'No students are boarded. Confirm the manifest with Transport Control before closing the service.',
      );
    }

    final updated = run.copyWith(
      status: DriverAfternoonRunStatus.inProgress,
      departedSchoolAt: _now(),
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_departed_school',
      details: {
        'boardedRiders': updated.boardedRiders,
        'guardianPickup': updated.guardianPickupCount,
        'notRiding': updated.notRidingCount,
      },
    );
    return updated;
  }

  Future<DriverAfternoonRun> arriveAtStop(String stopId) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    if (run.activeStop != null) {
      throw StateError('Depart ${run.activeStop!.name} before opening another stop.');
    }

    final index = run.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[index];
    if (!stop.riders.any((rider) => rider.status.enteredBus)) {
      throw StateError('No boarded riders are assigned to this stop today.');
    }
    if (stop.status == DriverAfternoonStopStatus.departed) return run;
    if (stop.status != DriverAfternoonStopStatus.pending) {
      throw StateError('This stop cannot be opened from its current state.');
    }

    for (var i = 0; i < index; i++) {
      final earlier = run.stops[i];
      final relevant = earlier.riders.any((rider) => rider.status.enteredBus);
      if (relevant && earlier.status != DriverAfternoonStopStatus.departed) {
        throw StateError('Complete the previous rider stop before continuing.');
      }
    }

    final stops = [...run.stops];
    stops[index] = stop.copyWith(
      status: DriverAfternoonStopStatus.active,
      arrivedAt: _now(),
    );
    final updated = run.copyWith(stops: stops);
    await _save(
      member,
      updated,
      eventType: 'afternoon_stop_arrived',
      details: {'stopId': stop.id, 'sequence': stop.sequence},
    );
    return updated;
  }

  Future<DriverAfternoonRun> setDropStatus({
    required String stopId,
    required String studentId,
    required DriverAfternoonRiderStatus status,
    String note = '',
  }) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    if (!const {
      DriverAfternoonRiderStatus.droppedGuardian,
      DriverAfternoonRiderStatus.droppedApprovedPoint,
      DriverAfternoonRiderStatus.guardianUnavailable,
      DriverAfternoonRiderStatus.dropException,
    }.contains(status)) {
      throw ArgumentError('Choose a valid drop-off status.');
    }
    if ((status == DriverAfternoonRiderStatus.guardianUnavailable ||
            status == DriverAfternoonRiderStatus.dropException) &&
        note.trim().isEmpty) {
      throw ArgumentError('Add a short note explaining the drop-off exception.');
    }

    final stopIndex = run.stops.indexWhere((stop) => stop.id == stopId);
    if (stopIndex < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[stopIndex];
    if (stop.status != DriverAfternoonStopStatus.active) {
      throw StateError('Open this stop before recording drop-off status.');
    }
    final riderIndex =
        stop.riders.indexWhere((rider) => rider.studentId == studentId);
    if (riderIndex < 0) {
      throw ArgumentError('This student is not assigned to the selected stop.');
    }
    final rider = stop.riders[riderIndex];
    if (rider.status != DriverAfternoonRiderStatus.boarded) {
      throw StateError('Only a student currently boarded for this stop can be released here.');
    }

    final updated = _replaceRider(
      run,
      stopIndex,
      riderIndex,
      rider.copyWith(
        status: status,
        note: note.trim(),
        updatedAt: _now(),
      ),
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_drop_status_recorded',
      details: {
        'studentId': studentId,
        'stopId': stopId,
        'status': status.name,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return updated;
  }

  Future<DriverAfternoonRun> departStop(String stopId) async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    final index = run.stops.indexWhere((stop) => stop.id == stopId);
    if (index < 0) throw ArgumentError('Stop not found on this route.');
    final stop = run.stops[index];
    if (stop.status == DriverAfternoonStopStatus.departed) return run;
    if (stop.status != DriverAfternoonStopStatus.active) {
      throw StateError('Arrive at this stop before departing it.');
    }
    if (!stop.allBoardedRidersResolvedAtStop) {
      final unresolved = stop.riders
          .where((rider) => rider.status == DriverAfternoonRiderStatus.boarded)
          .length;
      throw StateError(
        '$unresolved boarded rider${unresolved == 1 ? '' : 's'} still need a drop-off status.',
      );
    }

    final stops = [...run.stops];
    stops[index] = stop.copyWith(
      status: DriverAfternoonStopStatus.departed,
      departedAt: _now(),
    );
    final updated = run.copyWith(stops: stops);
    await _save(
      member,
      updated,
      eventType: 'afternoon_stop_departed',
      details: {
        'stopId': stop.id,
        'released': stop.safelyReleasedCount,
        'exceptions': stop.exceptionCount,
      },
    );
    return updated;
  }

  Future<DriverAfternoonRun> confirmReturnToSchool() async {
    final member = _requireDriver();
    final run = await loadToday();
    _requireInProgress(run);
    if (!run.allRelevantStopsDeparted) {
      throw StateError('Complete every rider stop before returning to school.');
    }
    if (run.stillOnBus == 0) {
      throw StateError('No students remain onboard for return to school.');
    }

    final at = _now();
    final stops = [
      for (final stop in run.stops)
        stop.copyWith(
          riders: [
            for (final rider in stop.riders)
              if (rider.status == DriverAfternoonRiderStatus.guardianUnavailable ||
                  rider.status == DriverAfternoonRiderStatus.dropException)
                rider.copyWith(
                  status: DriverAfternoonRiderStatus.returnedSchool,
                  updatedAt: at,
                )
              else
                rider,
          ],
        ),
    ];
    final updated = run.copyWith(
      stops: stops,
      status: DriverAfternoonRunStatus.returnedSchool,
      returnedSchoolAt: at,
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_students_returned_school',
      details: {
        'returnedRiders': updated.riders
            .where((rider) =>
                rider.status == DriverAfternoonRiderStatus.returnedSchool)
            .length,
      },
    );
    return updated;
  }

  Future<DriverAfternoonRun> completeRun() async {
    final member = _requireDriver();
    final run = await loadToday();
    if (run.status == DriverAfternoonRunStatus.completed) return run;
    if (run.status != DriverAfternoonRunStatus.inProgress &&
        run.status != DriverAfternoonRunStatus.returnedSchool) {
      throw StateError('The afternoon route is not ready to complete.');
    }
    if (!run.allRelevantStopsDeparted) {
      throw StateError('Complete every rider stop before finishing the route.');
    }
    if (run.stillOnBus > 0) {
      throw StateError(
        '${run.stillOnBus} student${run.stillOnBus == 1 ? '' : 's'} still remain onboard. Record a safe return to school first.',
      );
    }

    final updated = run.copyWith(
      status: DriverAfternoonRunStatus.completed,
      completedAt: _now(),
    );
    await _save(
      member,
      updated,
      eventType: 'afternoon_run_completed',
      details: {
        'safeReleaseCount': updated.safeDropCount,
        'exceptions': updated.exceptions,
      },
    );
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
    if (record != null) {
      return DriverTransportAssignment.fromJson(record.payload);
    }

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
    DriverAfternoonRun run,
    SchoolMembership member,
    DriverTransportAssignment assignment,
  ) {
    if (run.membershipId != member.id || run.routeId != assignment.routeId) {
      throw StateError('This afternoon run does not belong to the active Driver membership.');
    }
  }

  void _requireInProgress(DriverAfternoonRun run) {
    if (run.status != DriverAfternoonRunStatus.inProgress) {
      throw StateError('Depart school before recording route drop-off activity.');
    }
  }

  _AfternoonRiderLocation _findRider(
    DriverAfternoonRun run,
    String studentId,
  ) {
    for (var stopIndex = 0; stopIndex < run.stops.length; stopIndex++) {
      final riders = run.stops[stopIndex].riders;
      for (var riderIndex = 0; riderIndex < riders.length; riderIndex++) {
        if (riders[riderIndex].studentId == studentId) {
          return _AfternoonRiderLocation(
            stopIndex: stopIndex,
            riderIndex: riderIndex,
            rider: riders[riderIndex],
          );
        }
      }
    }
    throw ArgumentError('This student is not on the assigned afternoon manifest.');
  }

  DriverAfternoonRun _replaceRider(
    DriverAfternoonRun run,
    int stopIndex,
    int riderIndex,
    DriverAfternoonRider rider,
  ) {
    final stop = run.stops[stopIndex];
    final riders = [...stop.riders];
    riders[riderIndex] = rider;
    final stops = [...run.stops];
    stops[stopIndex] = stop.copyWith(riders: riders);
    return run.copyWith(stops: stops);
  }

  Future<void> _save(
    SchoolMembership member,
    DriverAfternoonRun run, {
    required String eventType,
    Map<String, Object?> details = const {},
  }) async {
    final at = _now();
    final existing = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: run.id,
    );
    final payload = {
      ...run.toJson(),
      'updatedAt': at,
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

    final eventId =
        '${run.id}:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final eventPayload = <String, Object?>{
      'id': eventId,
      'runId': run.id,
      'routeId': run.routeId,
      'serviceDate': run.serviceDate,
      'direction': 'school_to_home',
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _runId(String membershipId, String serviceDate) =>
      '$membershipId:afternoon:$serviceDate';

  String _now() => DateTime.now().toUtc().toIso8601String();
}

class _AfternoonRiderLocation {
  const _AfternoonRiderLocation({
    required this.stopIndex,
    required this.riderIndex,
    required this.rider,
  });

  final int stopIndex;
  final int riderIndex;
  final DriverAfternoonRider rider;
}
