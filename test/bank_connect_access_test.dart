import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_catalog_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/features/proprietor/data/job_assignment_repository.dart';

void main() {
  CatalogEntry entry(String key) => accessCatalogEntries.firstWhere((e) => e.key == key);

  test('connecting the school\'s bank accounts is a duty the owner can give, never one that comes with a role', () {
    expect(assignableDuties, contains('finance.bank_connections'));
    expect(assignableDuties['finance.bank_connections'], contains('bank accounts'));
    // Being a Finance Officer is not enough: no preset and no "all finance duties" shortcut includes it.
    expect(explicitOnlyDuties, contains('finance.bank_connections'));
    expect(dutiesInGroup('finance.'), isNot(contains('finance.bank_connections')));
    expect(dutiesInGroup('finance.'), contains('finance.reports')); // the rest of Finance is still one tap
    for (final role in ['finance', 'teacher', 'administrator', 'sectionHead', 'driver', 'custom']) {
      expect(dutiesForJobRole(role), isNot(contains('finance.bank_connections')), reason: role);
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
