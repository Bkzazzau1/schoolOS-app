import '../../driver/domain/driver_afternoon_run_models.dart';
import '../../driver/domain/driver_morning_run_models.dart';

const transportOperationalReportsBoundary =
    'Operational reports are read-only views derived from recorded Driver runs, incidents and vehicle defects. Historical records are not rewritten when a Driver, vehicle, route assignment or future route plan later changes.';

class TransportOperationalReportEntry {
  const TransportOperationalReportEntry({
    required this.serviceDate,
    required this.routeId,
    required this.routeName,
    required this.driverMembershipIds,
    required this.driverNames,
    required this.vehicles,
    required this.hasMorningRun,
    required this.morningStatus,
    required this.morningDriverMembershipId,
    required this.morningDriverName,
    required this.morningVehicle,
    required this.morningExpected,
    required this.morningArrived,
    required this.morningExceptions,
    required this.hasAfternoonRun,
    required this.afternoonStatus,
    required this.afternoonDriverMembershipId,
    required this.afternoonDriverName,
    required this.afternoonVehicle,
    required this.afternoonExpected,
    required this.afternoonSafelyReleased,
    required this.afternoonExceptions,
    required this.incidentCount,
    required this.urgentIncidentCount,
    required this.openIncidentCount,
    required this.vehicleDefectCount,
    required this.blockingVehicleDefectCount,
    required this.openVehicleDefectCount,
  });

  final String serviceDate;
  final String routeId;
  final String routeName;
  final List<String> driverMembershipIds;
  final List<String> driverNames;
  final List<String> vehicles;

  final bool hasMorningRun;
  final DriverMorningRunStatus? morningStatus;
  final String morningDriverMembershipId;
  final String morningDriverName;
  final String morningVehicle;
  final int morningExpected;
  final int morningArrived;
  final int morningExceptions;

  final bool hasAfternoonRun;
  final DriverAfternoonRunStatus? afternoonStatus;
  final String afternoonDriverMembershipId;
  final String afternoonDriverName;
  final String afternoonVehicle;
  final int afternoonExpected;
  final int afternoonSafelyReleased;
  final int afternoonExceptions;

  final int incidentCount;
  final int urgentIncidentCount;
  final int openIncidentCount;
  final int vehicleDefectCount;
  final int blockingVehicleDefectCount;
  final int openVehicleDefectCount;

  bool get morningCompleted =>
      morningStatus == DriverMorningRunStatus.completed;
  bool get afternoonCompleted =>
      afternoonStatus == DriverAfternoonRunStatus.completed;
  bool get serviceCompleted => morningCompleted && afternoonCompleted;

  int get totalExceptions => morningExceptions + afternoonExceptions;

  String get morningStatusLabel =>
      morningStatus?.label ?? (hasMorningRun ? 'Recorded' : 'Not recorded');
  String get afternoonStatusLabel =>
      afternoonStatus?.label ?? (hasAfternoonRun ? 'Recorded' : 'Not recorded');

  String get driverSummary => driverNames.isEmpty
      ? 'No Driver identity recorded'
      : driverNames.join(' → ');

  String get vehicleSummary =>
      vehicles.isEmpty ? 'No vehicle recorded' : vehicles.join(' → ');

  bool get hasSafetyAttention =>
      urgentIncidentCount > 0 || blockingVehicleDefectCount > 0;
}

class TransportOperationalReportsSnapshot {
  const TransportOperationalReportsSnapshot({required this.entries});

  final List<TransportOperationalReportEntry> entries;

  int get recordedRouteDays => entries.length;
  int get completedServiceDays =>
      entries.where((entry) => entry.serviceCompleted).length;
  int get totalIncidents =>
      entries.fold(0, (total, entry) => total + entry.incidentCount);
  int get urgentIncidents =>
      entries.fold(0, (total, entry) => total + entry.urgentIncidentCount);
  int get totalVehicleDefects =>
      entries.fold(0, (total, entry) => total + entry.vehicleDefectCount);
  int get blockingVehicleDefects => entries.fold(
        0,
        (total, entry) => total + entry.blockingVehicleDefectCount,
      );
  int get morningExpected =>
      entries.fold(0, (total, entry) => total + entry.morningExpected);
  int get morningArrived =>
      entries.fold(0, (total, entry) => total + entry.morningArrived);
  int get afternoonExpected =>
      entries.fold(0, (total, entry) => total + entry.afternoonExpected);
  int get afternoonSafelyReleased => entries.fold(
        0,
        (total, entry) => total + entry.afternoonSafelyReleased,
      );

  int get distinctDrivers {
    final ids = <String>{};
    for (final entry in entries) {
      ids.addAll(
        entry.driverMembershipIds.where((id) => id.trim().isNotEmpty),
      );
    }
    return ids.length;
  }

  int get distinctRoutes => entries.map((entry) => entry.routeId).toSet().length;
}
