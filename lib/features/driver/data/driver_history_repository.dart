import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/driver_afternoon_run_models.dart';
import '../domain/driver_history_models.dart';
import '../domain/driver_morning_run_models.dart';
import 'driver_afternoon_run_repository.dart';
import 'driver_dashboard_repository.dart';
import 'driver_incident_repository.dart';
import 'driver_morning_run_repository.dart';
import 'driver_vehicle_check_repository.dart';

class DriverHistoryRepository {
  DriverHistoryRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _dashboardRepository = DriverDashboardRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final DriverDashboardRepository _dashboardRepository;

  Future<DriverHistorySnapshot> load() async {
    final membership = _requireDriver();
    final dashboard = await _dashboardRepository.load();

    final morningRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: DriverMorningRunRepository.entityType,
    );
    final afternoonRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: DriverAfternoonRunRepository.entityType,
    );
    final incidentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: DriverIncidentRepository.entityType,
    );
    final defectRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: DriverVehicleCheckRepository.defectEntityType,
    );

    final mornings = <String, DriverMorningRun>{};
    for (final record in morningRecords) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.membershipId == membership.id &&
          run.routeId == dashboard.assignment.routeId) {
        mornings[run.serviceDate] = run;
      }
    }

    final afternoons = <String, DriverAfternoonRun>{};
    for (final record in afternoonRecords) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.membershipId == membership.id &&
          run.routeId == dashboard.assignment.routeId) {
        afternoons[run.serviceDate] = run;
      }
    }

    final incidentCountByDate = <String, int>{};
    for (final record in incidentRecords) {
      final payload = record.payload;
      if (payload['membershipId'] != membership.id ||
          payload['routeId'] != dashboard.assignment.routeId) {
        continue;
      }
      final date = payload['serviceDate'] as String? ?? '';
      if (date.isNotEmpty) {
        incidentCountByDate[date] = (incidentCountByDate[date] ?? 0) + 1;
      }
    }

    final defectCountByDate = <String, int>{};
    for (final record in defectRecords) {
      final payload = record.payload;
      if (payload['reportedByMembershipId'] != membership.id ||
          payload['routeId'] != dashboard.assignment.routeId) {
        continue;
      }
      final date = payload['serviceDate'] as String? ?? '';
      if (date.isNotEmpty) {
        defectCountByDate[date] = (defectCountByDate[date] ?? 0) + 1;
      }
    }

    final dates = <String>{
      ...mornings.keys,
      ...afternoons.keys,
      ...incidentCountByDate.keys,
      ...defectCountByDate.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final history = <DriverTripHistoryEntry>[];
    for (final date in dates) {
      final morning = mornings[date];
      final afternoon = afternoons[date];
      history.add(
        DriverTripHistoryEntry(
          serviceDate: date,
          routeId: morning?.routeId ??
              afternoon?.routeId ??
              dashboard.assignment.routeId,
          vehicle: morning?.vehicle ?? afternoon?.vehicle ?? dashboard.route.vehicle,
          morningStatus: morning?.status.label ?? 'Not recorded',
          morningExpected: morning?.expectedRiders ?? 0,
          morningArrived: morning?.arrivedSchoolRiders ?? 0,
          morningExceptions: morning?.exceptions ?? 0,
          afternoonStatus: afternoon?.status.label ?? 'Not recorded',
          afternoonExpected: afternoon?.expectedRiders ?? 0,
          afternoonSafelyReleased: afternoon?.safeDropCount ?? 0,
          afternoonExceptions: afternoon?.exceptions ?? 0,
          incidentCount: incidentCountByDate[date] ?? 0,
          vehicleDefectCount: defectCountByDate[date] ?? 0,
        ),
      );
    }

    return DriverHistorySnapshot(
      profile: DriverProfileSummary(
        driverName: dashboard.assignment.driverDisplayName,
        membershipId: membership.id,
        schoolName: membership.schoolName,
        roleLabel: membership.roleLabel,
        routeId: dashboard.assignment.routeId,
        routeName: dashboard.route.name,
        vehicle: dashboard.route.vehicle,
        assistantName: dashboard.route.assistant,
        assignedRiders: dashboard.route.riders,
      ),
      history: List.unmodifiable(history),
    );
  }

  SchoolMembership _requireDriver() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.driver) {
      throw StateError('Trip history requires an active Driver membership.');
    }
    return membership;
  }
}
