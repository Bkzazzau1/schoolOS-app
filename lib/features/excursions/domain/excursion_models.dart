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
    this.termId = '',
    this.termName = '',
    this.sessionName = '',
    this.classId = '',
    this.className = '',
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

  /// The real academic term this trip belongs to. Empty only for trips
  /// recorded before this link existed; every new trip must pick one.
  final String termId;
  final String termName;
  final String sessionName;

  /// Which class this trip is for, when it is a single real class rather
  /// than a club or a mixed group. Empty when there is no single class.
  final String classId;
  final String className;

  /// True once this trip has a real academic term, not just a free-text
  /// audience label. Trips seeded before the term link existed may not.
  bool get hasCanonicalTerm => termId.isNotEmpty;

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
        termId: termId,
        termName: termName,
        sessionName: sessionName,
        classId: classId,
        className: className,
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
        'termId': termId,
        'termName': termName,
        'sessionName': sessionName,
        'classId': classId,
        'className': className,
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
        termId: json['termId'] as String? ?? '',
        termName: json['termName'] as String? ?? '',
        sessionName: json['sessionName'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
      );
}

class ExcursionStat {
  const ExcursionStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class ExcursionPermissions {
  const ExcursionPermissions({
    required this.canManage,
    required this.canContribute,
    required this.canReviewReadiness,
  });

  /// Proprietor, Principal or Administrator: may add or edit any trip.
  final bool canManage;

  /// Teacher: may add a trip and edit only the ones they added.
  final bool canContribute;

  /// Proprietor or Principal only: readiness sign-off is a leadership call,
  /// not an Administrator one, matching the backend's guarded field.
  final bool canReviewReadiness;

  bool get canCreateTrip => canManage || canContribute;
}
