import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/lost_found/data/lost_found_policy_copy.dart';
import 'package:schoolos_app/features/lost_found/domain/lost_found_models.dart';

List<LostFoundItem> _items() => const [
      LostFoundItem(
        id: 'LF-TEST-101',
        item: 'Blue school sweater',
        category: 'Uniform',
        found: 'Primary playground',
        date: '13 Sep 2026',
        storage: 'Front Office Shelf A',
        status: LostFoundStatus.unclaimed,
        claimant: '',
        note: 'Name tag is not visible in the public listing.',
      ),
      LostFoundItem(
        id: 'LF-TEST-102',
        item: 'Black water bottle',
        category: 'Personal item',
        found: 'ICT Lab',
        date: '12 Sep 2026',
        storage: 'Front Office Shelf B',
        status: LostFoundStatus.claimReview,
        claimant: 'Primary 6 guardian request',
        note: 'Claim should be verified using item details not shown publicly.',
      ),
      LostFoundItem(
        id: 'LF-TEST-103',
        item: 'Mathematics textbook',
        category: 'Book',
        found: 'JSS 2 corridor',
        date: '11 Sep 2026',
        storage: 'Secondary Office',
        status: LostFoundStatus.returned,
        claimant: 'Verified student',
        note: 'Returned after ownership check.',
      ),
    ];

void main() {
  test('lost & found stats are computed entirely from the real items given, never a fixed sample', () {
    final stats = lostFoundStats(_items());
    expect(stats[0].value, '2', reason: 'two open items (unclaimed + claim review)');
    expect(stats[1].value, '1');
    expect(stats[2].value, '1');
    expect(stats[3].value, 'Off');

    final empty = lostFoundStats(const []);
    expect(empty[0].value, '0');
    expect(empty[1].value, '0');
    expect(empty[2].value, '0');
  });

  test('statuses cover unclaimed, claim review and returned', () {
    final items = _items();
    expect(items.where((item) => item.status == LostFoundStatus.unclaimed).length, 1);
    expect(items.where((item) => item.status == LostFoundStatus.claimReview).length, 1);
    expect(items.where((item) => item.status == LostFoundStatus.returned).length, 1);
  });

  test('search covers item, category and found location', () {
    final sweater = _items().first;

    expect(sweater.matches('sweater'), isTrue);
    expect(sweater.matches('uniform'), isTrue);
    expect(sweater.matches('primary playground'), isTrue);
    expect(sweater.matches('ict lab'), isFalse);
  });

  test('status changes survive serialization without contact fields', () {
    final updated = _items().first.copyWith(status: LostFoundStatus.claimReview);
    final json = updated.toJson();
    final restored = LostFoundItem.fromJson(json);

    expect(restored.status, LostFoundStatus.claimReview);
    expect(restored.id, 'LF-TEST-101');
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

  test('claim review and return transitions work as copyWith chains', () {
    final source = _items().first;
    final review = source.copyWith(status: LostFoundStatus.claimReview);
    final returned = review.copyWith(status: LostFoundStatus.returned);

    expect(review.status, LostFoundStatus.claimReview);
    expect(returned.status, LostFoundStatus.returned);
    expect(returned.isOpen, isFalse);
  });
}
