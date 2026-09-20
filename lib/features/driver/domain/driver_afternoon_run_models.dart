enum DriverAfternoonRunStatus {
  notStarted('Not started'),
  boarding('Boarding at school'),
  inProgress('On route'),
  returnedSchool('Returned to school'),
  completed('Completed');

  const DriverAfternoonRunStatus(this.label);
  final String label;
}

enum DriverAfternoonStopStatus {
  pending('Pending'),
  active('Active'),
  departed('Departed');

  const DriverAfternoonStopStatus(this.label);
  final String label;
}

enum DriverAfternoonRiderStatus {
  expected('Expected'),
  boarded('Boarded'),
  guardianPickup('Guardian pickup'),
  notRiding('Not riding'),
  boardingException('Boarding exception'),
  droppedGuardian('Dropped to guardian'),
  droppedApprovedPoint('Dropped at approved point'),
  guardianUnavailable('Guardian unavailable'),
  dropException('Drop exception'),
  returnedSchool('Returned to school');

  const DriverAfternoonRiderStatus(this.label);
  final String label;

  bool get boardingResolved => this != DriverAfternoonRiderStatus.expected;

  bool get enteredBus => switch (this) {
        DriverAfternoonRiderStatus.boarded ||
        DriverAfternoonRiderStatus.droppedGuardian ||
        DriverAfternoonRiderStatus.droppedApprovedPoint ||
        DriverAfternoonRiderStatus.guardianUnavailable ||
        DriverAfternoonRiderStatus.dropException ||
        DriverAfternoonRiderStatus.returnedSchool => true,
        _ => false,
      };

  bool get safelyReleased =>
      this == DriverAfternoonRiderStatus.droppedGuardian ||
      this == DriverAfternoonRiderStatus.droppedApprovedPoint ||
      this == DriverAfternoonRiderStatus.returnedSchool;

  bool get stillOnBus =>
      this == DriverAfternoonRiderStatus.boarded ||
      this == DriverAfternoonRiderStatus.guardianUnavailable ||
      this == DriverAfternoonRiderStatus.dropException;
}

class DriverAfternoonRider {
  const DriverAfternoonRider({
    required this.studentId,
    required this.name,
    required this.className,
    required this.stopId,
    this.status = DriverAfternoonRiderStatus.expected,
    this.note = '',
    this.updatedAt = '',
  });

  final String studentId;
  final String name;
  final String className;
  final String stopId;
  final DriverAfternoonRiderStatus status;
  final String note;
  final String updatedAt;

