enum TransportControlPhase {
  maintenance('Maintenance'),
  preparing('Preparing'),
  morningRoute('Morning route'),
  atSchool('At school'),
  afternoonBoarding('Afternoon boarding'),
  afternoonRoute('Afternoon route'),
  returnedSchool('Returned to school'),
  completed('Service completed'),
  baselineOnly('No live driver record');

  const TransportControlPhase(this.label);
  final String label;
}

class TransportControlRouteActivity {
  const TransportControlRouteActivity({
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.driverName,
    required this.phase,
    required this.morningSummary,
    required this.afternoonSummary,
    required this.expectedRiders,
    required this.currentlyOnBoard,
    required this.incidentCount,
    required this.urgentIncidentCount,
    required this.vehicleDefectCount,
    required this.blockingVehicleDefectCount,
    required this.hasDriverActivity,
    this.driverMembershipId = '',
  });

  final String routeId;
  final String routeName;
  final String vehicle;
  final String driverName;
  final String driverMembershipId;
  final TransportControlPhase phase;
  final String morningSummary;
  final String afternoonSummary;
  final int expectedRiders;
  final int currentlyOnBoard;
  final int incidentCount;
  final int urgentIncidentCount;
  final int vehicleDefectCount;
  final int blockingVehicleDefectCount;
  final bool hasDriverActivity;

  bool get needsAttention =>
      currentlyOnBoard > 0 ||
      urgentIncidentCount > 0 ||
      blockingVehicleDefectCount > 0 ||
      phase == TransportControlPhase.returnedSchool;
}

class TransportControlSnapshot {
  const TransportControlSnapshot({
    required this.serviceDate,
    required this.routes,
  });

  final String serviceDate;
  final List<TransportControlRouteActivity> routes;

  int get activeRuns => routes
      .where(
        (route) =>
            route.phase == TransportControlPhase.morningRoute ||
            route.phase == TransportControlPhase.afternoonRoute,
      )
      .length;

  int get ridersCurrentlyOnBoard => routes.fold<int>(
        0,
        (sum, route) => sum + route.currentlyOnBoard,
      );

  int get incidentsToday => routes.fold<int>(
        0,
        (sum, route) => sum + route.incidentCount,
      );

  int get urgentIncidentsToday => routes.fold<int>(
        0,
        (sum, route) => sum + route.urgentIncidentCount,
      );

  int get vehicleDefectsToday => routes.fold<int>(
        0,
        (sum, route) => sum + route.vehicleDefectCount,
      );

  int get blockingVehicleDefectsToday => routes.fold<int>(
        0,
        (sum, route) => sum + route.blockingVehicleDefectCount,
      );

  int get routesNeedingAttention =>
      routes.where((route) => route.needsAttention).length;

  int get routesWithDriverActivity =>
      routes.where((route) => route.hasDriverActivity).length;
}
