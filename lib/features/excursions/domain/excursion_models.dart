enum TripStatus {
  planning('Planning'),
  consentOpen('Consent open'),
  ready('Ready'),
  completed('Completed');

  const TripStatus(this.label);
  final String label;
}

class SchoolTrip {
  const SchoolTrip({
    required this.id,
    required this.title,
    required this.audience,
    required this.date,
    required this.destination,
    required this.coordinator,
    required this.students,
    required this.consentReceived,
    required this.transport,
    required this.emergency,
    required this.status,
    required this.note,
    this.readinessReviewed = false,
  });

  final String id;
  final String title;
  final String audience;
  final String date;
  final String destination;
  final String coordinator;
  final int students;
  final int consentReceived;
  final String transport;
  final String emergency;
  final TripStatus status;
  final String note;
  final bool readinessReviewed;

  int get consentOutstanding => students - consentReceived;
  int get consentPercent => students == 0 ? 0 : ((consentReceived / students) * 100).round();

  bool matches(String query, TripStatus? statusFilter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$title $audience $destination'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final statusMatches = statusFilter == null || status == statusFilter;
    return queryMatches && statusMatches;
  }

  SchoolTrip copyWith({bool? readinessReviewed}) => SchoolTrip(
        id: id,
        title: title,
        audience: audience,
        date: date,
        destination: destination,
        coordinator: coordinator,
        students: students,
        consentReceived: consentReceived,
        transport: transport,
        emergency: emergency,
        status: status,
        note: note,
        readinessReviewed: readinessReviewed ?? this.readinessReviewed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'audience': audience,
        'date': date,
        'destination': destination,
        'coordinator': coordinator,
        'students': students,
        'consentReceived': consentReceived,
        'transport': transport,
        'emergency': emergency,
        'status': status.name,
        'note': note,
        'readinessReviewed': readinessReviewed,
      };

  factory SchoolTrip.fromJson(Map<String, dynamic> json) => SchoolTrip(
        id: json['id'] as String,
        title: json['title'] as String,
        audience: json['audience'] as String,
        date: json['date'] as String,
        destination: json['destination'] as String,
        coordinator: json['coordinator'] as String,
        students: json['students'] as int,
        consentReceived: json['consentReceived'] as int,
        transport: json['transport'] as String,
        emergency: json['emergency'] as String,
        status: TripStatus.values.byName(json['status'] as String),
        note: json['note'] as String,
        readinessReviewed: json['readinessReviewed'] as bool? ?? false,
      );
}

class ExcursionStat {
  const ExcursionStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class ExcursionPermissions {
  const ExcursionPermissions({required this.canReviewReadiness});

  final bool canReviewReadiness;
}
