import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';
import 'family_fees_fixtures.dart';
import 'smart_collect_fixtures.dart';

/// A school server for the Smart Money Collection screens. It remembers what it was sent (by "METHOD path"), so the tests can check
/// what left the phone, and answers with the fixtures the tests set.
class CollectionsServer {
  // -- the provider layer ------------------------------------------------------------------------
  Map<String, Object?> providers = providersJson(activeId: 'conn-1');
  List<Map<String, Object?>> connections = [connectionJson()];
  bool canManage = true;
  Map<String, Object?> summary = summaryJson();
  List<Map<String, Object?>> payments = [paymentJson()];
  Map<String, int> counts = {'requires_review': 1};
  bool failConnect = false;
  bool stale = false;
  Map<String, Object?> webhook = webhookJson();

  // -- Smart Money Collection ----------------------------------------------------------------------
  Map<String, Object?> dashboard = dashboardJson();
  Map<String, Object?> policy = policyResponse();
  List<Map<String, Object?>> overrides = [];
  Map<String, Object?> periods = periodsJson();
  Map<String, Object?> switches = {'open': null, 'history': <Object?>[], 'permissions': permissionsJson()};
  Map<String, Object?> switchDetail = switchJson();
  List<Map<String, Object?>> batches = [];
  Map<String, Object?> batch = batchJson();

  /// What a batch action answers with (defaults to [batch]).
  Map<String, Object?>? batchAfterAction;
  List<Map<String, Object?>> items = [itemJson()];
  Map<String, Object?>? itemBuckets;
  List<Map<String, Object?>> failedItems = [];
  Map<String, Object?> progress = {'status': 'processing', 'total': 2, 'successful': 0, 'failed': 0, 'waiting': 2, 'generating': 0, 'finished': false};
  List<Map<String, Object?>> events = [];
  List<Map<String, Object?>> families = [familyJson()];
  bool hasMoreFamilies = false;
  bool canDecideBilling = true;
  List<Map<String, Object?>> accountHistory = [];
  Map<String, Object?> identity = {'hasBvn': false, 'hasNin': false};
  Map<String, Object?>? refusal;
  List<Map<String, String>> mergeProblems = const [];
  int refusalStatus = 400;
  Map<String, Object?> retryAnswer = {'retried': 1};

  final requests = <String, Map<String, dynamic>>{};
  final queries = <String, Map<String, String>>{};
  final calls = <String>[];

  static const _base = '/api/v1/schools/$schoolId/collections/';
  static const _fees = '/api/v1/schools/$schoolId/receivables/';

  http.Response _refuse() => jsonResponse(refusal, refusalStatus);

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst(_base, '').replaceFirst(_fees, 'receivables/');
    final key = '${r.method} $path';
    calls.add(key);
    queries[key] = r.url.queryParameters;
    if (r.method != 'GET') requests[key] = r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;

    // -- provider layer
    switch (key) {
      case 'GET providers/':
        return jsonResponse({...providers, 'canManage': canManage, 'permissions': permissionsJson(providers: canManage)});
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
        if (failConnect) return jsonResponse({'code': 'bad_credentials', 'message': 'The provider did not accept these credentials.'}, 400);
        final made = connectionJson(id: 'conn-new', provider: (requests[key]!['provider'] as String?) ?? 'paystack', active: false, webhook: 'awaiting_event');
        connections = [...connections, made];
        return jsonResponse({'connection': made}, 201);
      case 'POST transactions/pay-1/decide/':
        if (stale) return jsonResponse({'code': 'stale', 'message': 'Someone has changed this payment since you opened it. Refresh and look again.'}, 400);
        return jsonResponse({
          'transaction': paymentJson(status: 'matched', allocations: [
            {'id': 'a1', 'studentId': 'student-BG-0042', 'studentName': 'Aisha Bello', 'studentCode': 'BG-0042', 'purpose': 'tuition', 'amountMinor': 5000000, 'source': 'manual', 'superseded': false},
          ], decisions: []),
        });
    }
    final connection = RegExp(r'^(GET|POST) connections/([\w-]+)/(\w[\w-]*)/$').firstMatch(key);
    if (connection != null) {
      final id = connection.group(2)!;
      final action = connection.group(3)!;
      final row = connections.firstWhere((c) => c['id'] == id, orElse: () => connectionJson(id: id));
      if (action == 'webhook') return jsonResponse({'webhook': webhook});
      if (action == 'audit') return jsonResponse({'events': [{'id': 'e1', 'kind': 'provider_connected', 'connectionId': id, 'detail': <String, Object?>{}, 'at': '2026-09-20T10:00:00+01:00'}]});
      if (action == 'webhook-token') return jsonResponse({'connection': row, 'webhook': webhookJson()});
      if (refusal != null) return _refuse();
      return jsonResponse({'connection': row, 'test': {'ok': true, 'code': '', 'message': ''}});
    }

