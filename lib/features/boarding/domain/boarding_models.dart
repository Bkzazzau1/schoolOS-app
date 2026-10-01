enum DormStatus {
  normal('Normal'),
  review('Review');

  const DormStatus(this.label);
  final String label;
}

class BoardingDorm {
  const BoardingDorm({
    required this.name,
    required this.houseParent,
    required this.capacity,
    required this.occupied,
    required this.onCampus,
    required this.approvedLeave,
    required this.maintenance,
    required this.status,
    required this.note,
    this.handoverReviewed = false,
  });

  final String name;
  final String houseParent;
  final int capacity;
  final int occupied;
  final int onCampus;
  final int approvedLeave;
  final int maintenance;
  final DormStatus status;
  final String note;
  final bool handoverReviewed;

  int get vacancies => capacity - occupied;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$name $houseParent ${status.label}'
        .toLowerCase()
        .contains(normalized);
  }

  BoardingDorm copyWith({
    String? houseParent,
    int? capacity,
    int? occupied,
    int? onCampus,
    int? approvedLeave,
    int? maintenance,
    DormStatus? status,
    String? note,
    bool? handoverReviewed,
  }) =>
      BoardingDorm(
        name: name,
        houseParent: houseParent ?? this.houseParent,
        capacity: capacity ?? this.capacity,
        occupied: occupied ?? this.occupied,
        onCampus: onCampus ?? this.onCampus,
        approvedLeave: approvedLeave ?? this.approvedLeave,
        maintenance: maintenance ?? this.maintenance,
        status: status ?? this.status,
        note: note ?? this.note,
        handoverReviewed: handoverReviewed ?? this.handoverReviewed,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'houseParent': houseParent,
        'capacity': capacity,
        'occupied': occupied,
        'onCampus': onCampus,
        'approvedLeave': approvedLeave,
        'maintenance': maintenance,
        'status': status.name,
        'note': note,
        'handoverReviewed': handoverReviewed,
      };

  factory BoardingDorm.fromJson(Map<String, dynamic> json) => BoardingDorm(
        name: json['name'] as String,
        houseParent: json['houseParent'] as String,
        capacity: json['capacity'] as int,
        occupied: json['occupied'] as int,
        onCampus: json['onCampus'] as int,
        approvedLeave: json['approvedLeave'] as int,
        maintenance: json['maintenance'] as int,
        status: DormStatus.values.byName(json['status'] as String),
        note: json['note'] as String,
        handoverReviewed: json['handoverReviewed'] as bool? ?? false,
      );
}

class BoardingStat {
  const BoardingStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class BoardingPermissions {
  const BoardingPermissions({required this.canManageAll, required this.canReviewHandover});

  final bool canManageAll;
  final bool canReviewHandover;
}
