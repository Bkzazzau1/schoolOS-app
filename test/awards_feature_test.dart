import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/awards/data/award_demo_data.dart';
import 'package:schoolos_app/features/awards/domain/award_models.dart';

void main() {
  test('website seed contains five recognitions and exact headline metrics', () {
    expect(awardsWebsiteSeed, hasLength(5));
    expect(awardsTermRecognitionCount, 37);
    expect(awardsTeacherCount, 6);
    expect(awardsStudentRecognitionCount, 21);
    expect(awardsTeamHouseCount, 7);
    expect(awardsWebsiteSeed.where((award) => award.isPublic), hasLength(2));
  });

  test('all website recipient types and visibility levels are represented', () {
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

  test('filters match website search and exact recipient/visibility behavior', () {
    final house = awardsWebsiteSeed
        .where((award) => award.matches('Blue House'))
        .single;
    expect(house.id, 'AW-003');

    final publicAwards = awardsWebsiteSeed.where(
      (award) => award.matches(
        '',
        visibilityFilter: AwardVisibility.publicShowcase,
      ),
    );
    expect(publicAwards, hasLength(2));

    final students = awardsWebsiteSeed.where(
      (award) => award.matches(
        '',
        recipientTypeFilter: AwardRecipientType.student,
      ),
    );
    expect(students, hasLength(2));
  });

  test('recognition serialization preserves authority and visibility fields', () {
    final original = awardsWebsiteSeed.first;
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
