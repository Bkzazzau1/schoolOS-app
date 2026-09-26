import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_catalog_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/features/proprietor/data/job_assignment_repository.dart';

void main() {
  CatalogEntry entry(String key) => accessCatalogEntries.firstWhere((e) => e.key == key);

  const collectionDuties = {
    'finance.collection_provider_manage': 'collection providers',
    'finance.collection_policy_manage': 'policy',
    'finance.collection_prepare': 'Prepare',
    'finance.collection_approve': 'Approve',
  };

  test('each Smart Money Collection duty is one the owner can give, never one that comes with a role', () {
    for (final e in collectionDuties.entries) {
      expect(assignableDuties, contains(e.key));
      expect(assignableDuties[e.key], contains(e.value), reason: e.key);
      // Being a Finance Officer is not enough: no preset and no "all finance duties" shortcut includes it.
      expect(explicitOnlyDuties, contains(e.key));
      expect(dutiesInGroup('finance.'), isNot(contains(e.key)), reason: e.key);
      for (final role in ['finance', 'teacher', 'administrator', 'sectionHead', 'driver', 'custom']) {
        expect(dutiesForJobRole(role), isNot(contains(e.key)), reason: '$role ${e.key}');
      }
    }
    expect(dutiesInGroup('finance.'), contains('finance.reports')); // the rest of Finance is still one tap
  });

  test('preparing a batch and approving it are different duties, so one person can be given only one', () {
    expect(collectionDuties.keys.toSet().length, 4);
    expect('finance.collection_prepare', isNot('finance.collection_approve'));
  });

  test('the earlier bank-connections duty is gone from what an owner can give', () {
    expect(assignableDuties, isNot(contains('finance.bank_connections')));
  });

  test('deciding what families owe is a duty only the owner can give, and no preset or shortcut includes it', () {
    expect(assignableDuties, contains('finance.billing_authority'));
    expect(assignableDuties['finance.billing_authority'], contains('owe'));
    expect(explicitOnlyDuties, contains('finance.billing_authority'));
    expect(dutiesInGroup('finance.'), isNot(contains('finance.billing_authority')));
    for (final role in ['finance', 'administrator', 'sectionHead', 'teacher', 'custom']) {
      expect(dutiesForJobRole(role), isNot(contains('finance.billing_authority')), reason: role);
    }
  });

  test('Smart Money Collection is a sensitive activity for the owner and the finance office only', () {
    for (final key in ['owner.collections', 'finance.collections']) {
      final e = entry(key);
      expect(e.label, 'Smart Money Collection');
      expect(e.sensitive, isTrue, reason: key);
    }
    expect(entry('owner.collections').roles, {'proprietor'});
    expect(entry('finance.collections').roles, {'accountant'});
  });

  test('the finance menu names it the same way the catalog does', () {
    final item = financeOfficeNavigation.firstWhere((i) => i.key == 'collections');
    expect(item.label, entry('finance.collections').label);
  });

  test('no other role has an activity for it', () {
    final others = accessCatalogEntries.where((e) => e.label == 'Smart Money Collection').map((e) => e.key).toSet();
    expect(others, {'owner.collections', 'finance.collections'});
  });
}
