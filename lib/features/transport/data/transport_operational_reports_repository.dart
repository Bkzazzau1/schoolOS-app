import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_incident_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';
import '../domain/transport_operational_reports_models.dart';
import 'transport_repository.dart';

class TransportOperationalReportsRepository {
  TransportOperationalReportsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _transportRepository = TransportRepository(
          localDatabase: localDatabase,
          schoolSession: schoolSession,
        );

  static const morningEntityType = 'driver_morning_run';
  static const afternoonEntityType = 'driver_afternoon_run';
  static const incidentEntityType = 'driver_transport_incident';
  static const defectEntityType = 'driver_vehicle_defect';
  static const assignmentEntityType = 'driver_transport_assignment';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TransportRepository _transportRepository;

  bool _canView(SchoolRole role) => const {
        SchoolRole.proprietor,
        SchoolRole.administrator,
        SchoolRole.principal,
      }.contains(role);

  Future<TransportOperationalReportsSnapshot> load() async {
    final member = _schoolSession.requireActiveMembership();
    if (!_canView(member.role)) {
      throw StateError(
        'Trip History & Operational Reports requires a school management membership.',
      );
    }

    final transport = await _transportRepository.load();
    final routeNames = {
      for (final route in transport.routes) route.id: route.name,
    };

    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: assignmentEntityType,
    );
    final driverNameByMembership = <String, String>{};
    for (final record in assignmentRecords) {
      final payload = record.payload;
      final membershipId = payload['membershipId'] as String? ?? record.entityId;
      final name = payload['driverDisplayName'] as String? ?? '';
      if (membershipId.trim().isNotEmpty && name.trim().isNotEmpty) {
        driverNameByMembership[membershipId] = name.trim();
      }
    }

    final aggregates = <String, _OperationalAggregate>{};

