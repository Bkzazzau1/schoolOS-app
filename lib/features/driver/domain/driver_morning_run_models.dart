enum DriverMorningRunStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  arrivedSchool('Arrived at school'),
  completed('Completed');

  const DriverMorningRunStatus(this.label);
  final String label;
}

enum DriverMorningStopStatus {
  pending('Pending'),
  active('Active'),
  departed('Departed');

  const DriverMorningStopStatus(this.label);
  final String label;
}

enum DriverMorningRiderStatus {
  pending('Waiting'),
  boarded('Boarded'),
  noShow('No-show'),
  guardianCancelled('Guardian cancelled'),
  exception('Exception'),
  arrivedSchool('Arrived at school');

  const DriverMorningRiderStatus(this.label);
  final String label;

  bool get resolvedAtStop => this != DriverMorningRiderStatus.pending;
  bool get boardedBus =>
      this == DriverMorningRiderStatus.boarded ||
      this == DriverMorningRiderStatus.arrivedSchool;
}

class DriverMorningRider {
  const DriverMorningRider({
    required this.studentId,
    required this.name,
    required this.className,
    required this.stopId,
    this.status = DriverMorningRiderStatus.pending,
    this.note = '',
    this.updatedAt = '',
  });

  final String studentId;
  final String name;
  final String className;
  final String stopId;
  final DriverMorningRiderStatus status;
  final String note;
  final String updatedAt;

  DriverMorningRider copyWith({
    DriverMorningRiderStatus? status,
    String? note,
    String? updatedAt,
  }) =>
      DriverMorningRider(
        studentId: studentId,
        name: name,
        className: className,
        stopId: stopId,
        status: status ?? this.status,
        note: note ?? this.note,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'name': name,
        'className': className,
        'stopId': stopId,
        'status': status.name,
        'note': note,
        'updatedAt': updatedAt,
      };

