import '../../transport/domain/transport_models.dart';

class DriverTransportAssignment {
  const DriverTransportAssignment({
    required this.membershipId,
    required this.routeId,
    required this.driverDisplayName,
    this.staffId = '',
    this.active = true,
    this.assignedAt = '',
    this.assignedByMembershipId = '',
  });

  final String membershipId;
  final String routeId;
  final String driverDisplayName;

  /// Staff directory identity where the Driver account has been linked to an
  /// approved staff record. Demo/legacy assignments may not have one yet.
  final String staffId;

  /// An inactive assignment is an explicit management unassignment. Driver
  /// Portal must not silently fall back to a demo route when this is false.
  final bool active;

  final String assignedAt;
  final String assignedByMembershipId;

  bool get hasRoute => active && routeId.trim().isNotEmpty;

  DriverTransportAssignment copyWith({
    String? routeId,
    String? driverDisplayName,
    String? staffId,
    bool? active,
    String? assignedAt,
    String? assignedByMembershipId,
  }) =>
      DriverTransportAssignment(
        membershipId: membershipId,
        routeId: routeId ?? this.routeId,
        driverDisplayName: driverDisplayName ?? this.driverDisplayName,
        staffId: staffId ?? this.staffId,
        active: active ?? this.active,
        assignedAt: assignedAt ?? this.assignedAt,
        assignedByMembershipId:
            assignedByMembershipId ?? this.assignedByMembershipId,
      );

  Map<String, Object?> toJson() => {
        'membershipId': membershipId,
        'routeId': routeId,
        'driverDisplayName': driverDisplayName,
        'staffId': staffId,
        'active': active,
        'assignedAt': assignedAt,
        'assignedByMembershipId': assignedByMembershipId,
      };

  factory DriverTransportAssignment.fromJson(Map<String, dynamic> json) {
    final active = json['active'] as bool? ?? true;
    return DriverTransportAssignment(
      membershipId: json['membershipId'] as String? ?? '',
      routeId: active ? json['routeId'] as String? ?? '' : '',
      driverDisplayName: json['driverDisplayName'] as String? ?? '',
      staffId: json['staffId'] as String? ?? '',
      active: active,
      assignedAt: json['assignedAt'] as String? ?? '',
      assignedByMembershipId:
          json['assignedByMembershipId'] as String? ?? '',
    );
  }
}

class DriverDashboardSnapshot {
  const DriverDashboardSnapshot({
    required this.assignment,
    required this.route,
    required this.morningChecked,
    required this.morningExpected,
    required this.morningExceptions,
    required this.morningSummary,
    required this.afternoonExpected,
    required this.afternoonBoarded,
    required this.afternoonSafeReleased,
    required this.afternoonStillOnBus,
    required this.afternoonSummary,
    required this.vehicleCheckRequired,
    required this.vehicleCheckSummary,
    required this.nextAction,
  });

  final DriverTransportAssignment assignment;
  final SchoolTransportRoute route;
  final int morningChecked;
  final int morningExpected;
  final int morningExceptions;
  final String morningSummary;
  final int afternoonExpected;
  final int afternoonBoarded;
  final int afternoonSafeReleased;
  final int afternoonStillOnBus;
  final String afternoonSummary;
  final bool vehicleCheckRequired;
  final String vehicleCheckSummary;
  final String nextAction;

  bool get routeAvailable => route.isAvailable;
  bool get morningComplete =>
      morningExpected > 0 && morningChecked >= morningExpected;
}
