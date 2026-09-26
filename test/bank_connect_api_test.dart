import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/features/bankconnect/data/bank_connect_api.dart';

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';

void main() {
  late FakeServer server;
  late BankConnectApi api;
  late Map<String, Object?> reply;
  var status = 200;

  setUp(() {
    reply = {};
    status = 200;
    server = FakeServer((request) async => jsonResponse(reply, status));
    api = BankConnectApi(api: apiFor(server));
  });

  Map<String, dynamic> body(int index) => jsonDecode(server.requests[index].body) as Map<String, dynamic>;
  const base = '/api/v1/schools/$schoolId/collections/';

  test('it asks about this school and says which membership it is acting as', () async {
    reply = providersJson();
    await api.providers(ownerMembership);
    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '${base}providers/');
    expect(request.url.queryParameters['membership'], ownerMembership.id);
    expect(request.headers['Authorization'], 'Bearer access-1');
  });

  test('connecting sends the credentials once, in the body, and never in the address', () async {
    reply = {'connection': connectionJson(active: false)};
    final connection = await api.connect(
      ownerMembership,
      provider: 'monnify',
      environment: 'test',
      label: '  Main collections ',
      credentials: {'api_key': 'MK_SECRET_777', 'secret_key': 'SECRET-KEY-9', 'contract_code': '7059707855'},
      settings: {'preferred_bank_code': '50515'},
    );
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '${base}connections/');
    expect(request.url.toString(), isNot(contains('SECRET')));
    expect(request.url.toString(), isNot(contains('7059707855')));
    expect(body(0), {
      'provider': 'monnify',
      'environment': 'test',
      'label': 'Main collections',
      'credentials': {'api_key': 'MK_SECRET_777', 'secret_key': 'SECRET-KEY-9', 'contract_code': '7059707855'},
      'settings': {'preferred_bank_code': '50515'},
    });
    expect(connection.isActiveProvider, isFalse);
  });

  test('no settlement account is ever part of what is sent', () async {
    reply = {'connection': connectionJson()};
    await api.connect(ownerMembership, provider: 'paystack', environment: 'live', credentials: {'secret_key': 'sk_live_x'});
    final sent = jsonEncode(body(0));
    for (final banned in ['account_number', 'accountNumber', 'settlement', 'bank_code']) {
      expect(sent, isNot(contains(banned)), reason: banned);
    }
  });

  test('what comes back to the app never holds a credential', () async {
    reply = {'connection': connectionJson()};
    final connection = await api.connect(ownerMembership, provider: 'paystack', environment: 'live', credentials: {'secret_key': 'sk_live_SECRET'});
    final shown = [connection.id, connection.provider, connection.merchantName, connection.merchantReference, connection.label, connection.settings.toString()].join(' ');
    expect(shown, isNot(contains('SECRET')));
  });

  test('replacing credentials sends only the new ones to the right connection', () async {
    reply = {'connection': connectionJson(), 'test': null};
    await api.replaceCredentials(ownerMembership, 'conn-1', credentials: {'secret_key': 'sk_live_NEW'});
    expect(server.requests.single.url.path, '${base}connections/conn-1/replace-credentials/');
    expect(body(0), {'credentials': {'secret_key': 'sk_live_NEW'}});
  });

  test('actions on one connection go to its own address', () async {
    reply = {'connection': connectionJson(), 'test': {'ok': true, 'code': '', 'message': ''}};
    await api.test(ownerMembership, 'conn-1');
    await api.disable(ownerMembership, 'conn-1');
    await api.enable(ownerMembership, 'conn-1');
    await api.disconnect(ownerMembership, 'conn-1');
    await api.activate(ownerMembership, 'conn-1');
    await api.rename(ownerMembership, 'conn-1', label: 'Front desk');
    expect(server.requests.map((r) => r.url.path.replaceFirst('${base}connections/conn-1/', '')), ['test/', 'disable/', 'enable/', 'disconnect/', 'activate/', 'rename/']);
    expect(body(5), {'label': 'Front desk'});
  });

  test('the webhook setup is read from its own address and a new address is asked for by name', () async {
    reply = {'webhook': webhookJson()};
    final setup = await api.webhookSetup(ownerMembership, 'conn-1');
    expect(server.requests.single.url.path, '${base}connections/conn-1/webhook/');
    expect((setup.status, setup.mode), ('awaiting_event', 'dashboard'));
    reply = {'connection': connectionJson(webhook: 'awaiting_event'), 'webhook': webhookJson()};
    final again = await api.newWebhookAddress(ownerMembership, 'conn-1');
    expect(server.requests.last.url.path, '${base}connections/conn-1/webhook-token/');
    expect(again!.path, contains('TOKEN123'));
  });

  test('a refusal reaches the screen in the server\'s own words, with its code', () async {
    reply = {'code': 'environment_mismatch', 'message': 'These credentials are for the other mode.'};
    status = 400;
    await expectLater(
      api.connect(ownerMembership, provider: 'paystack', environment: 'live', credentials: {'secret_key': 'sk_test_x'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'These credentials are for the other mode.').having((e) => e.code, 'code', 'environment_mismatch')),
    );
  });

  test('payments and the review queue can be filtered by connection and status', () async {
    reply = pageJson([paymentJson()]);
    await api.payments(ownerMembership, connectionId: 'conn-1', status: 'matched', query: ' Musa ');
    final q = server.requests.single.url.queryParameters;
    expect((q['connection'], q['status'], q['q']), ('conn-1', 'matched', 'Musa'));
    await api.reviewQueue(ownerMembership, status: 'unmatched');
    expect(server.requests.last.url.path, '${base}review/');
  });

  test('a decision carries what the person was looking at, so a stale screen is refused', () async {
    reply = {'transaction': paymentJson(status: 'matched')};
    await api.decide(ownerMembership, 'pay-1', action: 'assign', expectedStatus: 'requires_review', studentId: 'student-1', note: ' ok ');
    expect(body(0), {'action': 'assign', 'expectedStatus': 'requires_review', 'studentId': 'student-1', 'note': 'ok'});
  });

  test('the summary asks for a period and whether to include test data', () async {
    reply = summaryJson();
    await api.summary(ownerMembership, period: 'week', includeSandbox: true);
    final q = server.requests.single.url.queryParameters;
    expect((q['period'], q['includeSandbox']), ('week', 'true'));
  });
}
