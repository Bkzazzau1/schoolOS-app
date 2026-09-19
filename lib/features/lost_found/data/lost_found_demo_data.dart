import '../domain/lost_found_models.dart';

const lostFoundWebsiteSeed = <LostFoundItem>[
  LostFoundItem(
    id: 'LF-101',
    item: 'Blue school sweater',
    category: 'Uniform',
    found: 'Primary playground',
    date: '13 Sep 2026',
    storage: 'Front Office Shelf A',
    status: LostFoundStatus.unclaimed,
    claimant: '—',
    note: 'Name tag is not visible in the public listing.',
  ),
  LostFoundItem(
    id: 'LF-102',
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
    id: 'LF-103',
    item: 'Mathematics textbook',
    category: 'Book',
    found: 'JSS 2 corridor',
    date: '11 Sep 2026',
    storage: 'Secondary Office',
    status: LostFoundStatus.returned,
    claimant: 'Verified student',
    note: 'Returned after ownership check.',
  ),
  LostFoundItem(
    id: 'LF-104',
    item: 'Lunch bag',
    category: 'Meal item',
    found: 'Main cafeteria',
    date: '13 Sep 2026',
    storage: 'Cafeteria desk',
    status: LostFoundStatus.unclaimed,
    claimant: '—',
    note: 'Perishable contents handled separately; bag retained.',
  ),
  LostFoundItem(
    id: 'LF-105',
    item: 'Sports shoes',
    category: 'Sports',
    found: 'Changing area',
    date: '10 Sep 2026',
    storage: 'Sports Office',
    status: LostFoundStatus.unclaimed,
    claimant: '—',
    note: 'Pair stored together with internal identifying notes.',
  ),
];

const lostFoundStoragePointCount = 4;
const lostFoundAutoDisposal = false;

const lostFoundClaimRules = <String, String>{
  'Keep one detail private':
      'Use hidden identifying details to verify the claimant.',
  'No child contact data':
      'Do not publish names, phone numbers or addresses in item listings.',
  'Retention policy later':
      'Schools can configure how long unclaimed items remain before disposal/donation.',
};

List<LostFoundStat> lostFoundStats(List<LostFoundItem> items) => [
      LostFoundStat(
        'Open items',
        '${items.where((item) => item.isOpen).length}',
        'Current mock register',
      ),
      LostFoundStat(
        'Claim review',
        '${items.where((item) => item.status == LostFoundStatus.claimReview).length}',
        'Needs ownership check',
      ),
      LostFoundStat(
        'Returned',
        '${items.where((item) => item.status == LostFoundStatus.returned).length}',
        'Current sample',
      ),
      const LostFoundStat('Storage points', '4', 'Front office + section desks'),
      const LostFoundStat('Auto disposal', 'Off', 'Policy required later'),
    ];
