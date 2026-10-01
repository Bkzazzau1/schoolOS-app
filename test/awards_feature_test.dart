import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/awards/data/award_policy_copy.dart';
import 'package:schoolos_app/features/awards/domain/award_models.dart';

List<AwardRecognition> _awards() => const [
      AwardRecognition(
        id: 'AW-TEST-1',
        title: 'Teacher of the Term',
        recipient: 'Mrs. Fatima Bello',
        recipientType: AwardRecipientType.teacher,
        section: 'Secondary',
        category: 'Teaching Excellence',
        citation: 'Recognized for consistent lesson preparation.',
        issuer: 'School Leadership',
        date: '13 Sep 2026',
        visibility: AwardVisibility.schoolAndParents,
        badge: '★',
      ),
      AwardRecognition(
        id: 'AW-TEST-2',
        title: 'Inter-House Sports Champion',
        recipient: 'Blue House',
        recipientType: AwardRecipientType.house,
        section: 'Whole school',
        category: 'Sports',
        citation: 'Highest combined points.',
        issuer: 'Sports Committee',
        date: '10 Sep 2026',
        visibility: AwardVisibility.publicShowcase,
        badge: '◆',
      ),
      AwardRecognition(
        id: 'AW-TEST-3',
        title: 'Most Improved Reader',
        recipient: 'Hauwa Musa',
        recipientType: AwardRecipientType.student,
        section: 'Primary 6',
        category: 'Growth & Progress',
        citation: 'Sustained improvement in reading fluency.',
        issuer: 'Primary School',
        date: '9 Sep 2026',
        visibility: AwardVisibility.schoolAndParents,
        badge: '↑',
      ),
    ];

void main() {
  test('award stats are computed entirely from the real awards given, never a fixed sample', () {
    final stats = awardStats(_awards());
    expect(stats[0].value, '3');
    expect(stats[1].value, '1', reason: 'one teacher award');
    expect(stats[2].value, '1', reason: 'one student award');
    expect(stats[3].value, '1', reason: 'one house award');
    expect(stats[4].value, '1', reason: 'one public showcase award');

    final empty = awardStats(const []);
    expect(empty.every((s) => s.value == '0'), isTrue);
  });

  test('all recipient types and visibility levels are represented', () {
    expect(AwardRecipientType.values, hasLength(6));
    expect(AwardVisibility.values, hasLength(3));
    expect(AwardRecipientType.values.map((item) => item.label), containsAll([
      'Student',
      'Teacher',
      'Team',
      'House',
      'Club',
      'Staff',
    ]));
    expect(AwardVisibility.values.map((item) => item.label), containsAll([
      'School + parents',
      'Public showcase',
      'Internal only',
    ]));
  });

  test('filters match search and exact recipient/visibility behavior', () {
    final awards = _awards();
    final house = awards.where((award) => award.matches('Blue House')).single;
    expect(house.id, 'AW-TEST-2');

    final publicAwards = awards.where(
      (award) => award.matches('', visibilityFilter: AwardVisibility.publicShowcase),
    );
    expect(publicAwards, hasLength(1));

    final students = awards.where(
      (award) => award.matches('', recipientTypeFilter: AwardRecipientType.student),
    );
    expect(students, hasLength(1));
  });

  test('recognition serialization preserves authority and visibility fields', () {
    final original = _awards().first;
    final restored = AwardRecognition.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.recipientType, AwardRecipientType.teacher);
    expect(restored.visibility, AwardVisibility.schoolAndParents);
    expect(restored.issuer, 'School Leadership');
  });

  test('public recognition remains approval and privacy constrained', () {
    expect(
      awardVisibilityDestinations['Public showcase'],
      contains('approved recognition'),
    );
    expect(
      awardVisibilityDestinations['Public showcase'],
      contains('privacy/media consent'),
    );
  });

  test('recognition is broader than permanent high-stakes ranking', () {
    expect(recognitionRankingBoundary, contains('without creating permanent'));
    expect(awardRecognitionCategories.keys, contains('Academic growth'));
    expect(awardRecognitionCategories.keys, contains('Character & service'));
    expect(awardRecognitionCategories.keys, contains('Creative & innovation'));
  });

  test('Early Years guardrail rejects best-child league tables and fixed labels', () {
    expect(earlyYearsRecognitionGuardrail, contains('best child'));
    expect(earlyYearsRecognitionGuardrail, contains('fixed ability label'));
  });
}