  factory DriverMorningRider.fromJson(Map<String, Object?> json) =>
      DriverMorningRider(
        studentId: json['studentId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        className: json['className'] as String? ?? '',
        stopId: json['stopId'] as String? ?? '',
        status: DriverMorningRiderStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverMorningRiderStatus.pending,
        ),
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

class DriverMorningStop {
  const DriverMorningStop({
    required this.id,
    required this.sequence,
    required this.name,
    required this.scheduledTime,
    required this.riders,
    this.status = DriverMorningStopStatus.pending,
    this.arrivedAt = '',
    this.departedAt = '',
  });

  final String id;
  final int sequence;
  final String name;
  final String scheduledTime;
  final List<DriverMorningRider> riders;
  final DriverMorningStopStatus status;
  final String arrivedAt;
  final String departedAt;

  int get resolvedCount =>
      riders.where((rider) => rider.status.resolvedAtStop).length;
  int get boardedCount => riders.where((rider) => rider.status.boardedBus).length;
  int get exceptionCount => riders
      .where(
        (rider) =>
            rider.status == DriverMorningRiderStatus.noShow ||
            rider.status == DriverMorningRiderStatus.guardianCancelled ||
            rider.status == DriverMorningRiderStatus.exception,
      )
      .length;
  bool get allRidersResolved => riders.every((rider) => rider.status.resolvedAtStop);

  DriverMorningStop copyWith({
    List<DriverMorningRider>? riders,
    DriverMorningStopStatus? status,
    String? arrivedAt,
    String? departedAt,
  }) =>
      DriverMorningStop(
        id: id,
        sequence: sequence,
        name: name,
        scheduledTime: scheduledTime,
        riders: riders ?? this.riders,
        status: status ?? this.status,
        arrivedAt: arrivedAt ?? this.arrivedAt,
        departedAt: departedAt ?? this.departedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sequence': sequence,
        'name': name,
        'scheduledTime': scheduledTime,
        'riders': [for (final rider in riders) rider.toJson()],
        'status': status.name,
        'arrivedAt': arrivedAt,
        'departedAt': departedAt,
      };

  factory DriverMorningStop.fromJson(Map<String, Object?> json) =>
      DriverMorningStop(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        scheduledTime: json['scheduledTime'] as String? ?? '',
        riders: [
          for (final item in (json['riders'] as List? ?? const []))
            DriverMorningRider.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        status: DriverMorningStopStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverMorningStopStatus.pending,
        ),
        arrivedAt: json['arrivedAt'] as String? ?? '',
        departedAt: json['departedAt'] as String? ?? '',
      );
}

class DriverMorningRun {
  const DriverMorningRun({
    required this.id,
    required this.membershipId,
    required this.routeId,
    required this.serviceDate,
    required this.vehicle,
    required this.driverName,
    required this.assistantName,
    required this.stops,
    this.status = DriverMorningRunStatus.notStarted,
    this.startedAt = '',
    this.arrivedSchoolAt = '',
    this.completedAt = '',
  });

  final String id;
  final String membershipId;
  final String routeId;
  final String serviceDate;
  final String vehicle;
  final String driverName;
  final String assistantName;
  final List<DriverMorningStop> stops;
  final DriverMorningRunStatus status;
  final String startedAt;
  final String arrivedSchoolAt;
  final String completedAt;

  int get expectedRiders =>
      stops.fold(0, (total, stop) => total + stop.riders.length);
  int get boardedRiders => stops.fold(0, (total, stop) => total + stop.boardedCount);
  int get exceptions => stops.fold(0, (total, stop) => total + stop.exceptionCount);
  int get pendingRiders => stops.fold(
        0,
        (total, stop) =>
            total + stop.riders.where((rider) => rider.status == DriverMorningRiderStatus.pending).length,
      );
  int get arrivedSchoolRiders => stops.fold(
        0,
        (total, stop) =>
            total +
            stop.riders
                .where((rider) => rider.status == DriverMorningRiderStatus.arrivedSchool)
                .length,
      );

  DriverMorningStop? get activeStop {
    for (final stop in stops) {
      if (stop.status == DriverMorningStopStatus.active) return stop;
    }
    return null;
  }

  DriverMorningStop? get nextPendingStop {
    for (final stop in stops) {
      if (stop.status == DriverMorningStopStatus.pending) return stop;
    }
    return null;
  }

  bool get allStopsDeparted =>
      stops.every((stop) => stop.status == DriverMorningStopStatus.departed);

  DriverMorningRun copyWith({
    List<DriverMorningStop>? stops,
    DriverMorningRunStatus? status,
    String? startedAt,
    String? arrivedSchoolAt,
    String? completedAt,
  }) =>
      DriverMorningRun(
        id: id,
        membershipId: membershipId,
        routeId: routeId,
        serviceDate: serviceDate,
        vehicle: vehicle,
        driverName: driverName,
        assistantName: assistantName,
        stops: stops ?? this.stops,
        status: status ?? this.status,
        startedAt: startedAt ?? this.startedAt,
        arrivedSchoolAt: arrivedSchoolAt ?? this.arrivedSchoolAt,
        completedAt: completedAt ?? this.completedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'membershipId': membershipId,
        'routeId': routeId,
        'serviceDate': serviceDate,
        'vehicle': vehicle,
        'driverName': driverName,
        'assistantName': assistantName,
        'stops': [for (final stop in stops) stop.toJson()],
        'status': status.name,
        'startedAt': startedAt,
        'arrivedSchoolAt': arrivedSchoolAt,
        'completedAt': completedAt,
      };

  factory DriverMorningRun.fromJson(Map<String, Object?> json) => DriverMorningRun(
        id: json['id'] as String? ?? '',
        membershipId: json['membershipId'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        serviceDate: json['serviceDate'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        driverName: json['driverName'] as String? ?? '',
        assistantName: json['assistantName'] as String? ?? '',
        stops: [
          for (final item in (json['stops'] as List? ?? const []))
            DriverMorningStop.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        status: DriverMorningRunStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverMorningRunStatus.notStarted,
        ),
        startedAt: json['startedAt'] as String? ?? '',
        arrivedSchoolAt: json['arrivedSchoolAt'] as String? ?? '',
        completedAt: json['completedAt'] as String? ?? '',
      );
}
