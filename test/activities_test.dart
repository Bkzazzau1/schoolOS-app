import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/activities/data/activity_policy_copy.dart';
import 'package:schoolos_app/features/activities/domain/activity_models.dart';

List<SchoolActivity> _activities() => const [
      SchoolActivity(
        id: 'ACT-TEST-1',
        name: 'Football Academy',
        type: ActivityType.sport,
        section: 'Primary + Secondary',
        coordinator: 'Mr. Daniel Musa',
        members: 64,
        schedule: 'Tue & Thu · 3:00 PM',
        venue: 'Main field',
        attendance: 92,
        consent: 'Not required',
        status: 'Active',
        icon: '⚽',
        note: 'Skill development, teamwork and inter-school fixtures.',
      ),
      SchoolActivity(
        id: 'ACT-TEST-2',
        name: 'Coding & Robotics Club',
        type: ActivityType.academicEnrichment,
        section: 'Secondary',
        coordinator: 'Mr. Samuel Ter',
        members: 42,
        schedule: 'Friday · 2:30 PM',
        venue: 'ICT Lab',
        attendance: 90,
        consent: 'Not required',
        status: 'Active',
        icon: '⌘',
        note: 'Coding challenges, simple robotics builds and digital creativity.',
      ),
    ];

void main() {
  test('activity stats are computed from the real activities given, never a fixed sample', () {
    final stats = activityStats(_activities());
    expect(stats[0].value, '2');
    expect(stats[1].value, '${64 + 42}');
    expect(stats[2].value, '2');
    expect(stats[3].value, '2');
    expect(stats[3].label, 'Dedicated workflows');

    final empty = activityStats(const []);
    expect(empty[0].value, '0');
    expect(empty[1].value, '0');
    expect(empty[2].value, '0');
  });

  test('programme types stay a fixed four-item scope', () {
    expect(ActivityType.values.map((type) => type.label).toList(), [
      'Sport',
      'Club',
      'Creative',
      'Academic enrichment',
    ]);
  });

  test('search, type and section filtering matches website behavior', () {
    final coding = _activities()[1];
    expect(coding.matches('robotics', null, null), isTrue);
    expect(coding.matches('', ActivityType.academicEnrichment, 'Secondary'), isTrue);
    expect(coding.matches('', ActivityType.sport, null), isFalse);
    expect(coding.matches('', null, 'Early Years'), isFalse);
  });

  test('activity serialization preserves operational fields', () {
    final original = _activities().first;
    final restored = SchoolActivity.fromJson(original.toJson());
    expect(restored.name, original.name);
    expect(restored.type, original.type);
    expect(restored.members, original.members);
    expect(restored.attendance, original.attendance);
    expect(restored.consent, original.consent);
  });

  test('co-curricular boundary stays separate from academic scoring', () {
    expect(activityParticipationRule, contains('must not silently become an academic ability score'));
    expect(activityTimetable.keys, containsAll(['Assembly', 'Club period', 'Sports period', 'Library / Lab / Creative']));
  });
}
