enum VisitStatus {
  expected('Expected'),
  onCampus('On campus'),
  checkedOut('Checked out'),
  review('Review');

  const VisitStatus(this.label);
  final String label;
}

class VisitorRecord {
  const VisitorRecord({
    required this.id,
    required this.visitor,
    required this.organization,
    required this.purpose,
    required this.host,
    required this.area,
    required this.arrival,
    required this.departure,
    required this.status,
    required this.pass,
    required this.note,
    this.frontDeskReviewed = false,
  });

  final String id;
  final String visitor;
  final String organization;
  final String purpose;
  final String host;
  final String area;
  final String arrival;
  final String departure;
  final VisitStatus status;
  final String pass;
  final String note;
  final bool frontDeskReviewed;

  bool matches(String query, VisitStatus? statusFilter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$visitor $organization $purpose $host'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final statusMatches = statusFilter == null || status == statusFilter;
    return queryMatches && statusMatches;
  }

  VisitorRecord copyWith({
    String? organization,
    String? purpose,
    String? host,
    String? area,
    String? arrival,
    String? departure,
    VisitStatus? status,
    String? pass,
    String? note,
    bool? frontDeskReviewed,
  }) =>
      VisitorRecord(
        id: id,
        visitor: visitor,
        organization: organization ?? this.organization,
        purpose: purpose ?? this.purpose,
        host: host ?? this.host,
        area: area ?? this.area,
        arrival: arrival ?? this.arrival,
        departure: departure ?? this.departure,
        status: status ?? this.status,
        pass: pass ?? this.pass,
        note: note ?? this.note,
        frontDeskReviewed: frontDeskReviewed ?? this.frontDeskReviewed,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'visitor': visitor,
        'organization': organization,
        'purpose': purpose,
        'host': host,
        'area': area,
        'arrival': arrival,
        'departure': departure,
        'status': status.name,
        'pass': pass,
        'note': note,
        'frontDeskReviewed': frontDeskReviewed,
      };

  factory VisitorRecord.fromJson(Map<String, dynamic> json) => VisitorRecord(
        id: json['id'] as String,
        visitor: json['visitor'] as String,
        organization: json['organization'] as String,
        purpose: json['purpose'] as String,
        host: json['host'] as String,
        area: json['area'] as String,
        arrival: json['arrival'] as String,
        departure: json['departure'] as String,
        status: VisitStatus.values.byName(json['status'] as String),
        pass: json['pass'] as String,
        note: json['note'] as String,
        frontDeskReviewed: json['frontDeskReviewed'] as bool? ?? false,
      );
}

class VisitorStat {
  const VisitorStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class VisitorPermissions {
  const VisitorPermissions({
    required this.canCreate,
    required this.canManageAll,
    required this.canReviewRecords,
  });

  final bool canCreate;
  final bool canManageAll;
  final bool canReviewRecords;
}
