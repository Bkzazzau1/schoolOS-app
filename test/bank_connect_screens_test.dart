import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/bankconnect/data/bank_connect_api.dart';
import 'package:schoolos_app/features/bankconnect/presentation/collections_hub_page.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/features/smartcollect/data/smart_collect_api.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'collections_test_server.dart';
import 'core/backend_test_support.dart';
import 'smart_collect_fixtures.dart';

Future<CollectionsServer> pumpHub(
  WidgetTester tester, {
  CollectionsServer? server,
  SchoolMembership membership = ownerMembership,
  bool withServer = true,
  bool withSmart = true,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = server ?? CollectionsServer();
  final client = apiFor(FakeServer(fake.handle));
  Widget home = Scaffold(body: CollectionsHubPage(membership: membership, saveExport: (file) async => '/documents/${file.fileName}'));
  if (withSmart) home = SmartCollectScope(api: SmartCollectApi(api: client), child: FamilyFeesScope(api: FamilyFeesApi(api: client), child: home));
  if (withServer) home = BankConnectScope(api: BankConnectApi(api: client), child: home);
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
    testWidgets('it says a server is needed and shows no provider, no account and no figures', (tester) async {
      await pumpHub(tester, withServer: false);
      expect(find.text('Smart Money Collection needs your school\'s server'), findsOneWidget);
      expect(find.text('Connect provider'), findsNothing);
      expect(find.textContaining('₦'), findsNothing);
    });

    testWidgets('a school server without Smart Money Collection still shows the providers and says the rest needs the server', (tester) async {
      await pumpHub(tester, withSmart: false);
      await openTab(tester, 'Collection');
      expect(find.textContaining('Collection batches come from your school\'s server'), findsOneWidget);
      await openTab(tester, 'Policy');
      expect(find.textContaining('The collection policy come from your school\'s server'), findsOneWidget);
    });
  });

  group('the hub', () {
    testWidgets('its tabs are Overview, Providers, Collection, Accounts, Policy, Payments and Review', (tester) async {
      await pumpHub(tester);
      for (final name in ['Overview', 'Providers', 'Collection', 'Accounts', 'Policy', 'Payments', 'Review']) {
        expect(find.widgetWithText(Tab, name), findsOneWidget, reason: name);
      }
      expect(find.widgetWithText(Tab, 'Bank accounts'), findsNothing);
      expect(find.widgetWithText(Tab, 'Family accounts'), findsNothing);
    });

    testWidgets('it says the money goes to the school through its provider and never through SchoolOS', (tester) async {
      await pumpHub(tester);
      expect(find.textContaining('SchoolOS never receives or holds it'), findsOneWidget);
    });
  });

  group('overview', () {
    testWidgets('with no provider connected it says so instead of showing zeros as facts', (tester) async {
      final server = CollectionsServer()..summary = summaryJson(available: false, today: 0);
      await pumpHub(tester, server: server, withSmart: false);
      expect(find.text('No collection provider is connected yet'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
      expect(find.text('Go to providers'), findsOneWidget);
    });

    testWidgets('with a provider it shows what came in, what is reconciled and what waits for a person', (tester) async {
      await pumpHub(tester, withSmart: false);
      expect(find.text('₦50,000'), findsWidgets); // today
      expect(find.text('₦150,000'), findsOneWidget); // this week
      expect(find.text('₦450,000'), findsWidgets); // this term
      expect(find.textContaining('₦300,000 matched to students'), findsOneWidget);
      expect(find.textContaining('₦150,000 still waiting for a person'), findsOneWidget);
      expect(find.text('2 to review'), findsOneWidget);
      expect(find.text('By provider'), findsOneWidget);
      expect(find.textContaining('Main collections (Live)'), findsOneWidget);
      expect(find.textContaining('Paystack'), findsWidgets);
    });

    testWidgets('it never claims to know what is still owed', (tester) async {
      await pumpHub(tester, withSmart: false);
      expect(find.textContaining('What is still owed is not shown yet'), findsOneWidget);
    });

    testWidgets('once fees have been raised it shows what is owed, by term, with arrears called what they are', (tester) async {
      final server = CollectionsServer()..summary = summaryJson(owed: true);
      await pumpHub(tester, server: server, withSmart: false);
      expect(find.text('Still owed'), findsOneWidget);
      expect(find.textContaining('₦290,000 from 2 families'), findsOneWidget);
      expect(find.textContaining('₦130,000 is arrears from terms that have ended'), findsOneWidget);
      expect(find.text('2026/2027 · First Term · Ended'), findsOneWidget);
      expect(find.textContaining('₦60,000 paid of ₦190,000 (32%)'), findsOneWidget);
    });

    testWidgets('test payments are left out and the screen says how many', (tester) async {
      final server = CollectionsServer()..summary = summaryJson(sandboxHidden: 3);
      await pumpHub(tester, server: server, withSmart: false);
      expect(find.text('Include test data'), findsOneWidget);
      expect(find.textContaining('3 test payments are left out of every figure'), findsOneWidget);
    });

    testWidgets('a provider that needs attention says the figures may be behind', (tester) async {
      final server = CollectionsServer()..summary = summaryJson(needAttention: 1);
      await pumpHub(tester, server: server, withSmart: false);
      expect(find.textContaining('1 provider(s) need attention, so these figures may be behind'), findsOneWidget);
    });

    testWidgets('Smart Money Collection\'s own overview shows the active provider, the accounts and what waits for people', (tester) async {
      final server = CollectionsServer()
        ..dashboard = dashboardJson(pending: 1, failed: 3, pendingBatches: [batchJson(status: 'pending_approval', isMaker: false)]);
      await pumpHub(tester, server: server);
      expect(find.text('Active provider: Paystack'), findsOneWidget);
      expect(find.text('Live'), findsWidgets);
      expect(find.text('Webhook active'), findsWidgets);
      expect(find.textContaining('Current period: 2026/2027 · First Term'), findsOneWidget);
      expect(find.textContaining('Default policy: Static accounts'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('stat-with-account'))).data, '10');
      expect(tester.widget<Text>(find.byKey(const ValueKey('stat-without-account'))).data, '4');
      expect(tester.widget<Text>(find.byKey(const ValueKey('stat-pending'))).data, '1');
      expect(tester.widget<Text>(find.byKey(const ValueKey('stat-failed'))).data, '3');
      expect(find.text('Waiting for your approval'), findsOneWidget);
      expect(find.text('Term one accounts'), findsOneWidget);
    });

    testWidgets('a school with no active provider is told to choose one', (tester) async {
      final server = CollectionsServer()..dashboard = (dashboardJson()..['activeProvider'] = null..['connectedProviders'] = <Object?>[]);
      await pumpHub(tester, server: server);
      expect(find.textContaining('No active collection provider'), findsOneWidget);
    });

    testWidgets('a planned provider switch is announced, and a ready one says nothing has changed yet', (tester) async {
      final server = CollectionsServer()..dashboard = dashboardJson(scheduledSwitch: switchJson(status: 'ready_to_switch'));
      await pumpHub(tester, server: server);
      expect(find.textContaining('Ready to switch from Paystack to Monnify. Nothing has changed'), findsOneWidget);
    });
  });

  group('providers', () {
    testWidgets('a connected provider shows its name, mode, merchant, whether it is active and its webhook, and never a credential', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Providers');
      expect(find.text('Paystack'), findsOneWidget);
      expect(find.textContaining('BrightGate Academy · ****7855'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Active provider'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Webhook active'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);
      expect(find.text('Webhook setup'), findsOneWidget);
      expect(find.text('Payments'), findsWidgets);
      expect(find.text('Connect provider'), findsOneWidget);
      expect(find.textContaining('sk_live'), findsNothing);
    });

    testWidgets('the finance office can look but not manage or connect anything', (tester) async {
      final server = CollectionsServer()..canManage = false;
      await pumpHub(tester, server: server, membership: financeMembership);
      await openTab(tester, 'Providers');
      expect(find.text('Connect provider'), findsNothing);
      expect(find.text('Test connection'), findsNothing);
      expect(find.text('Webhook setup'), findsNothing);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Replace credentials'), findsNothing);
    });

    testWidgets('the active provider cannot be disabled or disconnected from its own card', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Providers');
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Disable'), findsNothing);
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Replace credentials'), findsOneWidget);
    });

    testWidgets('with no active provider yet, a connected one can be made active', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(active: false)];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Choose the active provider'), findsOneWidget);
      await tester.tap(find.text('Make active provider'));
      await tester.pumpAndSettle();
      expect(find.textContaining('New family collection accounts will be made with Paystack'), findsOneWidget);
      await tester.tap(find.text('Make it active'));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST connections/conn-1/activate/'));
    });

    testWidgets('once one is active, choosing another is a switch, never a direct change', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(), connectionJson(id: 'conn-2', provider: 'monnify', active: false)];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Make active provider'), findsNothing);
      expect(find.text('Schedule switch to this provider'), findsOneWidget);
    });

    testWidgets('scheduling a switch plans it for a date and says nothing changes by itself', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(), connectionJson(id: 'conn-2', provider: 'monnify', active: false)];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.text('Schedule switch to this provider'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SchoolOS never switches the school\'s provider on its own'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('schedule-switch')));
      await tester.pumpAndSettle();
      final sent = server.requests['POST switches/']!;
      expect(sent['toConnectionId'], 'conn-2');
      expect(sent['scheduledFor'], isA<String>());
      expect(find.textContaining('Switch to Monnify scheduled'), findsOneWidget);
    });

    testWidgets('a scheduled switch shows current, target, date and who is affected, and cannot be applied yet', (tester) async {
      final server = CollectionsServer()
        ..connections = [connectionJson(), connectionJson(id: 'conn-2', provider: 'monnify', active: false)]
        ..switches = {'open': switchJson(warnings: ['The new provider\'s webhook has not been confirmed yet.']), 'history': <Object?>[], 'permissions': permissionsJson()};
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Scheduled provider switch'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.textContaining('12 (12 accounts)'), findsOneWidget);
      expect(find.text('₦2,500,000'), findsOneWidget);
      expect(find.textContaining('webhook has not been confirmed yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-switch')), findsNothing);
    });

    testWidgets('a ready switch says nothing has changed, and applying it is a separate, explicit act after a review', (tester) async {
      final server = CollectionsServer()
        ..connections = [connectionJson(), connectionJson(id: 'conn-2', provider: 'monnify', active: false)]
        ..switches = {'open': switchJson(status: 'ready_to_switch'), 'history': <Object?>[], 'permissions': permissionsJson()}
        ..switchDetail = switchJson(status: 'ready_to_switch');
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Ready to switch'), findsOneWidget);
      expect(find.textContaining('Nothing has changed yet: the switch happens only when you apply it'), findsOneWidget);
      expect(server.calls, isNot(contains('POST switches/sw-1/apply/')));
      await tester.tap(find.byKey(const ValueKey('review-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Review provider switch'), findsOneWidget);
      expect(find.textContaining('12 families have 12 live accounts with Paystack'), findsOneWidget);
      expect(find.textContaining('until its family has paid'), findsOneWidget);
      expect(find.textContaining('Nothing is deleted'), findsOneWidget);
      expect(server.calls, isNot(contains('POST switches/sw-1/apply/')));
      await tester.tap(find.byKey(const ValueKey('apply-switch')));
      await tester.pumpAndSettle();
      expect(server.calls, contains('POST switches/sw-1/apply/'));
      expect(find.textContaining('Monnify is now the active collection provider'), findsOneWidget);
    });

    testWidgets('a provider that stopped accepting its credentials says why and offers to replace them', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(status: 'needs_reauth', lastError: 'bad_credentials')];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Needs new credentials'), findsOneWidget);
      expect(find.textContaining('no longer accepts the saved credentials'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Replace credentials'), findsOneWidget);
    });

    testWidgets('replacing credentials sends new ones from masked boxes and leaves nothing on screen', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(status: 'needs_reauth', lastError: 'bad_credentials')];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.widgetWithText(FilledButton, 'Replace credentials'));
      await tester.pumpAndSettle();
      final key = find.byKey(const ValueKey('replace-secret_key'));
      expect(tester.widget<TextField>(key).obscureText, isTrue);
      expect(tester.widget<TextField>(key).autocorrect, isFalse);
      await tester.enterText(key, 'sk_live_NEW-SECRET-1');
      await tester.tap(find.byKey(const ValueKey('replace-save')));
      await tester.pumpAndSettle();
      expect(server.requests['POST connections/conn-1/replace-credentials/'], {'credentials': {'secret_key': 'sk_live_NEW-SECRET-1'}});
      expect(find.textContaining('NEW-SECRET'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('the webhook setup says where to put the address and that it is not active until an event arrives', (tester) async {
      final server = CollectionsServer()..webhook = webhookJson();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.text('Webhook setup'));
      await tester.pumpAndSettle();
      expect(find.text('Webhook setup'), findsWidgets);
      expect(find.byKey(const ValueKey('webhook-address')), findsOneWidget);
      expect(find.text('https://school.example/api/v1/bank-webhooks/paystack/TOKEN123/'), findsOneWidget);
      expect(find.textContaining('Settings > API Keys & Webhooks'), findsOneWidget);
      expect(find.textContaining('It is not active yet'), findsOneWidget);
      expect(find.text('Webhook waiting for its first event'), findsOneWidget);
    });

    testWidgets('an active webhook says a verified notification has arrived', (tester) async {
      final server = CollectionsServer()..webhook = webhookJson(status: 'active');
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.text('Webhook setup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A verified payment notification has arrived'), findsOneWidget);
    });

    testWidgets('disconnecting a provider that is not active asks first and explains that history is kept', (tester) async {
      final server = CollectionsServer()..connections = [connectionJson(), connectionJson(id: 'conn-2', provider: 'monnify', active: false)];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Payments and accounts already made are kept'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.calls, isNot(contains('POST connections/conn-2/disconnect/')));
    });

    testWidgets('an empty school is invited to connect its first provider', (tester) async {
      final server = CollectionsServer()..connections = [];
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('No collection provider connected yet'), findsOneWidget);
    });

    testWidgets('Payments filters the payments to that provider', (tester) async {
      final server = CollectionsServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Payments'));
      await tester.pumpAndSettle();
      expect(server.queries['GET transactions/']!['connection'], 'conn-1');
      expect(find.widgetWithText(InputChip, 'One provider'), findsOneWidget);
    });
  });

  group('connecting a provider', () {
    Future<CollectionsServer> openConnect(WidgetTester tester, CollectionsServer server) async {
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tester.tap(find.text('Connect provider'));
      await tester.pumpAndSettle();
      return server;
    }

    testWidgets('only Paystack, Monnify and Remita are offered, and no bank account is asked for', (tester) async {
      final server = CollectionsServer()..connections = [];
      await openConnect(tester, server);
      expect(find.text('Connect Collection Provider'), findsOneWidget);
      for (final name in ['Paystack', 'Monnify', 'Remita']) {
        expect(find.byKey(ValueKey('provider-${name.toLowerCase()}')), findsOneWidget, reason: name);
      }
      expect(find.textContaining('GTBank'), findsNothing);
      expect(find.textContaining('Account number'), findsNothing);
      expect(find.textContaining('Is this your school\'s account?'), findsNothing);
      expect(find.textContaining('Which account does this collect for?'), findsNothing);
      expect(find.textContaining('SchoolOS never receives or holds it'), findsOneWidget);
    });

    testWidgets('the form follows the provider: Paystack asks for one secret key, Monnify for three credentials and says it needs a BVN', (tester) async {
      final server = CollectionsServer()..connections = [];
      await openConnect(tester, server);
      expect(find.byKey(const ValueKey('credential-secret_key')), findsOneWidget);
      expect(find.byKey(const ValueKey('credential-api_key')), findsNothing);
      expect(find.textContaining('your school\'s own Paystack'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('provider-monnify')));
      await tester.pumpAndSettle();
      for (final f in ['api_key', 'secret_key', 'contract_code']) {
        expect(find.byKey(ValueKey('credential-$f')), findsOneWidget, reason: f);
      }
      expect(find.text('Needs the payer\'s BVN or NIN'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('provider-remita')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('credential-merchant_id')), findsOneWidget);
      expect(find.text('Made for an amount'), findsOneWidget);
    });

    testWidgets('secrets are masked, ids are not, and the mode can be chosen', (tester) async {
      final server = CollectionsServer()..connections = [];
      await openConnect(tester, server);
      await tester.tap(find.byKey(const ValueKey('provider-monnify')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credential-api_key'))).obscureText, isTrue);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credential-secret_key'))).obscureText, isTrue);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('credential-contract_code'))).obscureText, isFalse);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('connecting sends the school\'s own credentials once, then shows the webhook setup and clears the boxes', (tester) async {
      final server = CollectionsServer()..connections = [];
      await openConnect(tester, server);
      await tester.tap(find.byKey(const ValueKey('provider-monnify')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('credential-api_key')), 'MK_TEST_SECRET');
      await tester.enterText(find.byKey(const ValueKey('credential-secret_key')), 'SECRET-KEY-9');
      await tester.enterText(find.byKey(const ValueKey('credential-contract_code')), '7059707855');
      await tester.tap(find.byKey(const ValueKey('connect-provider')));
      await tester.pumpAndSettle();
      expect(server.requests['POST connections/'], {
        'provider': 'monnify',
        'environment': 'test',
        'label': '',
        'credentials': {'api_key': 'MK_TEST_SECRET', 'secret_key': 'SECRET-KEY-9', 'contract_code': '7059707855'},
      });
      expect(find.textContaining('is connected'), findsOneWidget);
      expect(find.byKey(const ValueKey('webhook-address')), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Providers'), findsWidgets);
      expect(find.textContaining('MK_TEST_SECRET'), findsNothing);
    });

    testWidgets('a missing credential is asked for before anything is sent', (tester) async {
      final server = CollectionsServer()..connections = [];
      await openConnect(tester, server);
      await tester.tap(find.byKey(const ValueKey('connect-provider')));
      await tester.pumpAndSettle();
      expect(find.text('Enter Secret key.'), findsOneWidget);
      expect(server.calls, isNot(contains('POST connections/')));
    });

    testWidgets('a refused credential shows the server\'s words and leaves the secret box empty', (tester) async {
      final server = CollectionsServer()
        ..connections = []
        ..failConnect = true;
      await openConnect(tester, server);
      await tester.enterText(find.byKey(const ValueKey('credential-secret_key')), 'wrong-SECRET-9');
      await tester.tap(find.byKey(const ValueKey('connect-provider')));
      await tester.pumpAndSettle();
      expect(find.text('The provider did not accept these credentials.'), findsOneWidget);
      expect(find.textContaining('wrong-SECRET-9'), findsNothing);
    });

    testWidgets('a server with no secure storage cannot be connected to, and says why', (tester) async {
      final server = CollectionsServer()
        ..connections = []
        ..providers = providersJson(storage: false);
      await openConnect(tester, server);
      expect(find.text('Secure storage is not set up'), findsOneWidget);
      expect(find.byKey(const ValueKey('provider-paystack')), findsNothing);
    });

    testWidgets('someone who may not manage providers is not offered the button at all', (tester) async {
      final server = CollectionsServer()..canManage = false;
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(find.text('Connect provider'), findsNothing);
    });
  });

  group('review', () {
    testWidgets('a payment SchoolOS could not settle waits for a person, with the evidence', (tester) async {
      await pumpHub(tester, withSmart: false);
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
      expect(find.textContaining('****9012'), findsOneWidget);
      expect(find.textContaining('Paystack 9930000902'), findsOneWidget);
    });

    testWidgets('assigning it to a student sends the decision with what the person was looking at', (tester) async {
      final server = CollectionsServer();
      await pumpHub(tester, server: server, withSmart: false);
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
      expect(server.requests['POST transactions/pay-1/decide/'], {
        'action': 'assign',
        'expectedStatus': 'requires_review',
        'studentId': 'student-BG-0042',
      });
      expect(find.text('Matched'), findsWidgets);
    });

    testWidgets('a decision made on a stale screen is refused with the server\'s words', (tester) async {
      final server = CollectionsServer()..stale = true;
      await pumpHub(tester, server: server, withSmart: false);
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
      final server = CollectionsServer();
      await pumpHub(tester, server: server, withSmart: false);
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
      expect(server.requests['POST transactions/pay-1/decide/'], {
        'action': 'unrelated_income',
        'expectedStatus': 'requires_review',
        'note': 'Hall hire deposit',
      });
    });

    testWidgets('an empty queue says nothing is waiting', (tester) async {
      final server = CollectionsServer()
        ..payments = []
        ..counts = {};
      await pumpHub(tester, server: server, withSmart: false);
      await openTab(tester, 'Review');
      expect(find.textContaining('Nothing is waiting for review'), findsOneWidget);
    });
  });

  group('payments', () {
    testWidgets('every payment with its state, the provider that reported it and the family account it was paid into', (tester) async {
      await pumpHub(tester, withSmart: false);
      await openTab(tester, 'Payments');
      expect(find.text('₦50,000'), findsOneWidget);
      expect(find.textContaining('Paystack · 9930000902'), findsOneWidget);
    });

    testWidgets('test data is labelled as such', (tester) async {
      final server = CollectionsServer()..payments = [paymentJson(sandbox: true)];
      await pumpHub(tester, server: server, withSmart: false);
      await openTab(tester, 'Payments');
      expect(find.text('Test data'), findsOneWidget);
    });

    testWidgets('a payment already matched shows who it was allocated to', (tester) async {
      final server = CollectionsServer()
        ..payments = [
          paymentJson(status: 'matched', allocations: [
            {'id': 'a1', 'studentId': 's1', 'studentName': 'Aisha Bello', 'studentCode': 'BG-0042', 'purpose': 'tuition', 'amountMinor': 5000000, 'source': 'auto', 'superseded': false},
          ]),
        ];
      await pumpHub(tester, server: server, withSmart: false);
      await openTab(tester, 'Payments');
      expect(find.text('For Aisha Bello'), findsOneWidget);
      expect(find.text('Matched'), findsOneWidget);
    });

    testWidgets('an empty list explains what will appear', (tester) async {
      final server = CollectionsServer()..payments = [];
      await pumpHub(tester, server: server, withSmart: false);
      await openTab(tester, 'Payments');
      expect(find.textContaining('No payments yet'), findsOneWidget);
    });
  });
}
