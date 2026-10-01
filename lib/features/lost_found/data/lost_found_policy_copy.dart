import '../domain/lost_found_models.dart';

/// Static guidance copy for Lost & Found - not data about this school, so it never needs a real
/// backend source. Real activity (found items) lives in [LostFoundRepository] instead.
const lostFoundAutoDisposal = false;

const lostFoundClaimRules = <String, String>{
  'Keep one detail private':
      'Use hidden identifying details to verify the claimant.',
  'No child contact data':
      'Do not publish names, phone numbers or addresses in item listings.',
  'Retention policy later':
      'Schools can configure how long unclaimed items remain before disposal/donation.',
};

/// Computed entirely from [items] - the real, locally-held found items a school has actually
/// logged, never fixed sample counts. "Storage points" was dropped outright: nothing in the app
/// tracks distinct physical storage locations, so there was no honest number to show.
List<LostFoundStat> lostFoundStats(List<LostFoundItem> items) => [
      LostFoundStat(
        'Open items',
        '${items.where((item) => item.isOpen).length}',
        'Awaiting collection',
      ),
      LostFoundStat(
        'Claim review',
        '${items.where((item) => item.status == LostFoundStatus.claimReview).length}',
        'Needs ownership check',
      ),
      LostFoundStat(
        'Returned',
        '${items.where((item) => item.status == LostFoundStatus.returned).length}',
        'Resolved items',
      ),
      const LostFoundStat('Auto disposal', 'Off', 'Policy required later'),
    ];
