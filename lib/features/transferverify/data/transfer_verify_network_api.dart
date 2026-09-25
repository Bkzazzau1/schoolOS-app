import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/dispute_models.dart';
import '../domain/network_models.dart';

/// Live-only (no offline sync-pull) - cross-tenant discovery does not fit
/// the tenant-scoped sync model, the same reasoning as
/// TransferVerifyAssociationsApi. A candidate-only guardian-phone lookup,
/// meant to be called from within an admission's own identity-check step -
/// never a general, unrestricted cross-school student search.
class TransferVerifyNetworkApi {
  TransferVerifyNetworkApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Map<String, String> _who(SchoolMembership membership) => {'membership': membership.id};

  Future<List<TransferVerifyCandidateMatch>> matchByPhone(SchoolMembership membership, String phone) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/match/',
      body: {..._who(membership), 'phone': phone},
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['candidates'] as List? ?? const []))
        TransferVerifyCandidateMatch.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<TransferVerificationRequestRecord> sendRequest(
    SchoolMembership membership, {
    required String transferAlertId,
    String note = '',
  }) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/requests/',
      body: {..._who(membership), 'transferAlertId': transferAlertId, 'note': note},
    );
    return _requestFromEnvelope(data);
  }

  Future<List<TransferVerificationRequestRecord>> requestsSent(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/requests/sent/',
      query: _who(membership),
    );
    return _requestList(data);
  }

  Future<List<TransferVerificationRequestRecord>> requestsReceived(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/requests/received/',
      query: _who(membership),
    );
    return _requestList(data);
  }

  Future<TransferVerificationRequestRecord> respond(
    SchoolMembership membership, {
    required String requestId,
    required bool confirm,
    String note = '',
  }) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/requests/$requestId/respond/',
      body: {..._who(membership), 'decision': confirm ? 'confirmed' : 'rejected', 'note': note},
    );
    return _requestFromEnvelope(data);
  }

  Future<TransferVerificationRequestRecord> cancel(SchoolMembership membership, String requestId) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/requests/$requestId/cancel/',
      body: _who(membership),
    );
    return _requestFromEnvelope(data);
  }

  List<TransferVerificationRequestRecord> _requestList(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['requests'] as List? ?? const []))
        TransferVerificationRequestRecord.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  TransferVerificationRequestRecord _requestFromEnvelope(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return TransferVerificationRequestRecord.fromJson(Map<String, Object?>.from(map['request'] as Map));
  }

  // --- Disputes --------------------------------------------------------

  Future<TransferVerifyDispute> openDispute(
    SchoolMembership membership, {
    required String transferAlertId,
    required TransferDisputeReason reason,
    String explanation = '',
  }) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/disputes/',
      body: {..._who(membership), 'transferAlertId': transferAlertId, 'reason': reason.toJson(), 'explanation': explanation},
    );
    return _disputeFromEnvelope(data);
  }

  Future<List<TransferVerifyDispute>> disputesMine(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/disputes/mine/',
      query: _who(membership),
    );
    return _disputeList(data);
  }

  Future<List<TransferVerifyDispute>> disputesReceived(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/disputes/received/',
      query: _who(membership),
    );
    return _disputeList(data);
  }

  Future<TransferVerifyDispute> reviewDispute(
    SchoolMembership membership, {
    required String disputeId,
    required bool accept,
    String note = '',
  }) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/disputes/$disputeId/review/',
      body: {..._who(membership), 'decision': accept ? 'accepted' : 'rejected', 'note': note},
    );
    return _disputeFromEnvelope(data);
  }

  List<TransferVerifyDispute> _disputeList(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['disputes'] as List? ?? const []))
        TransferVerifyDispute.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  TransferVerifyDispute _disputeFromEnvelope(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return TransferVerifyDispute.fromJson(Map<String, Object?>.from(map['dispute'] as Map));
  }

  // --- Clearance ---------------------------------------------------------

  Future<TransferVerifyClearance> issueClearance(SchoolMembership membership, {required String externalId, String note = ''}) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/clearances/',
      body: {..._who(membership), 'externalId': externalId, 'note': note},
    );
    return _clearanceFromEnvelope(data);
  }

  Future<List<TransferVerifyClearance>> clearancesForSchool(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/clearances/list/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['clearances'] as List? ?? const []))
        TransferVerifyClearance.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<TransferVerifyClearance> revokeClearance(SchoolMembership membership, String clearanceId) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/network/clearances/$clearanceId/revoke/',
      body: _who(membership),
    );
    return _clearanceFromEnvelope(data);
  }

  TransferVerifyClearance _clearanceFromEnvelope(Object? data) {
    final map = Map<String, dynamic>.from(data as Map);
    return TransferVerifyClearance.fromJson(Map<String, Object?>.from(map['clearance'] as Map));
  }

  /// Public - no membership/auth required, mirrors the backend's own
  /// unauthenticated endpoint exactly. Never returns more than valid/message.
  Future<Map<String, Object?>> verifyClearance(String token) async {
    final data = await _api.get('transferverify/clearances/verify/', query: {'token': token}, authenticated: false);
    return Map<String, Object?>.from(data as Map);
  }

  // --- A guardian's own case status --------------------------------------

  Future<List<TransferVerifyCaseStatus>> myCaseStatus(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/network/my-case/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['cases'] as List? ?? const []))
        TransferVerifyCaseStatus.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }
}

class TransferVerifyNetworkScope extends InheritedWidget {
  const TransferVerifyNetworkScope({super.key, required this.api, required super.child});

  final TransferVerifyNetworkApi api;

  static TransferVerifyNetworkApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TransferVerifyNetworkScope>()?.api;

  @override
  bool updateShouldNotify(TransferVerifyNetworkScope oldWidget) => api != oldWidget.api;
}