  DriverAfternoonRider copyWith({
    DriverAfternoonRiderStatus? status,
    String? note,
    String? updatedAt,
  }) => DriverAfternoonRider(
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

  factory DriverAfternoonRider.fromJson(Map<String, Object?> json) =>
      DriverAfternoonRider(
        studentId: json['studentId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        className: json['className'] as String? ?? '',
        stopId: json['stopId'] as String? ?? '',
        status: DriverAfternoonRiderStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverAfternoonRiderStatus.expected,
        ),
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

class DriverAfternoonStop {
  const DriverAfternoonStop({
    required this.id,
    required this.sequence,
    required this.name,
    required this.scheduledTime,
    required this.riders,
    this.status = DriverAfternoonStopStatus.pending,
    this.arrivedAt = '',
    this.departedAt = '',
  });

  final String id;
  final int sequence;
  final String name;
  final String scheduledTime;
  final List<DriverAfternoonRider> riders;
  final DriverAfternoonStopStatus status;
  final String arrivedAt;
  final String departedAt;

  List<DriverAfternoonRider> get boardedForThisStop =>
      riders.where((rider) => rider.status.enteredBus).toList(growable: false);

  int get safelyReleasedCount =>
      riders.where((rider) => rider.status.safelyReleased).length;

  int get exceptionCount => riders
      .where(
        (rider) =>
            rider.status == DriverAfternoonRiderStatus.guardianUnavailable ||
            rider.status == DriverAfternoonRiderStatus.dropException,
      )
      .length;

  bool get allBoardedRidersResolvedAtStop => riders.every(
        (rider) =>
            !rider.status.enteredBus ||
            rider.status != DriverAfternoonRiderStatus.boarded,
      );

  DriverAfternoonStop copyWith({
    List<DriverAfternoonRider>? riders,
    DriverAfternoonStopStatus? status,
    String? arrivedAt,
    String? departedAt,
  }) => DriverAfternoonStop(
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

  factory DriverAfternoonStop.fromJson(Map<String, Object?> json) =>
      DriverAfternoonStop(
        id: json['id'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        scheduledTime: json['scheduledTime'] as String? ?? '',
        riders: [
          for (final item in (json['riders'] as List? ?? const []))
            DriverAfternoonRider.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        status: DriverAfternoonStopStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverAfternoonStopStatus.pending,
        ),
        arrivedAt: json['arrivedAt'] as String? ?? '',
        departedAt: json['departedAt'] as String? ?? '',
      );
}

class DriverAfternoonRun {
  const DriverAfternoonRun({
    required this.id,
    required this.membershipId,
    required this.routeId,
    required this.serviceDate,
    required this.vehicle,
    required this.driverName,
    required this.assistantName,
    required this.stops,
    this.status = DriverAfternoonRunStatus.notStarted,
    this.startedAt = '',
    this.departedSchoolAt = '',
    this.returnedSchoolAt = '',
    this.completedAt = '',
  });

  final String id;
  final String membershipId;
  final String routeId;
  final String serviceDate;
  final String vehicle;
  final String driverName;
  final String assistantName;
  final List<DriverAfternoonStop> stops;
  final DriverAfternoonRunStatus status;
  final String startedAt;
  final String departedSchoolAt;
  final String returnedSchoolAt;
  final String completedAt;

  List<DriverAfternoonRider> get riders => [
        for (final stop in stops) ...stop.riders,
      ];

  int get expectedRiders => riders.length;
  int get boardedRiders => riders.where((rider) => rider.status.enteredBus).length;
  int get safeDropCount => riders.where((rider) => rider.status.safelyReleased).length;
  int get guardianPickupCount => riders
      .where((rider) => rider.status == DriverAfternoonRiderStatus.guardianPickup)
      .length;
  int get notRidingCount => riders
      .where((rider) => rider.status == DriverAfternoonRiderStatus.notRiding)
      .length;
  int get exceptions => riders
      .where(
        (rider) =>
            rider.status == DriverAfternoonRiderStatus.boardingException ||
            rider.status == DriverAfternoonRiderStatus.guardianUnavailable ||
            rider.status == DriverAfternoonRiderStatus.dropException,
      )
      .length;
  int get unresolvedBoarding => riders
      .where((rider) => rider.status == DriverAfternoonRiderStatus.expected)
      .length;
  int get stillOnBus => riders.where((rider) => rider.status.stillOnBus).length;

  DriverAfternoonStop? get activeStop {
    for (final stop in stops) {
      if (stop.status == DriverAfternoonStopStatus.active) return stop;
    }
    return null;
  }

  DriverAfternoonStop? get nextPendingStop {
    for (final stop in stops) {
      if (stop.status == DriverAfternoonStopStatus.pending &&
          stop.riders.any((rider) => rider.status.enteredBus)) {
        return stop;
      }
    }
    return null;
  }

  bool get allRelevantStopsDeparted => stops.every(
        (stop) =>
            !stop.riders.any((rider) => rider.status.enteredBus) ||
            stop.status == DriverAfternoonStopStatus.departed,
      );

  DriverAfternoonRun copyWith({
    List<DriverAfternoonStop>? stops,
    DriverAfternoonRunStatus? status,
    String? startedAt,
    String? departedSchoolAt,
    String? returnedSchoolAt,
    String? completedAt,
  }) => DriverAfternoonRun(
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
        departedSchoolAt: departedSchoolAt ?? this.departedSchoolAt,
        returnedSchoolAt: returnedSchoolAt ?? this.returnedSchoolAt,
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
        'departedSchoolAt': departedSchoolAt,
        'returnedSchoolAt': returnedSchoolAt,
        'completedAt': completedAt,
      };

  factory DriverAfternoonRun.fromJson(Map<String, Object?> json) =>
      DriverAfternoonRun(
        id: json['id'] as String? ?? '',
        membershipId: json['membershipId'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        serviceDate: json['serviceDate'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        driverName: json['driverName'] as String? ?? '',
        assistantName: json['assistantName'] as String? ?? '',
        stops: [
          for (final item in (json['stops'] as List? ?? const []))
            DriverAfternoonStop.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        status: DriverAfternoonRunStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverAfternoonRunStatus.notStarted,
        ),
        startedAt: json['startedAt'] as String? ?? '',
        departedSchoolAt: json['departedSchoolAt'] as String? ?? '',
        returnedSchoolAt: json['returnedSchoolAt'] as String? ?? '',
        completedAt: json['completedAt'] as String? ?? '',
      );
}
