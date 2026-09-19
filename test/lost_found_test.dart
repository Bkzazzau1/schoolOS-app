import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/lost_found/data/lost_found_demo_data.dart';
import 'package:schoolos_app/features/lost_found/domain/lost_found_models.dart';

void main() {
  test('website Lost and Found seed preserves five items and KPI totals', () {
    expect(lostFoundWebsiteSeed, hasLength(5));

    final stats = lostFoundStats(lostFoundWebsiteSeed);
    expect(stats[0].value, '4');
    expect(stats[1].value, '1');
    expect(stats[2].value, '1');
    expect(stats[3].value, '4');
    expect(stats[4].value, 'Off');
  });

  test('website statuses preserve unclaimed, claim review and returned', () {
    expect(
      lostFoundWebsiteSeed
          .where((item) => item.status == LostFoundStatus.unclaimed)
          .length,
      3,
    );
    expect(
      lostFoundWebsiteSeed
          .where((item) => item.status == LostFoundStatus.claimReview)
          .length,
      1,
    );
    expect(
      lostFoundWebsiteSeed
          .where((item) => item.status == LostFoundStatus.returned)
          .length,
      1,
    );
  });

  test('Lost and Found search covers item, category and found location', () {
    final sweater = lostFoundWebsiteSeed.first;

    expect(sweater.matches('sweater'), isTrue);
    expect(sweater.matches('uniform'), isTrue);
    expect(sweater.matches('primary playground'), isTrue);
    expect(sweater.matches('ict lab'), isFalse);
  });

  test('status changes survive serialization without contact fields', () {
    final updated = lostFoundWebsiteSeed.first.copyWith(
      status: LostFoundStatus.claimReview,
    );
    final json = updated.toJson();
    final restored = LostFoundItem.fromJson(json);

    expect(restored.status, LostFoundStatus.claimReview);
    expect(restored.id, 'LF-101');
    expect(json.containsKey('phone'), isFalse);
    expect(json.containsKey('address'), isFalse);
    expect(json.containsKey('childPhone'), isFalse);
    expect(json.containsKey('hiddenVerificationDetail'), isFalse);
  });

  test('claim rules preserve privacy and later retention policy', () {
    expect(lostFoundClaimRules, hasLength(3));
    expect(lostFoundClaimRules.keys, contains('Keep one detail private'));
    expect(lostFoundClaimRules.keys, contains('No child contact data'));
    expect(lostFoundClaimRules.keys, contains('Retention policy later'));
    expect(lostFoundAutoDisposal, isFalse);
  });

  test('claim review and return transitions match website actions', () {
    final source = lostFoundWebsiteSeed.first;
    final review = source.copyWith(status: LostFoundStatus.claimReview);
    final returned = review.copyWith(status: LostFoundStatus.returned);

    expect(review.status, LostFoundStatus.claimReview);
    expect(returned.status, LostFoundStatus.returned);
    expect(returned.isOpen, isFalse);
  });
}
