import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/data/transport_rider_assignment_repository.dart';
import '../../transport/data/transport_route_management_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_dashboard_models.dart';
import '../domain/driver_morning_run_models.dart';
import '../domain/driver_riders_models.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_dashboard_repository.dart';
import 'driver_morning_run_repository.dart';

class DriverRidersRepository {
  DriverRidersRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _routeManagement = TransportRouteManagementRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        ),
        _riderAssignments = TransportRiderAssignmentRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;
  final TransportRouteManagementRepository _routeManagement;
  final TransportRiderAssignmentRepository _riderAssignments;

  Future<DriverRidersSnapshot> loadToday() async {
    final member = _requireDriver();
    final assignment = await _loadAssignment(member);
    final route = await _assignedRoute(assignment);
    final plan = await _routeManagement.loadPlanForRoute(route.id);
    final assignedRiders =
        await _riderAssignments.loadAssignmentsForRoute(route.id);
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
      if (morning.membershipId != member.id || morning.routeId != route.id) {
        throw StateError('The morning transport record is outside this Driver assignment.');
      }
    }

    DriverAfternoonRun? afternoon;
    if (afternoonRecord != null) {
      afternoon = DriverAfternoonRun.fromJson(afternoonRecord.payload);
      if (afternoon.membershipId != member.id || afternoon.routeId != route.id) {
        throw StateError('The afternoon transport record is outside this Driver assignment.');
      }
    }

    final morningByStudent = <String, DriverMorningRider>{};
    if (morning != null) {
      for (final stop in morning.stops) {
        for (final rider in stop.riders) {
          if (morningByStudent.containsKey(rider.studentId)) {
            throw StateError(
              'Duplicate student ${rider.studentId} in morning transport record.',
            );
          }
          morningByStudent[rider.studentId] = rider;
        }
      }
    }

    final afternoonByStudent = <String, DriverAfternoonRider>{};
    if (afternoon != null) {
      for (final stop in afternoon.stops) {
        for (final rider in stop.riders) {
          if (afternoonByStudent.containsKey(rider.studentId)) {
            throw StateError(
              'Duplicate student ${rider.studentId} in afternoon transport record.',
            );
          }
          afternoonByStudent[rider.studentId] = rider;
        }
      }
    }

    final stopById = {for (final stop in plan.activeStops) stop.id: stop};
    final riders = <DriverRiderOperationalView>[];
    for (final assignmentRecord in assignedRiders) {
      final stop = stopById[assignmentRecord.stopId];
      if (stop == null) {
        throw StateError(
          '${assignmentRecord.studentName} is assigned to a stop that is not active on ${route.name}.',
        );
      }
      final morningRider = morningByStudent[assignmentRecord.studentId];
      final afternoonRider = afternoonByStudent[assignmentRecord.studentId];
      riders.add(
        DriverRiderOperationalView(
          studentId: assignmentRecord.studentId,
          name: assignmentRecord.studentName,
          className: assignmentRecord.className,
          stopId: stop.id,
          stopSequence: stop.sequence,
          stopName: stop.name,
          morningScheduledTime: stop.morningTime,
          afternoonScheduledTime: stop.afternoonTime,
          morningStatus:
              morningRider?.status ?? DriverMorningRiderStatus.pending,
          afternoonStatus:
              afternoonRider?.status ?? DriverAfternoonRiderStatus.expected,
          morningNote: morningRider?.note ?? '',
          afternoonNote: afternoonRider?.note ?? '',
        ),
      );
    }

    riders.sort((a, b) {
      final stopCompare = a.stopSequence.compareTo(b.stopSequence);
      if (stopCompare != 0) return stopCompare;
      return a.name.compareTo(b.name);
    });

    return DriverRidersSnapshot(
      routeId: route.id,
      vehicle: route.vehicle,
      serviceDate: today,
      riders: List.unmodifiable(riders),
    );
  }

  SchoolMembership _requireDriver() {
    final member = _schoolSession.requireActiveMembership();
    if (member.role != SchoolRole.driver) {
      throw StateError(
        'Only a Driver membership can view assigned transport riders.',
      );
    }
    return member;
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
      throw StateError('No active transport route is assigned to this Driver.');
    }
    final assignment = DriverTransportAssignment.fromJson(record.payload);
    if (assignment.membershipId != member.id || !assignment.hasRoute) {
      throw StateError('No active transport route is assigned to this Driver.');
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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
