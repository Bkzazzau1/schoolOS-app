enum TransportRouteStatus {
  onRoute('On route'),
  arrived('Arrived'),
  preparing('Preparing'),
  maintenance('Maintenance');

  const TransportRouteStatus(this.label);
  final String label;
}

class SchoolTransportRoute {
  const SchoolTransportRoute({
    required this.id,
    required this.name,
    required this.vehicle,
    required this.driver,
    required this.assistant,
    required this.riders,
    required this.stops,
    required this.morning,
    required this.afternoon,
    required this.status,
    required this.note,
    this.reviewed = false,
  });

  final String id;
  final String name;
  final String vehicle;
  final String driver;
  final String assistant;
  final int riders;
  final int stops;
  final String morning;
  final String afternoon;
  final TransportRouteStatus status;
  final String note;
  final bool reviewed;

  bool get isAvailable => status != TransportRouteStatus.maintenance;

  bool matches(String query, TransportRouteStatus? statusFilter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$name $vehicle $driver'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final statusMatches = statusFilter == null || status == statusFilter;
    return queryMatches && statusMatches;
  }

  SchoolTransportRoute copyWith({
    String? name,
    String? vehicle,
    String? driver,
    String? assistant,
    int? riders,
    int? stops,
    String? morning,
    String? afternoon,
    TransportRouteStatus? status,
    String? note,
    bool? reviewed,
  }) =>
      SchoolTransportRoute(
        id: id,
        name: name ?? this.name,
        vehicle: vehicle ?? this.vehicle,
        driver: driver ?? this.driver,
        assistant: assistant ?? this.assistant,
        riders: riders ?? this.riders,
        stops: stops ?? this.stops,
        morning: morning ?? this.morning,
        afternoon: afternoon ?? this.afternoon,
        status: status ?? this.status,
        note: note ?? this.note,
        reviewed: reviewed ?? this.reviewed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'vehicle': vehicle,
        'driver': driver,
        'assistant': assistant,
        'riders': riders,
        'stops': stops,
        'morning': morning,
        'afternoon': afternoon,
        'status': status.name,
        'note': note,
        'reviewed': reviewed,
      };

  factory SchoolTransportRoute.fromJson(Map<String, dynamic> json) =>
      SchoolTransportRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        vehicle: json['vehicle'] as String,
        driver: json['driver'] as String,
        assistant: json['assistant'] as String,
        riders: json['riders'] as int,
        stops: json['stops'] as int,
        morning: json['morning'] as String,
        afternoon: json['afternoon'] as String,
        status: TransportRouteStatus.values.byName(json['status'] as String),
        note: json['note'] as String,
        reviewed: json['reviewed'] as bool? ?? false,
      );
}

class TransportStat {
  const TransportStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class TransportPermissions {
  const TransportPermissions({
    required this.canReviewRoutes,
    required this.canViewOperationsControl,
    required this.canManageDriverAssignments,
    this.canManageRoutesAndStops = false,
  });

  final bool canReviewRoutes;
  final bool canViewOperationsControl;
  final bool canManageDriverAssignments;
  final bool canManageRoutesAndStops;
}
