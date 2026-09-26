import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/bank_models.dart';
import '../domain/collections_summary.dart';
import '../domain/json_read.dart';
import '../domain/payment_models.dart';

/// Talks to the school's server about its own bank accounts and the payments they receive.
///
/// This is online-only on purpose. Nothing here is written to the phone: no credential, no account
/// number, no payment. A bank credential passes through [connect], [rotate] and [reconnect] to the
/// server over HTTPS and is not kept, logged or returned - the server never sends one back.
class BankConnectApi {
  BankConnectApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/collections/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  Future<ProvidersInfo> providers(SchoolMembership m) async =>
      ProvidersInfo.fromJson(readMap(await _api.get('${_base(m)}providers/', query: _who(m))));

  Future<ConnectionsInfo> connections(SchoolMembership m) async =>
      ConnectionsInfo.fromJson(readMap(await _api.get('${_base(m)}connections/', query: _who(m))));

  /// Where to send the person to approve access on the bank's own page. No password is ever asked for.
  Future<AuthorizationStart> beginAuthorization(
    SchoolMembership m, {
    required String provider,
    required String redirectUri,
  }) async =>
      AuthorizationStart.fromJson(
        readMap(
          await _api.post(
            '${_base(m)}connections/authorize/',
            query: _who(m),
            body: {'provider': provider, 'redirectUri': redirectUri},
          ),
        ),
      );

