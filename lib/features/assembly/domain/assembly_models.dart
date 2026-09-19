enum AssemblySessionType {
  generalAssembly('General Assembly'),
  sectionAssembly('Section Assembly'),
  faithReligious('Faith / Religious'),
  civic('Civic'),
  wellbeing('Wellbeing');

  const AssemblySessionType(this.label);
  final String label;
}

class AssemblySession {
  const AssemblySession({
    required this.id,
    required this.title,
    required this.type,
    required this.audience,
    required this.day,
    required this.time,
    required this.venue,
    required this.lead,
    required this.participation,
    required this.note,
  });

  final String id;
  final String title;
  final AssemblySessionType type;
  final String audience;
  final String day;
  final String time;
  final String venue;
  final String lead;
  final String participation;
  final String note;

  bool matches(String query, AssemblySessionType? typeFilter) {
    final normalized = query.trim().toLowerCase();
    final haystack = '$title $audience $lead'.toLowerCase();
    final queryMatches = normalized.isEmpty || haystack.contains(normalized);
    final typeMatches = typeFilter == null || type == typeFilter;
    return queryMatches && typeMatches;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'audience': audience,
        'day': day,
        'time': time,
        'venue': venue,
        'lead': lead,
        'participation': participation,
        'note': note,
      };

  factory AssemblySession.fromJson(Map<String, dynamic> json) => AssemblySession(
        id: json['id'] as String,
        title: json['title'] as String,
        type: AssemblySessionType.values.byName(json['type'] as String),
        audience: json['audience'] as String,
        day: json['day'] as String,
        time: json['time'] as String,
        venue: json['venue'] as String,
        lead: json['lead'] as String,
        participation: json['participation'] as String,
        note: json['note'] as String,
      );
}

class AssemblyStat {
  const AssemblyStat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class AssemblyPermissions {
  const AssemblyPermissions({required this.canConfigureSchoolWide});

  final bool canConfigureSchoolWide;
}
