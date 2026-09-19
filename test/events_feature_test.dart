import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/events/data/event_demo_data.dart';
import 'package:schoolos_app/features/events/domain/event_models.dart';

void main() {
  test('website Events seed and KPI scope remain intact', () {
    expect(eventWebsiteSeed, hasLength(5));
    expect(eventWebsiteSeed.where((event) => event.isUpcoming), hasLength(5));
    expect(eventThisMonthCount, 3);
    expect(eventParentFacingCount, 3);
    expect(eventRegistrationOpenCount, 1);
    expect(eventCalendarConflicts, 0);
    expect(SchoolEventType.values, hasLength(6));
  });

  test('Events filtering matches type and searchable owner/audience', () {
    final sports = eventWebsiteSeed[1];
    expect(sports.matches('Sports Committee', SchoolEventType.sports), isTrue);
    expect(sports.matches('Whole school', SchoolEventType.sports), isTrue);
    expect(sports.matches('robotics', SchoolEventType.sports), isFalse);
    expect(sports.matches('', SchoolEventType.parents), isFalse);
  });

  test('Events serialize without losing calendar fields', () {
    final event = eventWebsiteSeed.first;
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

  test('shared calendar stays separate from academic timetable', () {
    expect(eventAcademicBoundary.toLowerCase(), contains('timetable'));
    expect(eventAuthorityRule.toLowerCase(), contains('whole-school'));
    expect(eventFutureIntegrations.keys, containsAll(['Noticeboard', 'Activities & Clubs', 'Excursions']));
  });
}
