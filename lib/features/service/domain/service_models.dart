enum ServiceProjectStatus {
  planned('Planned'),
  active('Active'),
  completed('Completed');

  const ServiceProjectStatus(this.label);
  final String label;
}

class ServiceProject {
  const ServiceProject({
    required this.id,
    required this.title,
    required this.type,
    required this.audience,
    required this.coordinator,
    required this.date,
    required this.participants,
    required this.hours,
    required this.status,
    required this.beneficiary,
    required this.note,
    this.verified = false,
  });

  final String id;
  final String title;
  final String type;
  final String audience;
  final String coordinator;
  final String date;
  final int participants;
  final int hours;
  final ServiceProjectStatus status;
  final String beneficiary;
  final String note;
  final bool verified;

  bool get isContributionBased => hours == 0;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return '$title $audience $coordinator'.toLowerCase().contains(normalized);
  }

  ServiceProject copyWith({
    String? type,
    String? audience,
    String? coordinator,
    String? date,
    int? participants,
    int? hours,
    ServiceProjectStatus? status,
    String? beneficiary,
    String? note,
    bool? verified,
  }) =>
      ServiceProject(
        id: id,
        title: title,
        type: type ?? this.type,
        audience: audience ?? this.audience,
        coordinator: coordinator ?? this.coordinator,
        date: date ?? this.date,
        participants: participants ?? this.participants,
        hours: hours ?? this.hours,
        status: status ?? this.status,
        beneficiary: beneficiary ?? this.beneficiary,
        note: note ?? this.note,
        verified: verified ?? this.verified,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'audience': audience,
        'coordinator': coordinator,
        'date': date,
        'participants': participants,
        'hours': hours,
        'status': status.name,
        'beneficiary': beneficiary,
        'note': note,
        'verified': verified,
      };

  factory ServiceProject.fromJson(Map<String, dynamic> json) => ServiceProject(
        id: json['id'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        audience: json['audience'] as String,
        coordinator: json['coordinator'] as String,
        date: json['date'] as String,
        participants: json['participants'] as int,
        hours: json['hours'] as int,
        status: ServiceProjectStatus.values.byName(json['status'] as String),
        beneficiary: json['beneficiary'] as String,
        note: json['note'] as String,
        verified: json['verified'] as bool? ?? false,
      );
}

class ServiceStat {
  const ServiceStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class ServicePermissions {
  const ServicePermissions({
    required this.canCreate,
    required this.canManageAll,
    required this.canVerifyRecords,
  });

  final bool canCreate;
  final bool canManageAll;
  final bool canVerifyRecords;
}
