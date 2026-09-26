import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/json_read.dart';
import '../../smartcollect/domain/collection_models.dart' show Periods;
import '../domain/mandate_models.dart';

/// Talks to the school's server about Mandates & Direct Debit: the school's own Remita and Lendsqr connections, payers' mandates,
/// and direct-debit batches that one person prepares and another approves.
///
/// This is online-only on purpose. Nothing here is written to the phone: no credential, no bank account number, no debit. A
/// provider credential or a payer's account number passes through [connect] and [startMandate] to the server over HTTPS and is not kept,
/// logged or returned - the server never sends one back. A debit is never queued offline as though it had happened: what the
/// server has not confirmed has not happened.
class MandatesApi {
  MandatesApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/mandates/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  // -- providers -----------------------------------------------------------------------------------

  Future<MandateProvidersInfo> providers(SchoolMembership m) async =>
      MandateProvidersInfo.fromJson(readMap(await _api.get('${_base(m)}providers/', query: _who(m))));

  Future<MandateConnectionsInfo> connections(SchoolMembership m) async =>
      MandateConnectionsInfo.fromJson(readMap(await _api.get('${_base(m)}connections/', query: _who(m))));

  /// Connect the school's own account at a provider with the credentials that provider issued to the school. Connecting one
  /// provider never touches another: there is no active provider.
  Future<MandateConnection> connect(
    SchoolMembership m, {
    required String provider,
    required String environment,
    String label = '',
    required Map<String, String> credentials,
  }) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}connections/',
        query: _who(m),
        body: {'provider': provider, 'environment': environment, 'label': label.trim(), 'credentials': credentials},
      ),
    );
    return MandateConnection.fromJson(readMap(data['connection']));
  }

  Future<MandateActionResult> _act(SchoolMembership m, String id, String action, [Map<String, Object?>? body]) async =>
      MandateActionResult.fromJson(readMap(await _api.post('${_base(m)}connections/$id/$action/', query: _who(m), body: body ?? const {})));

  Future<MandateActionResult> test(SchoolMembership m, String id) => _act(m, id, 'test');
  Future<MandateActionResult> disable(SchoolMembership m, String id) => _act(m, id, 'disable');
  Future<MandateActionResult> enable(SchoolMembership m, String id) => _act(m, id, 'enable');
  Future<MandateActionResult> disconnect(SchoolMembership m, String id) => _act(m, id, 'disconnect');
  Future<MandateActionResult> rename(SchoolMembership m, String id, {required String label}) => _act(m, id, 'rename', {'label': label});

  /// New credentials for the same connection. Credentials for a different merchant account are refused.
  Future<MandateActionResult> replaceCredentials(SchoolMembership m, String id, {required Map<String, String> credentials}) =>
      _act(m, id, 'replace-credentials', {'credentials': credentials});

  Future<MandateWebhook> webhook(SchoolMembership m, String id) async =>
      MandateWebhook.fromJson(readMap(readMap(await _api.get('${_base(m)}connections/$id/webhook/', query: _who(m)))['webhook']));

  /// A new address for the provider to call. The old one stops working.
  Future<MandateWebhook> newWebhookAddress(SchoolMembership m, String id) async {
    final data = readMap(await _api.post('${_base(m)}connections/$id/webhook-token/', query: _who(m), body: const {}));
    return MandateWebhook.fromJson(readMap(data['webhook']));
  }

  /// The banks the provider can make a mandate on.
  Future<List<BankOption>> banks(SchoolMembership m, String connectionId) async {
    final data = readMap(await _api.get('${_base(m)}connections/$connectionId/banks/', query: _who(m)));
    return [for (final b in readMaps(data['banks'])) BankOption.fromJson(b)];
  }

  // -- overview, families ---------------------------------------------------------------------------

  Future<MandatesOverview> overview(SchoolMembership m) async =>
      MandatesOverview.fromJson(readMap(await _api.get('${_base(m)}overview/', query: _who(m))));

  /// The school's sessions and terms, for choosing what a batch is for.
  Future<Periods> periods(SchoolMembership m) async => Periods.fromJson(readMap(await _api.get('${_base(m)}periods/', query: _who(m))));

  Future<List<FamilyPayer>> familyPayers(SchoolMembership m, String familyId) async {
    final data = readMap(await _api.get('${_base(m)}families/$familyId/payers/', query: _who(m)));
    return [for (final p in readMaps(data['payers'])) FamilyPayer.fromJson(p)];
  }

  // -- mandates --------------------------------------------------------------------------------------

  Future<MandatesPage> mandates(SchoolMembership m, {String? status, String? provider, String? familyId, bool? debitReady, String? search}) async =>
      MandatesPage.fromJson(
        readMap(
          await _api.get(
            '${_base(m)}mandates/',
            query: {
              ..._who(m),
              if (status != null) 'status': status,
              if (provider != null) 'provider': provider,
              if (familyId != null) 'family': familyId,
              if (debitReady != null) 'debitReady': debitReady ? '1' : '0',
              if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
            },
          ),
        ),
      );

  Future<Mandate> mandate(SchoolMembership m, String id) async =>
      Mandate.fromJson(readMap(readMap(await _api.get('${_base(m)}mandates/$id/', query: _who(m)))['mandate']));

  /// Start a mandate for a payer. Staff can never authorise it for them: the payer does that themselves. The account number goes to
  /// the server once and is never returned.
  Future<Mandate> startMandate(SchoolMembership m, StartMandateRequest request) async {
    final data = readMap(
      await _api.post(
        '${_base(m)}mandates/',
        query: _who(m),
        body: {
          'familyId': request.familyId,
          'payerId': request.payerId,
          'connectionId': request.connectionId,
          'bankCode': request.bankCode,
          'accountNumber': request.accountNumber,
          'maximumAmountMinor': request.maximumAmountMinor,
          'consentRoute': request.consentRoute,
          if (request.maxDebits != null) 'maxDebits': request.maxDebits,
          if (request.providerCustomerRef.isNotEmpty) 'providerCustomerRef': request.providerCustomerRef,
        },
      ),
    );
    return Mandate.fromJson(readMap(data['mandate']));
  }

  Future<Mandate> _mandateAction(SchoolMembership m, String id, String action, [Map<String, Object?>? body]) async =>
      Mandate.fromJson(readMap(readMap(await _api.post('${_base(m)}mandates/$id/$action/', query: _who(m), body: body ?? const {}))['mandate']));

  Future<Mandate> refreshMandate(SchoolMembership m, String id) => _mandateAction(m, id, 'refresh');
  Future<Mandate> retrySetup(SchoolMembership m, String id) => _mandateAction(m, id, 'retry-setup');
  Future<Mandate> resendActivation(SchoolMembership m, String id) => _mandateAction(m, id, 'resend-activation');
  Future<Mandate> cancelMandate(SchoolMembership m, String id, {String reason = ''}) => _mandateAction(m, id, 'cancel', {'reason': reason});
  Future<Mandate> suspendMandate(SchoolMembership m, String id) => _mandateAction(m, id, 'suspend');
  Future<Mandate> reactivateMandate(SchoolMembership m, String id) => _mandateAction(m, id, 'reactivate');
  Future<Mandate> makePrimary(SchoolMembership m, String id) => _mandateAction(m, id, 'primary');

  // -- the payer's own -------------------------------------------------------------------------------

  Future<List<Mandate>> myMandates(SchoolMembership m) async {
    final data = readMap(await _api.get('${_base(m)}my-mandates/', query: _who(m)));
    return [for (final x in readMaps(data['mandates'])) Mandate.fromJson(x)];
  }

  Future<Mandate> myMandate(SchoolMembership m, String id) async =>
      Mandate.fromJson(readMap(readMap(await _api.get('${_base(m)}my-mandates/$id/', query: _who(m)))['mandate']));

  Future<Mandate> _payerAction(SchoolMembership m, String id, String action, Map<String, Object?> body) async =>
      Mandate.fromJson(readMap(readMap(await _api.post('${_base(m)}my-mandates/$id/$action/', query: _who(m), body: body))['mandate']));

  /// The payer authorises the mandate, themselves. [consentTextHash] is the hash of the exact words their screen showed: if the
  /// mandate changed since, the server refuses and they must read it again.
  Future<Mandate> authorise(SchoolMembership m, String id, {required String consentTextHash}) =>
      _payerAction(m, id, 'consent', {'accepted': true, 'consentTextHash': consentTextHash});

  /// Ask the bank for a one-time password. Returns what the payer is asked to type.
  Future<List<ActivationField>> requestActivation(SchoolMembership m, String id) async {
    final data = readMap(await _api.post('${_base(m)}my-mandates/$id/activation-request/', query: _who(m), body: const {}));
    return [for (final f in readMaps(data['fields'])) ActivationField.fromJson(f)];
  }

  /// What the payer typed goes to the provider once and is kept nowhere.
  Future<Mandate> confirmActivation(SchoolMembership m, String id, {required Map<String, String> answers}) =>
      _payerAction(m, id, 'activation-confirm', {'answers': answers});

  Future<Mandate> refreshMyMandate(SchoolMembership m, String id) => _payerAction(m, id, 'refresh', const {});
  Future<Mandate> cancelMyMandate(SchoolMembership m, String id, {String reason = ''}) => _payerAction(m, id, 'cancel', {'reason': reason});

  // -- debit batches ---------------------------------------------------------------------------------

  Future<List<DebitBatch>> batches(SchoolMembership m, {String? status}) async {
    final data = readMap(await _api.get('${_base(m)}debit-batches/', query: {..._who(m), if (status != null) 'status': status}));
    return [for (final b in readMaps(data['batches'])) DebitBatch.fromJson(b)];
  }

  Future<DebitBatchDetail> createBatch(SchoolMembership m, {required String sessionId, String? termId, String title = ''}) async =>
      DebitBatchDetail.fromJson(
        readMap(
          await _api.post(
            '${_base(m)}debit-batches/',
            query: _who(m),
            body: {'sessionId': sessionId, if (termId != null) 'termId': termId, 'title': title.trim()},
          ),
        ),
      );

  Future<DebitBatchDetail> batch(SchoolMembership m, String id) async =>
      DebitBatchDetail.fromJson(readMap(await _api.get('${_base(m)}debit-batches/$id/', query: _who(m))));

  Future<DebitItemsPage> items(SchoolMembership m, String id, {String? eligibility, String? status}) async => DebitItemsPage.fromJson(
        readMap(
          await _api.get(
            '${_base(m)}debit-batches/$id/items/',
            query: {..._who(m), if (eligibility != null) 'eligibility': eligibility, if (status != null) 'status': status},
          ),
        ),
      );

  Future<List<BatchEvent>> events(SchoolMembership m, String id) async {
    final data = readMap(await _api.get('${_base(m)}debit-batches/$id/events/', query: _who(m)));
    return [for (final e in readMaps(data['events'])) BatchEvent.fromJson(e)];
  }

  Future<DebitProgress> progress(SchoolMembership m, String id) async =>
      DebitProgress.fromJson(readMap(readMap(await _api.get('${_base(m)}debit-batches/$id/progress/', query: _who(m)))['progress']));

  Future<List<DebitItem>> failed(SchoolMembership m, String id) async {
    final data = readMap(await _api.get('${_base(m)}debit-batches/$id/failed/', query: _who(m)));
    return [for (final i in readMaps(data['items'])) DebitItem.fromJson(i)];
  }

  Future<DebitBatchDetail> _batchAction(SchoolMembership m, String id, String action, [Map<String, Object?>? body]) async =>
      DebitBatchDetail.fromJson(readMap(await _api.post('${_base(m)}debit-batches/$id/$action/', query: _who(m), body: body ?? const {})));

  Future<DebitBatchDetail> refreshPreview(SchoolMembership m, String id, {required int version}) => _batchAction(m, id, 'preview', {'version': version});

  Future<DebitBatchDetail> select(
    SchoolMembership m,
    String id, {
    required int version,
    List<String> select = const [],
    List<String> deselect = const [],
    bool selectAllEligible = false,
    bool deselectAll = false,
  }) =>
      _batchAction(m, id, 'selection', {
        'version': version,
        if (select.isNotEmpty) 'select': select,
        if (deselect.isNotEmpty) 'deselect': deselect,
        if (selectAllEligible) 'selectAllEligible': true,
        if (deselectAll) 'deselectAll': true,
      });

  /// Lower one family's debit. A figure the ledger does not allow is refused.
  Future<DebitBatchDetail> lowerAmount(SchoolMembership m, String id, String itemId, {required int amountMinor, required int version, String reason = ''}) async =>
      DebitBatchDetail.fromJson(
        readMap(
          await _api.post(
            '${_base(m)}debit-batches/$id/items/$itemId/amount/',
            query: _who(m),
            body: {'amountMinor': amountMinor, 'version': version, 'reason': reason},
          ),
        ),
      );

  Future<DebitBatchDetail> submit(SchoolMembership m, String id, {required String snapshotHash, required int version}) =>
      _batchAction(m, id, 'submit', {'snapshotHash': snapshotHash, 'version': version});

  /// Approve exactly the snapshot the checker saw. A batch that changed since is refused, and its approval withdrawn.
  Future<DebitBatchDetail> approve(SchoolMembership m, String id, {required String snapshotHash}) =>
      _batchAction(m, id, 'approve', {'snapshotHash': snapshotHash});

  Future<DebitBatchDetail> reject(SchoolMembership m, String id, {required String reason}) => _batchAction(m, id, 'reject', {'reason': reason});
  Future<DebitBatchDetail> cancelBatch(SchoolMembership m, String id, {String reason = ''}) => _batchAction(m, id, 'cancel', {'reason': reason});
  Future<DebitBatchDetail> startDebiting(SchoolMembership m, String id) => _batchAction(m, id, 'start');

  /// Try failed debits again under the same approval. Only those whose approved facts are unchanged are retried.
  Future<DebitBatchDetail> retry(SchoolMembership m, String id, {List<String>? itemIds}) => _batchAction(m, id, 'retry', {if (itemIds != null) 'itemIds': itemIds});

  // -- debits ----------------------------------------------------------------------------------------

  Future<List<MandateTransactionRow>> transactions(SchoolMembership m, {String? status, String? provider}) async {
    final data = readMap(await _api.get('${_base(m)}transactions/', query: {..._who(m), if (status != null) 'status': status, if (provider != null) 'provider': provider}));
    return [for (final t in readMaps(data['transactions'])) MandateTransactionRow.fromJson(t)];
  }

  /// Ask the provider again what happened to one debit.
  Future<MandateTransactionRow> checkTransaction(SchoolMembership m, String id) async =>
      MandateTransactionRow.fromJson(readMap(readMap(await _api.post('${_base(m)}transactions/$id/check/', query: _who(m), body: const {}))['transaction']));
}

/// Makes the Mandates & Direct Debit API available to the screens below it. Absent when the app has no school server.
class MandatesScope extends InheritedWidget {
  const MandatesScope({super.key, required this.api, required super.child});

  final MandatesApi api;

  static MandatesApi? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<MandatesScope>()?.api;

  @override
  bool updateShouldNotify(MandatesScope oldWidget) => api != oldWidget.api;
}
