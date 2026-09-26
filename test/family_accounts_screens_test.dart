import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/features/bankconnect/data/bank_connect_api.dart';
import 'package:schoolos_app/features/bankconnect/presentation/collections_hub_page.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';
import 'family_fees_fixtures.dart';

/// A school server for the families' accounts that remembers what it was sent.
class Families {
  List<Map<String, Object?>> families = [
    familyRowJson(accounts: [payAccountJson(staff: true)]),
    familyRowJson(id: 'fam-2', code: 'FAM-SANI', name: 'Sani family', students: const ['Yusuf Sani']),
  ];
  bool hasMore = false;
  bool canDecide = true;
  List<Map<String, String>> mergeProblems = const [];
  List<Map<String, Object?>> connections = [connectionJson()];
  Map<String, Object?>? refusal;
  final requests = <String, Map<String, dynamic>>{};
  final queries = <String, Map<String, String>>{};

  static const _receivables = '/api/v1/schools/$schoolId/receivables/';
  static const _collections = '/api/v1/schools/$schoolId/collections/';

  Future<http.Response> handle(http.Request r) async {
    final receivables = r.url.path.startsWith(_receivables);
    final path = r.url.path.replaceFirst(receivables ? _receivables : _collections, '');
    final key = '${r.method} $path';
    queries[key] = r.url.queryParameters;
    if (r.method == 'POST') requests[key] = r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
    if (!receivables) {
      switch (key) {
        case 'GET summary/':
          return jsonResponse(summaryJson());
        case 'GET connections/':
          return jsonResponse(connectionsJson(connections));
        case 'GET providers/':
          return jsonResponse(providersJson());
      }
      return jsonResponse({'message': 'not found'}, 404);
    }
    if (refusal != null && r.method == 'POST') return jsonResponse(refusal, 400);
    switch (key) {
      case 'GET families/':
        return jsonResponse(familyPageJson(families, hasMore: hasMore, canDecideBilling: canDecide));
      case 'GET collection-accounts/providers/':
        return jsonResponse(accountProvidersJson());
      case 'POST families/fam-2/collection-accounts/':
        return jsonResponse({'account': payAccountJson(id: 'acc-new', staff: true)}, 201);
      case 'POST families/fam-2/collection-accounts/issue/':
        return jsonResponse({'account': payAccountJson(id: 'acc-new', provider: 'sandbox', bankName: 'SchoolOS Test Bank', isTest: true, staff: true)}, 201);
      case 'POST collection-accounts/issue-missing/':
        return jsonResponse({
          'issued': 3,
          'failed': [
            {'familyId': 'fam-9', 'familyName': 'Eze family', 'code': 'issue_failed', 'message': 'An account could not be made. Try again.'},
          ],
        });
      case 'GET families/fam-2/merge-preview/':
        return jsonResponse(mergePreviewJson(problems: mergeProblems));
      case 'POST families/fam-2/merge/':
        return jsonResponse({'merge': {'into': {}, 'source': {}, 'moved': {}}});
    }
    if (r.method == 'POST' && path.startsWith('collection-accounts/acc-1/')) {
      return jsonResponse({'account': payAccountJson(staff: true)});
    }
    return jsonResponse({'message': 'not found'}, 404);
  }
}

Map<String, Object?> gtbankConnection() => {
      ...connectionJson(id: 'conn-gt', label: 'GTBank tuition', sandbox: false),
      'provider': 'gtbank',
      'providerName': 'GTBank',
      'connectionType': 'direct_bank_api',
      'bankName': 'GTBank',
    };

