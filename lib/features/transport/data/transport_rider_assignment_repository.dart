import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_demo_data.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../driver/data/driver_morning_run_demo_data.dart';
import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';
import '../domain/transport_models.dart';
import '../domain/transport_rider_assignment_models.dart';
import '../domain/transport_route_management_models.dart';
import 'transport_route_management_repository.dart';

class TransportRiderAssignmentRepository {
  TransportRiderAssignmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _routeManagement = TransportRouteManagementRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const entityType = 'transport_rider_assignment';
  static const eventEntityType = 'transport_rider_assignment_event';
  static const studentDirectoryEntityType = 'administrator_student_directory';
  static const driverAssignmentEntityType = 'driver_transport_assignment';
  static const morningRunEntityType = 'driver_morning_run';
  static const afternoonRunEntityType = 'driver_afternoon_run';
  static const vehicleCheckEntityType = 'driver_vehicle_check';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRouteManagementRepository _routeManagement;

  bool _canView(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
        SchoolRole.principal,
      }.contains(role);

  bool _canManage(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
      }.contains(role);

  Future<TransportRiderAssignmentSnapshot> load() async {
    final member = _schoolSession.requireActiveMembership();
    if (!_canView(member.role)) {
      throw StateError(
        'Student transport assignments require a school management membership.',
      );
    }
    await _ensureInitialAssignments(member.schoolId);

    final assignments = await _loadAssignments(member.schoolId);
    final byStudent = <String, TransportRiderAssignment>{
      for (final assignment in assignments) assignment.studentId: assignment,
    };

    final directory = await _loadStudentDirectory(member.schoolId);
    final students = <String, ({String name, String className})>{};
    for (final student in directory) {
      students[student.id] = (name: student.name, className: student.className);
    }
    for (final assignment in assignments) {
      students.putIfAbsent(
        assignment.studentId,
        () => (
          name: assignment.studentName,
          className: assignment.className,
        ),
      );
    }

    final riders = <TransportRiderCandidate>[
      for (final entry in students.entries)
        TransportRiderCandidate(
          studentId: entry.key,
          name: entry.value.name,
          className: entry.value.className,
          currentRouteId: byStudent[entry.key]?.assigned == true
              ? byStudent[entry.key]!.routeId
              : '',
          currentStopId: byStudent[entry.key]?.assigned == true
              ? byStudent[entry.key]!.stopId
              : '',
        ),
    ]
      ..sort((a, b) {
        if (a.assigned != b.assigned) return a.assigned ? -1 : 1;
        final classCompare = a.className.compareTo(b.className);
        if (classCompare != 0) return classCompare;
        return a.name.compareTo(b.name);
      });

    return TransportRiderAssignmentSnapshot(
      riders: List.unmodifiable(riders),
      canManage: _canManage(member.role),
    );
  }

