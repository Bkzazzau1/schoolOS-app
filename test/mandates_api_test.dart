import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/features/mandates/data/mandates_api.dart';
import 'package:schoolos_app/features/mandates/domain/mandate_models.dart';

import 'core/backend_test_support.dart';
import 'mandates_fixtures.dart';
import 'mandates_test_server.dart';

void main() {
  late MandatesServer school;
  late FakeServer server;
  late MandatesApi api;

  setUp(() {
    school = MandatesServer();
    server = FakeServer(school.handle);
    api = MandatesApi(api: apiFor(server));
  });

  const base = '/api/v1/schools/$schoolId/mandates/';
  String tail(int index) => server.requests[index].url.path.replaceFirst(base, '');
  Map<String, dynamic> sent(int index) => jsonDecode(server.requests[index].body) as Map<String, dynamic>;
  final batchId = (real('batch_selected')['batch'] as Map)['id'] as String;
  final mandateId = (real('mandate_detail')['mandate'] as Map)['id'] as String;

  test('every call says which school and which membership it is acting as', () async {
    await api.overview(ownerMembership);
    final r = server.requests.single;
    expect((r.method, r.url.path), ('GET', '${base}overview/'));
    expect(r.url.queryParameters['membership'], ownerMembership.id);
    expect(r.headers['Authorization'], 'Bearer access-1');
  });

  group('providers', () {
    test('connecting sends the school\'s own credentials once, and what comes back has none', () async {
      final made = await api.connect(
        ownerMembership,
        provider: 'remita',
        environment: 'test',
        label: '  Remita  ',
        credentials: {'merchant_id': 'M-1', 'service_type_id': 'S-1', 'api_key': 'KEY-VALUE', 'api_token': 'TOKEN-VALUE'},
      );
      expect((server.requests.single.method, tail(0)), ('POST', 'connections/'));
      expect(sent(0), {
        'provider': 'remita',
        'environment': 'test',
        'label': 'Remita',
        'credentials': {'merchant_id': 'M-1', 'service_type_id': 'S-1', 'api_key': 'KEY-VALUE', 'api_token': 'TOKEN-VALUE'},
      });
      expect(made.provider, 'remita');
      expect(made.toString(), isNot(contains('KEY-VALUE')));
    });

    test('a provider can be tested, disabled, enabled, renamed, disconnected and given new credentials', () async {
      const id = 'connection-1';
      await api.test(ownerMembership, id);
      await api.disable(ownerMembership, id);
      await api.enable(ownerMembership, id);
      await api.rename(ownerMembership, id, label: 'Fees');
      await api.replaceCredentials(ownerMembership, id, credentials: {'api_key': 'NEW'});
      await api.disconnect(ownerMembership, id);
      expect([for (var i = 0; i < server.requests.length; i++) tail(i)], [for (final a in ['test', 'disable', 'enable', 'rename', 'replace-credentials', 'disconnect']) 'connections/$id/$a/']);
      expect(sent(3), {'label': 'Fees'});
      expect(sent(4), {'credentials': {'api_key': 'NEW'}});
    });

    test('a test says whether the connection works', () async {
      school.testAnswer = {'ok': false, 'code': 'bad_credentials', 'message': 'The provider did not accept them.'};
      final result = await api.test(ownerMembership, 'connection-1');
      expect((result.testOk, result.testCode), (false, 'bad_credentials'));
    });

    test('the callback setup can be read and its address renewed', () async {
      final hook = await api.webhook(ownerMembership, 'connection-1');
      expect(hook.path, startsWith('mandate-webhooks/remita/'));
      await api.newWebhookAddress(ownerMembership, 'connection-1');
      expect(server.requests.map((r) => '${r.method} ${r.url.path.replaceFirst(base, '')}'), ['GET connections/connection-1/webhook/', 'POST connections/connection-1/webhook-token/']);
    });

    test('the banks a provider can make a mandate on are asked of that connection', () async {
      final banks = await api.banks(ownerMembership, 'connection-1');
      expect(tail(0), 'connections/connection-1/banks/');
      expect(banks.map((b) => b.code), ['058', '044']);
    });
  });

  group('mandates', () {
    test('starting one sends the family, the payer, the connection, the bank, the account and the limit - and no consent of any kind', () async {
      final mandate = await api.startMandate(
        makerMembership,
        const StartMandateRequest(
          familyId: 'family-bello',
          payerId: 'payer-1',
          connectionId: 'connection-1',
          bankCode: '058',
          accountNumber: '0123456789',
          maximumAmountMinor: 50000000,
          consentRoute: 'payer_app',
        ),
      );
      expect((server.requests.single.method, tail(0)), ('POST', 'mandates/'));
      final body = sent(0);
      expect(body['accountNumber'], '0123456789');
      expect(body['maximumAmountMinor'], 50000000);
      expect(body['consentRoute'], 'payer_app');
      // Staff never authorise for the payer: nothing that says the payer agreed leaves the phone.
      expect(body.keys.where((k) => k.toLowerCase().contains('consent') && k != 'consentRoute'), isEmpty);
      expect(body.containsKey('accepted'), isFalse);
      // What comes back has a masked account only.
      expect(mandate.accountMask, '****6789');
      expect(jsonEncode(real('mandate_detail')), isNot(contains('0123456789')));
    });

    test('a provider that needs the payer\'s customer id is sent it, and one that does not is not', () async {
      await api.startMandate(
        makerMembership,
        const StartMandateRequest(familyId: 'f', payerId: 'p', connectionId: 'c', bankCode: '058', accountNumber: '0123456789', maximumAmountMinor: 100, consentRoute: 'provider', providerCustomerRef: 'CUST-9'),
      );
      await api.startMandate(
        makerMembership,
        const StartMandateRequest(familyId: 'f', payerId: 'p', connectionId: 'c', bankCode: '058', accountNumber: '0123456789', maximumAmountMinor: 100, consentRoute: 'provider'),
      );
      expect(sent(0)['providerCustomerRef'], 'CUST-9');
      expect(sent(1).containsKey('providerCustomerRef'), isFalse);
    });

    test('the list can be narrowed by status, provider, family, whether it is debit ready, and a search', () async {
      await api.mandates(ownerMembership, status: 'active', provider: 'remita', familyId: 'family-bello', debitReady: true, search: ' Bello ');
      final q = server.requests.single.url.queryParameters;
      expect((q['status'], q['provider'], q['family'], q['debitReady'], q['q']), ('active', 'remita', 'family-bello', '1', 'Bello'));
    });

    test('the actions on a mandate each go to their own address', () async {
      await api.refreshMandate(ownerMembership, mandateId);
      await api.retrySetup(ownerMembership, mandateId);
      await api.resendActivation(ownerMembership, mandateId);
      await api.suspendMandate(ownerMembership, mandateId);
      await api.reactivateMandate(ownerMembership, mandateId);
      await api.makePrimary(ownerMembership, mandateId);
      await api.cancelMandate(ownerMembership, mandateId, reason: 'The family left');
      expect(
        [for (var i = 0; i < server.requests.length; i++) tail(i)],
        [for (final a in ['refresh', 'retry-setup', 'resend-activation', 'suspend', 'reactivate', 'primary', 'cancel']) 'mandates/$mandateId/$a/'],
      );
      expect(sent(6), {'reason': 'The family left'});
    });
  });

  group('the payer\'s own', () {
    test('authorising sends the payer\'s yes and the hash of the exact words they read, and nothing else', () async {
      await api.authorise(parentMembership, mandateId, consentTextHash: 'abc123');
      expect((server.requests.single.method, tail(0)), ('POST', 'my-mandates/$mandateId/consent/'));
      expect(sent(0), {'accepted': true, 'consentTextHash': 'abc123'});
    });

    test('the one-time password is asked for and then sent once, by the field name the provider gave', () async {
      final fields = await api.requestActivation(parentMembership, mandateId);
      expect(fields.single.name, 'OTP');
      await api.confirmActivation(parentMembership, mandateId, answers: {'OTP': '654321'});
      expect(tail(0), 'my-mandates/$mandateId/activation-request/');
      expect(tail(1), 'my-mandates/$mandateId/activation-confirm/');
      expect(sent(1), {'answers': {'OTP': '654321'}});
    });

    test('the payer can always cancel their own', () async {
      await api.cancelMyMandate(parentMembership, mandateId, reason: 'I changed my mind');
      expect(tail(0), 'my-mandates/$mandateId/cancel/');
      expect(sent(0), {'reason': 'I changed my mind'});
    });

    test('the payer\'s list asks for their own mandates only', () async {
      final mine = await api.myMandates(parentMembership);
      expect(tail(0), 'my-mandates/');
      expect(mine.single.consentRequired, isTrue);
    });
  });

  group('debit batches', () {
    test('a batch is created for a session and a term with an optional name', () async {
      final made = await api.createBatch(makerMembership, sessionId: 'session-1', termId: 'term-1', title: '  Term one fees ');
      expect(tail(0), 'debit-batches/');
      expect(sent(0), {'sessionId': 'session-1', 'termId': 'term-1', 'title': 'Term one fees'});
      expect(made.batch.status, 'draft');
    });

    test('selecting sends the version the maker was looking at, so a stale view is refused, not silently applied', () async {
      await api.select(makerMembership, batchId, version: 3, selectAllEligible: true);
      await api.select(makerMembership, batchId, version: 3, select: ['a'], deselect: ['b']);
      expect(sent(0), {'version': 3, 'selectAllEligible': true});
      expect(sent(1), {'version': 3, 'select': ['a'], 'deselect': ['b']});
    });

    test('lowering sends an amount in kobo, the version the maker was looking at, and why', () async {
      await api.lowerAmount(makerMembership, batchId, 'item-1', amountMinor: 1000000, version: 4, reason: 'Part paid');
      expect(tail(0), 'debit-batches/$batchId/items/item-1/amount/');
      expect(sent(0), {'amountMinor': 1000000, 'version': 4, 'reason': 'Part paid'});
    });

    test('submitting names exactly what is being submitted, and approving names exactly what was reviewed', () async {
      await api.submit(makerMembership, batchId, snapshotHash: 'hash-1', version: 2);
      await api.approve(checkerMembership, batchId, snapshotHash: 'hash-1');
      expect(tail(0), 'debit-batches/$batchId/submit/');
      expect(sent(0), {'snapshotHash': 'hash-1', 'version': 2});
      expect(tail(1), 'debit-batches/$batchId/approve/');
      expect(sent(1), {'snapshotHash': 'hash-1'}); // no amounts: the checker approves the snapshot, not a figure typed on the phone
    });

    test('rejecting sends a reason; starting and retrying send no amounts', () async {
      await api.reject(checkerMembership, batchId, reason: 'Please check the Bello family first');
      await api.startDebiting(makerMembership, batchId);
      await api.retry(makerMembership, batchId, itemIds: ['x']);
      await api.retry(makerMembership, batchId);
      expect(sent(0), {'reason': 'Please check the Bello family first'});
      expect(server.requests[1].body.isEmpty || sent(1).isEmpty, isTrue);
      expect(sent(2), {'itemIds': ['x']});
      expect(sent(3), isEmpty);
    });

    test('a batch\'s progress, failed debits and history are read from their own addresses', () async {
      await api.progress(makerMembership, batchId);
      await api.failed(makerMembership, batchId);
      await api.events(makerMembership, batchId);
      await api.items(makerMembership, batchId, eligibility: 'eligible');
      expect([for (var i = 0; i < server.requests.length; i++) tail(i)], [for (final a in ['progress', 'failed', 'events', 'items']) 'debit-batches/$batchId/$a/']);
      expect(server.requests[3].url.queryParameters['eligibility'], 'eligible');
    });

    test('the school\'s sessions and terms come from the server, so a maker with only the mandate duty can choose one', () async {
      final periods = await api.periods(makerMembership);
      expect(tail(0), 'periods/');
      expect(periods.sessions.single.name, '2026/2027');
      expect(periods.sessions.single.terms.map((t) => t.name), ['First Term', 'Second Term']);
    });
  });

  group('debits', () {
    test('the list can be narrowed by status and provider, and one can be asked about again', () async {
      final rows = await api.transactions(ownerMembership, status: 'unknown', provider: 'remita');
      expect(server.requests.single.url.queryParameters['status'], 'unknown');
      expect(server.requests.single.url.queryParameters['provider'], 'remita');
      await api.checkTransaction(ownerMembership, rows.first.id);
      expect(tail(1), 'transactions/${rows.first.id}/check/');
    });
  });

  group('when the server says no', () {
    test('a batch that changed since the checker looked is a conflict with its own code', () async {
      school.refuse = (409, {'code': 'stale_approval', 'message': 'This batch changed since you opened it. Look at it again.'});
      await expectLater(
        api.approve(checkerMembership, batchId, snapshotHash: 'old'),
        throwsA(isA<ApiException>().having((e) => e.isConflict, 'conflict', true).having((e) => e.code, 'code', 'stale_approval')),
      );
    });

    test('a maker approving their own batch is refused as forbidden', () async {
      school.refuse = (403, {'code': 'maker_cannot_approve', 'message': 'Someone else must approve this batch.'});
      await expectLater(api.approve(makerMembership, batchId, snapshotHash: 'h'), throwsA(isA<ApiException>().having((e) => e.isForbidden, 'forbidden', true)));
    });
  });
}
