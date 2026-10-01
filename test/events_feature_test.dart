import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/events/data/event_policy_copy.dart';
import 'package:schoolos_app/features/events/domain/event_models.dart';

List<SchoolEvent> _events() => const [
      SchoolEvent(
        id: 'EV-TEST-1',
        title: 'Parent–Teacher Conference',
        type: SchoolEventType.parents,
        audience: 'Primary + Secondary families',
        date: '18 Sep 2026',
        time: '9:00 AM–2:00 PM',
        venue: 'Classrooms',
        owner: 'Academic Leadership',
        status: SchoolEventStatus.scheduled,
        note: 'Appointment windows by class.',
      ),
      SchoolEvent(
        id: 'EV-TEST-2',
        title: 'Inter-House Sports Day',
        type: SchoolEventType.sports,
        audience: 'Whole school',
        date: '24 Sep 2026',
        time: '8:00 AM–4:00 PM',
        venue: 'Main field',
        owner: 'Sports Committee',
        status: SchoolEventStatus.registrationOpen,
        note: 'Athletics, relays and field events.',
      ),
      SchoolEvent(
        id: 'EV-TEST-3',
        title: 'Last Term Mock Exam',
        type: SchoolEventType.academic,
        audience: 'JSS 3',
        date: '1 Jan 2026',
        time: '8:00 AM',
        venue: 'Secondary blocks',
        owner: 'Principal Office',
        status: SchoolEventStatus.completed,
        note: 'Already happened.',
      ),
    ];

void main() {
  test('event stats are computed from the real events given, never a fixed sample', () {
    final stats = eventStats(_events());
    expect(stats[0].value, '3');
    expect(stats[1].value, '2', reason: 'two of the three are still upcoming');
    expect(stats[2].value, '1', reason: 'only one is registrationOpen');

    final empty = eventStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('SchoolEventType has six real types', () {
    expect(SchoolEventType.values, hasLength(6));
  });

  test('Events filtering matches type and searchable owner/audience', () {
    final sports = _events()[1];
    expect(sports.matches('Sports Committee', SchoolEventType.sports), isTrue);
    expect(sports.matches('Whole school', SchoolEventType.sports), isTrue);
    expect(sports.matches('robotics', SchoolEventType.sports), isFalse);
    expect(sports.matches('', SchoolEventType.parents), isFalse);
  });

  test('Events serialize without losing calendar fields', () {
    final event = _events().first;
    final restored = SchoolEvent.fromJson(event.toJson());
    expect(restored.id, event.id);
    expect(restored.title, event.title);
    expect(restored.type, event.type);
    expect(restored.audience, event.audience);
    expect(restored.date, event.date);
    expect(restored.time, event.time);
    expect(restored.venue, event.venue);
    expect(restored.owner, event.owner);
    expect(restored.status, event.status);
    expect(restored.note, event.note);
  });

  test('a completed event is never upcoming', () {
    expect(_events().last.isUpcoming, isFalse);
    expect(_events().first.isUpcoming, isTrue);
  });

  test('shared calendar stays separate from academic timetable', () {
    expect(eventAcademicBoundary.toLowerCase(), contains('timetable'));
    expect(eventAuthorityRule.toLowerCase(), contains('whole-school'));
    expect(eventFutureIntegrations.keys, containsAll(['Noticeboard', 'Activities & Clubs', 'Excursions']));
  });
}
