import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/features/smartcollect/data/smart_collect_api.dart';
import 'package:schoolos_app/features/smartcollect/presentation/accounts_tab.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'collections_test_server.dart';
import 'core/backend_test_support.dart';
import 'family_fees_fixtures.dart';

Future<CollectionsServer> pumpFamilies(
  WidgetTester tester, {
  CollectionsServer? server,
  SchoolMembership membership = ownerMembership,
  bool canDecide = true,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = server ?? (CollectionsServer()
    ..families = [
      familyRowJson(accounts: [payAccountJson(staff: true)]),
      familyRowJson(id: 'fam-2', code: 'FAM-SANI', name: 'Sani family', students: const ['Yusuf Sani']),
    ]);
  fake.canDecideBilling = canDecide;
  final client = apiFor(FakeServer(fake.handle));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: AccountsTab(api: SmartCollectApi(api: client), familyApi: FamilyFeesApi(api: client), membership: membership)),
  ));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> openMenu(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('each family is shown once with its children and the one account it pays into, under the provider\'s own word for the number', (tester) async {
      await pumpFamilies(tester);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.textContaining('Ahmad Bello, Aisha Bello, Maryam Bello'), findsOneWidget);
      expect(find.text('GTBank'), findsOneWidget);
      expect(find.text('Account number: 0123456789'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('a family with no account says one is made by a batch, and there is nothing to set up by hand', (tester) async {
      await pumpFamilies(tester);
      expect(find.text('Sani family'), findsOneWidget);
      expect(find.textContaining('No collection account yet. One is made when the family is in an approved collection batch'), findsOneWidget);
      for (final gone in ['Set up', 'Record what the bank gave', 'Issue for every family without one', 'Add an account at another bank']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
    });

    testWidgets('an account still being set up, a paused one, a settled one and a test account are each labelled', (tester) async {
      final server = CollectionsServer()
        ..families = [
          familyRowJson(accounts: [
            payAccountJson(id: 'a', status: 'provisioning', staff: true),
            payAccountJson(id: 'b', provider: 'paystack', bankName: 'Wema Bank', accountNumber: '1000000001', status: 'suspended', staff: true),
            payAccountJson(id: 'c', provider: 'sandbox', bankName: 'Test Bank', accountNumber: '9123456789', isTest: true, staff: true),
            payAccountJson(id: 'd', provider: 'monnify', bankName: 'Moniepoint', accountNumber: '6000000001', status: 'settled', canPay: true, staff: true),
          ]),
        ];
      await pumpFamilies(tester, server: server);
      expect(find.text('Being set up'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('Test data'), findsOneWidget);
    });

    testWidgets('a provider\'s own label for the number, and its extra facts, are shown as given', (tester) async {
      final server = CollectionsServer()
        ..families = [
          familyRowJson(accounts: [
            payAccountJson(
              provider: 'monnify', bankName: 'Moniepoint', accountNumber: '6000000001', numberLabel: 'Account number',
              details: [
                {'label': 'Collection target', 'value': 'NGN 150,000.00'},
              ],
              staff: true,
            ),
          ]),
        ];
      await pumpFamilies(tester, server: server);
      expect(find.text('Account number: 6000000001'), findsOneWidget);
      expect(find.text('Collection target: NGN 150,000.00'), findsOneWidget);
      expect(find.textContaining('Remita'), findsNothing);
    });

    testWidgets('the filters and the search ask the server, and paging asks for the next page', (tester) async {
      final server = CollectionsServer()
        ..families = [familyRowJson(), familyRowJson(id: 'fam-2', code: 'FAM-SANI', name: 'Sani family')]
        ..hasMoreFamilies = true;
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('accounts-filter-without')));
      await tester.pumpAndSettle();
      expect(server.queries['GET receivables/families/']!['accounts'], 'without');
      await tester.enterText(find.byKey(const ValueKey('family-search')), 'Sani');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(server.queries['GET receivables/families/']!['q'], 'Sani');
      await tester.tap(find.text('Show more families'));
      await tester.pumpAndSettle();
      expect(server.queries['GET receivables/families/']!['offset'], '2');
    });

    testWidgets('a merged family says so and offers no actions', (tester) async {
      final server = CollectionsServer()..families = [familyRowJson(id: 'fam-2', name: 'Sani family', status: 'inactive', mergedInto: 'fam-1', students: const [])];
      await pumpFamilies(tester, server: server);
      expect(find.text('Merged into another family'), findsOneWidget);
      expect(find.byKey(const ValueKey('family-menu-fam-2')), findsNothing);
    });
  });

  group('managing an account', () {
    testWidgets('pausing needs a reason, which is sent', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'account-menu-acc-1', 'Pause…');
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('reason-field')), 'Under review');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST receivables/collection-accounts/acc-1/suspend/'], {'reason': 'Under review'});
    });

    testWidgets('retiring needs a reason too, says the provider is asked to close it, and cancelling sends nothing', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'account-menu-acc-1', 'Retire…');
      expect(find.textContaining('The provider is asked to close it'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.calls.where((c) => c.contains('collection-accounts/acc-1')), isEmpty);
    });

    testWidgets('a paused account can be reinstated', (tester) async {
      final server = CollectionsServer()..families = [familyRowJson(accounts: [payAccountJson(status: 'suspended', staff: true)])];
      await pumpFamilies(tester, server: server);
      await openMenu(tester, 'account-menu-acc-1', 'Reinstate');
      expect(server.calls, contains('POST receivables/collection-accounts/acc-1/reinstate/'));
    });

    testWidgets('an account the provider is still making can be marked ready', (tester) async {
      final server = CollectionsServer()..families = [familyRowJson(accounts: [payAccountJson(status: 'provisioning', staff: true)])];
      await pumpFamilies(tester, server: server);
      await openMenu(tester, 'account-menu-acc-1', 'Mark as ready');
      expect(server.calls, contains('POST receivables/collection-accounts/acc-1/mark-provisioned/'));
    });

    testWidgets('an account being closed offers no further action', (tester) async {
      final server = CollectionsServer()..families = [familyRowJson(accounts: [payAccountJson(status: 'closing', staff: true)])];
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('account-menu-acc-1')));
      await tester.pumpAndSettle();
      expect(find.text('Retire…'), findsNothing);
      expect(find.text('Pause…'), findsNothing);
    });
  });

  group('merging families', () {
    testWidgets('only someone who may decide billing is offered it', (tester) async {
      await pumpFamilies(tester, canDecide: false);
      expect(find.byKey(const ValueKey('family-menu-fam-2')), findsNothing);
    });

    testWidgets('choose the family, read what would happen, give a reason and confirm', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'family-menu-fam-2', 'Merge into another family…');
      await tester.enterText(find.byKey(const ValueKey('merge-search')), 'Bello');
      await tester.tap(find.byKey(const ValueKey('merge-find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('merge-target-fam-2')), findsNothing); // never its own target
      await tester.tap(find.byKey(const ValueKey('merge-target-fam-1')));
      await tester.pumpAndSettle();
      expect(server.queries['GET receivables/families/fam-2/merge-preview/']!['into'], 'fam-1');
      expect(find.textContaining('Sani family will be merged into Bello family'), findsOneWidget);
      expect(find.textContaining('Children moving: Yusuf Sani'), findsOneWidget);
      expect(find.textContaining('a family holds one live account per school'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('merge-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('merge-reason')), 'Registered twice');
      await tester.tap(find.byKey(const ValueKey('merge-understood')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST receivables/families/fam-2/merge/'], {'intoFamilyId': 'fam-1', 'reason': 'Registered twice'});
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('what would refuse a merge is shown and the merge cannot be confirmed', (tester) async {
      final server = CollectionsServer()
        ..families = [familyRowJson(), familyRowJson(id: 'fam-2', code: 'FAM-SANI', name: 'Sani family')]
        ..mergeProblems = [
          {'code': 'target_merged', 'message': 'Bello family has itself been merged into another family. Merge into that one.'},
        ];
      await pumpFamilies(tester, server: server);
      await openMenu(tester, 'family-menu-fam-2', 'Merge into another family…');
      await tester.tap(find.byKey(const ValueKey('merge-find')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-target-fam-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('merge-problem')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('merge-reason')), 'Registered twice');
      await tester.tap(find.byKey(const ValueKey('merge-understood')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('merge-confirm'))).onPressed, isNull);
    });

    testWidgets('a refusal from the server is shown in the dialog', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'family-menu-fam-2', 'Merge into another family…');
      await tester.tap(find.byKey(const ValueKey('merge-find')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-target-fam-1')));
      await tester.pumpAndSettle();
      server.refusal = {'code': 'not_billing_authority', 'message': 'Only the owner, or someone the owner has given billing authority, can decide what families owe.'};
      await tester.enterText(find.byKey(const ValueKey('merge-reason')), 'Registered twice');
      await tester.tap(find.byKey(const ValueKey('merge-understood')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('merge-error')), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
