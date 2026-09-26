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

  test('it asks about this school and says which membership it is acting as', () async {
    reply = providersJson();
    await api.providers(ownerMembership);
    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/schools/$schoolId/collections/providers/');
    expect(request.url.queryParameters['membership'], ownerMembership.id);
    expect(request.headers['Authorization'], 'Bearer access-1');
  });

  test('connecting sends the credentials once, in the body, and never in the address', () async {
    reply = {'connection': connectionJson(status: 'pending')};
    final connection = await api.connect(
      ownerMembership,
      provider: 'sandbox',
      purpose: 'tuition',
      label: '  Tuition Collection ',
      credentials: {'sandbox_key': 'sandbox-SECRET-777', 'account_number': '0123456789'},
    );
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/schools/$schoolId/collections/connections/');
    expect(request.url.toString(), isNot(contains('SECRET')));
    expect(request.url.toString(), isNot(contains('0123456789')));
    expect(body(0), {
      'provider': 'sandbox',
      'purpose': 'tuition',
      'label': 'Tuition Collection',
      'credentials': {'sandbox_key': 'sandbox-SECRET-777', 'account_number': '0123456789'},
    });
    expect(connection.status, 'pending');
  });

  test('what comes back to the app never holds a credential or a full account number', () async {
    reply = {'connection': connectionJson(status: 'pending')};
    final connection = await api.connect(ownerMembership, provider: 'sandbox', purpose: 'tuition', credentials: {'sandbox_key': 'sandbox-SECRET-777'});
    expect(connection.toString(), isNot(contains('SECRET')));
    expect(connection.accountMask, '****6789');
    expect(connection.accountMask, isNot(contains('0123456789')));
  });

  test('approving on the bank\'s own page sends a code and the state, not a password', () async {
    reply = {'authorizationUrl': 'schoolos://bank/return?code=x&state=abc', 'state': 'abc'};
    final start = await api.beginAuthorization(ownerMembership, provider: 'sandbox', redirectUri: 'schoolos://bank/return');
    expect((start.state, start.url), ('abc', 'schoolos://bank/return?code=x&state=abc'));
    expect(body(0), {'provider': 'sandbox', 'redirectUri': 'schoolos://bank/return'});
    reply = {'connection': connectionJson(status: 'pending')};
    await api.connect(ownerMembership, provider: 'sandbox', purpose: 'transport', authorizationCode: ' sandbox-approved ', state: 'abc');
    expect(body(1), {'provider': 'sandbox', 'purpose': 'transport', 'label': '', 'authorizationCode': 'sandbox-approved', 'state': 'abc'});
  });

  test('a refusal arrives with the server\'s own words and a code, and holds no secret', () async {
    status = 400;
    reply = {'code': 'bad_credentials', 'message': 'The provider did not accept these credentials.'};
    try {
      await api.connect(ownerMembership, provider: 'sandbox', purpose: 'tuition', credentials: {'sandbox_key': 'sandbox-SECRET-777'});
      fail('should have been refused');
    } on ApiException catch (error) {
      expect(error.code, 'bad_credentials');
      expect(error.message, 'The provider did not accept these credentials.');
      expect(error.toString(), isNot(contains('SECRET')));
    }
  });

  test('a server that is not set up for secure storage reads as a server problem, not as a wrong answer', () async {
    status = 503;
    reply = {'code': 'secure_storage_unavailable', 'message': 'Secure storage is not set up.'};
    expect(() => api.connect(ownerMembership, provider: 'sandbox', purpose: 'tuition', credentials: {}), throwsA(isA<ApiOfflineException>()));
  });

  test('actions go to their own address with the membership', () async {
    reply = {'connection': connectionJson(), 'test': {'ok': true, 'code': '', 'message': ''}};
    await api.test(ownerMembership, 'conn-1');
    reply = {'connection': connectionJson(), 'sync': {'ok': true, 'fetched': 1, 'created': 1, 'duplicates': 0, 'invalid': 0, 'more': false, 'code': '', 'message': ''}};
    final synced = await api.sync(ownerMembership, 'conn-1');
    expect(synced.sync!.created, 1);
    reply = {'connection': connectionJson()};
    await api.disable(ownerMembership, 'conn-1');
    await api.enable(ownerMembership, 'conn-1');
    await api.disconnect(ownerMembership, 'conn-1');
    await api.confirm(ownerMembership, 'conn-1');
    await api.newWebhookAddress(ownerMembership, 'conn-1');
    final paths = server.requests.map((r) => r.url.path.replaceFirst('/api/v1/schools/$schoolId/collections/connections/conn-1/', '')).toList();
    expect(paths, ['test/', 'sync/', 'disable/', 'enable/', 'disconnect/', 'confirm/', 'webhook-token/']);
    expect(server.requests.every((r) => r.method == 'POST' && r.url.queryParameters['membership'] == ownerMembership.id), isTrue);
  });

  test('the callback address is read once, from the confirmation', () async {
    reply = {'connection': connectionJson(), 'webhook': {'path': 'bank-webhooks/sandbox/token123/'}};
    final result = await api.confirm(ownerMembership, 'conn-1');
    expect(result.webhookPath, 'bank-webhooks/sandbox/token123/');
  });

  test('renaming sends only what changed', () async {
    reply = {'connection': connectionJson()};
    await api.rename(ownerMembership, 'conn-1', label: 'Bus fees');
    await api.rename(ownerMembership, 'conn-1', purpose: 'transport');
    expect(body(0), {'label': 'Bus fees'});
    expect(body(1), {'purpose': 'transport'});
  });

  test('rotating and reconnecting send a fresh credential to the right address', () async {
    reply = {'connection': connectionJson()};
    await api.rotate(ownerMembership, 'conn-1', credentials: {'sandbox_key': 'sandbox-NEW'});
    await api.reconnect(ownerMembership, 'conn-1', credentials: {'sandbox_key': 'sandbox-NEW'});
    expect(server.requests.map((r) => r.url.pathSegments.reversed.skip(1).first), ['rotate', 'reconnect']);
    expect(body(0), {'credentials': {'sandbox_key': 'sandbox-NEW'}});
  });

  test('payments are asked for a page at a time with the filters that were set', () async {
    reply = pageJson([paymentJson()]);
    await api.payments(ownerMembership, connectionId: 'conn-1', status: 'unmatched', query: ' musa ', limit: 20, offset: 40);
    await api.payments(ownerMembership);
    final first = server.requests[0].url.queryParameters;
    expect((first['connection'], first['status'], first['q'], first['limit'], first['offset']), ('conn-1', 'unmatched', 'musa', '20', '40'));
    final second = server.requests[1].url.queryParameters;
    expect(second.containsKey('q') || second.containsKey('status') || second.containsKey('connection'), isFalse);
    expect(server.requests[0].url.path, endsWith('/collections/transactions/'));
  });

  test('the review queue and one payment', () async {
    reply = pageJson([paymentJson()], counts: {'requires_review': 1});
    final page = await api.reviewQueue(ownerMembership, status: 'requires_review');
    expect(page.counts, {'requires_review': 1});
    expect(server.requests.single.url.path, endsWith('/collections/review/'));
    reply = {'transaction': paymentJson(id: 'pay-9')};
    expect((await api.payment(ownerMembership, 'pay-9')).id, 'pay-9');
    expect(server.requests.last.url.path, endsWith('/collections/transactions/pay-9/'));
  });

  test('a decision says what the person was looking at, so a stale one is refused', () async {
    reply = {'transaction': paymentJson(status: 'matched')};
    await api.decide(ownerMembership, 'pay-1', action: 'assign', expectedStatus: 'requires_review', studentId: 'student-1', purpose: 'books', note: ' Father confirmed ');
    expect(server.requests.single.url.path, endsWith('/collections/transactions/pay-1/decide/'));
    expect(body(0), {'action': 'assign', 'expectedStatus': 'requires_review', 'studentId': 'student-1', 'purpose': 'books', 'note': 'Father confirmed'});
  });

  test('a split sends whole kobo for each student', () async {
    reply = {'transaction': paymentJson(status: 'matched')};
    await api.decide(ownerMembership, 'pay-1', action: 'split', split: [
      (studentId: 's1', amountMinor: 3000000, purpose: null),
      (studentId: 's2', amountMinor: 2000000, purpose: 'transport'),
    ]);
    expect(body(0)['allocations'], [
      {'studentId': 's1', 'amountMinor': 3000000},
      {'studentId': 's2', 'amountMinor': 2000000, 'purpose': 'transport'},
    ]);
  });

  test('a decision made on a stale screen comes back as the server\'s message', () async {
    status = 400;
    reply = {'code': 'stale', 'message': 'Someone has changed this payment since you opened it. Refresh and look again.'};
    expect(
      () => api.decide(ownerMembership, 'pay-1', action: 'assign', expectedStatus: 'requires_review', studentId: 's1'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'stale')),
    );
  });

  test('students are searched for by what was typed', () async {
    reply = {'students': [{'id': 's1', 'name': 'Aisha Bello', 'studentCode': 'BG-0042', 'admissionNumber': 'ADM/1', 'className': 'Primary 3', 'status': 'active'}]};
    final hits = await api.searchStudents(ownerMembership, ' aisha ');
    expect(hits.single.name, 'Aisha Bello');
    expect(server.requests.single.url.queryParameters['q'], 'aisha');
  });

  test('the summary asks for test data only when told to', () async {
    reply = summaryJson();
    await api.summary(ownerMembership);
    await api.summary(ownerMembership, period: 'week', includeSandbox: true);
    expect(server.requests[0].url.queryParameters['includeSandbox'], isNull);
    expect(server.requests[0].url.queryParameters['period'], 'term');
    expect((server.requests[1].url.queryParameters['period'], server.requests[1].url.queryParameters['includeSandbox']), ('week', 'true'));
  });

  test('nothing is kept between calls: a new call after a failure starts clean', () async {
    status = 400;
    reply = {'code': 'x', 'message': 'no'};
    await expectLater(api.providers(ownerMembership), throwsA(isA<ApiException>()));
    status = 200;
    reply = providersJson();
    expect((await api.providers(ownerMembership)).providers, isNotEmpty);
  });
}
