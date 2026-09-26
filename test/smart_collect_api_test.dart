import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/features/smartcollect/data/smart_collect_api.dart';

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';
import 'smart_collect_fixtures.dart';

void main() {
  late FakeServer server;
  late SmartCollectApi api;
  late Map<String, Object?> reply;
  var status = 200;
  http.Response? raw;

  setUp(() {
    reply = {};
    status = 200;
    raw = null;
    server = FakeServer((request) async => raw ?? jsonResponse(reply, status));
    api = SmartCollectApi(api: apiFor(server));
  });

  Map<String, dynamic> body(int index) => jsonDecode(server.requests[index].body) as Map<String, dynamic>;
  const base = '/api/v1/schools/$schoolId/collections/';
  String tail(int index) => server.requests[index].url.path.replaceFirst(base, '');

  test('every call says which school and which membership it is acting as', () async {
    reply = dashboardJson();
    await api.dashboard(ownerMembership);
    final r = server.requests.single;
    expect((r.method, r.url.path), ('GET', '${base}dashboard/'));
    expect(r.url.queryParameters['membership'], ownerMembership.id);
    expect(r.headers['Authorization'], 'Bearer access-1');
  });

  group('the policy', () {
    test('the default is changed with PATCH and only the changed settings are sent', () async {
      reply = policyResponse(policy: policyJson(accountMode: 'dynamic'));
      final p = await api.updatePolicy(ownerMembership, {'account_mode': 'dynamic', 'settlement_action': 'grace_then_close', 'grace_period_hours': 48});
      expect(server.requests.single.method, 'PATCH');
      expect(body(0), {'values': {'account_mode': 'dynamic', 'settlement_action': 'grace_then_close', 'grace_period_hours': 48}});
      expect(p.values['account_mode'], 'dynamic');
    });

    test('an override sends its target, its settings, its reason and how long it lasts', () async {
      reply = {'override': overrideJson()};
      await api.setOverride(
        ownerMembership,
        scope: 'family',
        familyId: 'fam-1',
        values: {'eligibility_policy': 'include'},
        reason: '  Agreed payment plan ',
        expiryKind: 'end_of_term',
        expiryTermId: 'term-1',
      );
      expect(tail(0), 'policy/overrides/');
      expect(body(0), {
        'scope': 'family',
        'familyId': 'fam-1',
        'values': {'eligibility_policy': 'include'},
        'reason': 'Agreed payment plan',
        'expiryKind': 'end_of_term',
        'expiryTermId': 'term-1',
      });
    });

    test('nothing in an override request can name a provider', () async {
      reply = {'override': overrideJson()};
      await api.setOverride(ownerMembership, scope: 'term', termId: 'term-1', values: {'account_mode': 'dynamic'});
      expect(jsonEncode(body(0)), isNot(contains('provider')));
    });

    test('removing an override and asking what applies to a family', () async {
      reply = {'override': overrideJson(active: false)};
      await api.removeOverride(ownerMembership, 'ov-1', reason: 'done');
      expect(tail(0), 'policy/overrides/ov-1/remove/');
      reply = {
        'effective': {'values': <String, Object?>{}, 'sources': <String, Object?>{}, 'problems': <Object?>[], 'description': {'fields': <Object?>[], 'problems': <Object?>[]}}
      };
      await api.effectivePolicy(ownerMembership, sessionId: 'ses-1', termId: 'term-1', familyId: 'fam-1');
      final q = server.requests.last.url.queryParameters;
      expect((q['session'], q['term'], q['family']), ('ses-1', 'term-1', 'fam-1'));
    });

    test('overrides can be listed by scope, with their history', () async {
      reply = {'overrides': [overrideJson()]};
      final list = await api.overrides(ownerMembership, scope: 'family', history: true);
      final q = server.requests.single.url.queryParameters;
      expect((q['scope'], q['history']), ('family', '1'));
      expect(list.single.targetLabel, 'Bello family');
    });
  });

  group('a batch', () {
    test('it is made for a session and term, with an optional policy for just this batch', () async {
      reply = {'batch': batchJson()};
      await api.createBatch(ownerMembership, sessionId: 'ses-1', termId: 'term-1', title: ' Term one ', policy: {'account_mode': 'dynamic'}, reason: 'New arrangement');
      expect(body(0), {'sessionId': 'ses-1', 'termId': 'term-1', 'title': 'Term one', 'policy': {'account_mode': 'dynamic'}, 'reason': 'New arrangement'});
    });

    test('selection carries the version the person was looking at, so a stale screen is refused', () async {
      reply = {'batch': batchJson()};
      await api.setSelection(ownerMembership, 'batch-1', select: ['i1'], deselect: ['i2'], expectedVersion: 3);
      expect(tail(0), 'batches/batch-1/selection/');
      expect(body(0), {'select': ['i1'], 'deselect': ['i2'], 'expectedVersion': 3});
      await api.setSelection(ownerMembership, 'batch-1', selectAllEligible: true);
      expect(body(1), {'selectAllEligible': true});
      await api.setSelection(ownerMembership, 'batch-1', deselectAll: true);
      expect(body(2), {'deselectAll': true});
    });

    test('a stale screen gets a conflict it can act on, with the current version', () async {
      reply = {'code': 'stale_preview', 'message': 'This batch was changed since you last looked at it.', 'version': 4, 'snapshotHash': 'abc'};
      status = 409;
      await expectLater(
        api.setSelection(ownerMembership, 'batch-1', select: ['i1'], expectedVersion: 3),
        throwsA(isA<ApiException>().having((e) => e.isConflict, 'conflict', isTrue).having((e) => e.code, 'code', 'stale_preview')),
      );
    });

    test('families are listed by bucket, selection, override and text, a page at a time', () async {
      reply = itemsJson([itemJson()]);
      await api.items(ownerMembership, 'batch-1', bucket: 'needs_override', selected: true, overriddenOnly: true, query: ' bello ', limit: 20, offset: 40);
      final q = server.requests.single.url.queryParameters;
      expect((q['bucket'], q['selected'], q['overridden'], q['q'], q['limit'], q['offset']), ('needs_override', '1', '1', 'bello', '20', '40'));
    });

    test('overriding a family needs a reason and goes to that family only', () async {
      reply = {'batch': batchJson()};
      await api.overrideEligibility(ownerMembership, 'batch-1', 'item-1', reason: ' Head teacher agreed ', expectedVersion: 3);
      expect(tail(0), 'batches/batch-1/items/item-1/override/');
      expect(body(0), {'reason': 'Head teacher agreed', 'expectedVersion': 3});
      await api.clearOverride(ownerMembership, 'batch-1', 'item-1');
      expect(tail(1), 'batches/batch-1/items/item-1/override-clear/');
      await api.chooseArrears(ownerMembership, 'batch-1', 'item-1', receivableIds: ['r1', 'r2']);
      expect(body(2), {'receivableIds': ['r1', 'r2']});
    });

    test('submitting names the fingerprint, and approving names the exact one the checker saw', () async {
      reply = {'batch': batchJson(status: 'pending_approval')};
      await api.submit(ownerMembership, 'batch-1', expectedHash: 'h1', expectedVersion: 3);
      expect(body(0), {'expectedHash': 'h1', 'expectedVersion': 3});
      await api.approve(ownerMembership, 'batch-1', expectedHash: 'h1', manualApprovals: ['i9']);
      expect(tail(1), 'batches/batch-1/approve/');
      expect(body(1), {'expectedHash': 'h1', 'manualApprovals': ['i9']});
    });

    test('a rejection carries its reason', () async {
      reply = {'batch': batchJson(status: 'rejected', rejectionReason: 'x y z')};
      final b = await api.reject(ownerMembership, 'batch-1', reason: '  Bravo should not be in it ');
      expect(body(0), {'reason': 'Bravo should not be in it'});
      expect(b.isRejected, isTrue);
    });

    test('starting is its own call, made only after approval', () async {
      reply = {'batch': batchJson(status: 'processing')};
      await api.start(ownerMembership, 'batch-1');
      expect(tail(0), 'batches/batch-1/start/');
    });

    test('a retry says how many were retried and whether a fresh approval is needed first', () async {
      reply = {'batch': batchJson(status: 'processing'), 'retried': 4};
      var result = await api.retry(ownerMembership, 'batch-1', itemIds: ['i1']);
      expect((result.retried, result.approvalNeeded), (4, false));
      expect(body(0), {'itemIds': ['i1']});
      reply = {'batch': batchJson(status: 'draft'), 'retried': 0, 'approvalNeeded': true};
      result = await api.retry(ownerMembership, 'batch-1');
      expect((result.retried, result.approvalNeeded, result.batch.isDraft), (0, true, true));
      expect(body(1), isEmpty);
    });

    test('progress and the failed families are read from their own addresses', () async {
      reply = {'progress': {'status': 'processing', 'total': 10, 'successful': 4, 'failed': 1, 'waiting': 5, 'generating': 0, 'finished': false}};
      final p = await api.progress(ownerMembership, 'batch-1');
      expect((p.total, p.done), (10, 5));
      reply = {'items': [itemJson(generation: 'failed', error: 'provider_rejected', errorMessage: 'no')], 'count': 1};
      final failed = await api.failed(ownerMembership, 'batch-1');
      expect(tail(1), 'batches/batch-1/failed/');
      expect(failed.single.hasFailed, isTrue);
    });

    test('the preview is exported as a file, asking for its type and reading nothing as JSON', () async {
      raw = http.Response.bytes([0x25, 0x50, 0x44, 0x46], 200, headers: {'content-type': 'application/pdf'});
      final file = await api.export(ownerMembership, 'batch-1234567890', type: 'pdf', selectedOnly: true);
      final r = server.requests.single;
      expect(r.url.path, '${base}batches/batch-1234567890/export/');
      expect((r.url.queryParameters['type'], r.url.queryParameters['selected']), ('pdf', '1'));
      expect(r.headers['Accept'], '*/*');
      expect(file.bytes, [0x25, 0x50, 0x44, 0x46]);
      expect(file.fileName, endsWith('.pdf'));
    });

    test('an export the server refuses says why', () async {
      raw = jsonResponse({'code': 'invalid_format', 'message': 'Choose pdf or xlsx.'}, 400);
      await expectLater(api.export(ownerMembership, 'batch-1234567890', type: 'docx'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Choose pdf or xlsx.')));
    });
  });

  group('provider switching', () {
    test('a switch is planned for a time, in UTC, with an optional note', () async {
      reply = {'switch': switchJson()};
      await api.scheduleSwitch(ownerMembership, toConnectionId: 'conn-2', scheduledFor: DateTime.utc(2026, 10, 5, 9), note: ' after exams ');
      expect(tail(0), 'switches/');
      expect(body(0), {'toConnectionId': 'conn-2', 'scheduledFor': '2026-10-05T09:00:00.000Z', 'note': 'after exams'});
    });

    test('applying and cancelling are separate, explicit calls', () async {
      reply = {'switch': switchJson(status: 'applied')};
      await api.applySwitch(ownerMembership, 'sw-1');
      expect(tail(0), 'switches/sw-1/apply/');
      await api.cancelSwitch(ownerMembership, 'sw-1', reason: 'not yet');
      expect(tail(1), 'switches/sw-1/cancel/');
      expect(body(1), {'reason': 'not yet'});
    });

    test('the open switch and its history are read together', () async {
      reply = {'open': switchJson(status: 'ready_to_switch'), 'history': [switchJson(status: 'applied')], 'permissions': permissionsJson()};
      final info = await api.switches(ownerMembership);
      expect((info.open!.isReady, info.history.length, info.permissions.canManageProviders), (true, 1, true));
    });
  });

  group('families', () {
    test('a payer\'s identity number is written and never read back', () async {
      reply = {'identity': {'hasBvn': true, 'hasNin': false}};
      final s = await api.savePayerIdentity(ownerMembership, 'fam-1', bvn: '12345678901', nin: '');
      expect(server.requests.single.method, 'PUT');
      expect(tail(0), 'families/fam-1/payer-identity/');
      expect(body(0), {'bvn': '12345678901'});
      expect(server.requests.single.url.toString(), isNot(contains('12345678901')));
      expect(s.onFile, isTrue);
      final got = await api.payerIdentity(ownerMembership, 'fam-1');
      expect(server.requests.last.method, 'GET');
      expect(got.hasBvn, isTrue);
    });

    test('a family\'s account history is read from receivables, and retiring an account needs a reason', () async {
      reply = {'accounts': [accountRecordJson(), accountRecordJson(id: 'acc-0', status: 'closed')]};
      final list = await api.familyAccounts(ownerMembership, 'fam-1');
      expect(server.requests.single.url.path, '/api/v1/schools/$schoolId/receivables/families/fam-1/collection-accounts/');
      expect(list.map((a) => a.status), ['active', 'closed']);
      reply = {'account': accountRecordJson(status: 'closing')};
      await api.closeAccount(ownerMembership, 'acc-1', reason: ' Family left ');
      expect(server.requests.last.url.path, '/api/v1/schools/$schoolId/receivables/collection-accounts/acc-1/close/');
      expect(body(1), {'reason': 'Family left'});
    });
  });
}
