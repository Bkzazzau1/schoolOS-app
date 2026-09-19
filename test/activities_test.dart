import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/activities/data/activity_demo_data.dart';
import 'package:schoolos_app/features/activities/domain/activity_models.dart';

void main() {
  test('activities seed matches the website programme directory', () {
    expect(activityWebsiteSeed.length, 6);
    expect(activityWebsiteSeed.map((item) => item.id).toList(), [
      'ACT-001',
      'ACT-002',
      'ACT-003',
      'ACT-004',
      'ACT-005',
      'ACT-006',
    ]);
    expect(activityWebsiteSeed[2].name, 'Coding & Robotics Club');
    expect(activityWebsiteSeed[2].attendance, 90);
    expect(activityWebsiteSeed[4].section, 'Early Years');
  });

  test('website KPI and programme type scope remains stable', () {
    expect(activityStats['Active programmes'], '18');
    expect(activityStats['Participation entries'], '472');
    expect(activityStats['Programme types'], '4');
    expect(activityStats['Upcoming sessions'], '6');
    expect(activityStats['Dedicated workflows'], '2');
    expect(ActivityType.values.map((type) => type.label).toList(), [
      'Sport',
      'Club',
      'Creative',
      'Academic enrichment',
    ]);
  });

  test('search, type and section filtering matches website behavior', () {
    final coding = activityWebsiteSeed[2];
    expect(coding.matches('robotics', null, null), isTrue);
    expect(coding.matches('', ActivityType.academicEnrichment, 'Secondary'), isTrue);
    expect(coding.matches('', ActivityType.sport, null), isFalse);
    expect(coding.matches('', null, 'Early Years'), isFalse);
  });

  test('activity serialization preserves operational fields', () {
    final original = activityWebsiteSeed.first;
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
