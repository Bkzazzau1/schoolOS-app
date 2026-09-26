import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/features/bankconnect/data/bank_connect_api.dart';
import 'package:schoolos_app/features/bankconnect/presentation/collections_hub_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';

/// A school server that remembers what it was sent, so the tests can check what left the phone.
class Bank {
  Map<String, Object?> providers = providersJson();
  List<Map<String, Object?>> connections = [connectionJson()];
  bool canManage = true;
  Map<String, Object?> summary = summaryJson();
  List<Map<String, Object?>> payments = [paymentJson()];
  Map<String, int> counts = {'requires_review': 1};
  bool failConnect = false;
  bool stale = false;
  final requests = <String, Map<String, dynamic>>{};
  final queries = <String, Map<String, String>>{};

  static const _base = '/api/v1/schools/$schoolId/collections/';

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst(_base, '');
    final key = '${r.method} $path';
    queries[key] = r.url.queryParameters;
    if (r.method == 'POST') requests[key] = r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
    switch (key) {
      case 'GET providers/':
        return jsonResponse({...providers, 'canManage': canManage});
      case 'GET connections/':
        return jsonResponse(connectionsJson(connections, canManage: canManage));
      case 'GET summary/':
        return jsonResponse(summary);
      case 'GET transactions/':
        return jsonResponse(pageJson(payments));
      case 'GET review/':
        return jsonResponse(pageJson(payments, counts: counts));
      case 'GET transactions/pay-1/':
        return jsonResponse({'transaction': paymentJson(decisions: [])});
      case 'GET students/':
        return jsonResponse({'students': <Object?>[]});
      case 'POST connections/':
        if (failConnect) {
          return jsonResponse({'code': 'bad_credentials', 'message': 'The provider did not accept these credentials.'}, 400);
        }
        return jsonResponse({'connection': connectionJson(id: 'conn-2', status: 'pending')}, 201);
      case 'POST connections/conn-2/confirm/':
        connections = [...connections, connectionJson(id: 'conn-2')];
        return jsonResponse({'connection': connectionJson(id: 'conn-2'), 'webhook': {'path': 'bank-webhooks/sandbox/TOKEN123/'}});
      case 'POST connections/conn-2/disconnect/':
        return jsonResponse({'connection': connectionJson(id: 'conn-2', status: 'revoked'), 'providerRevoked': true});
      case 'POST transactions/pay-1/decide/':
        if (stale) {
          return jsonResponse({'code': 'stale', 'message': 'Someone has changed this payment since you opened it. Refresh and look again.'}, 400);
        }
        return jsonResponse({
          'transaction': paymentJson(status: 'matched', allocations: [
            {'id': 'a1', 'studentId': 'student-BG-0042', 'studentName': 'Aisha Bello', 'studentCode': 'BG-0042', 'purpose': 'tuition', 'amountMinor': 5000000, 'source': 'manual', 'superseded': false},
          ], decisions: []),
        });
    }
    if (r.method == 'POST' && path.startsWith('connections/')) {
      return jsonResponse({'connection': connections.isEmpty ? connectionJson() : connections.first, 'test': {'ok': true, 'code': '', 'message': ''}});
    }
    return jsonResponse({'message': 'not found'}, 404);
  }
}

