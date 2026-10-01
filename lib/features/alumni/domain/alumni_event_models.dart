/// A real reunion/event the school has created for its own Alumni
/// (`apps/alumni/models.py: AlumniEvent`). `attendingCount` and `myRsvp` are both real, computed
/// server-side from real `AlumniEventRsvp` rows - never stored on the event itself, and never
/// fabricated when nobody has responded yet.
class AlumniEvent {
  const AlumniEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.timeText,
    required this.venue,
    required this.note,
    required this.attendingCount,
    required this.myRsvp,
  });

  final String id;
  final String title;
  final String date;
  final String timeText;
  final String venue;
  final String note;
  final int attendingCount;

  /// `true` attending, `false` not attending, `null` - this alumnus has never responded.
  final bool? myRsvp;

  factory AlumniEvent.fromJson(Map<String, dynamic> json) => AlumniEvent(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        date: json['date'] as String? ?? '',
        timeText: json['timeText'] as String? ?? '',
        venue: json['venue'] as String? ?? '',
        note: json['note'] as String? ?? '',
        attendingCount: (json['attendingCount'] as num?)?.toInt() ?? 0,
        myRsvp: json['myRsvp'] as bool?,
      );
}
