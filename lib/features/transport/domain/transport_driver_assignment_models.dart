class TransportDriverRosterEntry {
  const TransportDriverRosterEntry({
    required this.staffId,
    required this.membershipId,
    required this.name,
    required this.jobTitle,
    required this.workArea,
    required this.accountLinked,
    required this.onboardingStatus,
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.assignmentActive,
    required this.isDemoMembership,
    required this.routeConflict,
  });

  final String staffId;
  final String membershipId;
  final String name;
  final String jobTitle;
  final String workArea;
  final bool accountLinked;
  final String onboardingStatus;
  final String routeId;
  final String routeName;
  final String vehicle;
  final bool assignmentActive;
  final bool isDemoMembership;
  final bool routeConflict;

  bool get canReceiveOperationalAssignment =>
      accountLinked && membershipId.trim().isNotEmpty;

  bool get assigned => assignmentActive && routeId.trim().isNotEmpty;
}

class TransportAssignableRoute {
  const TransportAssignableRoute({
    required this.routeId,
    required this.routeName,
    required this.vehicle,
    required this.available,
    required this.assignedMembershipId,
    required this.assignedDriverName,
    required this.activeAssignmentCount,
  });

  final String routeId;
  final String routeName;
  final String vehicle;
  final bool available;
  final String assignedMembershipId;
  final String assignedDriverName;
  final int activeAssignmentCount;

  bool get alreadyAssigned => activeAssignmentCount > 0;
  bool get hasConflict => activeAssignmentCount > 1;
}

class TransportDriverAssignmentsSnapshot {
  const TransportDriverAssignmentsSnapshot({
    required this.drivers,
    required this.routes,
    required this.canManageAssignments,
  });

  final List<TransportDriverRosterEntry> drivers;
  final List<TransportAssignableRoute> routes;
  final bool canManageAssignments;

  int get linkedDrivers => drivers.where((driver) => driver.accountLinked).length;
  int get assignedDrivers => drivers.where((driver) => driver.assigned).length;
  int get pendingActivation =>
      drivers.where((driver) => !driver.accountLinked).length;
  int get unassignedLinkedDrivers => drivers
      .where((driver) => driver.accountLinked && !driver.assigned)
      .length;
  int get conflictingRoutes => routes.where((route) => route.hasConflict).length;
}
