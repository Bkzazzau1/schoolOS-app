import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/access/access_catalog_data.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/finance_office/data/finance_office_dashboard_demo_data.dart';
import 'package:schoolos_app/features/mandates/data/mandates_api.dart';
import 'package:schoolos_app/features/proprietor/data/job_assignment_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_scope.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_source.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_workspace_page.dart';

import 'core/backend_test_support.dart';
import 'mandates_fixtures.dart';
import 'mandates_test_server.dart';

/// Who may do what in Mandates & Direct Debit, and where it sits in the menus. It is a payment path of its own, apart from Smart Money Collection,
/// with four duties of its own that only the owner can give.
void main() {
  const mandateDuties = {
    'finance.mandate_provider_manage': 'Remita and Lendsqr',
    'finance.mandate_manage': 'mandates',
    'finance.mandate_prepare': 'Prepare',
    'finance.mandate_approve': 'Approve',
  };

  CatalogEntry entry(String key) => accessCatalogEntries.firstWhere((e) => e.key == key);

  group('the four duties', () {
    test('each is one the owner can give, never one that comes with a role or a shortcut', () {
      for (final e in mandateDuties.entries) {
        expect(assignableDuties, contains(e.key));
        expect(assignableDuties[e.key], contains(e.value), reason: e.key);
        expect(explicitOnlyDuties, contains(e.key));
        expect(dutiesInGroup('finance.'), isNot(contains(e.key)), reason: e.key); // "all finance duties" does not include it
        for (final role in ['finance', 'teacher', 'administrator', 'sectionHead', 'driver', 'custom']) {
          expect(dutiesForJobRole(role), isNot(contains(e.key)), reason: '$role ${e.key}'); // being a Finance Officer is not enough
        }
      }
      expect(dutiesInGroup('finance.'), contains('finance.reports')); // the rest of Finance is still one tap
    });

    test('preparing a debit batch and approving it are different duties, so one person can be given only one', () {
      expect(mandateDuties.keys.toSet(), hasLength(4));
      expect('finance.mandate_prepare', isNot('finance.mandate_approve'));
    });

    test('they are not the Smart Money Collection duties, and no collection duty is a mandate duty', () {
      final collection = assignableDuties.keys.where((k) => k.startsWith('finance.collection_')).toSet();
      expect(collection, isNotEmpty);
      expect(collection.intersection(mandateDuties.keys.toSet()), isEmpty);
      for (final key in mandateDuties.keys) {
        expect(assignableDuties[key], isNot(contains('Paystack')));
        expect(assignableDuties[key], isNot(contains('Monnify')));
        expect(assignableDuties[key]!.toLowerCase(), isNot(contains('collection')));
      }
    });

  });

  group('the menus', () {
    test('it is a sensitive activity for the owner and the finance office only, under its own name', () {
      for (final key in ['owner.mandates', 'finance.mandates']) {
        expect(entry(key).label, 'Mandates & Direct Debit');
        expect(entry(key).sensitive, isTrue, reason: key);
      }
      expect(entry('owner.mandates').roles, {'proprietor'});
      expect(entry('finance.mandates').roles, {'accountant'});
      final others = accessCatalogEntries.where((e) => e.label == 'Mandates & Direct Debit').map((e) => e.key).toSet();
      expect(others, {'owner.mandates', 'finance.mandates'});
    });

    test('the finance menu names it the same way the catalog does, and it is not Smart Money Collection', () {
      final item = financeOfficeNavigation.firstWhere((i) => i.key == 'mandates');
      expect(item.label, entry('finance.mandates').label);
      expect(item.label, isNot(entry('finance.collections').label));
      expect(financeOfficeNavigation.where((i) => i.key == 'collections'), hasLength(1)); // Smart Money Collection is still its own item
    });

    test('the owner menu has it beside Smart Money Collection, not inside it', () {
      final source = File('lib/features/proprietor/presentation/proprietor_workspace_page.dart').readAsStringSync();
      expect(source, contains("_OwnerNavItem('mandates', 'Mandates & Direct Debit'"));
      expect(source, contains("_OwnerNavItem('collections', 'Smart Money Collection'"));
    });
  });

  group('in the owner\'s workspace', () {
    Future<void> openMandates(WidgetTester tester, {MandatesServer? server}) async {
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = _Database();
      final session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships([ownerMembership]);
      await session.selectSchool(ownerMembership);
      Widget home = ProprietorWorkspacePage(
        membership: ownerMembership,
        localDatabase: db,
        schoolSession: session,
        schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
      );
      home = OwnerAccessScope(repository: _NoopOwnerAccess(), child: home);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => server == null ? child! : MandatesScope(api: MandatesApi(api: apiFor(FakeServer(server.handle))), child: child!),
          home: home,
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Owner workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Mandates & Direct Debit'), findsWidgets);
      await tester.tap(find.text('Mandates & Direct Debit').first);
      await tester.pumpAndSettle();
    }

    testWidgets('with no school server it says plainly that it needs one, and invents no provider, mandate or debit', (tester) async {
      await openMandates(tester);
      expect(find.textContaining('needs your school\'s server'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a school server it opens the hub, with its own tabs', (tester) async {
      await openMandates(tester, server: MandatesServer());
      for (final name in ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions']) {
        expect(find.widgetWithText(Tab, name), findsOneWidget, reason: name);
      }
      expect(tester.takeException(), isNull);
    });
  });
}

class _NoopOwnerAccess implements OwnerAccessSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) return Future<LocalRecord?>.value(null);
    if (invocation.memberName == #getLocalRecords) return Future<List<LocalRecord>>.value([]);
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}
