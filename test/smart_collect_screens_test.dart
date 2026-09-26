import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/features/smartcollect/data/smart_collect_api.dart';
import 'package:schoolos_app/features/smartcollect/presentation/accounts_tab.dart';
import 'package:schoolos_app/features/smartcollect/presentation/batches_tab.dart';
import 'package:schoolos_app/features/smartcollect/presentation/collection_batch_screen.dart';
import 'package:schoolos_app/features/smartcollect/presentation/new_batch_page.dart';
import 'package:schoolos_app/features/smartcollect/presentation/policy_tab.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'collections_test_server.dart';
import 'core/backend_test_support.dart';
import 'smart_collect_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  CollectionsServer server,
  Widget Function(SmartCollectApi smart, FamilyFeesApi families) build,
) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = apiFor(FakeServer(server.handle));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: build(SmartCollectApi(api: client), FamilyFeesApi(api: client)))));
  await tester.pumpAndSettle();
}

Future<void> pumpBatch(WidgetTester tester, CollectionsServer server, {List<String>? saved}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = apiFor(FakeServer(server.handle));
  await tester.pumpWidget(MaterialApp(
    home: CollectionBatchScreen(
      api: SmartCollectApi(api: client),
      membership: ownerMembership,
      batchId: 'batch-1',
      saveExport: (file) async {
        saved?.add(file.fileName);
        return '/documents/${file.fileName}';
      },
      pollInterval: const Duration(milliseconds: 200),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the policy', () {
    Future<void> open(WidgetTester tester, CollectionsServer server, {SchoolMembership m = ownerMembership}) =>
        pumpScreen(tester, server, (smart, families) => PolicyTab(api: smart, familyApi: families, membership: m));

    testWidgets('the school default is shown in words, and each override says what it is for, why and for how long', (tester) async {
      final server = CollectionsServer()..overrides = [overrideJson()];
      await open(tester, server);
      expect(find.text('School default policy'), findsOneWidget);
      expect(find.text('Account type'), findsWidgets);
      expect(find.text('Static'), findsOneWidget);
      expect(find.text('Make it dormant straight away'), findsOneWidget);
      expect(find.text('Carry the previous balance forward'), findsOneWidget);
      expect(find.text('Include them only with an override'), findsOneWidget);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.text('Override for this family'), findsOneWidget);
      expect(find.text('Why: Pays per term'), findsOneWidget);
      expect(find.text('Until the end of First Term'), findsOneWidget);
    });

    testWidgets('it explains that the nearest layer wins', (tester) async {
      await open(tester, CollectionsServer());
      expect(find.textContaining('family, then batch, then term, then session, then this default'), findsOneWidget);
    });

    testWidgets('someone who cannot change the policy sees it but is not offered any change', (tester) async {
      final server = CollectionsServer()
        ..policy = policyResponse(canManage: false)
        ..overrides = [overrideJson()];
      await open(tester, server, m: financeMembership);
      expect(find.text('School default policy'), findsOneWidget);
      expect(find.byKey(const ValueKey('edit-default-policy')), findsNothing);
      expect(find.byKey(const ValueKey('add-override')), findsNothing);
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('editing the default sends only what changed', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('edit-default-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dynamic').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-default-policy')));
      await tester.pumpAndSettle();
      expect(server.requests['PATCH policy/'], {'values': {'account_mode': 'dynamic'}});
    });

    testWidgets('a wait asks for the school\'s own waiting period, and none is assumed', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('edit-default-policy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('field-grace_period_hours')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('field-settlement_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wait, then close it').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('field-grace_period_hours')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('field-grace_period_hours'))).controller!.text, isEmpty);
      await tester.enterText(find.byKey(const ValueKey('field-grace_period_hours')), '48');
      await tester.pumpAndSettle();
      expect(find.text('2 days'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-default-policy')));
      await tester.pumpAndSettle();
      expect(server.requests['PATCH policy/'], {'values': {'settlement_action': 'grace_then_close', 'grace_period_hours': 48}});
    });

    testWidgets('an override changes only the ticked settings and can never name a provider', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('add-override')));
      await tester.pumpAndSettle();
      expect(find.textContaining('can never choose its own provider'), findsOneWidget);
      // the settings are switched off until ticked
      expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('field-account_mode'))).onChanged, isNull);
      await tester.enterText(find.byKey(const ValueKey('override-family-search')), 'bello');
      await tester.tap(find.byIcon(Icons.search).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bello family'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('change-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dynamic').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Why (the school may require a reason)'), 'Pays per term');
      await tester.tap(find.byKey(const ValueKey('save-override')));
      await tester.pumpAndSettle();
      final sent = server.requests['POST policy/overrides/']!;
      expect(sent['scope'], 'family');
      expect(sent['familyId'], 'fam-1');
      expect(sent['values'], {'account_mode': 'dynamic'});
      expect(sent['reason'], 'Pays per term');
      expect(sent['expiryKind'], 'until_removed');
      expect(sent.toString(), isNot(contains('provider')));
    });

    testWidgets('an override with nothing ticked is refused on the screen', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('add-override')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-override')));
      await tester.pumpAndSettle();
      expect(find.text('Tick at least one setting to change.'), findsOneWidget);
      expect(server.calls, isNot(contains('POST policy/overrides/')));
    });

    testWidgets('removing an override asks first and says it stays on record', (tester) async {
      final server = CollectionsServer()..overrides = [overrideJson()];
      await open(tester, server);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The override stays on record'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST policy/overrides/ov-1/remove/'));
    });

    testWidgets('a refusal shows the server\'s words', (tester) async {
      final server = CollectionsServer()
        ..refusal = {'code': 'reason_required', 'message': 'Say why you are making an override: the school asks for a reason.'};
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('edit-default-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dynamic').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-default-policy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('the school asks for a reason'), findsOneWidget);
    });
  });

  group('the list of batches', () {
    Future<void> open(WidgetTester tester, CollectionsServer server) =>
        pumpScreen(tester, server, (smart, families) => BatchesTab(api: smart, membership: ownerMembership, saveExport: (f) async => '/x'));

    testWidgets('each batch shows its period, provider, status, totals and who prepared it', (tester) async {
      final server = CollectionsServer()
        ..batches = [
          batchJson(status: 'pending_approval'),
          batchJson(id: 'batch-2', status: 'rejected', rejectionReason: 'Bravo should not be included', title: 'Second try'),
          batchJson(id: 'batch-3', status: 'partially_successful', selected: 600, successful: 590, failed: 10, title: 'Big one'),
        ];
      await open(tester, server);
      expect(find.text('Term one accounts'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsWidgets);
      expect(find.textContaining('Paystack (Live)'), findsWidgets);
      expect(find.textContaining('2 of 3 families · ₦150,000 to be collected'), findsWidgets);
      expect(find.text('Rejected: Bravo should not be included'), findsOneWidget);
      expect(find.text('590 generated · 10 failed'), findsOneWidget);
      expect(find.textContaining('Prepared by Tunde Maker'), findsWidgets);
    });

    testWidgets('someone who prepares can start a batch and someone who approves is offered the batches waiting for them', (tester) async {
      await open(tester, CollectionsServer());
      expect(find.byKey(const ValueKey('new-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey('batch-filter-awaiting')), findsOneWidget);
    });

    testWidgets('someone who only approves cannot start a batch', (tester) async {
      await open(tester, CollectionsServer()..dashboard = dashboardJson(perms: permissionsJson(prepare: false)));
      expect(find.byKey(const ValueKey('new-batch')), findsNothing);
    });

    testWidgets('someone who only prepares is not offered the batches waiting for approval', (tester) async {
      await open(tester, CollectionsServer()..dashboard = dashboardJson(perms: permissionsJson(approve: false)));
      expect(find.byKey(const ValueKey('batch-filter-awaiting')), findsNothing);
    });

    testWidgets('the filters ask the server for what they say', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('batch-filter-awaiting')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/']!['awaiting'], '1');
      await tester.tap(find.byKey(const ValueKey('batch-filter-rejected')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/']!['status'], 'rejected');
      await tester.tap(find.byKey(const ValueKey('batch-filter-failed')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/']!['status'], 'partially_successful,failed');
    });

    testWidgets('an empty list says so', (tester) async {
      await open(tester, CollectionsServer());
      expect(find.text('No batches here'), findsOneWidget);
    });
  });

  group('preparing a batch', () {
    testWidgets('it starts from the current session and term, names the active provider, and sends nothing until asked', (tester) async {
      final server = CollectionsServer();
      await pumpScreen(tester, server, (smart, families) => NewBatchPage(api: smart, membership: ownerMembership));
      expect(find.text('2026/2027'), findsWidgets);
      expect(find.text('First Term'), findsWidgets);
      expect(find.text('Paystack (Live)'), findsOneWidget);
      expect(find.textContaining('A batch is approved for it, and cannot use another'), findsOneWidget);
      expect(find.textContaining('Nothing is sent to the provider until then'), findsOneWidget);
      expect(server.calls, isNot(contains('POST batches/')));
    });

    testWidgets('it makes the preview for the chosen period and, when asked, a policy for just this batch', (tester) async {
      final server = CollectionsServer();
      await pumpScreen(tester, server, (smart, families) => NewBatchPage(api: smart, membership: ownerMembership));
      await tester.tap(find.byKey(const ValueKey('change-batch-policy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('change-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-account_mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dynamic').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name for this batch (optional)'), 'Term one');
      await tester.tap(find.byKey(const ValueKey('create-batch')));
      await tester.pumpAndSettle();
      final sent = server.requests['POST batches/']!;
      expect((sent['sessionId'], sent['termId'], sent['title']), ('ses-1', 'term-1', 'Term one'));
      expect(sent['policy'], {'account_mode': 'dynamic'});
    });

    testWidgets('with no active provider nothing can be prepared, and it says why', (tester) async {
      final server = CollectionsServer()..dashboard = (dashboardJson()..['activeProvider'] = null);
      await pumpScreen(tester, server, (smart, families) => NewBatchPage(api: smart, membership: ownerMembership));
      expect(find.textContaining('no active collection provider yet'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('create-batch'))).onPressed, isNull);
    });

    testWidgets('a refusal from the server is shown', (tester) async {
      final server = CollectionsServer()..refusal = {'code': 'no_active_provider', 'message': 'Choose the school\'s active collection provider first.'};
      await pumpScreen(tester, server, (smart, families) => NewBatchPage(api: smart, membership: ownerMembership));
      await tester.tap(find.byKey(const ValueKey('create-batch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose the school\'s active collection provider first'), findsOneWidget);
    });
  });

  group('the maker reviewing a batch', () {
    CollectionsServer draft({List<Map<String, Object?>>? items, Map<String, Object?>? batch}) => CollectionsServer()
      ..batch = batch ?? batchJson(counts: {'eligible': {'total': 2, 'selected': 2}, 'needs_override': {'total': 1, 'selected': 0}})
      ..items = items ??
          [
            itemJson(id: 'a', family: 'Alpha family', code: 'FAM-A'),
            itemJson(id: 'b', family: 'Bravo family', code: 'FAM-B', current: 5000000, proposed: 5000000),
            itemJson(id: 'c', family: 'Charlie family', code: 'FAM-C', status: 'needs_override', selected: false, previous: 8000000, current: 6000000, proposed: 14000000, note: 'Still owes for an earlier term. A person must override to include them.'),
          ];

    testWidgets('it shows the totals, the provider, the version and every family with why it is or is not eligible', (tester) async {
      await pumpBatch(tester, draft());
      expect(find.text('Term one accounts'), findsWidgets);
      expect(find.text('Draft'), findsWidgets);
      expect(find.textContaining('Paystack (Live)'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('total-selected'))).data, '2');
      expect(tester.widget<Text>(find.byKey(const ValueKey('total-collection'))).data, '₦150,000');
      expect(find.text('Alpha family'), findsOneWidget);
      expect(find.text('Charlie family'), findsOneWidget);
      expect(find.text('Needs an override'), findsWidgets);
      expect(find.textContaining('Still owes for an earlier term'), findsOneWidget);
      expect(find.text('₦80,000'), findsOneWidget); // Charlie's previous balance
    });

    testWidgets('a family that needs an override cannot be ticked until it has one', (tester) async {
      await pumpBatch(tester, draft());
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('select-c'))).onChanged, isNull);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('select-a'))).onChanged, isNotNull);
    });

    testWidgets('selecting and deselecting sends the version the person was looking at', (tester) async {
      final server = draft();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('select-a')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/selection/'], {'deselect': ['a'], 'expectedVersion': 3});
      await tester.tap(find.byKey(const ValueKey('select-all-eligible')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/selection/'], {'selectAllEligible': true, 'expectedVersion': 3});
      await tester.tap(find.byKey(const ValueKey('deselect-all')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/selection/'], {'deselectAll': true, 'expectedVersion': 3});
    });

    testWidgets('overriding a family\'s eligibility needs a reason, which is kept with the person\'s name, and changes nothing that is owed', (tester) async {
      final server = draft();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('override-c')));
      await tester.pumpAndSettle();
      expect(find.textContaining('What they owe does not change'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('reason-field')), 'Head teacher agreed');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/items/c/override/'], {'reason': 'Head teacher agreed', 'expectedVersion': 3});
    });

    testWidgets('an overridden family says who included it and why, and the override can be removed', (tester) async {
      final server = draft(items: [itemJson(id: 'c', family: 'Charlie family', status: 'needs_override', override: true, overrideReason: 'Head teacher agreed', previous: 8000000)]);
      await pumpBatch(tester, server);
      expect(find.textContaining('Included by an override (Tunde Maker): Head teacher agreed. What the family owes is unchanged.'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('select-c'))).onChanged, isNotNull);
      await tester.tap(find.byKey(const ValueKey('clear-override-c')));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST batches/batch-1/items/c/override-clear/'));
    });

    testWidgets('where the policy lets a person choose, they choose which earlier balances go into the target', (tester) async {
      final breakdown = [
        {'receivableId': 'r1', 'label': 'Tuition', 'period': '2026/2027 · First Term', 'dueDate': '2026-11-20', 'outstandingMinor': 8000000},
        {'receivableId': 'r2', 'label': 'Transport', 'period': '2026/2027 · First Term', 'dueDate': '2026-11-20', 'outstandingMinor': 2000000},
      ];
      final server = draft(items: [itemJson(id: 'c', family: 'Charlie', arrearsPolicy: 'custom_selection', previous: 10000000, breakdown: breakdown)]);
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('balances-c')));
      await tester.pumpAndSettle();
      expect(find.textContaining('the ones you leave out are still owed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('balance-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Carried into the target: ₦80,000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-balances')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/items/c/arrears/'], {'receivableIds': ['r1'], 'expectedVersion': 3});
    });

    testWidgets('a family whose provider needs its payer\'s BVN says so, and the number is written without ever being shown', (tester) async {
      final server = draft(items: [itemJson(id: '1', family: 'Mona family', status: 'missing_details', selected: false, missing: ['the payer\'s BVN or NIN'], note: 'Monnify needs the payer\'s BVN or NIN before it will make an account.')]);
      await pumpBatch(tester, server);
      expect(tester.widget<Checkbox>(find.byKey(const ValueKey('select-1'))).onChanged, isNull);
      await tester.tap(find.byKey(const ValueKey('identity-1')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('identity-bvn'))).obscureText, isTrue);
      await tester.enterText(find.byKey(const ValueKey('identity-bvn')), '12345678901');
      await tester.tap(find.byKey(const ValueKey('identity-save')));
      await tester.pumpAndSettle();
      expect(server.requests['PUT families/fam-1/payer-identity/'], {'bvn': '12345678901'});
      expect(server.calls, contains('POST batches/batch-1/preview/'));
      expect(find.textContaining('12345678901'), findsNothing);
    });

    testWidgets('the families can be filtered by what they are, by selection and by override', (tester) async {
      final server = draft();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('bucket-needs_override')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/batch-1/items/']!['bucket'], 'needs_override');
      await tester.tap(find.byKey(const ValueKey('filter-selected')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/batch-1/items/']!['selected'], '1');
      await tester.tap(find.byKey(const ValueKey('filter-overridden')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/batch-1/items/']!['overridden'], '1');
    });

    testWidgets('the preview can be exported as a PDF or an Excel file, and nothing is sent to the provider to do it', (tester) async {
      final saved = <String>[];
      final server = draft();
      await pumpBatch(tester, server, saved: saved);
      await tester.tap(find.byKey(const ValueKey('export-pdf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('export-xlsx')));
      await tester.pumpAndSettle();
      expect(saved, ['collection-batch-batch-1.pdf', 'collection-batch-batch-1.xlsx']);
      expect(server.queries['GET batches/batch-1/export/']!['type'], 'xlsx');
      expect(find.textContaining('Saved on this device'), findsOneWidget);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('submitting asks first, sends the fingerprint the maker saw, and only someone who prepares is offered it', (tester) async {
      final server = draft();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('submit-batch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone else must approve it before any account is generated'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/submit/'], {
        'expectedHash': 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
        'expectedVersion': 3,
      });
    });

    testWidgets('a batch with nobody selected cannot be submitted', (tester) async {
      await pumpBatch(tester, draft(batch: batchJson(selected: 0, collection: 0)));
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('submit-batch'))).onPressed, isNull);
    });

    testWidgets('a rejected batch shows who rejected it and why, and goes back to the maker to be revised', (tester) async {
      final server = draft(batch: batchJson(status: 'rejected', rejectionReason: 'Bravo should not be included', can: batchCan(edit: true, submit: true, cancel: true)));
      await pumpBatch(tester, server);
      expect(find.byKey(const ValueKey('rejection-banner')), findsOneWidget);
      expect(find.textContaining('Rejected by Chidi Checker: Bravo should not be included'), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-batch')), findsOneWidget);
    });

    testWidgets('a screen that went stale is told so with the server\'s words and reloaded', (tester) async {
      final server = draft()..refusal = {'code': 'stale_preview', 'message': 'This batch was changed since you last looked at it. Refresh it and try again.', 'version': 4};
      server.refusalStatus = 409;
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('select-a')));
      await tester.pumpAndSettle();
      expect(find.textContaining('This batch was changed since you last looked at it'), findsOneWidget);
      expect(server.calls.where((c) => c == 'GET batches/batch-1/').length, greaterThan(1));
    });

    testWidgets('a batch for a provider that is no longer active says to refresh it', (tester) async {
      await pumpBatch(tester, draft(batch: batchJson(providerActive: false)));
      expect(find.textContaining('no longer Paystack'), findsOneWidget);
    });

    testWidgets('the policy behind the batch says where each setting came from', (tester) async {
      await pumpBatch(tester, draft());
      await tester.tap(find.byKey(const ValueKey('batch-policy')));
      await tester.pumpAndSettle();
      expect(find.text('Using school default'), findsWidgets);
      expect(find.text('Override for this batch'), findsOneWidget);
    });

    testWidgets('the history of the batch is available, with reasons', (tester) async {
      final server = draft()
        ..events = [
          {'id': 1, 'kind': 'created', 'version': 1, 'actor': person('Tunde Maker'), 'detail': <String, Object?>{}, 'at': '2026-09-25T09:00:00+01:00'},
          {'id': 2, 'kind': 'rejected', 'version': 2, 'actor': person('Chidi Checker', role: 'principal'), 'detail': {'reason': 'Bravo should not be included'}, 'at': '2026-09-25T10:00:00+01:00'},
        ];
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('batch-history')));
      await tester.pumpAndSettle();
      expect(find.text('Prepared'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.textContaining('Reason: Bravo should not be included'), findsOneWidget);
    });
  });

  group('the checker deciding on a batch', () {
    CollectionsServer pending({bool isMaker = false, bool canApprove = true, List<Map<String, Object?>>? items}) => CollectionsServer()
      ..batch = batchJson(status: 'pending_approval', isMaker: isMaker, can: batchCan(approve: canApprove, reject: canApprove))
      ..items = items ?? [itemJson(id: 'a', family: 'Alpha family'), itemJson(id: 'b', family: 'Bravo family')];

    testWidgets('they see exactly what would be generated, cannot change it, and are offered approve and reject', (tester) async {
      await pumpBatch(tester, pending());
      expect(find.text('Waiting for approval'), findsWidgets);
      expect(find.byKey(const ValueKey('approve-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey('reject-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-batch')), findsNothing);
      expect(find.byKey(const ValueKey('select-a')), findsNothing);
      expect(find.byKey(const ValueKey('export-pdf')), findsOneWidget);
      expect(find.text('Submitted by'), findsOneWidget);
      expect(find.textContaining('Tunde Maker'), findsWidgets);
    });

    testWidgets('approving asks first and names the exact fingerprint they saw', (tester) async {
      final server = pending();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('approve-batch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('if anything changes before it runs, it is withdrawn'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/approve/'], {'expectedHash': 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90'});
    });

    testWidgets('the person who prepared it is told someone else must approve, and is not offered the button', (tester) async {
      await pumpBatch(tester, pending(isMaker: true, canApprove: false));
      expect(find.text('You prepared or changed this batch, so someone else must approve it.'), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-batch')), findsNothing);
      expect(find.byKey(const ValueKey('reject-batch')), findsNothing);
    });

    testWidgets('a rejection needs a real reason, and it goes back with it', (tester) async {
      final server = pending();
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('reject-batch')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('reason-field')), 'No');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('reason-field')), 'Bravo should not be included');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/reject/'], {'reason': 'Bravo should not be included'});
    });

    testWidgets('families the policy asks the approver to approve one by one must all be ticked before approval', (tester) async {
      final server = pending(items: [itemJson(id: 'm1', family: 'Mona family', status: 'manual_approval', previous: 5000000, manualNeeded: true)])
        ..itemBuckets = {'manual_approval': {'total': 1, 'selected': 1}};
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('approve-batch')));
      await tester.pumpAndSettle();
      expect(find.text('Approve these families one by one'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('manual-approve-all'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('approve-m1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manual-approve-all')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/approve/'], {
        'expectedHash': 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
        'manualApprovals': ['m1'],
      });
    });

    testWidgets('when the batch changed after the checker opened it, they are told it was withdrawn', (tester) async {
      final server = pending()
        ..refusal = {'code': 'batch_changed', 'message': 'What families owe changed since this batch was submitted. Its approval was withdrawn and it is back with the maker.'}
        ..refusalStatus = 409;
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('approve-batch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Its approval was withdrawn and it is back with the maker'), findsOneWidget);
    });
  });

  group('generating the accounts', () {
    testWidgets('only an approved batch offers to generate, after asking, and it says nothing has reached the provider before', (tester) async {
      final server = CollectionsServer()
        ..batch = batchJson(status: 'approved', can: batchCan(start: true))
        ..batchAfterAction = batchJson(status: 'processing', progress: {'status': 'processing', 'total': 2, 'successful': 0, 'failed': 0, 'waiting': 2, 'generating': 0, 'finished': false});
      await pumpBatch(tester, server);
      expect(find.byKey(const ValueKey('start-batch')), findsOneWidget);
      expect(find.byKey(const ValueKey('submit-batch')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('start-batch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('asks Paystack to make an account for each selected family'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-action')));
      await tester.pump();
      await tester.pump();
      expect(server.calls, contains('POST batches/batch-1/start/'));
      expect(find.text('Generating collection accounts'), findsOneWidget);
      expect(find.byKey(const ValueKey('generation-progress')), findsOneWidget);
      // leave the poll timer running down cleanly
      server.batch = batchJson(status: 'completed', selected: 2, successful: 2);
      server.progress = {'status': 'completed', 'total': 2, 'successful': 2, 'failed': 0, 'waiting': 0, 'generating': 0, 'finished': true};
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Generation complete'), findsOneWidget);
    });

    testWidgets('a batch that finished with errors keeps its successes, lists the failures and offers to retry them', (tester) async {
      final failed = [
        itemJson(id: 'f1', family: 'Bravo family', generation: 'failed', error: 'provider_rejected', errorMessage: 'The provider did not accept the request.'),
        itemJson(id: 'f2', family: 'Delta family', generation: 'failed', error: 'provider_rejected', errorMessage: 'The provider did not accept the request.'),
      ];
      final server = CollectionsServer()
        ..batch = batchJson(status: 'partially_successful', selected: 600, successful: 590, failed: 10, can: batchCan(retry: true))
        ..items = [itemJson(id: 'a', family: 'Alpha family', generation: 'success'), ...failed]
        ..failedItems = failed;
      await pumpBatch(tester, server);
      expect(find.text('Generation complete with errors'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('result-successful'))).data, '590');
      expect(tester.widget<Text>(find.byKey(const ValueKey('result-failed'))).data, '10');
      expect(find.textContaining('Every account that was generated stays'), findsOneWidget);
      expect(find.text('Generated'), findsOneWidget);
      expect(find.text('The provider did not accept the request.'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('view-failed')));
      await tester.pumpAndSettle();
      expect(server.queries['GET batches/batch-1/items/']!['generation'], 'failed');
    });

    testWidgets('all failed families can be retried at once', (tester) async {
      final server = CollectionsServer()
        ..batch = batchJson(status: 'partially_successful', selected: 3, successful: 2, failed: 1, can: batchCan(retry: true))
        ..retryAnswer = {'retried': 1};
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('retry-all')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/retry/'], isEmpty);
      expect(find.text('Retrying 1 family.'), findsOneWidget);
    });

    testWidgets('chosen failed families can be retried on their own', (tester) async {
      final failed = [
        itemJson(id: 'f1', family: 'Bravo family', generation: 'failed', error: 'provider_rejected', errorMessage: 'The provider did not accept the request.'),
        itemJson(id: 'f2', family: 'Delta family', generation: 'failed', error: 'provider_rejected', errorMessage: 'The provider did not accept the request.'),
      ];
      final server = CollectionsServer()
        ..batch = batchJson(status: 'partially_successful', selected: 3, successful: 1, failed: 2, can: batchCan(retry: true))
        ..items = failed
        ..failedItems = failed;
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('select-failed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retry-selected')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-f1'))); // untick one
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('retry-selected')));
      await tester.pumpAndSettle();
      expect(server.requests['POST batches/batch-1/retry/'], {'itemIds': ['f2']});
    });

    testWidgets('when something changed since approval, the retry says the batch needs a fresh approval and retries nothing', (tester) async {
      final server = CollectionsServer()
        ..batch = batchJson(status: 'partially_successful', selected: 3, successful: 2, failed: 1, can: batchCan(retry: true))
        ..batchAfterAction = batchJson(status: 'draft')
        ..retryAnswer = {'retried': 0, 'approvalNeeded': true};
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('retry-all')));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs a fresh approval before the failed families are retried'), findsOneWidget);
    });

    testWidgets('a batch can be cancelled only while nothing has been generated', (tester) async {
      final server = CollectionsServer()..batch = batchJson(can: batchCan(edit: true, submit: true, cancel: true));
      await pumpBatch(tester, server);
      await tester.tap(find.byKey(const ValueKey('cancel-batch')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nothing has been generated'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST batches/batch-1/cancel/'));
    });
  });

  group('the families and their accounts', () {
    Future<void> open(WidgetTester tester, CollectionsServer server) =>
        pumpScreen(tester, server, (smart, families) => AccountsTab(api: smart, familyApi: families, membership: ownerMembership));

    testWidgets('a family with an account shows its status and number; one without says an account is made by a batch', (tester) async {
      final server = CollectionsServer()
        ..families = [
          familyJson(accounts: [
            {
              'id': 'acc-1', 'provider': 'paystack', 'bankName': 'Wema Bank', 'accountName': 'Bello', 'accountNumber': '9930000902', 'numberLabel': 'Account number',
              'details': <Object?>[], 'note': '', 'status': 'active', 'canPay': true, 'isTest': false,
            },
          ]),
          familyJson(id: 'fam-2', name: 'Kabir family', code: 'FAM-KABIR'),
        ];
      await open(tester, server);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Wema Bank'), findsOneWidget);
      expect(find.text('Account number: 9930000902'), findsOneWidget);
      expect(find.textContaining('No collection account yet. One is made when the family is in an approved collection batch.'), findsOneWidget);
    });

    testWidgets('no account is typed in by hand and none is issued from here', (tester) async {
      await open(tester, CollectionsServer());
      for (final gone in ['Record what the bank gave', 'Issue accounts for every family', 'Set up account', 'Add an account']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('Accounts are made by a collection batch'), findsOneWidget);
    });

    testWidgets('the families can be filtered by having an account', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('accounts-filter-without')));
      await tester.pumpAndSettle();
      expect(server.queries['GET receivables/families/']!['accounts'], 'without');
    });

    testWidgets('a family\'s history shows every account it has had, which batch made it and why one closed', (tester) async {
      final server = CollectionsServer()..accountHistory = [accountRecordJson(), accountRecordJson(id: 'acc-0', status: 'closed', number: '9930000111')];
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('family-fam-1')));
      await tester.pumpAndSettle();
      expect(find.text('Account history'), findsOneWidget);
      expect(find.textContaining('9930000902'), findsWidgets);
      expect(find.textContaining('9930000111'), findsOneWidget);
      expect(find.textContaining('Made by Term one accounts'), findsWidgets);
      expect(find.textContaining('Closed 20 Sep 2026: Family left'), findsOneWidget);
      expect(find.byKey(const ValueKey('retire-acc-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('retire-acc-0')), findsNothing); // a closed account cannot be retired again
    });

    testWidgets('retiring an account needs a reason and asks the provider to close it', (tester) async {
      final server = CollectionsServer()..accountHistory = [accountRecordJson()];
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('family-fam-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('retire-acc-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('The provider is asked to close 9930000902'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('reason-field')), 'Family left the school');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST receivables/collection-accounts/acc-1/close/'], {'reason': 'Family left the school'});
    });

    testWidgets('a payer\'s identity number can be recorded, is only ever "on file", and never appears', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('family-fam-1')));
      await tester.pumpAndSettle();
      expect(find.text('Add payer BVN or NIN'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('family-identity')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('identity-nin')), '10987654321');
      await tester.tap(find.byKey(const ValueKey('identity-save')));
      await tester.pumpAndSettle();
      expect(server.requests['PUT families/fam-1/payer-identity/'], {'nin': '10987654321'});
      expect(find.text('Payer identity: on file'), findsOneWidget);
      expect(find.textContaining('10987654321'), findsNothing);
    });

    testWidgets('a family can have a policy of its own, without choosing a provider', (tester) async {
      final server = CollectionsServer();
      await open(tester, server);
      await tester.tap(find.byKey(const ValueKey('family-fam-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('family-policy')));
      await tester.pumpAndSettle();
      expect(find.text('Bello family'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('change-settlement_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('field-settlement_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave it for a person').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-override')));
      await tester.pumpAndSettle();
      final sent = server.requests['POST policy/overrides/']!;
      expect((sent['scope'], sent['familyId']), ('family', 'fam-1'));
      expect(sent['values'], {'settlement_action': 'manual'});
    });
  });
}
