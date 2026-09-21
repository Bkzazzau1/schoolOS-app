import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_catalog_data.dart';

/// The owner's menu decides what is shown by asking the access catalog about `owner.<key>`. A menu item whose key is not in
/// the catalog could never be switched off by the owner, so every one must be listed.
void main() {
  final source = File('lib/features/proprietor/presentation/proprietor_workspace_page.dart').readAsStringSync();
  final menuKeys = [for (final m in RegExp(r"_OwnerNavItem\('([a-z-]+)'").allMatches(source)) m.group(1)!];
  final catalogKeys = {for (final e in accessCatalogEntries) e.key};

  test('the owner menu has items to check', () {
    expect(menuKeys.length, greaterThanOrEqualTo(10));
  });

  test('every owner menu item is an activity in the access catalog', () {
    for (final key in menuKeys) {
      expect(catalogKeys, contains('owner.$key'), reason: 'owner menu item "$key" is missing from the catalog');
    }
  });

  test('every owner activity in the catalog is a screen the app has', () {
    final known = {...menuKeys, 'finance-approvals'};
    for (final e in accessCatalogEntries.where((e) => e.key.startsWith('owner.'))) {
      expect(known, contains(e.key.substring('owner.'.length)), reason: '${e.key} has no screen in the app');
    }
  });
}
