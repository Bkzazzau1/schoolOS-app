enum DriverVehicleCheckPeriod {
  morning('Morning'),
  afternoon('Afternoon');

  const DriverVehicleCheckPeriod(this.label);
  final String label;
}

enum DriverVehicleCheckItemStatus {
  unchecked('Unchecked'),
  passed('Pass'),
  failed('Fail');

  const DriverVehicleCheckItemStatus(this.label);
  final String label;
}

enum DriverVehicleCheckSeverity {
  critical('Must pass before departure'),
  advisory('Report and monitor');

  const DriverVehicleCheckSeverity(this.label);
  final String label;
}

enum DriverVehicleCheckStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  ready('Ready for trip'),
  blocked('Blocked — defect review required');

  const DriverVehicleCheckStatus(this.label);
  final String label;
}

class DriverVehicleCheckItem {
  const DriverVehicleCheckItem({
    required this.id,
    required this.label,
    required this.description,
    required this.severity,
    this.status = DriverVehicleCheckItemStatus.unchecked,
    this.note = '',
    this.updatedAt = '',
  });

  final String id;
  final String label;
  final String description;
  final DriverVehicleCheckSeverity severity;
  final DriverVehicleCheckItemStatus status;
  final String note;
  final String updatedAt;

  bool get isChecked => status != DriverVehicleCheckItemStatus.unchecked;
  bool get failed => status == DriverVehicleCheckItemStatus.failed;
  bool get blocksTrip => failed && severity == DriverVehicleCheckSeverity.critical;

  DriverVehicleCheckItem copyWith({
    DriverVehicleCheckItemStatus? status,
    String? note,
    String? updatedAt,
  }) => DriverVehicleCheckItem(
        id: id,
        label: label,
        description: description,
        severity: severity,
        status: status ?? this.status,
        note: note ?? this.note,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'severity': severity.name,
        'status': status.name,
        'note': note,
        'updatedAt': updatedAt,
      };

  factory DriverVehicleCheckItem.fromJson(Map<String, Object?> json) =>
      DriverVehicleCheckItem(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        description: json['description'] as String? ?? '',
        severity: DriverVehicleCheckSeverity.values.firstWhere(
          (value) => value.name == json['severity'],
          orElse: () => DriverVehicleCheckSeverity.critical,
        ),
        status: DriverVehicleCheckItemStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverVehicleCheckItemStatus.unchecked,
        ),
        note: json['note'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}

class DriverVehicleCheck {
  const DriverVehicleCheck({
    required this.id,
    required this.membershipId,
    required this.routeId,
    required this.vehicle,
    required this.serviceDate,
    required this.period,
    required this.items,
    this.status = DriverVehicleCheckStatus.notStarted,
    this.submittedAt = '',
  });

  final String id;
  final String membershipId;
  final String routeId;
  final String vehicle;
  final String serviceDate;
  final DriverVehicleCheckPeriod period;
  final List<DriverVehicleCheckItem> items;
  final DriverVehicleCheckStatus status;
  final String submittedAt;

  bool get allChecked => items.isNotEmpty && items.every((item) => item.isChecked);
  int get passedCount =>
      items.where((item) => item.status == DriverVehicleCheckItemStatus.passed).length;
  int get failedCount => items.where((item) => item.failed).length;
  int get blockingFailureCount => items.where((item) => item.blocksTrip).length;
  bool get isReady => status == DriverVehicleCheckStatus.ready;

  DriverVehicleCheck copyWith({
    List<DriverVehicleCheckItem>? items,
    DriverVehicleCheckStatus? status,
    String? submittedAt,
  }) => DriverVehicleCheck(
        id: id,
        membershipId: membershipId,
        routeId: routeId,
        vehicle: vehicle,
        serviceDate: serviceDate,
        period: period,
        items: items ?? this.items,
        status: status ?? this.status,
        submittedAt: submittedAt ?? this.submittedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'membershipId': membershipId,
        'routeId': routeId,
        'vehicle': vehicle,
        'serviceDate': serviceDate,
        'period': period.name,
        'items': [for (final item in items) item.toJson()],
        'status': status.name,
        'submittedAt': submittedAt,
      };

  factory DriverVehicleCheck.fromJson(Map<String, Object?> json) =>
      DriverVehicleCheck(
        id: json['id'] as String? ?? '',
        membershipId: json['membershipId'] as String? ?? '',
        routeId: json['routeId'] as String? ?? '',
        vehicle: json['vehicle'] as String? ?? '',
        serviceDate: json['serviceDate'] as String? ?? '',
        period: DriverVehicleCheckPeriod.values.firstWhere(
          (value) => value.name == json['period'],
          orElse: () => DriverVehicleCheckPeriod.morning,
        ),
        items: [
          for (final item in (json['items'] as List? ?? const []))
            DriverVehicleCheckItem.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
        ],
        status: DriverVehicleCheckStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DriverVehicleCheckStatus.notStarted,
        ),
        submittedAt: json['submittedAt'] as String? ?? '',
      );
}