Future<Bank> pumpHub(
  WidgetTester tester, {
  Bank? bank,
  SchoolMembership membership = ownerMembership,
  bool withServer = true,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = bank ?? Bank();
  final api = BankConnectApi(api: apiFor(FakeServer(fake.handle)));
  Widget home = Scaffold(body: CollectionsHubPage(membership: membership));
  if (withServer) home = BankConnectScope(api: api, child: home);
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> openTab(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(Tab, name));
  await tester.pumpAndSettle();
}

void main() {
  group('with no school server', () {
    testWidgets('it says a server is needed and shows no accounts, no figures and nothing to connect', (tester) async {
      await pumpHub(tester, withServer: false);
      expect(find.text('Bank accounts need your school\'s server'), findsOneWidget);
      expect(find.text('Connect bank'), findsNothing);
      expect(find.textContaining('₦'), findsNothing);
    });
  });

  group('overview', () {
    testWidgets('with no account connected it says so instead of showing zeros as facts', (tester) async {
      final bank = Bank()..summary = summaryJson(available: false, today: 0);
      await pumpHub(tester, bank: bank);
      expect(find.text('No bank account is connected yet'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
      expect(find.text('Go to bank accounts'), findsOneWidget);
    });

    testWidgets('with an account it shows what came in, what is reconciled and what waits for a person', (tester) async {
      await pumpHub(tester);
      expect(find.text('₦50,000'), findsWidgets); // today
      expect(find.text('₦150,000'), findsOneWidget); // this week
      expect(find.text('₦450,000'), findsWidgets); // this term
      expect(find.textContaining('₦300,000 matched to students'), findsOneWidget);
      expect(find.textContaining('₦150,000 still waiting for a person'), findsOneWidget);
      expect(find.text('2 to review'), findsOneWidget);
      expect(find.text('Tuition'), findsOneWidget);
      expect(find.textContaining('Tuition Collection ****1111'), findsOneWidget);
    });

    testWidgets('it never claims to know what is still owed', (tester) async {
      await pumpHub(tester);
      expect(find.textContaining('What is still owed is not shown yet'), findsOneWidget);
    });

    testWidgets('test payments are left out and the screen says how many', (tester) async {
      final bank = Bank()..summary = summaryJson(sandboxHidden: 3);
      await pumpHub(tester, bank: bank);
      expect(find.text('Include test data'), findsOneWidget);
      expect(find.textContaining('3 test payments are left out of every figure'), findsOneWidget);
    });

    testWidgets('a payment in another currency is said not to be in the naira totals', (tester) async {
      final bank = Bank()..summary = summaryJson(otherCurrency: 2);
      await pumpHub(tester, bank: bank);
      expect(find.textContaining('2 payment(s) in another currency'), findsOneWidget);
    });
  });

  group('bank accounts', () {
    testWidgets('a connected account shows the bank\'s name, the last four digits, its state and what it can do', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Bank accounts');
      expect(find.text('Tuition Collection'), findsOneWidget);
      expect(find.textContaining('Sandbox Bank · ****6789'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Test data'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
      expect(find.text('Payments'), findsWidgets);
      expect(find.text('Connect bank'), findsOneWidget);
      expect(find.textContaining('0123456789'), findsNothing);
    });

    testWidgets('the finance office can look and sync but not change or connect anything', (tester) async {
      final bank = Bank()..canManage = false;
      await pumpHub(tester, bank: bank, membership: financeMembership);
      await openTab(tester, 'Bank accounts');
      expect(find.text('Connect bank'), findsNothing);
      expect(find.text('Test'), findsNothing);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Change credentials'), findsNothing);
    });

    testWidgets('an account waiting for confirmation can be confirmed and shows its callback address once', (tester) async {
      final bank = Bank()..connections = [connectionJson(id: 'conn-2', status: 'pending')];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      expect(find.text('Waiting for confirmation'), findsOneWidget);
      await tester.tap(find.text('Confirm account'));
      await tester.pumpAndSettle();
      expect(bank.requests.containsKey('POST connections/conn-2/confirm/'), isTrue);
      expect(find.text('Callback address'), findsOneWidget);
      expect(find.text('bank-webhooks/sandbox/TOKEN123/'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.textContaining('bank-webhooks'), findsNothing);
    });

    testWidgets('an account the bank stopped accepting says why and offers to reconnect', (tester) async {
      final bank = Bank()..connections = [connectionJson(status: 'needs_reauth', lastError: 'bad_credentials')];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      expect(find.text('Needs reconnecting'), findsOneWidget);
      expect(find.textContaining('no longer accepts the saved credentials'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
    });

    testWidgets('reconnecting sends new credentials from masked boxes and leaves nothing on screen', (tester) async {
      final bank = Bank()..connections = [connectionJson(status: 'needs_reauth', lastError: 'bad_credentials')];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      await tester.tap(find.text('Reconnect'));
      await tester.pumpAndSettle();
      final key = find.widgetWithText(TextField, 'Sandbox key');
      expect(tester.widget<TextField>(key).obscureText, isTrue);
      expect(tester.widget<TextField>(key).autocorrect, isFalse);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Account number (10 digits)')).obscureText, isFalse);
      await tester.enterText(key, 'sandbox-SECRET-777');
      await tester.enterText(find.widgetWithText(TextField, 'Account number (10 digits)'), '0123456789');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Reconnect')));
      await tester.pumpAndSettle();
      expect(bank.requests['POST connections/conn-1/reconnect/'], {
        'credentials': {'sandbox_key': 'sandbox-SECRET-777', 'account_number': '0123456789'},
      });
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('disconnecting asks first and explains that history is kept', (tester) async {
      final bank = await pumpHub(tester);
      await openTab(tester, 'Bank accounts');
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Payments already received are kept'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(bank.requests.keys, isNot(contains('POST connections/conn-1/disconnect/')));
    });

    testWidgets('an empty school is invited to connect its first account', (tester) async {
      final bank = Bank()..connections = [];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      expect(find.text('No bank accounts connected yet'), findsOneWidget);
    });

    testWidgets('View payments filters the payments to that account', (tester) async {
      final bank = Bank();
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Payments'));
      await tester.pumpAndSettle();
      expect(bank.queries['GET transactions/']!['connection'], 'conn-1');
      expect(find.widgetWithText(InputChip, 'One account'), findsOneWidget);
    });
  });

  group('connecting an account', () {
    Future<void> openConnect(WidgetTester tester, Bank bank) async {
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      await tester.tap(find.text('Connect bank'));
      await tester.pumpAndSettle();
    }

    testWidgets('a bank SchoolOS has no documentation for is shown but cannot be chosen', (tester) async {
      await openConnect(tester, Bank());
      expect(find.text('Connect a bank account'), findsOneWidget);
      expect(find.textContaining('Awaiting verified bank API documentation'), findsOneWidget);
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'GTBank')).enabled, isFalse);
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Sandbox (test data)')).enabled, isTrue);
      expect(find.textContaining('Parents\' own bank accounts never are'), findsOneWidget);
    });

    testWidgets('the whole flow: choose, describe, enter credentials, see the bank\'s own name, confirm', (tester) async {
      final bank = Bank()..connections = [];
      await openConnect(tester, bank);
      await tester.tap(find.text('Sandbox (test data)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'A name for it (optional)'), 'Tuition Collection');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final key = find.widgetWithText(TextField, 'Sandbox key');
      expect(tester.widget<TextField>(key).obscureText, isTrue);
      await tester.enterText(key, 'sandbox-SECRET-777');
      await tester.enterText(find.widgetWithText(TextField, 'Account number (10 digits)'), '0123456789');
      await tester.tap(find.text('Check the account'));
      await tester.pumpAndSettle();
      expect(bank.requests['POST connections/'], {
        'provider': 'sandbox',
        'purpose': 'tuition',
        'label': 'Tuition Collection',
        'credentials': {'sandbox_key': 'sandbox-SECRET-777', 'account_number': '0123456789'},
      });
      expect(find.text('Is this your school\'s account?'), findsOneWidget);
      expect(find.text('Sandbox Bank'), findsOneWidget);
      expect(find.text('SANDBOX SCHOOL ACCOUNT'), findsOneWidget);
      expect(find.text('Account ****6789'), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('0123456789'), findsNothing);
      await tester.tap(find.text('Yes, this is our account'));
      await tester.pumpAndSettle();
      expect(bank.requests.containsKey('POST connections/conn-2/confirm/'), isTrue);
      expect(find.textContaining('is connected'), findsOneWidget);
      expect(find.text('bank-webhooks/sandbox/TOKEN123/'), findsOneWidget);
    });

    testWidgets('saying it is not the right account removes it and keeps nothing', (tester) async {
      final bank = Bank()..connections = [];
      await openConnect(tester, bank);
      await tester.tap(find.text('Sandbox (test data)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Sandbox key'), 'sandbox-x');
      await tester.enterText(find.widgetWithText(TextField, 'Account number (10 digits)'), '0123456789');
      await tester.tap(find.text('Check the account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No, this is not the right account'));
      await tester.pumpAndSettle();
      expect(bank.requests.containsKey('POST connections/conn-2/disconnect/'), isTrue);
      expect(find.text('Which account?'), findsOneWidget);
    });

    testWidgets('a refused credential shows the server\'s words and the boxes are emptied', (tester) async {
      final bank = Bank()
        ..connections = []
        ..failConnect = true;
      await openConnect(tester, bank);
      await tester.tap(find.text('Sandbox (test data)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Sandbox key'), 'wrong-SECRET-9');
      await tester.enterText(find.widgetWithText(TextField, 'Account number (10 digits)'), '0123456789');
      await tester.tap(find.text('Check the account'));
      await tester.pumpAndSettle();
      expect(find.text('The provider did not accept these credentials.'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Sandbox key')).controller!.text, isEmpty);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Account number (10 digits)')).controller!.text, isEmpty);
      expect(find.textContaining('SECRET'), findsNothing);
    });

    testWidgets('a server with no secure storage cannot be connected to, and says why', (tester) async {
      final bank = Bank()..providers = providersJson(storage: false);
      await openConnect(tester, bank);
      expect(find.textContaining('no secure storage set up for bank credentials'), findsOneWidget);
      expect(find.text('Sandbox (test data)'), findsNothing);
    });

    testWidgets('someone who may not manage accounts is not offered the button at all', (tester) async {
      final bank = Bank()..canManage = false;
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Bank accounts');
      expect(find.text('Connect bank'), findsNothing);
    });
  });

  group('review', () {
    testWidgets('a payment SchoolOS could not settle waits for a person, with the evidence', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Review');
      expect(find.text('₦50,000'), findsOneWidget);
      expect(find.text('Musa Bello'), findsOneWidget);
      expect(find.text('Needs review'), findsWidgets);
      expect(find.text('All (1)'), findsOneWidget);
      await tester.tap(find.text('Musa Bello'));
      await tester.pumpAndSettle();
      expect(find.text('What SchoolOS saw'), findsOneWidget);
      expect(find.textContaining('2 students fit about equally well'), findsOneWidget);
      expect(find.textContaining('Aisha Bello (BG-0042) - 65%'), findsOneWidget);
      expect(find.textContaining('Bilal Bello (BG-0043) - 65%'), findsOneWidget);
      expect(find.textContaining('The sender\'s name matches a guardian\'s name (+35)'), findsWidgets);
      expect(find.text('• The sender\'s name matches a guardian\'s name (+35)'), findsWidgets);
      expect(find.textContaining('****9012'), findsOneWidget);
    });

    testWidgets('assigning it to a student sends the decision with what the person was looking at', (tester) async {
      final bank = Bank();
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Review');
      await tester.tap(find.text('Musa Bello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign to a student').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a student'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Aisha Bello (BG-0042)'));
      await tester.pumpAndSettle();
      expect(find.text('Aisha Bello'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();
      expect(bank.requests['POST transactions/pay-1/decide/'], {
        'action': 'assign',
        'expectedStatus': 'requires_review',
        'studentId': 'student-BG-0042',
      });
      expect(find.text('Matched'), findsWidgets);
      expect(find.text('Allocated to'), findsOneWidget);
    });

    testWidgets('a decision made on a stale screen is refused with the server\'s words and the screen refreshes', (tester) async {
      final bank = Bank()..stale = true;
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Review');
      await tester.tap(find.text('Musa Bello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign to a student').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a student'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Aisha Bello (BG-0042)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone has changed this payment since you opened it'), findsOneWidget);
    });

    testWidgets('a decision that changes what a payment means needs a note', (tester) async {
      final bank = Bank();
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Review');
      await tester.tap(find.text('Musa Bello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not school fees'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, 'Hall hire deposit');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(bank.requests['POST transactions/pay-1/decide/'], {
        'action': 'unrelated_income',
        'expectedStatus': 'requires_review',
        'note': 'Hall hire deposit',
      });
    });

    testWidgets('an empty queue says nothing is waiting', (tester) async {
      final bank = Bank()
        ..payments = []
        ..counts = {};
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Review');
      expect(find.textContaining('Nothing is waiting for review'), findsOneWidget);
    });
  });

  group('payments', () {
    testWidgets('every payment with its state, and test data labelled as such', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Payments');
      expect(find.text('₦50,000'), findsOneWidget);
      expect(find.text('Test data'), findsOneWidget);
      expect(find.textContaining('Sandbox Bank ****6789'), findsOneWidget);
    });

    testWidgets('a payment already matched shows who it was allocated to', (tester) async {
      final bank = Bank()
        ..payments = [
          paymentJson(status: 'matched', allocations: [
            {'id': 'a1', 'studentId': 's1', 'studentName': 'Aisha Bello', 'studentCode': 'BG-0042', 'purpose': 'tuition', 'amountMinor': 5000000, 'source': 'auto', 'superseded': false},
          ]),
        ];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Payments');
      expect(find.text('For Aisha Bello'), findsOneWidget);
      expect(find.text('Matched'), findsOneWidget);
    });

    testWidgets('an empty list explains what will appear', (tester) async {
      final bank = Bank()..payments = [];
      await pumpHub(tester, bank: bank);
      await openTab(tester, 'Payments');
      expect(find.textContaining('No payments yet'), findsOneWidget);
    });
  });
}
