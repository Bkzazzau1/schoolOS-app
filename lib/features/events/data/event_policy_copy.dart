import '../domain/event_models.dart';

/// Static guidance copy for Events & School Calendar - not data about this school, so it never
/// needs a real backend source. Real activity (events) lives in [EventRepository] instead.
const eventAuthorityRule =
    'A section leader may create events for their section; whole-school events require school-wide authority. Parents and students see only events targeted to them.';

const eventAcademicBoundary =
    'Academic timetable periods remain separate from the shared school calendar.';

const eventFutureIntegrations = <String, String>{
  'Noticeboard': 'Turn an event into an official announcement.',
  'Activities & Clubs': 'Link fixtures, club sessions and showcases.',
  'Excursions': 'Attach consent and transport requirements.',
};

class EventStat {
  const EventStat(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

/// Computed from [events] - the real, locally-held events a school has actually created, never a
/// fixed sample count. "This month" and "Parent-facing" are deliberately left out: [SchoolEvent.date]
/// and [SchoolEvent.audience] are free text a manager can type anything into, so there is no reliable
/// way to compute either without risking a silently wrong classification.
List<EventStat> eventStats(List<SchoolEvent> events) => [
      EventStat('Total events', '${events.length}', 'Across the whole calendar'),
      EventStat(
        'Upcoming events',
        '${events.where((e) => e.isUpcoming).length}',
        'Across current calendar',
      ),
      EventStat(
        'Registration open',
        '${events.where((e) => e.status == SchoolEventStatus.registrationOpen).length}',
        'Open for sign-up',
      ),
    ];
