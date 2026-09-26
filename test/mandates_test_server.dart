import 'dart:convert';

import 'package:http/http.dart' as http;

import 'core/backend_test_support.dart';
import 'mandates_fixtures.dart';
import 'smart_collect_fixtures.dart' show familyJson;

typedef Refusal = (int, Map<String, Object?>);

/// A school server for the Mandates & Direct Debit screens. It answers with the responses the real server recorded, remembers what it was sent
/// (by "METHOD path", the path being what follows the school's mandates address) so the tests can check what left the phone, and lets a test
/// change any answer.
class MandatesServer {
  // -- providers ---------------------------------------------------------------------------------
  Map<String, Object?> providers = real('providers');
  Map<String, Object?> connections = real('connections_both');
  Map<String, Object?> connectAnswer = real('connect_remita');
  Map<String, Object?> webhook = real('webhook');
  Map<String, Object?> banks = real('banks');
  Map<String, Object?> testAnswer = {'ok': true, 'code': '', 'message': ''};

  // -- overview, families ----------------------------------------------------------------------------
  Map<String, Object?> overview = real('overview_after');
  Map<String, Object?> periods = real('periods');
  Map<String, Object?> payers = real('family_payers');
  List<Map<String, Object?>> families = [familyJson(id: 'family-bello', name: 'Bello family')];

  // -- mandates ---------------------------------------------------------------------------------------
  Map<String, Object?> mandates = real('mandates');
  Map<String, Object?> mandate = real('mandate_detail');

  /// What a mandate action answers with (defaults to [mandate]'s own).
  Map<String, Object?>? mandateAfterAction;
  Map<String, Object?> myMandates = real('my_mandates_consent');
  Map<String, Object?> authorised = real('my_mandate_authorised');
  Map<String, Object?> activationFields = real('activation_request');
  Map<String, Object?> activated = real('activation_confirm');
  Map<String, Object?> started = real('mandate_detail');

  // -- batches ----------------------------------------------------------------------------------------
  Map<String, Object?> batches = real('batches');
  Map<String, Object?> batch = real('batch_selected');
  Map<String, Object?> created = real('batch_created');
  Map<String, Object?> items = real('batch_items');
  Map<String, Object?> events = real('batch_events');
  Map<String, Object?> progress = real('batch_progress');
  Map<String, Object?> failed = {'items': <Object?>[]};

  /// What a batch action answers with (defaults to [batch]).
  Map<String, Object?>? batchAfterAction;
  Map<String, Object?> transactions = real('transactions');

  /// A refusal for every write: (status, body).
  Refusal? refuse;

  final requests = <String, Map<String, dynamic>>{};
  final queries = <String, Map<String, String>>{};
  final calls = <String>[];
  final overrides = <String, http.Response Function(Map<String, dynamic> body)>{};

  static const _base = '/api/v1/schools/$schoolId/mandates/';
  static const _fees = '/api/v1/schools/$schoolId/receivables/';

  /// How many times a call was made.
  int count(String key) => calls.where((c) => c == key).length;

  Map<String, Object?> _connection(String id) {
    for (final c in maps(connections['connections'])) {
      if (c['id'] == id) return c;
    }
    return maps(connections['connections']).first;
  }

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst(_base, '').replaceFirst(_fees, 'receivables/');
    final key = '${r.method} $path';
    calls.add(key);
    queries[key] = r.url.queryParameters;
    final body = r.method != 'GET' && r.body.isNotEmpty ? jsonDecode(r.body) as Map<String, dynamic> : <String, dynamic>{};
    if (r.method != 'GET') requests[key] = body;

    final custom = overrides[key];
    if (custom != null) return custom(body);
    if (r.method != 'GET' && refuse != null) return jsonResponse(refuse!.$2, refuse!.$1);

    switch (key) {
      case 'GET providers/':
        return jsonResponse(providers);
      case 'GET connections/':
        return jsonResponse(connections);
      case 'POST connections/':
        return jsonResponse(connectAnswer, 201);
      case 'GET overview/':
        return jsonResponse(overview);
      case 'GET periods/':
        return jsonResponse(periods);
      case 'GET receivables/families/':
        return jsonResponse({'families': families, 'hasMore': false, 'permissions': {'canDecideBilling': false}});
      case 'GET mandates/':
        return jsonResponse(mandates);
      case 'POST mandates/':
        return jsonResponse(started, 201);
      case 'GET my-mandates/':
        return jsonResponse(myMandates);
      case 'GET debit-batches/':
        return jsonResponse(batches);
      case 'POST debit-batches/':
        return jsonResponse(created, 201);
      case 'GET transactions/':
        return jsonResponse(transactions);
    }

    final connection = RegExp(r'^(GET|POST) connections/([\w-]+)/([\w-]+)/$').firstMatch(key);
    if (connection != null) {
      final id = connection.group(2)!;
      final action = connection.group(3)!;
      final row = _connection(id);
      if (action == 'webhook' || action == 'webhook-token') return jsonResponse({'webhook': (webhook['webhook'])});
      if (action == 'banks') return jsonResponse(banks);
      if (action == 'audit') return jsonResponse(real('audit'));
      return jsonResponse({'connection': row, if (action == 'test' || action == 'enable') 'test': testAnswer});
    }

    final payers = RegExp(r'^GET families/([\w-]+)/payers/$').firstMatch(key);
    if (payers != null) return jsonResponse(this.payers);

    final mandateRoute = RegExp(r'^(GET|POST) mandates/([\w-]+)/(?:([\w-]+)/)?$').firstMatch(key);
    if (mandateRoute != null) {
      if (r.method == 'GET') return jsonResponse(mandate);
      return jsonResponse(mandateAfterAction ?? {'mandate': (mandate['mandate'])});
    }

    final mine = RegExp(r'^(GET|POST) my-mandates/([\w-]+)/(?:([\w-]+)/)?$').firstMatch(key);
    if (mine != null) {
      final action = mine.group(3);
      if (r.method == 'GET') return jsonResponse({'mandate': maps(myMandates['mandates']).first});
      switch (action) {
        case 'consent':
          return jsonResponse(authorised);
        case 'activation-request':
          return jsonResponse(activationFields);
        case 'activation-confirm':
          return jsonResponse(activated);
      }
      return jsonResponse(mandateAfterAction ?? {'mandate': maps(myMandates['mandates']).first});
    }

    final batchRoute = RegExp(r'^(GET|POST) debit-batches/([\w-]+)/(.*)$').firstMatch(key);
    if (batchRoute != null) {
      final tail = batchRoute.group(3)!;
      if (r.method == 'GET') {
        switch (tail) {
          case '':
            return jsonResponse(batch);
          case 'items/':
            return jsonResponse(items);
          case 'events/':
            return jsonResponse(events);
          case 'progress/':
            return jsonResponse(progress);
          case 'failed/':
            return jsonResponse(failed);
        }
      } else {
        return jsonResponse(batchAfterAction ?? batch);
      }
    }

    final check = RegExp(r'^POST transactions/([\w-]+)/check/$').firstMatch(key);
    if (check != null) return jsonResponse({'transaction': maps(transactions['transactions']).first});

    return jsonResponse({'code': 'not_found', 'message': 'No such call in the test server: $key'}, 404);
  }
}