  /// Ask the provider to verify the account. It stays "waiting for confirmation" until [confirm].
  Future<BankConnection> connect(
    SchoolMembership m, {
    required String provider,
    required String purpose,
    String label = '',
    Map<String, String>? credentials,
    String? authorizationCode,
    String? state,
  }) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}connections/',
        query: _who(m),
        body: {
          'provider': provider,
          'purpose': purpose,
          'label': label.trim(),
          if (credentials != null) 'credentials': credentials,
          if (authorizationCode != null) 'authorizationCode': authorizationCode.trim(),
          if (state != null) 'state': state,
        },
      ),
    );
    return BankConnection.fromJson(readMap(data['connection']));
  }

  Future<ConnectionActionResult> _act(SchoolMembership m, String id, String action, [Map<String, Object?>? body]) async =>
      ConnectionActionResult.fromJson(
        readMap(await _api.post('${_base(m)}connections/$id/$action/', query: _who(m), body: body ?? const {})),
      );

  /// The person has seen the bank's own name for the account and says it is theirs.
  Future<ConnectionActionResult> confirm(SchoolMembership m, String id) => _act(m, id, 'confirm');
  Future<ConnectionActionResult> test(SchoolMembership m, String id) => _act(m, id, 'test');
  Future<ConnectionActionResult> sync(SchoolMembership m, String id) => _act(m, id, 'sync');
  Future<ConnectionActionResult> disable(SchoolMembership m, String id) => _act(m, id, 'disable');
  Future<ConnectionActionResult> enable(SchoolMembership m, String id) => _act(m, id, 'enable');
  Future<ConnectionActionResult> disconnect(SchoolMembership m, String id) => _act(m, id, 'disconnect');

  /// A new address for the provider to call. The old one stops working; the new one is shown once.
  Future<ConnectionActionResult> newWebhookAddress(SchoolMembership m, String id) => _act(m, id, 'webhook-token');

  Future<ConnectionActionResult> rename(SchoolMembership m, String id, {String? purpose, String? label}) =>
      _act(m, id, 'rename', {if (purpose != null) 'purpose': purpose, if (label != null) 'label': label});

  /// A new credential for the same account. A credential for a different account is refused.
  Future<ConnectionActionResult> rotate(
    SchoolMembership m,
    String id, {
    Map<String, String>? credentials,
    String? authorizationCode,
    String? state,
  }) =>
      _act(m, id, 'rotate', _renewal(credentials, authorizationCode, state));

  /// Restore an account that stopped working, with a fresh credential for the same account.
  Future<ConnectionActionResult> reconnect(
    SchoolMembership m,
    String id, {
    Map<String, String>? credentials,
    String? authorizationCode,
    String? state,
  }) =>
      _act(m, id, 'reconnect', _renewal(credentials, authorizationCode, state));

  Map<String, Object?> _renewal(Map<String, String>? credentials, String? code, String? state) => {
        if (credentials != null) 'credentials': credentials,
        if (code != null) 'authorizationCode': code.trim(),
        if (state != null) 'state': state,
      };

  Future<List<ConnectionAuditEvent>> audit(SchoolMembership m, String id) async {
    final data = readMap(await _api.get('${_base(m)}connections/$id/audit/', query: _who(m)));
    return [for (final e in readMaps(data['events'])) ConnectionAuditEvent.fromJson(e)];
  }

  Future<PaymentPage> payments(
    SchoolMembership m, {
    String? connectionId,
    String? status,
    String? direction,
    String? query,
    int limit = 30,
    int offset = 0,
  }) async =>
      PaymentPage.fromJson(
        readMap(
          await _api.get(
            '${_base(m)}transactions/',
            query: {
              ..._who(m),
              if (connectionId != null) 'connection': connectionId,
              if (status != null) 'status': status,
              if (direction != null) 'direction': direction,
              if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
              'limit': '$limit',
              'offset': '$offset',
            },
          ),
        ),
      );

  /// Money received that a person still has something to do with, oldest first.
  Future<PaymentPage> reviewQueue(SchoolMembership m, {String? status, int limit = 30, int offset = 0}) async =>
      PaymentPage.fromJson(
        readMap(
          await _api.get(
            '${_base(m)}review/',
            query: {..._who(m), if (status != null) 'status': status, 'limit': '$limit', 'offset': '$offset'},
          ),
        ),
      );

  /// One payment with every decision ever made about it.
  Future<BankPayment> payment(SchoolMembership m, String id) async =>
      BankPayment.fromJson(readMap(readMap(await _api.get('${_base(m)}transactions/$id/', query: _who(m)))['transaction']));

  /// Decide what a payment is. [expectedStatus] is what the person was looking at, so a decision made on
  /// a stale screen is refused instead of silently overwriting a colleague's.
  Future<BankPayment> decide(
    SchoolMembership m,
    String id, {
    required String action,
    String? expectedStatus,
    String? studentId,
    String? purpose,
    List<({String studentId, int amountMinor, String? purpose})>? split,
    String note = '',
    String? duplicateOf,
  }) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}transactions/$id/decide/',
        query: _who(m),
        body: {
          'action': action,
          if (expectedStatus != null) 'expectedStatus': expectedStatus,
          if (studentId != null) 'studentId': studentId,
          if (purpose != null) 'purpose': purpose,
          if (split != null)
            'allocations': [
              for (final part in split)
                {
                  'studentId': part.studentId,
                  'amountMinor': part.amountMinor,
                  if (part.purpose != null) 'purpose': part.purpose,
                },
            ],
          if (note.trim().isNotEmpty) 'note': note.trim(),
          if (duplicateOf != null) 'duplicateOf': duplicateOf,
        },
      ),
    );
    return BankPayment.fromJson(readMap(data['transaction']));
  }

  Future<List<StudentHit>> searchStudents(SchoolMembership m, String text) async {
    final data = readMap(await _api.get('${_base(m)}students/', query: {..._who(m), 'q': text.trim()}));
    return [for (final s in readMaps(data['students'])) StudentHit.fromJson(s)];
  }

  Future<CollectionsSummary> summary(SchoolMembership m, {String period = 'term', bool includeSandbox = false}) async =>
      CollectionsSummary.fromJson(
        readMap(
          readMap(
            await _api.get(
              '${_base(m)}summary/',
              query: {..._who(m), 'period': period, if (includeSandbox) 'includeSandbox': 'true'},
            ),
          )['summary'],
        ),
      );
}

/// Makes the bank API available to the screens below it. Absent when the app has no school server:
/// the screens then say a server is needed, instead of showing accounts that do not exist.
class BankConnectScope extends InheritedWidget {
  const BankConnectScope({super.key, required this.api, required super.child});

  final BankConnectApi api;

  static BankConnectApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BankConnectScope>()?.api;

  @override
  bool updateShouldNotify(BankConnectScope oldWidget) => api != oldWidget.api;
}
