import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_models.dart' show CollectionPermissions;
import '../../bankconnect/domain/json_read.dart';
import '../domain/collection_models.dart';

/// A file the server made (a batch preview as a PDF or an Excel workbook).
class ExportedFile {
  const ExportedFile({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

/// Talks to the school's server about Smart Money Collection: the collection policy, provider switches and collection batches.
///
/// Online-only on purpose. Nothing here is kept on the phone: no family's account, no identity number, no credential. A batch is
/// prepared and approved on the server; the app only shows it and sends the person's choices.
class SmartCollectApi {
  SmartCollectApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership m) => 'schools/${m.schoolId}/collections/';
  Map<String, String> _who(SchoolMembership m) => {'membership': m.id};

  Future<Map<String, dynamic>> _get(SchoolMembership m, String tail, [Map<String, String>? query]) async =>
      readMap(await _api.get('${_base(m)}$tail', query: {..._who(m), ...?query}));

  Future<Map<String, dynamic>> _post(SchoolMembership m, String tail, [Map<String, Object?>? body]) async =>
      readMap(await _api.post('${_base(m)}$tail', query: _who(m), body: body ?? const {}));

  // -- overview -----------------------------------------------------------------------------------

  Future<CollectionDashboard> dashboard(SchoolMembership m) async => CollectionDashboard.fromJson(await _get(m, 'dashboard/'));

  Future<Periods> periods(SchoolMembership m) async => Periods.fromJson(await _get(m, 'periods/'));

  // -- policy -------------------------------------------------------------------------------------

  /// The school's default policy, and what this person may do with it.
  Future<PolicyInfo> policy(SchoolMembership m) async {
    final data = await _get(m, 'policy/');
    return PolicyInfo(
      policy: CollectionPolicy.fromJson(readMap(data['policy'])),
      permissions: CollectionPermissions.fromJson(readMap(data['permissions'])),
    );
  }

  /// Change the school's default. Only the fields sent change.
  Future<CollectionPolicy> updatePolicy(SchoolMembership m, Map<String, Object?> values) async {
    final data = readMap(await _api.patch('${_base(m)}policy/', query: _who(m), body: {'values': values}));
    return CollectionPolicy.fromJson(readMap(data['policy']));
  }

  /// The policy that applies to a session, term, batch or family, with where each field came from.
  Future<EffectivePolicy> effectivePolicy(SchoolMembership m, {String? sessionId, String? termId, String? familyId, String? batchId}) async {
    final data = await _get(m, 'policy/effective/', {
      if (sessionId != null) 'session': sessionId,
      if (termId != null) 'term': termId,
      if (familyId != null) 'family': familyId,
      if (batchId != null) 'batch': batchId,
    });
    return EffectivePolicy.fromJson(readMap(data['effective']));
  }

  Future<List<PolicyOverride>> overrides(SchoolMembership m, {String? scope, bool history = false}) async {
    final data = await _get(m, 'policy/overrides/', {if (scope != null) 'scope': scope, if (history) 'history': '1'});
    return [for (final o in readMaps(data['overrides'])) PolicyOverride.fromJson(o)];
  }

  /// Put an override on a session, term or family (a batch's own is set through [setBatchPolicy]). Only the fields sent are overridden.
  Future<PolicyOverride> setOverride(
    SchoolMembership m, {
    required String scope,
    String? sessionId,
    String? termId,
    String? familyId,
    required Map<String, Object?> values,
    String reason = '',
    String? expiryKind,
    String? expiresOn,
    String? expiryTermId,
  }) async {
    final data = await _post(m, 'policy/overrides/', {
      'scope': scope,
      if (sessionId != null) 'sessionId': sessionId,
      if (termId != null) 'termId': termId,
      if (familyId != null) 'familyId': familyId,
      'values': values,
      'reason': reason.trim(),
      if (expiryKind != null) 'expiryKind': expiryKind,
      if (expiresOn != null) 'expiresOn': expiresOn,
      if (expiryTermId != null) 'expiryTermId': expiryTermId,
    });
    return PolicyOverride.fromJson(readMap(data['override']));
  }

  Future<PolicyOverride> removeOverride(SchoolMembership m, String id, {String reason = ''}) async =>
      PolicyOverride.fromJson(readMap((await _post(m, 'policy/overrides/$id/remove/', {'reason': reason.trim()}))['override']));

  // -- provider switching ---------------------------------------------------------------------------

  Future<SwitchesInfo> switches(SchoolMembership m) async => SwitchesInfo.fromJson(await _get(m, 'switches/'));

  Future<ProviderSwitch> scheduleSwitch(SchoolMembership m, {required String toConnectionId, required DateTime scheduledFor, String note = ''}) async =>
      ProviderSwitch.fromJson(readMap((await _post(m, 'switches/', {
        'toConnectionId': toConnectionId,
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        if (note.trim().isNotEmpty) 'note': note.trim(),
      }))['switch']));

  Future<ProviderSwitch> switchDetail(SchoolMembership m, String id) async => ProviderSwitch.fromJson(readMap((await _get(m, 'switches/$id/'))['switch']));

  /// Make the target the school's ONE active provider. Only a switch that is READY, and only by a person's explicit act.
  Future<ProviderSwitch> applySwitch(SchoolMembership m, String id) async =>
      ProviderSwitch.fromJson(readMap((await _post(m, 'switches/$id/apply/'))['switch']));

  Future<ProviderSwitch> cancelSwitch(SchoolMembership m, String id, {String reason = ''}) async =>
      ProviderSwitch.fromJson(readMap((await _post(m, 'switches/$id/cancel/', {'reason': reason.trim()}))['switch']));

  // -- batches ------------------------------------------------------------------------------------

  Future<List<CollectionBatch>> batches(SchoolMembership m, {String? status, bool mine = false, bool awaiting = false, int limit = 30}) async {
    final data = await _get(m, 'batches/', {
      if (status != null) 'status': status,
      if (mine) 'mine': '1',
      if (awaiting) 'awaiting': '1',
      'limit': '$limit',
    });
    return [for (final b in readMaps(data['batches'])) CollectionBatch.fromJson(b)];
  }

  Future<CollectionBatch> createBatch(
    SchoolMembership m, {
    required String sessionId,
    String? termId,
    String title = '',
    Map<String, Object?>? policy,
    String reason = '',
  }) async {
    final data = await _post(m, 'batches/', {
      'sessionId': sessionId,
      if (termId != null) 'termId': termId,
      if (title.trim().isNotEmpty) 'title': title.trim(),
      if (policy != null && policy.isNotEmpty) 'policy': policy,
      if (reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return CollectionBatch.fromJson(readMap(data['batch']));
  }

  Future<CollectionBatch> batch(SchoolMembership m, String id) async => CollectionBatch.fromJson(readMap((await _get(m, 'batches/$id/'))['batch']));

  Future<BatchPage> items(
    SchoolMembership m,
    String batchId, {
    String? bucket,
    bool? selected,
    bool overriddenOnly = false,
    String? generation,
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async =>
      BatchPage.fromJson(await _get(m, 'batches/$batchId/items/', {
        if (bucket != null) 'bucket': bucket,
        if (selected != null) 'selected': selected ? '1' : '0',
        if (overriddenOnly) 'overridden': '1',
        if (generation != null) 'generation': generation,
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': '$limit',
        'offset': '$offset',
      }));

  Future<List<BatchEvent>> events(SchoolMembership m, String batchId) async =>
      [for (final e in readMaps((await _get(m, 'batches/$batchId/events/'))['events'])) BatchEvent.fromJson(e)];

  Future<CollectionBatch> _batchAction(SchoolMembership m, String batchId, String action, [Map<String, Object?>? body]) async =>
      CollectionBatch.fromJson(readMap((await _post(m, 'batches/$batchId/$action/', body))['batch']));

  /// Work every family out again from the ledger as it is now. The maker's own choices are kept.
  Future<CollectionBatch> refreshPreview(SchoolMembership m, String batchId, {int? expectedVersion}) =>
      _batchAction(m, batchId, 'preview', {if (expectedVersion != null) 'expectedVersion': expectedVersion});

  /// Select and deselect families. [expectedVersion] is the version the person was looking at: a stale screen is refused.
  Future<CollectionBatch> setSelection(
    SchoolMembership m,
    String batchId, {
    List<String> select = const [],
    List<String> deselect = const [],
    bool selectAllEligible = false,
    bool deselectAll = false,
    int? expectedVersion,
  }) =>
      _batchAction(m, batchId, 'selection', {
        if (select.isNotEmpty) 'select': select,
        if (deselect.isNotEmpty) 'deselect': deselect,
        if (selectAllEligible) 'selectAllEligible': true,
        if (deselectAll) 'deselectAll': true,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      });

  Future<CollectionBatch> rename(SchoolMembership m, String batchId, String title) => _batchAction(m, batchId, 'title', {'title': title.trim()});

  /// A policy for just this batch (for example dynamic accounts this term).
  Future<CollectionBatch> setBatchPolicy(SchoolMembership m, String batchId, {required Map<String, Object?> values, String reason = '', int? expectedVersion}) =>
      _batchAction(m, batchId, 'policy', {'values': values, 'reason': reason.trim(), if (expectedVersion != null) 'expectedVersion': expectedVersion});

  Future<CollectionBatch> overrideEligibility(SchoolMembership m, String batchId, String itemId, {required String reason, int? expectedVersion}) =>
      _itemAction(m, batchId, itemId, 'override', {'reason': reason.trim(), if (expectedVersion != null) 'expectedVersion': expectedVersion});

  Future<CollectionBatch> clearOverride(SchoolMembership m, String batchId, String itemId, {int? expectedVersion}) =>
      _itemAction(m, batchId, itemId, 'override-clear', {if (expectedVersion != null) 'expectedVersion': expectedVersion});

  /// Choose which earlier balances go into a family's collection target (where the arrears policy lets a person choose).
  Future<CollectionBatch> chooseArrears(SchoolMembership m, String batchId, String itemId, {required List<String> receivableIds, int? expectedVersion}) =>
      _itemAction(m, batchId, itemId, 'arrears', {'receivableIds': receivableIds, if (expectedVersion != null) 'expectedVersion': expectedVersion});

  Future<CollectionBatch> _itemAction(SchoolMembership m, String batchId, String itemId, String action, Map<String, Object?> body) async =>
      CollectionBatch.fromJson(readMap((await _post(m, 'batches/$batchId/items/$itemId/$action/', body))['batch']));

  /// Send the batch to be approved. [expectedHash] is the fingerprint the maker was looking at.
  Future<CollectionBatch> submit(SchoolMembership m, String batchId, {required String expectedHash, int? expectedVersion}) =>
      _batchAction(m, batchId, 'submit', {'expectedHash': expectedHash, if (expectedVersion != null) 'expectedVersion': expectedVersion});

  /// Approve exactly what was submitted. [manualApprovals] are the families the school's policy asks the approver to approve one by one.
  Future<CollectionBatch> approve(SchoolMembership m, String batchId, {required String expectedHash, List<String> manualApprovals = const []}) =>
      _batchAction(m, batchId, 'approve', {'expectedHash': expectedHash, if (manualApprovals.isNotEmpty) 'manualApprovals': manualApprovals});

  Future<CollectionBatch> reject(SchoolMembership m, String batchId, {required String reason}) =>
      _batchAction(m, batchId, 'reject', {'reason': reason.trim()});

  Future<CollectionBatch> cancel(SchoolMembership m, String batchId, {String reason = ''}) =>
      _batchAction(m, batchId, 'cancel', {'reason': reason.trim()});

  /// Generate the accounts of an APPROVED batch. The provider calls are queued on the server and made there.
  Future<CollectionBatch> start(SchoolMembership m, String batchId) => _batchAction(m, batchId, 'start');

  /// Try the failed families again (all of them, or only [itemIds]). [RetryResult.approvalNeeded] means the batch changed since it was
  /// approved, so it went back to its maker for a fresh approval and nothing was retried.
  Future<RetryResult> retry(SchoolMembership m, String batchId, {List<String>? itemIds}) async {
    final data = await _post(m, 'batches/$batchId/retry/', {if (itemIds != null) 'itemIds': itemIds});
    return RetryResult(
      batch: CollectionBatch.fromJson(readMap(data['batch'])),
      retried: data['retried'] as int? ?? 0,
      approvalNeeded: data['approvalNeeded'] == true,
    );
  }

  Future<BatchProgress> progress(SchoolMembership m, String batchId) async =>
      BatchProgress.fromJson(readMap((await _get(m, 'batches/$batchId/progress/'))['progress']));

  Future<List<BatchItem>> failed(SchoolMembership m, String batchId) async =>
      [for (final i in readMaps((await _get(m, 'batches/$batchId/failed/'))['items'])) BatchItem.fromJson(i)];

  /// The batch preview as a PDF (`pdf`) or an Excel workbook (`xlsx`). Reads what is stored on the server: no provider is called.
  Future<ExportedFile> export(SchoolMembership m, String batchId, {required String type, bool selectedOnly = false}) async {
    final bytes = await _api.getBytes(
      '${_base(m)}batches/$batchId/export/',
      query: {..._who(m), 'type': type, if (selectedOnly) 'selected': '1'},
    );
    return ExportedFile(bytes: bytes, fileName: 'collection-batch-${batchId.length > 8 ? batchId.substring(0, 8) : batchId}.$type');
  }

  // -- families --------------------------------------------------------------------------------------

  /// Whether a BVN / NIN is on file for the family's payer. The number itself is never sent to the app.
  Future<PayerIdentityStatus> payerIdentity(SchoolMembership m, String familyId) async =>
      PayerIdentityStatus.fromJson(readMap((await _get(m, 'families/$familyId/payer-identity/'))['identity']));

  /// Record the payer's identity number. Write-only: it goes to the server over HTTPS and is not kept here.
  Future<PayerIdentityStatus> savePayerIdentity(SchoolMembership m, String familyId, {String? bvn, String? nin}) async {
    final data = readMap(await _api.put(
      '${_base(m)}families/$familyId/payer-identity/',
      query: _who(m),
      body: {if (bvn != null && bvn.trim().isNotEmpty) 'bvn': bvn.trim(), if (nin != null && nin.trim().isNotEmpty) 'nin': nin.trim()},
    ));
    return PayerIdentityStatus.fromJson(readMap(data['identity']));
  }

  /// Every account a family has had, live and closed, with which batch made each.
  Future<List<FamilyAccountRecord>> familyAccounts(SchoolMembership m, String familyId) async {
    final data = readMap(await _api.get('schools/${m.schoolId}/receivables/families/$familyId/collection-accounts/', query: _who(m)));
    return [for (final a in readMaps(data['accounts'])) FamilyAccountRecord.fromJson(a)];
  }

  /// Retire a family's account: the provider is asked to close it, and it stays on record. Needs a reason.
  Future<void> closeAccount(SchoolMembership m, String accountId, {required String reason}) async {
    await _api.post('schools/${m.schoolId}/receivables/collection-accounts/$accountId/close/', query: _who(m), body: {'reason': reason.trim()});
  }
}

class RetryResult {
  const RetryResult({required this.batch, required this.retried, required this.approvalNeeded});

  final CollectionBatch batch;
  final int retried;
  final bool approvalNeeded;
}

/// Makes the Smart Money Collection API available to the screens below it. Absent when the app has no school server.
class SmartCollectScope extends InheritedWidget {
  const SmartCollectScope({super.key, required this.api, required super.child});

  final SmartCollectApi api;

  static SmartCollectApi? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<SmartCollectScope>()?.api;

  @override
  bool updateShouldNotify(SmartCollectScope oldWidget) => api != oldWidget.api;
}
