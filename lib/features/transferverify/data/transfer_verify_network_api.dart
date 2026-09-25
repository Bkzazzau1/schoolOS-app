import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
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
}

class TransferVerifyNetworkScope extends InheritedWidget {
  const TransferVerifyNetworkScope({super.key, required this.api, required super.child});

  final TransferVerifyNetworkApi api;

  static TransferVerifyNetworkApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TransferVerifyNetworkScope>()?.api;

  @override
  bool updateShouldNotify(TransferVerifyNetworkScope oldWidget) => api != oldWidget.api;
}