    final morningRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: morningEntityType,
    );
    for (final record in morningRecords) {
      final run = DriverMorningRun.fromJson(record.payload);
      if (run.serviceDate.trim().isEmpty || run.routeId.trim().isEmpty) continue;
      final item = aggregates.putIfAbsent(
        _key(run.serviceDate, run.routeId),
        () => _OperationalAggregate(run.serviceDate, run.routeId),
      );
      item.addDriver(run.membershipId, run.driverName);
      item.addVehicle(run.vehicle);
      item.morning = _preferMorning(item.morning, run);
    }

    final afternoonRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: afternoonEntityType,
    );
    for (final record in afternoonRecords) {
      final run = DriverAfternoonRun.fromJson(record.payload);
      if (run.serviceDate.trim().isEmpty || run.routeId.trim().isEmpty) continue;
      final item = aggregates.putIfAbsent(
        _key(run.serviceDate, run.routeId),
        () => _OperationalAggregate(run.serviceDate, run.routeId),
      );
      item.addDriver(run.membershipId, run.driverName);
      item.addVehicle(run.vehicle);
      item.afternoon = _preferAfternoon(item.afternoon, run);
    }

    final incidentRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: incidentEntityType,
    );
    for (final record in incidentRecords) {
      final incident = DriverTransportIncident.fromJson(record.payload);
      if (incident.serviceDate.trim().isEmpty || incident.routeId.trim().isEmpty) {
        continue;
      }
      final item = aggregates.putIfAbsent(
        _key(incident.serviceDate, incident.routeId),
        () => _OperationalAggregate(incident.serviceDate, incident.routeId),
      );
      item.addDriver(
        incident.membershipId,
        driverNameByMembership[incident.membershipId] ?? '',
      );
      item.addVehicle(incident.vehicle);
      item.incidentCount++;
      if (incident.isOpen) item.openIncidentCount++;
      if (incident.isOpen && incident.requiresImmediateEscalation) {
        item.urgentIncidentCount++;
      }
    }

    final defectRecords = await _localDatabase.getLocalRecords(
      tenantId: member.schoolId,
      entityType: defectEntityType,
    );
    for (final record in defectRecords) {
      final payload = record.payload;
      final serviceDate = payload['serviceDate'] as String? ?? '';
      final routeId = payload['routeId'] as String? ?? '';
      if (serviceDate.trim().isEmpty || routeId.trim().isEmpty) continue;
      final item = aggregates.putIfAbsent(
        _key(serviceDate, routeId),
        () => _OperationalAggregate(serviceDate, routeId),
      );
      final reporter = payload['reportedByMembershipId'] as String? ?? '';
      item.addDriver(reporter, driverNameByMembership[reporter] ?? '');
      item.addVehicle(payload['vehicle'] as String? ?? '');
      item.vehicleDefectCount++;

      final status = (payload['status'] as String? ?? 'reported').toLowerCase();
      final closed = const {'cleared', 'resolved', 'closed'}.contains(status);
      if (!closed) {
        item.openVehicleDefectCount++;
        if (payload['blocksTrip'] as bool? ?? false) {
          item.blockingVehicleDefectCount++;
        }
      }
    }

    final entries = <TransportOperationalReportEntry>[];
    for (final item in aggregates.values) {
      final morning = item.morning;
      final afternoon = item.afternoon;
      entries.add(
        TransportOperationalReportEntry(
          serviceDate: item.serviceDate,
          routeId: item.routeId,
          routeName: routeNames[item.routeId] ?? item.routeId,
          driverMembershipIds: List.unmodifiable(item.driverMembershipIds),
          driverNames: List.unmodifiable(item.driverNames),
          vehicles: List.unmodifiable(item.vehicles),
          hasMorningRun: morning != null,
          morningStatus: morning?.status,
          morningDriverMembershipId: morning?.membershipId ?? '',
          morningDriverName: morning?.driverName ?? '',
          morningVehicle: morning?.vehicle ?? '',
          morningExpected: morning?.expectedRiders ?? 0,
          morningArrived: morning?.arrivedSchoolRiders ?? 0,
          morningExceptions: morning?.exceptions ?? 0,
          hasAfternoonRun: afternoon != null,
          afternoonStatus: afternoon?.status,
          afternoonDriverMembershipId: afternoon?.membershipId ?? '',
          afternoonDriverName: afternoon?.driverName ?? '',
          afternoonVehicle: afternoon?.vehicle ?? '',
          afternoonExpected: afternoon?.expectedRiders ?? 0,
          afternoonSafelyReleased: afternoon?.safeDropCount ?? 0,
          afternoonExceptions: afternoon?.exceptions ?? 0,
          incidentCount: item.incidentCount,
          urgentIncidentCount: item.urgentIncidentCount,
          openIncidentCount: item.openIncidentCount,
          vehicleDefectCount: item.vehicleDefectCount,
          blockingVehicleDefectCount: item.blockingVehicleDefectCount,
          openVehicleDefectCount: item.openVehicleDefectCount,
        ),
      );
    }

    entries.sort((a, b) {
      final date = b.serviceDate.compareTo(a.serviceDate);
      if (date != 0) return date;
      return a.routeId.compareTo(b.routeId);
    });

    return TransportOperationalReportsSnapshot(
      entries: List.unmodifiable(entries),
    );
  }

  DriverMorningRun _preferMorning(
    DriverMorningRun? current,
    DriverMorningRun candidate,
  ) {
    if (current == null) return candidate;
    final currentRank = _morningRank(current.status);
    final candidateRank = _morningRank(candidate.status);
    if (candidateRank != currentRank) {
      return candidateRank > currentRank ? candidate : current;
    }
    return _evidenceTime(candidate.completedAt, candidate.arrivedSchoolAt, candidate.startedAt)
            .compareTo(
              _evidenceTime(current.completedAt, current.arrivedSchoolAt, current.startedAt),
            ) >=
        0
        ? candidate
        : current;
  }

  DriverAfternoonRun _preferAfternoon(
    DriverAfternoonRun? current,
    DriverAfternoonRun candidate,
  ) {
    if (current == null) return candidate;
    final currentRank = _afternoonRank(current.status);
    final candidateRank = _afternoonRank(candidate.status);
    if (candidateRank != currentRank) {
      return candidateRank > currentRank ? candidate : current;
    }
    return _evidenceTime(
              candidate.completedAt,
              candidate.returnedSchoolAt,
              candidate.departedSchoolAt,
              candidate.startedAt,
            ).compareTo(
              _evidenceTime(
                current.completedAt,
                current.returnedSchoolAt,
                current.departedSchoolAt,
                current.startedAt,
              ),
            ) >=
        0
        ? candidate
        : current;
  }

  int _morningRank(DriverMorningRunStatus status) => switch (status) {
        DriverMorningRunStatus.notStarted => 0,
        DriverMorningRunStatus.inProgress => 1,
        DriverMorningRunStatus.arrivedSchool => 2,
        DriverMorningRunStatus.completed => 3,
      };

  int _afternoonRank(DriverAfternoonRunStatus status) => switch (status) {
        DriverAfternoonRunStatus.notStarted => 0,
        DriverAfternoonRunStatus.boarding => 1,
        DriverAfternoonRunStatus.inProgress => 2,
        DriverAfternoonRunStatus.returnedSchool => 3,
        DriverAfternoonRunStatus.completed => 4,
      };

  DateTime _evidenceTime(String first, [
    String second = '',
    String third = '',
    String fourth = '',
  ]) {
    for (final value in [first, second, third, fourth]) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static String _key(String serviceDate, String routeId) =>
      '$serviceDate|$routeId';
}

class _OperationalAggregate {
  _OperationalAggregate(this.serviceDate, this.routeId);

  final String serviceDate;
  final String routeId;
  DriverMorningRun? morning;
  DriverAfternoonRun? afternoon;
  final List<String> driverMembershipIds = [];
  final List<String> driverNames = [];
  final List<String> vehicles = [];
  int incidentCount = 0;
  int urgentIncidentCount = 0;
  int openIncidentCount = 0;
  int vehicleDefectCount = 0;
  int blockingVehicleDefectCount = 0;
  int openVehicleDefectCount = 0;

  void addDriver(String membershipId, String name) {
    final cleanId = membershipId.trim();
    final cleanName = name.trim();
    if (cleanId.isNotEmpty && !driverMembershipIds.contains(cleanId)) {
      driverMembershipIds.add(cleanId);
    }
    if (cleanName.isNotEmpty && !driverNames.contains(cleanName)) {
      driverNames.add(cleanName);
    }
  }

  void addVehicle(String vehicle) {
    final clean = vehicle.trim();
    if (clean.isNotEmpty && !vehicles.contains(clean)) vehicles.add(clean);
  }
}
