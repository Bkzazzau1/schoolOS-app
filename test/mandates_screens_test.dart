import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/features/mandates/data/mandates_api.dart';
import 'package:schoolos_app/features/mandates/presentation/debit_batch_screen.dart';
import 'package:schoolos_app/features/mandates/presentation/direct_debit_card.dart';
import 'package:schoolos_app/features/mandates/presentation/mandates_hub_page.dart';
import 'package:schoolos_app/features/mandates/presentation/payer_mandates_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'mandates_fixtures.dart';
import 'mandates_test_server.dart';

Future<MandatesServer> pumpWith(WidgetTester tester, Widget Function(MandatesApi api) page, {MandatesServer? server, bool withServer = true, Size size = const Size(1200, 2800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final fake = server ?? MandatesServer();
  final client = apiFor(FakeServer(fake.handle));
  final api = MandatesApi(api: client);
  // The scopes sit above the Navigator, as they do in the app, so a page pushed from another one can still reach them.
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) {
        Widget tree = FamilyFeesScope(api: FamilyFeesApi(api: client), child: child!);
        if (withServer) tree = MandatesScope(api: api, child: tree);
        return tree;
      },
      home: Scaffold(body: page(api)),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<MandatesServer> pumpHub(WidgetTester tester, {MandatesServer? server, SchoolMembership membership = ownerMembership, bool withServer = true}) =>
    pumpWith(tester, (api) => MandatesHubPage(membership: membership), server: server, withServer: withServer);

Future<void> openTab(WidgetTester tester, String name) async {
  final tab = find.widgetWithText(Tab, name);
  await tester.ensureVisible(tab); // on a phone the tab bar scrolls
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder key(String k) => find.byKey(ValueKey(k));

final bello = (real('mandate_detail')['mandate'] as Map)['id'] as String;
final batchId = (real('batch_selected')['batch'] as Map)['id'] as String;

/// A recorded mandate list with the recorded permissions changed.
Map<String, Object?> permissionsFor({bool providers = false, bool manage = false, bool prepare = false, bool approve = false}) =>
    mandatePermissions(providers: providers, manage: manage, prepare: prepare, approve: approve);

/// The connection the server would return after Lendsqr is connected.
Map<String, Object?> lendsqrConnection() {
  final lendsqr = maps(real('providers')['providers']).firstWhere((p) => p['code'] == 'lendsqr');
  final remita = clone(real('connect_remita'))['connection'] as Map<String, Object?>;
  return {
    ...remita,
    'id': 'connection-lendsqr',
    'provider': 'lendsqr',
    'providerName': 'Lendsqr',
    'merchantName': 'Lendsqr merchant',
    'merchantReference': '****0001',
    'label': '',
    'webhookStatus': 'not_configured',
    'capabilities': lendsqr['capabilities'],
    'mandateCounts': {'active': 0, 'pending': 0, 'live': 0, 'total': 0},
  };
}

/// A draft batch's items as the maker sees them once everything ready is selected.
Map<String, Object?> selectedItems() {
  final copy = clone(real('batch_items'));
  for (final i in maps(copy['items'])) {
    i['selected'] = true;
    i['status'] = 'pending';
  }
  return copy;
}

void main() {
  group('with no school server', () {
    testWidgets('the hub says a server is needed and shows no provider, no mandate, no debit and no figures', (tester) async {
      await pumpHub(tester, withServer: false);
      expect(find.text('Mandates & Direct Debit needs your school\'s server'), findsOneWidget);
      expect(find.text('Connect a provider'), findsNothing);
      expect(find.textContaining('₦'), findsNothing);
      expect(find.textContaining('A debit is never queued on a phone as though it had happened'), findsOneWidget);
    });

    testWidgets('the payer\'s card offers nothing, and the payer\'s page says a server is needed', (tester) async {
      await pumpWith(tester, (api) => const DirectDebitCard(membership: parentMembership), withServer: false);
      expect(find.byKey(const ValueKey('direct-debit-card')), findsNothing);
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), withServer: false);
      expect(find.text('Mandates & Direct Debit needs your school\'s server'), findsOneWidget);
    });
  });

  group('the hub', () {
    testWidgets('its tabs are Overview, Providers, Mandates, Debit Batches and Transactions', (tester) async {
      await pumpHub(tester);
      for (final name in ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions']) {
        expect(find.widgetWithText(Tab, name), findsOneWidget, reason: name);
      }
    });

    testWidgets('no tab has an "Active Provider" badge: both providers can operate at once', (tester) async {
      await pumpHub(tester);
      for (final name in ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions']) {
        await openTab(tester, name);
        expect(find.textContaining('Active Provider'), findsNothing, reason: name);
        expect(find.textContaining('Active provider'), findsNothing, reason: name);
      }
    });

    testWidgets('it is not Smart Money Collection: no collection provider is named anywhere in it', (tester) async {
      await pumpHub(tester);
      for (final name in ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions']) {
        await openTab(tester, name);
        expect(find.textContaining('Paystack'), findsNothing, reason: name);
        expect(find.textContaining('Monnify'), findsNothing, reason: name);
        expect(find.textContaining('Smart Money'), findsNothing, reason: name);
      }
    });
  });

  group('overview', () {
    testWidgets('it says what the ledger, not a mandate, decides, and shows what the server counted', (tester) async {
      await pumpHub(tester);
      expect(find.textContaining('What a family owes always comes from the fee ledger, never from a mandate'), findsOneWidget);
      expect(find.textContaining('SchoolOS never holds the money'), findsWidgets);
      expect(find.text('₦380,000'), findsOneWidget); // collected
      expect(find.text('2 confirmed debits'), findsOneWidget);
      expect(find.descendant(of: key('ov-active'), matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: key('ov-waiting'), matching: find.text('0')), findsOneWidget);
    });

    testWidgets('each connected provider is listed with how many of its mandates are active, side by side', (tester) async {
      await pumpHub(tester);
      expect(key('overview-sandbox'), findsOneWidget);
      expect(key('overview-remita'), findsOneWidget);
      expect(find.textContaining('2 mandates active'), findsOneWidget);
      expect(find.textContaining('0 mandates active'), findsOneWidget);
    });

    testWidgets('with nothing connected it says so instead of showing providers', (tester) async {
      final server = MandatesServer()..overview = {...real('overview_after'), 'providers': <Object?>[]};
      await pumpHub(tester, server: server);
      expect(find.text('No provider is connected yet.'), findsOneWidget);
    });

    testWidgets('a debit whose outcome is not known yet is counted on its own, not as a failure', (tester) async {
      final o = clone(real('overview_after'));
      (o['debits'] as Map)['unknown'] = 1;
      await pumpHub(tester, server: MandatesServer()..overview = o);
      expect(find.descendant(of: key('ov-unknown'), matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: key('ov-failed-debits'), matching: find.text('0')), findsOneWidget);
    });
  });

  group('providers', () {
    testWidgets('both connections show, each with its own status and mandates, and the owner can test, replace, disable and disconnect', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Providers');
      expect(key('connection-sandbox'), findsOneWidget);
      expect(key('connection-remita'), findsOneWidget);
      expect(find.text('Test data'), findsWidgets); // the sandbox is labelled, never confused with a real school's provider
      for (final action in ['test', 'replace', 'disable', 'disconnect']) {
        expect(key('$action-remita'), findsOneWidget, reason: action);
      }
      expect(find.textContaining('Merchant ****7916'), findsOneWidget);
    });

    testWidgets('a provider that sends callbacks shows its callback setup and says it is not active until a real event arrives; one that does not has none', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Providers');
      expect(key('webhook-sandbox'), findsNothing);
      await tapKey(tester, 'webhook-remita');
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Callback setup')), findsOneWidget);
      expect(find.textContaining('mandate-webhooks/remita/'), findsOneWidget);
      expect(find.textContaining('Remita does not sign its notifications'), findsOneWidget);
      expect(find.textContaining('not active yet'), findsOneWidget);
      await tapKey(tester, 'callback-renew');
      expect(find.textContaining('mandate-webhooks/remita/'), findsOneWidget);
    });

    testWidgets('testing a connection says whether it works, and a failure shows the provider\'s reason', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tapKey(tester, 'test-remita');
      expect(find.text('The connection works.'), findsOneWidget);
      server.testAnswer = {'ok': false, 'code': 'bad_credentials', 'message': 'Remita did not accept the credentials.'};
      await tester.pump(const Duration(seconds: 5));
      await tapKey(tester, 'test-remita');
      expect(find.text('Remita did not accept the credentials.'), findsOneWidget);
    });

    testWidgets('disconnecting asks first and then disconnects that one provider only', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tapKey(tester, 'disconnect-remita');
      expect(find.text('Disconnect Remita?'), findsOneWidget);
      expect(server.count('POST connections/${remitaId()}/disconnect/'), 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
      await tester.pumpAndSettle();
      expect(server.count('POST connections/${remitaId()}/disconnect/'), 1);
      expect(server.calls.where((c) => c.endsWith('/disconnect/')), hasLength(1));
    });

    testWidgets('someone who may only look sees the providers with no way to connect, test or disconnect them', (tester) async {
      final server = MandatesServer()..connections = {...real('connections_both'), 'permissions': permissionsFor(prepare: true)};
      await pumpHub(tester, server: server, membership: makerMembership);
      await openTab(tester, 'Providers');
      expect(key('connection-remita'), findsOneWidget);
      expect(key('connect-provider'), findsNothing);
      expect(key('test-remita'), findsNothing);
      expect(key('disconnect-remita'), findsNothing);
      expect(key('replace-remita'), findsNothing);
    });

    testWidgets('replacing credentials sends the new ones once and shows none afterwards', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tapKey(tester, 'replace-remita');
      expect(tester.widget<TextField>(key('replace-api_key')).obscureText, isTrue);
      expect(tester.widget<TextField>(key('replace-api_token')).obscureText, isTrue);
      await tester.enterText(key('replace-merchant_id'), 'M-2');
      await tester.enterText(key('replace-service_type_id'), 'S-2');
      await tester.enterText(key('replace-api_key'), 'NEW-KEY');
      await tester.enterText(key('replace-api_token'), 'NEW-TOKEN');
      await tester.tap(key('replace-confirm'));
      await tester.pumpAndSettle();
      expect(server.requests['POST connections/${remitaId()}/replace-credentials/'], {
        'credentials': {'merchant_id': 'M-2', 'service_type_id': 'S-2', 'api_key': 'NEW-KEY', 'api_token': 'NEW-TOKEN'},
      });
      expect(find.text('NEW-KEY'), findsNothing);
      expect(find.text('NEW-TOKEN'), findsNothing);
    });

    testWidgets('a provider that cannot debit through SchoolOS says so on its card', (tester) async {
      final server = MandatesServer();
      server.connections = {
        ...real('connections_both'),
        'connections': [...maps(real('connections_both')['connections']), lendsqrConnection()],
      };
      await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      expect(key('connection-lendsqr'), findsOneWidget);
      expect(find.textContaining('cannot send a debit through this provider yet'), findsOneWidget);
      expect(key('webhook-lendsqr'), findsNothing); // it sends no callbacks
    });
  });

  group('connecting a provider', () {
    Future<MandatesServer> openConnect(WidgetTester tester, {MandatesServer? server}) async {
      final fake = await pumpHub(tester, server: server);
      await openTab(tester, 'Providers');
      await tapKey(tester, 'connect-provider');
      return fake;
    }

    testWidgets('only the provider that is not connected yet is offered, and nothing is called an active one', (tester) async {
      await openConnect(tester);
      expect(key('provider-lendsqr'), findsOneWidget);
      expect(key('provider-remita'), findsNothing);
      expect(find.textContaining('Both providers are connected'), findsNothing);
      expect(find.textContaining('Debits not available through SchoolOS yet'), findsOneWidget);
      expect(find.textContaining('Needs the payer\'s customer id'), findsOneWidget);
    });

    testWidgets('the school\'s own key is asked for as a secret, live use is explained, and the key goes once and is not kept', (tester) async {
      final server = MandatesServer();
      server.overrides['POST connections/'] = (body) {
        server.connections = {
          ...real('connections_both'),
          'connections': [...maps(real('connections_both')['connections']), lendsqrConnection()],
        };
        return jsonResponse({'connection': lendsqrConnection()}, 201);
      };
      await openConnect(tester, server: server);
      await tapKey(tester, 'provider-lendsqr');
      expect(tester.widget<TextField>(key('credential-api_key')).obscureText, isTrue);
      expect(key('live-note'), findsNothing);
      await tester.tap(find.text('Live'));
      await tester.pumpAndSettle();
      expect(key('live-note'), findsOneWidget); // live is gated on this server, and it says why
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      await tester.enterText(key('label'), 'School fees');
      await tester.enterText(key('credential-api_key'), 'LENDSQR-SECRET');
      await tapKey(tester, 'connect-submit');
      expect(server.requests['POST connections/'], {
        'provider': 'lendsqr',
        'environment': 'test',
        'label': 'School fees',
        'credentials': {'api_key': 'LENDSQR-SECRET'},
      });
      expect(find.text('LENDSQR-SECRET'), findsNothing);
      expect(key('connection-lendsqr'), findsOneWidget); // the list now has it, next to the others
      expect(key('connection-remita'), findsOneWidget);
    });

    testWidgets('a refusal is shown in the provider\'s own words and the secret is cleared from the screen', (tester) async {
      final server = MandatesServer();
      server.overrides['POST connections/'] = (body) => jsonResponse({'code': 'bad_credentials', 'message': 'Lendsqr did not accept this key.'}, 400);
      await openConnect(tester, server: server);
      await tapKey(tester, 'provider-lendsqr');
      await tester.enterText(key('credential-api_key'), 'WRONG-KEY');
      await tapKey(tester, 'connect-submit');
      expect(find.text('Lendsqr did not accept this key.'), findsOneWidget);
      expect(tester.widget<TextField>(key('credential-api_key')).controller!.text, isEmpty);
    });

    testWidgets('a server without secure storage cannot be connected to, and the button is off', (tester) async {
      final server = MandatesServer()..providers = {...real('providers'), 'secureStorageReady': false};
      await openConnect(tester, server: server);
      await tapKey(tester, 'provider-lendsqr');
      expect(find.textContaining('Secure storage is not set up'), findsOneWidget);
      expect(tester.widget<FilledButton>(key('connect-submit')).onPressed, isNull);
    });
  });

  group('mandates', () {
    testWidgets('each mandate shows its family, payer, provider, bank, whether it can be debited, and only a masked account', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Mandates');
      expect(find.text('2 mandates'), findsOneWidget);
      expect(find.textContaining('****6789'), findsOneWidget);
      expect(find.textContaining('****4321'), findsOneWidget);
      for (final account in recordedAccountNumbers) {
        expect(find.textContaining(account), findsNothing);
      }
      expect(find.text('Debit ready'), findsOneWidget);
      expect(find.text('Not debit ready'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(find.text('Waiting for the payer to authorise'), findsOneWidget);
    });

    testWidgets('the filters ask the server, and say how many there are of each', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Mandates');
      expect(find.text('Waiting for the payer (1)'), findsOneWidget);
      await tapKey(tester, 'filter-pending_consent');
      expect(server.queries['GET mandates/']!['status'], 'pending_consent');
      await tapKey(tester, 'provider-filter-remita');
      expect(server.queries['GET mandates/']!['provider'], 'remita');
    });

    testWidgets('a mandate waiting for the payer says the payer must authorise it and nobody at the school can', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Mandates');
      await tester.tap(key('mandate-$bello'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('****6789'), findsOneWidget);
      expect(find.textContaining('Nobody at the school can do it for them'), findsOneWidget);
      expect(find.byKey(const ValueKey('debit-ready')), findsOneWidget);
      expect(find.textContaining('No. The payer has not authorised it yet.'), findsOneWidget);
      // Staff have no way to authorise for the payer.
      expect(find.textContaining('Authorise'), findsNothing);
      expect(find.textContaining('authorised on'), findsNothing);
      expect(find.textContaining('consent given'), findsNothing);
      expect(find.text('Ask the provider now'), findsOneWidget);
      expect(find.text('Cancel the mandate'), findsOneWidget);
    });

    testWidgets('cancelling a mandate needs a reason and then asks the server', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Mandates');
      await tester.tap(key('mandate-$bello'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'cancel');
      await tester.enterText(key('reason-field'), 'x');
      await tester.tap(key('reason-confirm'));
      await tester.pumpAndSettle();
      expect(server.count('POST mandates/$bello/cancel/'), 0);
      await tester.enterText(key('reason-field'), 'The family left the school');
      await tester.tap(key('reason-confirm'));
      await tester.pumpAndSettle();
      expect(server.requests['POST mandates/$bello/cancel/'], {'reason': 'The family left the school'});
    });

    testWidgets('someone who cannot manage mandates can look at one but has no actions', (tester) async {
      final server = MandatesServer()..mandates = {...real('mandates'), 'permissions': permissionsFor(approve: true)};
      await pumpHub(tester, server: server, membership: checkerMembership);
      await openTab(tester, 'Mandates');
      expect(key('start-mandate'), findsNothing);
      await tester.tap(key('mandate-$bello'));
      await tester.pumpAndSettle();
      expect(find.text('Ask the provider now'), findsNothing);
      expect(find.text('Cancel the mandate'), findsNothing);
    });
  });

  group('starting a mandate', () {
    Future<MandatesServer> startFromHub(WidgetTester tester, MandatesServer server) async {
      await pumpHub(tester, server: server);
      await openTab(tester, 'Mandates');
      await tapKey(tester, 'start-mandate');
      return server;
    }

    testWidgets('the family, payer, provider, bank, account and limit are asked for, and there is no "the payer agreed" box', (tester) async {
      final server = await startFromHub(tester, MandatesServer());
      expect(find.textContaining('Staff cannot give that consent for them'), findsOneWidget);
      await tester.enterText(key('family-search'), 'Bello');
      await tapKey(tester, 'family-search-go');
      await tapKey(tester, 'family-family-bello');
      expect(find.textContaining('has an account in the app, so they will be asked to review and authorise it there'), findsOneWidget);
      await tester.tap(key('connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test mandate provider (Test)').last);
      await tester.pumpAndSettle();
      await tester.tap(key('bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Bank').last);
      await tester.pumpAndSettle();
      await tester.enterText(key('account'), '0123456789');
      await tester.enterText(key('maximum'), '500,000');
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
      await tapKey(tester, 'start-submit');
      final sent = server.requests['POST mandates/']!;
      expect(sent['familyId'], 'family-bello');
      expect(sent['payerId'], isNotEmpty);
      expect(sent['bankCode'], '058');
      expect(sent['accountNumber'], '0123456789');
      expect(sent['maximumAmountMinor'], 50000000);
      expect(sent['consentRoute'], 'payer_app');
      expect(sent.keys.where((k) => k != 'consentRoute' && k.toLowerCase().contains('consent')), isEmpty);
      // The list came back without a full account number anywhere.
      expect(find.textContaining('0123456789'), findsNothing);
    });

    testWidgets('a refusal is shown and the account number is cleared from the screen, whatever the answer', (tester) async {
      final server = MandatesServer();
      server.refuse = (400, {'code': 'duplicate_mandate', 'message': 'This family already has a live mandate on that account.'});
      await startFromHub(tester, server);
      await tester.enterText(key('family-search'), 'Bello');
      await tapKey(tester, 'family-search-go');
      await tapKey(tester, 'family-family-bello');
      await tester.tap(key('connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test mandate provider (Test)').last);
      await tester.pumpAndSettle();
      await tester.tap(key('bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test Bank').last);
      await tester.pumpAndSettle();
      await tester.enterText(key('account'), '0123456789');
      await tester.enterText(key('maximum'), '500000');
      await tapKey(tester, 'start-submit');
      expect(find.text('This family already has a live mandate on that account.'), findsOneWidget);
      expect(tester.widget<TextField>(key('account')).controller!.text, isEmpty);
      expect(find.text('0123456789'), findsNothing);
    });

    testWidgets('incomplete details are refused on the phone before anything is sent', (tester) async {
      final server = await startFromHub(tester, MandatesServer());
      await tapKey(tester, 'start-submit');
      expect(find.text('Choose the family, the payer, the provider and the bank.'), findsOneWidget);
      expect(server.count('POST mandates/'), 0);
    });
  });

  group('the payer\'s own direct debit', () {
    testWidgets('the card on the Parent\'s page says a mandate is waiting for them and opens it', (tester) async {
      await pumpWith(tester, (api) => const DirectDebitCard(membership: parentMembership));
      expect(find.byKey(const ValueKey('direct-debit-card')), findsOneWidget);
      expect(find.textContaining('1 direct debit is waiting for you to authorise or activate'), findsOneWidget);
      expect(find.textContaining('Nothing is debited until you have and your bank has activated it'), findsOneWidget);
      await tapKey(tester, 'open-direct-debit');
      expect(find.textContaining('I, Bello Parent, authorise BrightGate'), findsOneWidget); // the words they are asked to agree to
    });

    testWidgets('nothing appears on the Parent\'s page when no direct debit has been set up for them', (tester) async {
      await pumpWith(tester, (api) => const DirectDebitCard(membership: parentMembership), server: MandatesServer()..myMandates = {'mandates': <Object?>[]});
      expect(find.byKey(const ValueKey('direct-debit-card')), findsNothing);
    });

    testWidgets('the payer is shown the school, the bank, a masked account and the exact words, and is not told it is active', (tester) async {
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership));
      expect(find.text('BrightGate'), findsOneWidget);
      expect(find.text('****6789'), findsOneWidget);
      expect(find.textContaining('I, Bello Parent, authorise BrightGate'), findsOneWidget);
      expect(find.textContaining('Not active yet. Nothing can be debited from your account'), findsOneWidget);
      expect(find.textContaining('0123456789'), findsNothing);
    });

    testWidgets('authorising sends the payer\'s own yes with the hash of the words they were shown, then the activation is theirs to do', (tester) async {
      final server = MandatesServer();
      final shown = maps(server.myMandates['mandates']).first;
      server.overrides['POST my-mandates/${shown['id']}/consent/'] = (body) {
        server.myMandates = {'mandates': [(server.authorised['mandate'])]};
        return jsonResponse(server.authorised);
      };
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), server: server);
      await tapKey(tester, 'authorise-${shown['id']}');
      expect(server.requests['POST my-mandates/${shown['id']}/consent/'], {'accepted': true, 'consentTextHash': shown['consentTextHash']});
      expect(find.text('You authorised this direct debit.'), findsOneWidget);
      expect(key('authorise-${shown['id']}'), findsNothing); // it cannot be authorised twice
      expect(find.text('Activate it'), findsOneWidget);
    });

    testWidgets('a bank one-time password is typed hidden, sent once, and shown nowhere; the mandate is active only once the provider says so', (tester) async {
      final server = MandatesServer();
      final id = (server.authorised['mandate'] as Map)['id'];
      server.myMandates = {'mandates': [(server.authorised['mandate'])]};
      server.overrides['POST my-mandates/$id/activation-confirm/'] = (body) {
        server.myMandates = {'mandates': [(server.activated['mandate'])]};
        return jsonResponse(server.activated);
      };
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), server: server);
      expect(find.textContaining('Not active yet'), findsOneWidget);
      await tapKey(tester, 'activate-$id');
      expect(tester.widget<TextField>(key('activation-OTP')).obscureText, isTrue);
      await tester.enterText(key('activation-OTP'), '654321');
      await tapKey(tester, 'activation-confirm');
      expect(server.requests['POST my-mandates/$id/activation-confirm/'], {'answers': {'OTP': '654321'}});
      expect(find.text('654321'), findsNothing);
      expect(find.textContaining('Active: the school can debit this account for approved school fees'), findsOneWidget);
    });

    testWidgets('a wrong password is refused in the bank\'s words and the mandate stays not active', (tester) async {
      final server = MandatesServer();
      final id = (server.authorised['mandate'] as Map)['id'];
      server.myMandates = {'mandates': [(server.authorised['mandate'])]};
      server.overrides['POST my-mandates/$id/activation-confirm/'] = (body) => jsonResponse({'code': 'activation_refused', 'message': 'The bank did not accept that password.'}, 400);
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), server: server);
      await tapKey(tester, 'activate-$id');
      await tester.enterText(key('activation-OTP'), '000000');
      await tapKey(tester, 'activation-confirm');
      expect(find.text('The bank did not accept that password.'), findsOneWidget);
      expect(find.textContaining('Not active yet'), findsOneWidget);
    });

    testWidgets('the payer can cancel their own direct debit after being asked', (tester) async {
      final server = MandatesServer();
      final id = (server.authorised['mandate'] as Map)['id'];
      server.myMandates = {'mandates': [(server.authorised['mandate'])]};
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), server: server);
      await tapKey(tester, 'payer-cancel-$id');
      expect(find.text('Cancel this direct debit?'), findsOneWidget);
      expect(server.count('POST my-mandates/$id/cancel/'), 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel the direct debit'));
      await tester.pumpAndSettle();
      expect(server.requests['POST my-mandates/$id/cancel/'], {'reason': 'The payer withdrew their authority.'});
    });
  });

  group('debit batches: the list', () {
    testWidgets('a checker sees the batch waiting for approval, who prepared it and what it would debit, and cannot prepare one', (tester) async {
      await pumpHub(tester, membership: checkerMembership, server: MandatesServer()..overview = {...real('overview_after'), 'permissions': permissionsFor(approve: true)});
      await openTab(tester, 'Debit Batches');
      expect(find.text('Term one fees'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.textContaining('2 debits, ₦380,000'), findsOneWidget);
      expect(find.textContaining('Prepared by administrator@school.ng'), findsOneWidget);
      expect(key('prepare-batch'), findsNothing);
    });

    testWidgets('a maker can prepare a batch for a session and a term, and it opens as a draft to review', (tester) async {
      final server = MandatesServer()
        ..overview = {...real('overview_after'), 'permissions': permissionsFor(prepare: true)}
        ..batch = batchDetail(real('batch_created'), batch: {'id': batchId})
        ..items = selectedItems();
      await pumpHub(tester, server: server, membership: makerMembership);
      await openTab(tester, 'Debit Batches');
      await tapKey(tester, 'prepare-batch');
      expect(find.text('2026/2027'), findsWidgets);
      await tester.enterText(key('batch-title'), 'Term one fees');
      await tester.tap(key('batch-create'));
      await tester.pumpAndSettle();
      expect(server.requests['POST debit-batches/'], {
        'sessionId': (maps(real('periods')['sessions']).first)['id'],
        'termId': ((real('periods')['current'] as Map)['termId']),
        'title': 'Term one fees',
      });
      expect(find.text('Direct Debit Preview'), findsOneWidget);
    });
  });

  group('debit batches: the maker', () {
    Future<MandatesServer> pumpBatch(WidgetTester tester, {required SchoolMembership who, MandatesServer? server, Duration poll = const Duration(seconds: 4)}) =>
        pumpWith(tester, (api) => DebitBatchScreen(api: api, membership: who, batchId: batchId, pollEvery: poll), server: server);

    MandatesServer draft() => MandatesServer()
      ..batch = real('batch_selected')
      ..items = selectedItems();

    testWidgets('the preview shows what the ledger says each family owes and what would be debited, and nothing has been sent to a provider', (tester) async {
      final server = draft();
      await pumpBatch(tester, who: makerMembership, server: server);
      expect(find.text('Direct Debit Preview'), findsOneWidget);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.text('Sani family'), findsOneWidget);
      expect(find.descendant(of: key('sum-proposed'), matching: find.text('₦380,000')), findsOneWidget);
      expect(find.descendant(of: key('sum-outstanding'), matching: find.text('₦380,000')), findsOneWidget);
      expect(find.textContaining('₦280,000'), findsWidgets);
      expect(find.textContaining('****6789'), findsOneWidget);
      expect(find.text('Ready to debit'), findsWidgets);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);
      expect(find.text('Approve Debits'), findsNothing); // a maker prepares; someone else approves
    });

    testWidgets('selecting everything ready asks the server with the version the maker was looking at', (tester) async {
      final server = draft();
      await pumpBatch(tester, who: makerMembership, server: server);
      await tapKey(tester, 'select-all');
      final version = ((real('batch_selected')['batch'] as Map)['version']);
      expect(server.requests['POST debit-batches/$batchId/selection/'], {'version': version, 'selectAllEligible': true});
    });

    testWidgets('an amount can be lowered but the server, not the phone, decides that it may not be raised', (tester) async {
      final server = draft();
      await pumpBatch(tester, who: makerMembership, server: server);
      final item = maps(server.items['items']).first;
      await tapKey(tester, 'lower-${item['id']}');
      await tester.enterText(key('lower-amount'), '10,000');
      await tester.tap(key('lower-confirm'));
      await tester.pumpAndSettle();
      final sent = server.requests['POST debit-batches/$batchId/items/${item['id']}/amount/']!;
      expect(sent['amountMinor'], 1000000);
      expect(find.textContaining('A debit can be lowered, never raised'), findsNothing); // the dialog closed
      server.refuse = (400, {'code': 'amount_too_high', 'message': 'A debit can never be more than the ledger says the family owes.'});
      await tapKey(tester, 'lower-${item['id']}');
      await tester.enterText(key('lower-amount'), '999,999');
      await tester.tap(key('lower-confirm'));
      await tester.pumpAndSettle();
      expect(find.text('A debit can never be more than the ledger says the family owes.'), findsOneWidget);
    });

    testWidgets('submitting names exactly the snapshot and version the maker prepared', (tester) async {
      final server = draft();
      server.batchAfterAction = real('batch_submitted');
      await pumpBatch(tester, who: makerMembership, server: server);
      await tapKey(tester, 'submit');
      final b = real('batch_selected')['batch'] as Map;
      expect(server.requests['POST debit-batches/$batchId/submit/'], {'snapshotHash': b['snapshotHash'], 'version': b['version']});
      expect(find.text('Submitted for approval.'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsWidgets);
      expect(find.text('Approve Debits'), findsNothing);
    });

    testWidgets('an empty batch cannot be submitted', (tester) async {
      final server = MandatesServer()..batch = real('batch_created');
      await pumpBatch(tester, who: makerMembership, server: server);
      expect(tester.widget<FilledButton>(key('submit')).onPressed, isNull);
    });

    testWidgets('a rejected batch shows the checker\'s reason and is back with the maker to change', (tester) async {
      final server = draft();
      server.batch = batchDetail(
        real('batch_selected'),
        batch: {'status': 'rejected', 'rejectionReason': 'Please check the Bello family first', 'rejectedBy': {'id': checkerMembership.id, 'name': 'principal@school.ng'}},
        permissions: permissionsFor(prepare: true),
      );
      await pumpBatch(tester, who: makerMembership, server: server);
      expect(find.text('Rejected by principal@school.ng'), findsOneWidget);
      expect(find.text('Please check the Bello family first'), findsOneWidget);
      expect(key('select-all'), findsOneWidget);
      expect(key('submit'), findsOneWidget);
    });
  });

  group('debit batches: the checker', () {
    Future<MandatesServer> pumpChecker(WidgetTester tester, MandatesServer server, {SchoolMembership who = checkerMembership}) =>
        pumpWith(tester, (api) => DebitBatchScreen(api: api, membership: who, batchId: batchId), server: server);

    MandatesServer waiting({Map<String, Object?>? permissions}) => MandatesServer()
      ..batch = batchDetail(real('batch_submitted'), permissions: permissions ?? permissionsFor(approve: true))
      ..items = selectedItems();

    testWidgets('the checker sees exactly what would be debited and approves that snapshot, and only that', (tester) async {
      final server = waiting();
      server.batchAfterAction = real('batch_approved');
      await pumpChecker(tester, server);
      expect(find.textContaining('Approving means approving exactly these 2 debits, ₦380,000 in all.'), findsOneWidget);
      await tapKey(tester, 'approve');
      final hash = (real('batch_submitted')['batch'] as Map)['snapshotHash'];
      expect(server.requests['POST debit-batches/$batchId/approve/'], {'snapshotHash': hash});
      expect(find.text('Approved.'), findsOneWidget);
      expect(key('start'), findsOneWidget);
    });

    testWidgets('a person who prepared or submitted the batch is told someone else must approve it, and has no approve button', (tester) async {
      await pumpChecker(tester, waiting(permissions: permissionsFor(approve: true, prepare: true)), who: makerMembership);
      expect(key('maker-cannot-approve'), findsOneWidget);
      expect(key('approve'), findsNothing);
      expect(key('reject'), findsNothing);
    });

    testWidgets('someone without the approve duty sees the batch but has nothing to approve with', (tester) async {
      await pumpChecker(tester, waiting(permissions: permissionsFor(prepare: true)), who: makerMembership);
      expect(key('approve'), findsNothing);
      expect(find.text('Waiting for approval'), findsWidgets);
    });

    testWidgets('rejecting needs a reason in a few words, and then sends it', (tester) async {
      final server = waiting();
      server.batchAfterAction = batchDetail(real('batch_submitted'), batch: {'status': 'rejected', 'rejectionReason': 'Bello paid part of it by transfer'}, permissions: permissionsFor(approve: true));
      await pumpChecker(tester, server);
      await tapKey(tester, 'reject');
      await tester.enterText(key('reason-field'), 'no');
      await tester.tap(key('reason-confirm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Say why, in a few words'), findsOneWidget);
      expect(server.count('POST debit-batches/$batchId/reject/'), 0);
      await tester.enterText(key('reason-field'), 'Bello paid part of it by transfer');
      await tester.tap(key('reason-confirm'));
      await tester.pumpAndSettle();
      expect(server.requests['POST debit-batches/$batchId/reject/'], {'reason': 'Bello paid part of it by transfer'});
      expect(find.text('Rejected. It is back with the maker.'), findsOneWidget);
    });

    testWidgets('a batch that changed since the checker opened it is refused, the checker is told, and what is true now is shown', (tester) async {
      final server = waiting();
      server.refuse = (409, {'code': 'batch_changed', 'message': 'What families owe changed since this was prepared. It is back with the maker.'});
      await pumpChecker(tester, server);
      final before = server.count('GET debit-batches/$batchId/');
      await tapKey(tester, 'approve');
      expect(find.text('What families owe changed since this was prepared. It is back with the maker.'), findsOneWidget);
      expect(server.count('GET debit-batches/$batchId/'), before + 1); // it looked again
      expect(server.count('POST debit-batches/$batchId/start/'), 0);
    });

    testWidgets('starting is confirmed first and says the balance and mandate are checked again before each debit', (tester) async {
      final server = MandatesServer()
        ..batch = real('batch_approved')
        ..items = selectedItems();
      server.batchAfterAction = real('batch_started');
      await pumpChecker(tester, server);
      await tapKey(tester, 'start');
      expect(find.text('Start debiting?'), findsOneWidget);
      expect(find.textContaining('checks the family\'s balance and mandate again and sends nothing that changed'), findsOneWidget);
      expect(server.count('POST debit-batches/$batchId/start/'), 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Start debiting'));
      await tester.pumpAndSettle();
      expect(server.count('POST debit-batches/$batchId/start/'), 1);
      expect(server.requests['POST debit-batches/$batchId/start/'], isEmpty); // no amounts: the server debits what was approved
    });
  });

  group('debit batches: while debiting and afterwards', () {
    Future<MandatesServer> pumpBatch(WidgetTester tester, MandatesServer server, {Duration poll = const Duration(seconds: 4), SchoolMembership who = makerMembership}) =>
        pumpWith(tester, (api) => DebitBatchScreen(api: api, membership: who, batchId: batchId, pollEvery: poll), server: server);

    Map<String, Object?> withFailures({String status = 'partially_successful'}) => batchDetail(
          real('batch_selected'),
          batch: {'status': status, 'successCount': 1, 'failedCount': 1, 'approvedSnapshotHash': (real('batch_selected')['batch'] as Map)['snapshotHash']},
          permissions: permissionsFor(prepare: true),
        );

    Map<String, Object?> itemsWithOneFailure({String failedStatus = 'failed', String code = 'insufficient_funds'}) {
      final copy = selectedItems();
      final rows = maps(copy['items']);
      rows[0]['status'] = 'success';
      rows[1]['status'] = failedStatus;
      rows[1]['errorCode'] = code;
      return copy;
    }

    testWidgets('a running batch shows progress, and a debit the provider has not answered is asked about, never sent again', (tester) async {
      final server = MandatesServer()
        ..batch = batchDetail(real('batch_selected'), batch: {'status': 'processing'}, permissions: permissionsFor(prepare: true))
        ..items = itemsWithOneFailure(failedStatus: 'unknown', code: '')
        ..progress = {
          'progress': {'status': 'processing', 'total': 2, 'success': 1, 'failed': 0, 'unknown': 1, 'queued': 0, 'done': false},
          'batch': (real('batch_selected')['batch']),
        };
      await pumpBatch(tester, server, poll: const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('1 debited, 0 failed, 1 waiting for the provider to say, 0 queued.'), findsOneWidget);
      expect(find.text('Outcome not known yet'), findsOneWidget);
      expect(find.textContaining('It is being asked, and will not be sent again'), findsOneWidget);
      expect(find.text('Failed'), findsNothing); // an unknown outcome is not called a failure
      expect(key('retry-all'), findsNothing);
    });

    testWidgets('when the run finishes the screen looks again and shows the result', (tester) async {
      final server = MandatesServer()
        ..batch = batchDetail(real('batch_selected'), batch: {'status': 'processing'}, permissions: permissionsFor(prepare: true))
        ..items = selectedItems()
        ..progress = real('batch_progress');
      await pumpBatch(tester, server, poll: const Duration(milliseconds: 100));
      final loads = server.count('GET debit-batches/$batchId/');
      server.batch = batchDetail(real('batch_selected'), batch: {'status': 'completed', 'successCount': 2}, permissions: permissionsFor(prepare: true));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(server.count('GET debit-batches/$batchId/'), greaterThan(loads));
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('a partial failure keeps the successes and offers to retry only the failure', (tester) async {
      final server = MandatesServer()
        ..batch = withFailures()
        ..items = itemsWithOneFailure();
      await pumpBatch(tester, server);
      expect(find.textContaining('1 debited and kept. 1 did not go through.'), findsOneWidget);
      expect(find.text('Debited'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('The account did not have enough money.'), findsOneWidget);
      expect(key('retry-all'), findsOneWidget);
      final failedId = maps(server.items['items'])[1]['id'];
      final okId = maps(server.items['items'])[0]['id'];
      expect(key('retry-$failedId'), findsOneWidget);
      expect(key('retry-$okId'), findsNothing); // a success is never offered for retry
    });

    testWidgets('retrying all asks the server, and a debit that changed is said to need a fresh maker and checker, with nothing sent for it', (tester) async {
      final server = MandatesServer()
        ..batch = withFailures()
        ..items = itemsWithOneFailure();
      server.batchAfterAction = batchDetail(
        real('batch_selected'),
        batch: {'status': 'partially_successful', 'successCount': 1, 'failedCount': 1},
        permissions: permissionsFor(prepare: true),
        retry: {
          'retried': <Object?>[],
          'needsFreshApproval': [
            {'itemId': 'x', 'family': 'Sani family', 'code': 'changed_since_approval'},
          ],
        },
      );
      await pumpBatch(tester, server);
      await tapKey(tester, 'retry-all');
      expect(server.requests['POST debit-batches/$batchId/retry/'], isEmpty);
      expect(find.textContaining('Sani family changed since approval, so they need a fresh maker and checker. Nothing was sent for them.'), findsOneWidget);
    });

    testWidgets('one failed debit can be picked and retried on its own', (tester) async {
      final server = MandatesServer()
        ..batch = withFailures()
        ..items = itemsWithOneFailure();
      await pumpBatch(tester, server);
      expect(tester.widget<OutlinedButton>(key('retry-selected')).onPressed, isNull);
      final failedId = maps(server.items['items'])[1]['id'];
      await tapKey(tester, 'retry-$failedId');
      await tapKey(tester, 'retry-selected');
      expect(server.requests['POST debit-batches/$batchId/retry/'], {'itemIds': [failedId]});
    });

    testWidgets('a batch where every debit failed says so and can be retried', (tester) async {
      final server = MandatesServer()
        ..batch = withFailures(status: 'failed')
        ..items = itemsWithOneFailure();
      await pumpBatch(tester, server);
      expect(find.text('Every debit failed'), findsOneWidget);
      expect(key('retry-all'), findsOneWidget);
    });

    testWidgets('a completed batch offers no retry and no edit', (tester) async {
      final server = MandatesServer()
        ..batch = batchDetail(real('batch_selected'), batch: {'status': 'completed', 'successCount': 2}, permissions: permissionsFor(prepare: true, approve: true))
        ..items = selectedItems();
      await pumpBatch(tester, server);
      expect(key('retry-all'), findsNothing);
      expect(key('select-all'), findsNothing);
      expect(key('start'), findsNothing);
      expect(key('approve'), findsNothing);
    });

    testWidgets('the history says what happened, in order', (tester) async {
      final server = MandatesServer()
        ..batch = withFailures()
        ..items = itemsWithOneFailure();
      await pumpBatch(tester, server);
      for (final label in ['Prepared', 'Selection changed', 'Submitted for approval', 'Approved', 'Debiting started']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });
  });

  group('debits', () {
    testWidgets('each confirmed debit says it was put towards the fees, and shows a masked account', (tester) async {
      await pumpHub(tester);
      await openTab(tester, 'Transactions');
      expect(find.text('Sani family'), findsOneWidget);
      expect(find.text('Bello family'), findsOneWidget);
      expect(find.text('Put towards the fees'), findsNWidgets(2));
      expect(find.text('Successful'), findsWidgets);
      expect(find.textContaining('****6789'), findsOneWidget);
      expect(find.text('₦280,000'), findsOneWidget);
      expect(find.text('₦100,000'), findsOneWidget);
    });

    testWidgets('a debit whose outcome is not known can be asked about, and one that succeeded cannot', (tester) async {
      final t = clone(real('transactions'));
      final rows = maps(t['transactions']);
      rows[0]['status'] = 'unknown';
      rows[0]['settled'] = false;
      final server = MandatesServer()..transactions = t;
      await pumpHub(tester, server: server);
      await openTab(tester, 'Transactions');
      expect(find.text('Outcome not known yet'), findsOneWidget);
      expect(find.text('Put towards the fees'), findsOneWidget); // only the confirmed one
      expect(key('check-${rows[0]['id']}'), findsOneWidget);
      expect(key('check-${rows[1]['id']}'), findsNothing);
      await tapKey(tester, 'check-${rows[0]['id']}');
      expect(server.count('POST transactions/${rows[0]['id']}/check/'), 1);
    });

    testWidgets('the filter asks the server for that status', (tester) async {
      final server = MandatesServer();
      await pumpHub(tester, server: server);
      await openTab(tester, 'Transactions');
      await tapKey(tester, 'tx-filter-unknown');
      expect(server.queries['GET transactions/']!['status'], 'unknown');
    });
  });
  group('on a phone', () {
    const phone = Size(390, 844);

    testWidgets('every tab of the hub fits a phone without overflowing', (tester) async {
      await pumpWith(tester, (api) => const MandatesHubPage(membership: ownerMembership), size: phone);
      for (final name in ['Overview', 'Providers', 'Mandates', 'Debit Batches', 'Transactions']) {
        await openTab(tester, name);
        expect(tester.takeException(), isNull, reason: name);
      }
    });

    testWidgets('a batch under review fits a phone for the maker and for the checker', (tester) async {
      for (final (who, permissions) in [(makerMembership, permissionsFor(prepare: true)), (checkerMembership, permissionsFor(approve: true))]) {
        final server = MandatesServer()
          ..batch = batchDetail(real('batch_submitted'), permissions: permissions)
          ..items = selectedItems();
        await pumpWith(tester, (api) => DebitBatchScreen(api: api, membership: who, batchId: batchId), server: server, size: phone);
        expect(tester.takeException(), isNull, reason: who.role.name);
      }
    });

    testWidgets('the payer\'s direct debit and the form that starts a mandate fit a phone', (tester) async {
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), size: phone);
      expect(tester.takeException(), isNull);
      await pumpWith(tester, (api) => const MandatesHubPage(membership: ownerMembership), size: phone);
      await openTab(tester, 'Mandates');
      await tapKey(tester, 'start-mandate');
      expect(tester.takeException(), isNull);
    });

    testWidgets('connecting a provider fits a phone', (tester) async {
      await pumpWith(tester, (api) => const MandatesHubPage(membership: ownerMembership), size: phone);
      await openTab(tester, 'Providers');
      await tapKey(tester, 'connect-provider');
      await tapKey(tester, 'provider-lendsqr');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a mandate\'s detail fits a phone', (tester) async {
      final server = MandatesServer();
      server.mandates = {...real('mandates'), 'mandates': maps(real('mandates')['mandates']).reversed.toList()}; // the waiting one first, so it is on screen
      await pumpWith(tester, (api) => const MandatesHubPage(membership: ownerMembership), server: server, size: const Size(390, 1800)); // a phone's width; tall so the row is on screen
      await openTab(tester, 'Mandates');
      await tapKey(tester, 'mandate-$bello');
      expect(find.text('The mandate'), findsOneWidget); // it really opened
      expect(tester.takeException(), isNull);
    });

    testWidgets('a payer who has authorised sees how to activate it on a phone', (tester) async {
      final server = MandatesServer();
      server.myMandates = {'mandates': [(server.authorised['mandate'])]};
      await pumpWith(tester, (api) => const PayerMandatesPage(membership: parentMembership), server: server, size: phone);
      expect(find.text('Activate it'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

String remitaId() => (maps(real('connections_both')['connections'])[1])['id'] as String;