    // -- Smart Money Collection
    switch (key) {
      case 'GET dashboard/':
        return jsonResponse(dashboard);
      case 'GET periods/':
        return jsonResponse(periods);
      case 'GET policy/':
        return jsonResponse(policy);
      case 'PATCH policy/':
        if (refusal != null) return _refuse();
        return jsonResponse(policy);
      case 'GET policy/overrides/':
        return jsonResponse({'overrides': overrides});
      case 'POST policy/overrides/':
        if (refusal != null) return _refuse();
        return jsonResponse({'override': overrideJson()}, 201);
      case 'GET switches/':
        return jsonResponse(switches);
      case 'POST switches/':
        if (refusal != null) return _refuse();
        return jsonResponse({'switch': switchJson()}, 201);
      case 'GET batches/':
        return jsonResponse({'batches': batches, 'hasMore': false, 'permissions': permissionsJson()});
      case 'POST batches/':
        if (refusal != null) return _refuse();
        return jsonResponse({'batch': batch}, 201);
      case 'GET receivables/families/':
        return jsonResponse({'families': families, 'hasMore': hasMoreFamilies, 'permissions': {'canDecideBilling': canDecideBilling}});
      case 'GET families/fam-1/payer-identity/':
        return jsonResponse({'identity': identity});
      case 'PUT families/fam-1/payer-identity/':
        if (refusal != null) return _refuse();
        identity = {'hasBvn': requests[key]!.containsKey('bvn'), 'hasNin': requests[key]!.containsKey('nin')};
        return jsonResponse({'identity': identity});
      case 'GET receivables/families/fam-1/collection-accounts/':
        return jsonResponse({'accounts': accountHistory});
      case 'GET receivables/families/fam-2/merge-preview/':
        return jsonResponse(mergePreviewJson(problems: mergeProblems));
      case 'POST receivables/families/fam-2/merge/':
        if (refusal != null) return _refuse();
        return jsonResponse({'merge': {'into': {}, 'source': {}, 'moved': {}}});
    }
    final accountAction = RegExp(r'^POST receivables/collection-accounts/([\w-]+)/(suspend|reinstate|close|mark-provisioned)/$').firstMatch(key);
    if (accountAction != null) {
      if (refusal != null) return _refuse();
      return jsonResponse({'account': accountRecordJson(id: accountAction.group(1)!)});
    }
    final sw = RegExp(r'^(GET|POST) switches/([\w-]+)/(apply/|cancel/)?$').firstMatch(key);
    if (sw != null) {
      if (refusal != null && sw.group(1) == 'POST') return _refuse();
      if (sw.group(3) == 'apply/') return jsonResponse({'switch': switchJson(status: 'applied')});
      if (sw.group(3) == 'cancel/') return jsonResponse({'switch': switchJson(status: 'cancelled')});
      return jsonResponse({'switch': switchDetail, 'review': <String, Object?>{}});
    }
    final item = RegExp(r'^POST batches/([\w-]+)/items/([\w-]+)/([\w-]+)/$').firstMatch(key);
    if (item != null) {
      if (refusal != null) return _refuse();
      return jsonResponse({'batch': batchAfterAction ?? batch});
    }
    final b = RegExp(r'^(GET|POST) batches/([\w-]+)/([\w-]*)/?$').firstMatch(key);
    if (b != null) {
      final action = b.group(3)!;
      if (b.group(1) == 'GET') {
        switch (action) {
          case '':
            return jsonResponse({'batch': batch});
          case 'items':
            if (queries[key]!['generation'] == 'failed') return jsonResponse(itemsJson(failedItems));
            return jsonResponse(itemsJson(_filtered(queries[key]!), buckets: itemBuckets));
          case 'events':
            return jsonResponse({'events': events});
          case 'progress':
            return jsonResponse({'progress': progress, 'batch': batch});
          case 'failed':
            return jsonResponse({'items': failedItems, 'count': failedItems.length});
          case 'export':
            return http.Response.bytes(utf8.encode('%PDF-1.4 test'), 200, headers: {'content-type': 'application/pdf'});
        }
      } else {
        if (refusal != null) return _refuse();
        if (action == 'retry') return jsonResponse({'batch': batchAfterAction ?? batch, ...retryAnswer});
        return jsonResponse({'batch': batchAfterAction ?? batch});
      }
    }
    return jsonResponse({'message': 'not found: $key'}, 404);
  }

  List<Map<String, Object?>> _filtered(Map<String, String> q) {
    var rows = items;
    if (q['bucket'] != null) rows = [for (final i in rows) if (q['bucket']!.split(',').contains(i['eligibilityStatus'])) i];
    if (q['selected'] == '1') rows = [for (final i in rows) if (i['selected'] == true) i];
    if (q['overridden'] == '1') rows = [for (final i in rows) if (i['eligibilityOverride'] == true) i];
    return rows;
  }
}