  /// A single real student's current transport assignment, if any — safe for a guardian to read for
  /// their own linked child, without the school-management viewer restriction [load] enforces for the
  /// full roster (a parent's own membership role is never in [_canView]). Ensures the same real
  /// initial seed [load] does, so a parent is never shown "unassigned" merely because no manager has
  /// opened the Transport screen yet in this session. It is the caller's responsibility to only ever
  /// look up a student it has already verified is really linked to the active guardian.
  Future<TransportRiderAssignment?> assignmentForStudent(String studentId) async {
    final member = _schoolSession.requireActiveMembership();
    await _ensureInitialAssignments(member.schoolId);
    final record = await _localDatabase.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: studentId,
    );
    if (record == null) return null;
    return TransportRiderAssignment.fromJson(record.payload);
  }

  Future<List<TransportRiderAssignment>> loadAssignmentsForRoute(
    String routeId,
  ) async {
    final member = _schoolSession.requireActiveMembership();
    final normalizedRouteId = routeId.trim();
    if (normalizedRouteId.isEmpty) {
      throw ArgumentError('Route id is required to load transport riders.');
    }
    await _requireRouteReadScope(member, normalizedRouteId);
    await _ensureInitialAssignments(member.schoolId);
    final assignments = await _loadAssignments(member.schoolId);
    final result = assignments
        .where(
          (item) => item.assigned && item.routeId == normalizedRouteId,
        )
        .toList(growable: false)
      ..sort((a, b) {
        final stopCompare = a.stopId.compareTo(b.stopId);
        if (stopCompare != 0) return stopCompare;
        return a.studentName.compareTo(b.studentName);
      });
    return result;
  }

  Future<TransportActionResult> assignStudent({
    required String studentId,
    required String routeId,
    required String stopId,
  }) async {
    final manager = _requireManager();
    final cleanStudentId = studentId.trim();
    final cleanRouteId = routeId.trim();
    final cleanStopId = stopId.trim();
    if (cleanStudentId.isEmpty || cleanRouteId.isEmpty || cleanStopId.isEmpty) {
      return const TransportActionResult(
        success: false,
        message: 'Choose a student, route and transport stop.',
      );
    }
    await _ensureInitialAssignments(manager.schoolId);

    final candidate = await _studentCandidate(manager.schoolId, cleanStudentId);
    if (candidate == null) {
      return const TransportActionResult(
        success: false,
        message: 'The selected student is not available in the school directory.',
      );
    }

    final plan = await _routeManagement.loadPlanForRoute(cleanRouteId);
    TransportStopDefinition? targetStop;
    for (final stop in plan.activeStops) {
      if (stop.id == cleanStopId) {
        targetStop = stop;
        break;
      }
    }
    if (targetStop == null) {
      return const TransportActionResult(
        success: false,
        message: 'The selected stop is not active on this route.',
      );
    }

    final existingRecord = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: entityType,
      entityId: cleanStudentId,
    );
    final existing = existingRecord == null
        ? null
        : TransportRiderAssignment.fromJson(existingRecord.payload);

    if (existing?.assigned == true &&
        existing!.routeId == cleanRouteId &&
        existing.stopId == cleanStopId) {
      return const TransportActionResult(
        success: true,
        message: 'This student is already assigned to the selected transport stop.',
      );
    }

    if (existing?.assigned == true &&
        await _routeLockedToday(manager.schoolId, existing!.routeId)) {
      return const TransportActionResult(
        success: false,
        message: 'The student’s current route is locked because today’s transport preparation or service has already started.',
      );
    }
    if (await _routeLockedToday(manager.schoolId, cleanRouteId)) {
      return const TransportActionResult(
        success: false,
        message: 'The target route is locked because today’s transport preparation or service has already started.',
      );
    }

    final now = _now();
    final updated = TransportRiderAssignment(
      studentId: cleanStudentId,
      studentName: candidate.name,
      className: candidate.className,
      routeId: cleanRouteId,
      stopId: cleanStopId,
      active: true,
      assignedAt: now,
      assignedByMembershipId: manager.id,
    );
    await _saveAssignment(manager, updated, existingRecord);
    await _appendEvent(
      manager: manager,
      studentId: cleanStudentId,
      eventType: existing?.assigned == true
          ? 'student_transport_reassigned'
          : 'student_transport_assigned',
      previousRouteId: existing?.routeId ?? '',
      previousStopId: existing?.stopId ?? '',
      newRouteId: cleanRouteId,
      newStopId: cleanStopId,
    );
    if (existing?.assigned == true && existing!.routeId != cleanRouteId) {
      await _syncRouteRiderCount(manager, existing.routeId);
    }
    await _syncRouteRiderCount(manager, cleanRouteId);

    return TransportActionResult(
      success: true,
      message:
          '${candidate.name} assigned to ${targetStop.name}. Saved offline and queued for sync.',
    );
  }

  Future<TransportActionResult> unassignStudent(String studentId) async {
    final manager = _requireManager();
    final cleanStudentId = studentId.trim();
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: entityType,
      entityId: cleanStudentId,
    );
    if (record == null) {
      return const TransportActionResult(
        success: true,
        message: 'This student has no active transport assignment.',
      );
    }
    final current = TransportRiderAssignment.fromJson(record.payload);
    if (!current.assigned) {
      return const TransportActionResult(
        success: true,
        message: 'This student has no active transport assignment.',
      );
    }
    if (await _routeLockedToday(manager.schoolId, current.routeId)) {
      return const TransportActionResult(
        success: false,
        message: 'This route is locked because today’s transport preparation or service has already started.',
      );
    }

    final updated = current.copyWith(
      routeId: '',
      stopId: '',
      active: false,
      assignedAt: _now(),
      assignedByMembershipId: manager.id,
    );
    await _saveAssignment(manager, updated, record);
    await _appendEvent(
      manager: manager,
      studentId: cleanStudentId,
      eventType: 'student_transport_unassigned',
      previousRouteId: current.routeId,
      previousStopId: current.stopId,
      newRouteId: '',
      newStopId: '',
    );
    await _syncRouteRiderCount(manager, current.routeId);

    return TransportActionResult(
      success: true,
      message: '${current.studentName} removed from future transport service.',
    );
  }

  Future<void> _ensureInitialAssignments(String tenantId) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: entityType,
    );
    if (existing.isNotEmpty) return;

    for (final stop in defaultBus02MorningStops()) {
      for (final rider in stop.riders) {
        final assignment = TransportRiderAssignment(
          studentId: rider.studentId,
          studentName: rider.name,
          className: rider.className,
          routeId: 'BUS-02',
          stopId: stop.id,
          active: true,
        );
        await _localDatabase.upsertLocalRecord(
          tenantId: tenantId,
          entityType: entityType,
          entityId: rider.studentId,
          payload: assignment.toJson(),
          isDirty: false,
        );
      }
    }
  }

  Future<List<TransportRiderAssignment>> _loadAssignments(String tenantId) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: entityType,
    );
    return [
      for (final record in records)
        TransportRiderAssignment.fromJson(record.payload),
    ];
  }

  Future<List<AdministratorStudentRecord>> _loadStudentDirectory(
    String tenantId,
  ) async {
    var records = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: studentDirectoryEntityType,
    );
    if (records.isEmpty) {
      for (final student in administratorStudentsWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: tenantId,
          entityType: studentDirectoryEntityType,
          entityId: student.id,
          payload: student.toJson(),
          isDirty: false,
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: tenantId,
        entityType: studentDirectoryEntityType,
      );
    }
    return [
      for (final record in records)
        AdministratorStudentRecord.fromJson(record.payload),
    ];
  }

  Future<({String name, String className})?> _studentCandidate(
    String tenantId,
    String studentId,
  ) async {
    final directory = await _loadStudentDirectory(tenantId);
    for (final student in directory) {
      if (student.id == studentId) {
        return (name: student.name, className: student.className);
      }
    }
    final record = await _localDatabase.getLocalRecord(
      tenantId: tenantId,
      entityType: entityType,
      entityId: studentId,
    );
    if (record == null) return null;
    final assignment = TransportRiderAssignment.fromJson(record.payload);
    return (name: assignment.studentName, className: assignment.className);
  }

  SchoolMembership _requireManager() {
    final member = _schoolSession.requireActiveMembership();
    if (!_canManage(member.role)) {
      throw StateError(
        'Only the Proprietor or Administrator can change student transport assignments.',
      );
    }
    return member;
  }

  Future<void> _requireRouteReadScope(
    SchoolMembership member,
    String routeId,
  ) async {
    if (member.role == SchoolRole.driver) {
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
          'Drivers can only access riders assigned to their active transport route.',
        );
      }
      return;
    }

    if (!_canView(member.role)) {
      throw StateError(
        'Transport rider rosters require an authorized school management membership.',
      );
    }
  }

  Future<bool> _routeLockedToday(String tenantId, String routeId) async {
    final today = _todayKey();
    final morningRecords = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: morningRunEntityType,
    );
    for (final record in morningRecords) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.routeId == routeId && run.serviceDate == today) return true;
    }
    final afternoonRecords = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: afternoonRunEntityType,
    );
    for (final record in afternoonRecords) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.routeId == routeId && run.serviceDate == today) return true;
    }
    final checkRecords = await _localDatabase.getLocalRecords(
      tenantId: tenantId,
      entityType: vehicleCheckEntityType,
    );
    for (final record in checkRecords) {
      if ((record.payload['routeId'] as String? ?? '') == routeId &&
          (record.payload['serviceDate'] as String? ?? '') == today) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveAssignment(
    SchoolMembership manager,
    TransportRiderAssignment assignment,
    LocalRecord? current,
  ) async {
    final payload = assignment.toJson();
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: entityType,
      entityId: assignment.studentId,
      payload: payload,
      serverVersion: current?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: entityType,
      entityId: assignment.studentId,
      operation: current == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: current?.serverVersion,
    );
  }

  Future<void> _syncRouteRiderCount(
    SchoolMembership manager,
    String routeId,
  ) async {
    if (routeId.isEmpty) return;
    final assignments = await _loadAssignments(manager.schoolId);
    final count = assignments
        .where((item) => item.assigned && item.routeId == routeId)
        .length;
    final record = await _localDatabase.getLocalRecord(
      tenantId: manager.schoolId,
      entityType: TransportRouteManagementRepository.routeEntityType,
      entityId: routeId,
    );
    if (record == null) return;
    final route = SchoolTransportRoute.fromJson(record.payload);
    final updated = route.copyWith(riders: count);
    await _localDatabase.upsertLocalRecord(
      tenantId: manager.schoolId,
      entityType: TransportRouteManagementRepository.routeEntityType,
      entityId: routeId,
      payload: updated.toJson(),
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: manager.schoolId,
      membershipId: manager.id,
      entityType: TransportRouteManagementRepository.routeEntityType,
      entityId: routeId,
      operation: SyncOperation.update,
      payload: updated.toJson(),
      baseVersion: record.serverVersion,
    );
  }

  Future<void> _appendEvent({
    required SchoolMembership manager,
    required String studentId,
    required String eventType,
    required String previousRouteId,
    required String previousStopId,
    required String newRouteId,
    required String newStopId,
  }) async {
    final id = '$studentId:$eventType:${DateTime.now().microsecondsSinceEpoch}';
    final payload = <String, Object?>{
      'id': id,
      'studentId': studentId,
      'eventType': eventType,
      'previousRouteId': previousRouteId,
      'previousStopId': previousStopId,
      'newRouteId': newRouteId,
      'newStopId': newStopId,
      'at': _now(),
      'actorMembershipId': manager.id,
      'actorRole': manager.role.name,
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
