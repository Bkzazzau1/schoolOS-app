enum ActivityType {
  sport('Sport'),
  club('Club'),
  creative('Creative'),
  academicEnrichment('Academic enrichment');

  const ActivityType(this.label);
  final String label;
}

class SchoolActivity {
  const SchoolActivity({
    required this.id,
    required this.name,
    required this.type,
    required this.section,
    required this.coordinator,
    required this.members,
    required this.schedule,
    required this.venue,
    required this.attendance,
    required this.consent,
    required this.status,
    required this.icon,
    required this.note,
  });

  final String id;
  final String name;
  final ActivityType type;
  final String section;
  final String coordinator;
  final int members;
  final String schedule;
  final String venue;
  final int attendance;
  final String consent;
  final String status;
  final String icon;
  final String note;

  bool matches(String query, ActivityType? typeFilter, String? sectionFilter) {
    final normalized = query.trim().toLowerCase();
    final text = '$name ${type.label} $section $coordinator'.toLowerCase();
    final queryMatches = normalized.isEmpty || text.contains(normalized);
    final typeMatches = typeFilter == null || type == typeFilter;
    final sectionMatches = sectionFilter == null || section.contains(sectionFilter);
    return queryMatches && typeMatches && sectionMatches;
  }

  SchoolActivity copyWith({
    String? name,
    ActivityType? type,
    String? section,
    String? coordinator,
    int? members,
    String? schedule,
    String? venue,
    int? attendance,
    String? consent,
    String? status,
    String? icon,
    String? note,
  }) {
    return SchoolActivity(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      section: section ?? this.section,
      coordinator: coordinator ?? this.coordinator,
      members: members ?? this.members,
      schedule: schedule ?? this.schedule,
      venue: venue ?? this.venue,
      attendance: attendance ?? this.attendance,
      consent: consent ?? this.consent,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'section': section,
        'coordinator': coordinator,
        'members': members,
        'schedule': schedule,
        'venue': venue,
        'attendance': attendance,
        'consent': consent,
        'status': status,
        'icon': icon,
        'note': note,
      };

  factory SchoolActivity.fromJson(Map<String, dynamic> json) => SchoolActivity(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ActivityType.values.byName(json['type'] as String),
        section: json['section'] as String,
        coordinator: json['coordinator'] as String,
        members: json['members'] as int,
        schedule: json['schedule'] as String,
        venue: json['venue'] as String,
        attendance: json['attendance'] as int,
        consent: json['consent'] as String,
        status: json['status'] as String,
        icon: json['icon'] as String,
        note: json['note'] as String,
      );
}

class ActivityPermissions {
  const ActivityPermissions({
    required this.canManageAll,
    required this.canTakeAttendance,
  });

  final bool canManageAll;
  final bool canTakeAttendance;
}