Future<Families> pumpFamilies(
  WidgetTester tester, {
  Families? server,
  SchoolMembership membership = ownerMembership,
  bool withFamilyApi = true,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = server ?? Families();
  final client = apiFor(FakeServer(fake.handle));
  Widget home = Scaffold(body: CollectionsHubPage(membership: membership));
  if (withFamilyApi) home = FamilyFeesScope(api: FamilyFeesApi(api: client), child: home);
  home = BankConnectScope(api: BankConnectApi(api: client), child: home);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Tab, 'Family accounts'));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> pick(WidgetTester tester, Key dropdown, String option) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> openMenu(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('each family is shown once with its children and the account it pays into', (tester) async {
      await pumpFamilies(tester);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.textContaining('Ahmad Bello, Aisha Bello, Maryam Bello'), findsOneWidget);
      // One account for three children, shown under the bank's own word for the number.
      expect(find.text('GTBank'), findsOneWidget);
      expect(find.textContaining('Account number: 0123456789'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('a family with no account says it has nowhere to pay and offers to set one up', (tester) async {
      await pumpFamilies(tester);
      expect(find.text('Sani family'), findsOneWidget);
      expect(find.textContaining('No payment account yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-fam-2')), findsOneWidget);
    });

    testWidgets('an account still being set up or paused says so, and a test account is labelled', (tester) async {
      final server = Families()
        ..families = [
          familyRowJson(accounts: [
            payAccountJson(id: 'a', status: 'provisioning', staff: true),
            payAccountJson(id: 'b', provider: 'uba', bankName: 'UBA', accountNumber: '1000000001', status: 'suspended', staff: true),
            payAccountJson(id: 'c', provider: 'sandbox', bankName: 'Test Bank', accountNumber: '9123456789', isTest: true, staff: true),
          ]),
        ];
      await pumpFamilies(tester, server: server);
      expect(find.text('Being set up'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Test data'), findsOneWidget);
    });

    testWidgets('a bank\'s own label for the number and its extra facts are shown as given', (tester) async {
      final server = Families()
        ..families = [
          familyRowJson(accounts: [
            payAccountJson(
              provider: 'moniepoint', bankName: 'Moniepoint', accountNumber: 'MP-4471-2209', numberLabel: 'Payment code',
              details: [
                {'label': 'Payment reference', 'value': 'BG-0042'},
              ],
              staff: true,
            ),
          ]),
        ];
      await pumpFamilies(tester, server: server);
      expect(find.textContaining('Payment code: MP-4471-2209'), findsOneWidget);
      expect(find.text('Payment reference: BG-0042'), findsOneWidget);
    });

    testWidgets('the filters and the search ask the server, and paging asks for the next page', (tester) async {
      final server = await pumpFamilies(tester, server: Families()..hasMore = true);
      await tester.tap(find.byKey(const ValueKey('family-filter-No account yet')));
      await tester.pumpAndSettle();
      expect(server.queries['GET families/']!['accounts'], 'without');
      await tester.enterText(find.byKey(const ValueKey('family-search')), 'Sani');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(server.queries['GET families/']!['q'], 'Sani');
      await tester.tap(find.text('Show more families'));
      await tester.pumpAndSettle();
      expect(server.queries['GET families/']!['offset'], '2');
    });

    testWidgets('a merged family says so and offers no actions', (tester) async {
      final server = Families()..families = [familyRowJson(id: 'fam-2', name: 'Sani family', status: 'inactive', mergedInto: 'fam-1', students: const [])];
      await pumpFamilies(tester, server: server);
      expect(find.text('Merged into another family'), findsOneWidget);
      expect(find.byKey(const ValueKey('family-menu-fam-2')), findsNothing);
      expect(find.byKey(const ValueKey('setup-fam-2')), findsNothing);
    });

    testWidgets('without the school\'s server for families it says so and shows none', (tester) async {
      await pumpFamilies(tester, withFamilyApi: false);
      expect(find.textContaining('come from your school’s server'), findsOneWidget);
      expect(find.text('Bello family'), findsNothing);
    });
  });

  group('setting up an account', () {
    testWidgets('recording what a bank gave adapts to that bank: its word for the number, its example, its extra facts', (tester) async {
      final server = await pumpFamilies(tester);
      await tester.tap(find.byKey(const ValueKey('setup-fam-2')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Record what the bank gave');
      await pick(tester, const ValueKey('record-provider'), 'Moniepoint Business');
      expect(find.text('Payment code'), findsOneWidget);
      expect(find.text('For example MP-4471-2209'), findsOneWidget);
      expect(find.byKey(const ValueKey('fact-label-0')), findsOneWidget); // "Payment reference", offered because this bank asks for it
      expect(tester.widget<TextField>(find.byKey(const ValueKey('fact-label-0'))).controller!.text, 'Payment reference');

      await tester.enterText(find.byKey(const ValueKey('record-number')), 'MP 4471 2209');
      await tester.enterText(find.byKey(const ValueKey('record-name')), 'SANI FAMILY');
      await tester.enterText(find.byKey(const ValueKey('fact-value-0')), 'BG-0099');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-confirm')));
      await tester.pumpAndSettle();

      final sent = server.requests['POST families/fam-2/collection-accounts/']!;
      expect(sent['provider'], 'moniepoint');
      expect(sent['accountNumber'], 'MP 4471 2209'); // the server tidies it; the phone sends what was typed
      expect(sent['accountName'], 'SANI FAMILY');
      expect(sent['details'], [
        {'label': 'Payment reference', 'value': 'BG-0099'},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('saving needs a number and a bank name, and a refusal is shown in the dialog without closing it', (tester) async {
      final server = Families()..refusal = {'code': 'invalid_account_number', 'message': 'That is not a valid account number.'};
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('setup-fam-2')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Record what the bank gave');
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('setup-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('record-number')), '#!');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('setup-error')), findsOneWidget);
      expect(find.text('That is not a valid account number.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a bank that can issue accounts is asked to, under the school\'s own connection', (tester) async {
      final server = await pumpFamilies(tester);
      await tester.tap(find.byKey(const ValueKey('setup-fam-2')));
      await tester.pumpAndSettle();
      // The only connected account is the sandbox, which can issue.
      expect(find.byKey(const ValueKey('issue-note')), findsOneWidget);
      expect(find.textContaining('SchoolOS will ask Sandbox (test data) to issue an account'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST families/fam-2/collection-accounts/issue/'], {'connectionId': 'conn-1'});
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a listed bank that cannot issue yet says why and offers only recording it by hand', (tester) async {
      final server = Families()..connections = [gtbankConnection()];
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('setup-fam-2')));
      await tester.pumpAndSettle();
      // Issuing is not the default when the bank cannot do it.
      expect(find.byKey(const ValueKey('record-provider')), findsOneWidget);
      await tapText(tester, 'Ask the bank to issue it');
      expect(find.textContaining('cannot issue accounts for families yet'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('setup-confirm'))).onPressed, isNull);
      expect(server.requests.containsKey('POST families/fam-2/collection-accounts/issue/'), isFalse);
    });

    testWidgets('with no connected bank account issuing is not possible and the dialog says how to go on', (tester) async {
      final server = Families()..connections = [];
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('setup-fam-2')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Ask the bank to issue it');
      expect(find.textContaining('No bank account is connected yet'), findsOneWidget);
    });

    testWidgets('issuing for every family reports how many were made and which could not be', (tester) async {
      final server = await pumpFamilies(tester);
      await tester.tap(find.byKey(const ValueKey('issue-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('issue-all-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST collection-accounts/issue-missing/'], {'connectionId': 'conn-1'});
      expect(find.text('Issued 3 accounts.'), findsOneWidget);
      expect(find.textContaining('Eze family: An account could not be made'), findsOneWidget);
    });

    testWidgets('issuing for everyone is not offered for a bank that cannot issue yet', (tester) async {
      final server = Families()..connections = [gtbankConnection()];
      await pumpFamilies(tester, server: server);
      await tester.tap(find.byKey(const ValueKey('issue-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('issue-all-cannot')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('issue-all-confirm'))).onPressed, isNull);
    });
  });

  group('managing an account', () {
    testWidgets('pausing needs a reason, which is sent', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'account-menu-acc-1', 'Pause…');
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('reason')), 'Under review');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reason-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST collection-accounts/acc-1/suspend/'], {'reason': 'Under review'});
    });

    testWidgets('closing needs a reason too, and cancelling sends nothing', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'account-menu-acc-1', 'Close…');
      await tapText(tester, 'Cancel');
      expect(server.requests.keys.where((k) => k.contains('collection-accounts/acc-1')), isEmpty);
    });

    testWidgets('a paused account can be reinstated, and one being set up can be marked ready', (tester) async {
      final server = Families()
        ..families = [
          familyRowJson(accounts: [
            payAccountJson(status: 'suspended', staff: true),
          ]),
        ];
      await pumpFamilies(tester, server: server);
      await openMenu(tester, 'account-menu-acc-1', 'Reinstate');
      expect(server.requests.containsKey('POST collection-accounts/acc-1/reinstate/'), isTrue);
    });
  });

  group('merging families', () {
    testWidgets('only someone who may decide billing is offered it', (tester) async {
      await pumpFamilies(tester, server: Families()..canDecide = false);
      await tester.tap(find.byKey(const ValueKey('family-menu-fam-2')));
      await tester.pumpAndSettle();
      expect(find.text('Merge into another family…'), findsNothing);
    });

    testWidgets('choose the family, read what would happen, give a reason and confirm', (tester) async {
      final server = await pumpFamilies(tester);
      await openMenu(tester, 'family-menu-fam-2', 'Merge into another family…');
      await tester.enterText(find.byKey(const ValueKey('merge-search')), 'Bello');
      await tester.tap(find.byKey(const ValueKey('merge-find')));
      await tester.pumpAndSettle();
      // The family itself is never offered as its own target.
      expect(find.byKey(const ValueKey('merge-target-fam-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('merge-target-fam-1')));
      await tester.pumpAndSettle();
      expect(server.queries['GET families/fam-2/merge-preview/']!['into'], 'fam-1');
      expect(find.textContaining('Sani family will be merged into Bello family'), findsOneWidget);
      expect(find.textContaining('Children moving: Yusuf Sani'), findsOneWidget);
      expect(find.textContaining('Accounts that move to Bello family: UBA'), findsOneWidget);
      expect(find.textContaining('Accounts at GTBank stay where they are'), findsOneWidget);
      // Nothing happens until a reason is given and the person says they understand.
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('merge-confirm'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('merge-reason')), 'Registered twice');
      await tester.tap(find.byKey(const ValueKey('merge-understood')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge-confirm')));
      await tester.pumpAndSettle();
      expect(server.requests['POST families/fam-2/merge/'], {'intoFamilyId': 'fam-1', 'reason': 'Registered twice'});
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('what would refuse a merge is shown and the merge cannot be confirmed', (tester) async {
      final server = Families()
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
      final server = Families();
      await pumpFamilies(tester, server: server);
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
