enum DriverRouteDirection {
  morning('Morning · Home → School'),
  afternoon('Afternoon · School → Home');

  const DriverRouteDirection(this.label);
  final String label;
}

enum DriverRouteStopState {
  pending('Pending'),
  active('Active'),
  completed('Completed'),
  noService('No riders today');

  const DriverRouteStopState(this.label);
  final String label;
}

class DriverRouteStopView {
  const DriverRouteStopView({
    required this.id,
    required this.sequence,
    required this.name,
    required this.scheduledTime,
    required this.assignedRiders,
    required this.state,
    required this.primaryCount,
    required this.secondaryCount,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  final String id;
  final int sequence;
  final String name;
  final String scheduledTime;
  final int assignedRiders;
  final DriverRouteStopState state;
  final int primaryCount;
  final int secondaryCount;
  final String primaryLabel;
  final String secondaryLabel;
}

class DriverRouteSnapshot {
  const DriverRouteSnapshot({
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.driverName,
    required this.assistantName,
    required this.serviceDate,
    required this.totalAssignedRiders,
    required this.morningStops,
    required this.afternoonStops,
  });

  final String routeId;
  final String routeName;
  final String vehicle;
  final String driverName;
  final String assistantName;
  final String serviceDate;
  final int totalAssignedRiders;
  final List<DriverRouteStopView> morningStops;
  final List<DriverRouteStopView> afternoonStops;

  List<DriverRouteStopView> stopsFor(DriverRouteDirection direction) =>
      direction == DriverRouteDirection.morning ? morningStops : afternoonStops;

  int completedStops(DriverRouteDirection direction) => stopsFor(direction)
      .where((stop) =>
          stop.state == DriverRouteStopState.completed ||
          stop.state == DriverRouteStopState.noService)
      .length;
}
