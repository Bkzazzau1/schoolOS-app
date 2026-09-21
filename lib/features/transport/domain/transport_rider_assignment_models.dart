class TransportRiderAssignment {
  const TransportRiderAssignment({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.routeId,
    required this.stopId,
    this.active = true,
    this.assignedAt = '',
    this.assignedByMembershipId = '',
  });

  final String studentId;
  final String studentName;
  final String className;
  final String routeId;
  final String stopId;
  final bool active;
  final String assignedAt;
  final String assignedByMembershipId;

  bool get assigned => active && routeId.isNotEmpty && stopId.isNotEmpty;

  TransportRiderAssignment copyWith({
    String? studentName,
    String? className,
    String? routeId,
    String? stopId,
    bool? active,
    String? assignedAt,
    String? assignedByMembershipId,
  }) =>
      TransportRiderAssignment(
        studentId: studentId,
        studentName: studentName ?? this.studentName,
        className: className ?? this.className,
        routeId: routeId ?? this.routeId,
        stopId: stopId ?? this.stopId,
        active: active ?? this.active,
        assignedAt: assignedAt ?? this.assignedAt,
        assignedByMembershipId:
            assignedByMembershipId ?? this.assignedByMembershipId,
      );

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'routeId': routeId,
        'stopId': stopId,
        'active': active,
        'assignedAt': assignedAt,
        'assignedByMembershipId': assignedByMembershipId,
      };

  factory TransportRiderAssignment.fromJson(Map<String, Object?> json) {
    final active = json['active'] as bool? ?? true;
    return TransportRiderAssignment(
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      routeId: active ? json['routeId'] as String? ?? '' : '',
      stopId: active ? json['stopId'] as String? ?? '' : '',
      active: active,
      assignedAt: json['assignedAt'] as String? ?? '',
      assignedByMembershipId:
          json['assignedByMembershipId'] as String? ?? '',
    );
  }
}

class TransportRiderCandidate {
  const TransportRiderCandidate({
    required this.studentId,
    required this.name,
    required this.className,
    required this.currentRouteId,
    required this.currentStopId,
  });

  final String studentId;
  final String name;
  final String className;
  final String currentRouteId;
  final String currentStopId;

  bool get assigned => currentRouteId.isNotEmpty && currentStopId.isNotEmpty;
}

class TransportRiderAssignmentSnapshot {
  const TransportRiderAssignmentSnapshot({
    required this.riders,
    required this.canManage,
  });

  final List<TransportRiderCandidate> riders;
  final bool canManage;

  int get assignedCount => riders.where((rider) => rider.assigned).length;
  int get unassignedCount => riders.length - assignedCount;
}
