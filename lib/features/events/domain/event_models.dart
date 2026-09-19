enum SchoolEventType {
  academic('Academic'),
  schoolWide('School-wide'),
  sports('Sports'),
  parents('Parents'),
  club('Club'),
  holiday('Holiday');

  const SchoolEventType(this.label);
  final String label;
}

enum SchoolEventStatus {
  scheduled('Scheduled'),
  registrationOpen('Registration open'),
  completed('Completed');

  const SchoolEventStatus(this.label);
  final String label;
}

class SchoolEvent {
  const SchoolEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.audience,
    required this.date,
    required this.time,
    required this.venue,
    required this.owner,
    required this.status,
    required this.note,
  });

  final String id;
  final String title;
  final SchoolEventType type;
  final String audience;
  final String date;
  final String time;
  final String venue;
  final String owner;
  final SchoolEventStatus status;
  final String note;

  bool get isUpcoming => status != SchoolEventStatus.completed;

  bool matches(String query, SchoolEventType? typeFilter) {
    final normalized = query.trim().toLowerCase();
    final searchable = '$title $audience $owner'.toLowerCase();
    final queryMatches = normalized.isEmpty || searchable.contains(normalized);
    final typeMatches = typeFilter == null || type == typeFilter;
    return queryMatches && typeMatches;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'audience': audience,
        'date': date,
        'time': time,
        'venue': venue,
        'owner': owner,
        'status': status.name,
        'note': note,
      };

  factory SchoolEvent.fromJson(Map<String, dynamic> json) => SchoolEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        type: SchoolEventType.values.byName(json['type'] as String),
        audience: json['audience'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
        venue: json['venue'] as String,
        owner: json['owner'] as String,
        status: SchoolEventStatus.values.byName(json['status'] as String),
        note: json['note'] as String,
      );
}

class EventPermissions {
  const EventPermissions({required this.canManageAll});

  final bool canManageAll;
}
