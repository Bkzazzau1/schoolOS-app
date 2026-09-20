class DriverTripHistoryEntry {
  const DriverTripHistoryEntry({
    required this.serviceDate,
    required this.routeId,
    required this.vehicle,
    required this.morningStatus,
    required this.morningExpected,
    required this.morningArrived,
    required this.morningExceptions,
    required this.afternoonStatus,
    required this.afternoonExpected,
    required this.afternoonSafelyReleased,
    required this.afternoonExceptions,
    required this.incidentCount,
    required this.vehicleDefectCount,
  });

  final String serviceDate;
  final String routeId;
  final String vehicle;
  final String morningStatus;
  final int morningExpected;
  final int morningArrived;
  final int morningExceptions;
  final String afternoonStatus;
  final int afternoonExpected;
  final int afternoonSafelyReleased;
  final int afternoonExceptions;
  final int incidentCount;
  final int vehicleDefectCount;

  bool get morningCompleted => morningStatus == 'Completed';
  bool get afternoonCompleted => afternoonStatus == 'Completed';
  bool get serviceCompleted => morningCompleted && afternoonCompleted;
  int get totalExceptions => morningExceptions + afternoonExceptions;
}

class DriverProfileSummary {
  const DriverProfileSummary({
    required this.driverName,
    required this.membershipId,
    required this.schoolName,
    required this.roleLabel,
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.assistantName,
    required this.assignedRiders,
  });

  final String driverName;
  final String membershipId;
  final String schoolName;
  final String roleLabel;
  final String routeId;
  final String routeName;
  final String vehicle;
  final String assistantName;
  final int assignedRiders;
}

class DriverHistorySnapshot {
  const DriverHistorySnapshot({
    required this.profile,
    required this.history,
  });

  final DriverProfileSummary profile;
  final List<DriverTripHistoryEntry> history;

  int get recordedDays => history.length;
  int get completedServiceDays => history.where((item) => item.serviceCompleted).length;
  int get totalIncidents =>
      history.fold(0, (total, item) => total + item.incidentCount);
  int get totalVehicleDefects =>
      history.fold(0, (total, item) => total + item.vehicleDefectCount);
}
