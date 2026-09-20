import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../transport/data/transport_repository.dart';
import '../../transport/domain/transport_models.dart';
import '../domain/driver_dashboard_models.dart';
import 'driver_dashboard_demo_data.dart';

class DriverDashboardRepository {
  DriverDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const assignmentEntityType = 'driver_transport_assignment';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;

  Future<DriverDashboardSnapshot> load() async {
    final membership = _requireDriver();
    final assignment = await _loadAssignment(membership);
    final transport = await _transportRepository.load();

    SchoolTransportRoute? assignedRoute;
    for (final route in transport.routes) {
      if (route.id == assignment.routeId) {
        assignedRoute = route;
        break;
      }
    }

    if (assignedRoute == null) {
      throw StateError(
        'Your assigned transport route is not available on this device yet.',
      );
    }

    final counts = _parseMorningCounts(assignedRoute.morning);
    final expected = counts.$2 > 0 ? counts.$2 : assignedRoute.riders;
    final checked = counts.$1.clamp(0, expected);
    final exceptions = (expected - checked).clamp(0, expected);

    return DriverDashboardSnapshot(
      assignment: assignment,
      route: assignedRoute,
      morningChecked: checked,
      morningExpected: expected,
      morningExceptions: exceptions,
      vehicleCheckRequired: true,
      nextAction: _nextActionFor(assignedRoute),
    );
  }

  SchoolMembership _requireDriver() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.driver) {
      throw StateError('This workspace is available only to a Driver membership.');
    }
    return membership;
  }

  Future<DriverTransportAssignment> _loadAssignment(
    SchoolMembership membership,
  ) async {
    var record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: assignmentEntityType,
      entityId: membership.id,
    );

    if (record == null) {
      final seeded = DriverTransportAssignment(
        membershipId: membership.id,
        routeId: defaultDriverAssignment.routeId,
        driverDisplayName: defaultDriverAssignment.driverDisplayName,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentEntityType,
        entityId: membership.id,
        payload: seeded.toJson(),
      );
      record = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentEntityType,
        entityId: membership.id,
      );
    }

    if (record == null) {
      throw StateError('Driver assignment could not be loaded.');
    }

    final assignment = DriverTransportAssignment.fromJson(record.payload);
    if (assignment.membershipId != membership.id ||
        assignment.routeId.trim().isEmpty) {
      throw StateError('Driver assignment is not valid for this membership.');
    }
    return assignment;
  }

  (int, int) _parseMorningCounts(String value) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(value);
    if (match == null) return (0, 0);
    return (
      int.tryParse(match.group(1) ?? '') ?? 0,
      int.tryParse(match.group(2) ?? '') ?? 0,
    );
  }

  String _nextActionFor(SchoolTransportRoute route) {
    if (!route.isAvailable) {
      return 'Vehicle unavailable — wait for transport clearance.';
    }
    return switch (route.status) {
      TransportRouteStatus.preparing => 'Complete the vehicle check before departure.',
      TransportRouteStatus.onRoute => 'Continue the active route and reconcile riders.',
      TransportRouteStatus.arrived => 'Prepare the afternoon rider manifest before dismissal.',
      TransportRouteStatus.maintenance =>
        'Vehicle unavailable — wait for transport clearance.',
    };
  }
}
