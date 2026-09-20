import '../../transport/domain/transport_models.dart';

class DriverTransportAssignment {
  const DriverTransportAssignment({
    required this.membershipId,
    required this.routeId,
    required this.driverDisplayName,
  });

  final String membershipId;
  final String routeId;
  final String driverDisplayName;

  Map<String, Object?> toJson() => {
        'membershipId': membershipId,
        'routeId': routeId,
        'driverDisplayName': driverDisplayName,
      };

  factory DriverTransportAssignment.fromJson(Map<String, dynamic> json) =>
      DriverTransportAssignment(
        membershipId: json['membershipId'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        driverDisplayName: json['driverDisplayName'] as String? ?? '',
      );
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
  final String nextAction;

  bool get routeAvailable => route.isAvailable;
  bool get morningComplete =>
      morningExpected > 0 && morningChecked >= morningExpected;
}
