import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/bank_models.dart';
import '../domain/collections_summary.dart';
import '../domain/json_read.dart';
import '../domain/payment_models.dart';

/// Talks to the school's server about its own collection providers (Paystack, Monnify, Remita) and the payments they report.
///
/// This is online-only on purpose. Nothing here is written to the phone: no credential, no payment. A provider credential
/// passes through [connect] and [replaceCredentials] to the server over HTTPS and is not kept, logged or returned - the server
/// never sends one back.
class BankConnectApi {
  BankConnectApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/collections/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  Future<ProvidersInfo> providers(SchoolMembership m) async =>
      ProvidersInfo.fromJson(readMap(await _api.get('${_base(m)}providers/', query: _who(m))));

  Future<ConnectionsInfo> connections(SchoolMembership m) async =>
      ConnectionsInfo.fromJson(readMap(await _api.get('${_base(m)}connections/', query: _who(m))));

  /// Connect the school's own account at a provider with the credentials that provider issued to the school. The server checks them
  /// with the provider. The connection is not yet the active provider.
  Future<ProviderConnection> connect(
    SchoolMembership m, {
    required String provider,
    required String environment,
    String label = '',
    required Map<String, String> credentials,
    Map<String, String> settings = const {},
  }) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}connections/',
        query: _who(m),
        body: {
          'provider': provider,
          'environment': environment,
          'label': label.trim(),
          'credentials': credentials,
          if (settings.isNotEmpty) 'settings': settings,
        },
      ),
    );
    return ProviderConnection.fromJson(readMap(data['connection']));
  }

  Future<ConnectionActionResult> _act(SchoolMembership m, String id, String action, [Map<String, Object?>? body]) async =>
      ConnectionActionResult.fromJson(
        readMap(await _api.post('${_base(m)}connections/$id/$action/', query: _who(m), body: body ?? const {})),
      );

  Future<ConnectionActionResult> test(SchoolMembership m, String id) => _act(m, id, 'test');
  Future<ConnectionActionResult> disable(SchoolMembership m, String id) => _act(m, id, 'disable');
  Future<ConnectionActionResult> enable(SchoolMembership m, String id) => _act(m, id, 'enable');
  Future<ConnectionActionResult> disconnect(SchoolMembership m, String id) => _act(m, id, 'disconnect');

  /// Choose the school's FIRST active collection provider. Once one is active, a change is a provider switch.
  Future<ConnectionActionResult> activate(SchoolMembership m, String id) => _act(m, id, 'activate');

  Future<ConnectionActionResult> rename(SchoolMembership m, String id, {required String label}) => _act(m, id, 'rename', {'label': label});

  /// New credentials for the same provider connection. Credentials for a different merchant account are refused.
  Future<ConnectionActionResult> replaceCredentials(
    SchoolMembership m,
    String id, {
    required Map<String, String> credentials,
    Map<String, String>? settings,
  }) =>
      _act(m, id, 'replace-credentials', {'credentials': credentials, if (settings != null) 'settings': settings});

  /// Where to give the provider SchoolOS's address for payment notifications, and whether it is known to work.
  Future<WebhookSetup> webhookSetup(SchoolMembership m, String id) async =>
      WebhookSetup.fromJson(readMap(readMap(await _api.get('${_base(m)}connections/$id/webhook/', query: _who(m)))['webhook']));

  /// A new address for the provider to call. The old one stops working and the webhook waits for its first event again.
  Future<WebhookSetup?> newWebhookAddress(SchoolMembership m, String id) async => (await _act(m, id, 'webhook-token')).webhook;

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
