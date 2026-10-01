import 'transport_models.dart';

class TransportActionResult {
  const TransportActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class TransportStopDefinition {
  const TransportStopDefinition({
    required this.id,
    required this.sequence,
    required this.name,
    required this.morningTime,
    required this.afternoonTime,
    this.active = true,
  });

  final String id;
  final int sequence;
  final String name;
  final String morningTime;
  final String afternoonTime;
  final bool active;

  TransportStopDefinition copyWith({
    int? sequence,
    String? name,
    String? morningTime,
    String? afternoonTime,
    bool? active,
  }) =>
      TransportStopDefinition(
        id: id,
        sequence: sequence ?? this.sequence,
        name: name ?? this.name,
        morningTime: morningTime ?? this.morningTime,
        afternoonTime: afternoonTime ?? this.afternoonTime,
        active: active ?? this.active,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sequence': sequence,
        'name': name,
        'morningTime': morningTime,
        'afternoonTime': afternoonTime,
        'active': active,
      };

  factory TransportStopDefinition.fromJson(Map<String, Object?> json) =>
      TransportStopDefinition(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        morningTime: json['morningTime'] as String? ?? '',
        afternoonTime: json['afternoonTime'] as String? ?? '',
        active: json['active'] as bool? ?? true,
      );
}

class TransportRoutePlan {
  const TransportRoutePlan({
    required this.routeId,
    required this.stops,
    this.updatedAt = '',
    this.updatedByMembershipId = '',
  });

  final String routeId;
  final List<TransportStopDefinition> stops;
  final String updatedAt;
  final String updatedByMembershipId;

  List<TransportStopDefinition> get activeStops {
    final result = stops.where((stop) => stop.active).toList(growable: false)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return result;
  }

  TransportRoutePlan copyWith({
    List<TransportStopDefinition>? stops,
    String? updatedAt,
    String? updatedByMembershipId,
  }) =>
      TransportRoutePlan(
        routeId: routeId,
        stops: stops ?? this.stops,
        updatedAt: updatedAt ?? this.updatedAt,
        updatedByMembershipId:
            updatedByMembershipId ?? this.updatedByMembershipId,
      );

  Map<String, Object?> toJson() => {
        'routeId': routeId,
        'stops': [for (final stop in stops) stop.toJson()],
        'updatedAt': updatedAt,
        'updatedByMembershipId': updatedByMembershipId,
      };

  factory TransportRoutePlan.fromJson(Map<String, Object?> json) =>
      TransportRoutePlan(
        routeId: json['routeId'] as String? ?? '',
        stops: [
          for (final item in (json['stops'] as List? ?? const []))
            TransportStopDefinition.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        updatedAt: json['updatedAt'] as String? ?? '',
        updatedByMembershipId: json['updatedByMembershipId'] as String? ?? '',
      );
}

class TransportRouteManagementEntry {
  const TransportRouteManagementEntry({
    required this.route,
    required this.plan,
    required this.assignedDriverName,
    required this.assignedMembershipId,
    required this.lockedForToday,
    required this.lockReason,
  });

  final SchoolTransportRoute route;
  final TransportRoutePlan plan;
  final String assignedDriverName;
  final String assignedMembershipId;
  final bool lockedForToday;
  final String lockReason;

  int get activeStopCount => plan.activeStops.length;
}

class TransportRouteManagementSnapshot {
  const TransportRouteManagementSnapshot({
    required this.routes,
    required this.canManageRoutes,
    required this.canManageStops,
  });

  final List<TransportRouteManagementEntry> routes;

  /// Create/edit the route record itself (name, vehicle, assistant, note) - mirrors
  /// apps.schoollife.specs.campus.TRANSPORT's manage=MANAGERS (proprietor, principal,
  /// administrator).
  final bool canManageRoutes;

  /// Create/edit a route's stop plan - mirrors apps.transport.route_plan's own, narrower
  /// MANAGERS (proprietor, administrator - principal excluded).
  final bool canManageStops;

  int get configuredRoutes =>
      routes.where((entry) => entry.activeStopCount > 0).length;
  int get totalStops =>
      routes.fold(0, (sum, entry) => sum + entry.activeStopCount);
  int get lockedToday => routes.where((entry) => entry.lockedForToday).length;
}
