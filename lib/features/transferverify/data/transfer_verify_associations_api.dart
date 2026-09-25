import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/association_models.dart';

/// Live-only (no offline sync-pull) - cross-tenant association membership
/// does not fit the tenant-scoped sync model, the same reasoning
/// apps.billing already established for organization subscriptions. Mirrors
/// AlumniServerApi's shape.
class TransferVerifyAssociationsApi {
  TransferVerifyAssociationsApi({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Map<String, String> _who(SchoolMembership membership) => {'membership': membership.id};

  Future<List<TransferVerifyAssociation>> catalog() async {
    final data = await _api.get('transferverify/associations/');
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['associations'] as List? ?? const []))
        TransferVerifyAssociation.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<List<SchoolAssociationMembershipRecord>> myMemberships(SchoolMembership membership) async {
    final data = await _api.get(
      'schools/${membership.schoolId}/transferverify/associations/',
      query: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return [
      for (final item in (map['memberships'] as List? ?? const []))
        SchoolAssociationMembershipRecord.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<SchoolAssociationMembershipRecord> join(SchoolMembership membership, String associationId) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/associations/$associationId/join/',
      body: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return SchoolAssociationMembershipRecord.fromJson(Map<String, Object?>.from(map['membership'] as Map));
  }

  Future<SchoolAssociationMembershipRecord> exit(SchoolMembership membership, String membershipRowId) async {
    final data = await _api.post(
      'schools/${membership.schoolId}/transferverify/associations/memberships/$membershipRowId/exit/',
      body: _who(membership),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return SchoolAssociationMembershipRecord.fromJson(Map<String, Object?>.from(map['membership'] as Map));
  }
}

class TransferVerifyAssociationsScope extends InheritedWidget {
  const TransferVerifyAssociationsScope({super.key, required this.api, required super.child});

  final TransferVerifyAssociationsApi api;

  static TransferVerifyAssociationsApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TransferVerifyAssociationsScope>()?.api;

  @override
  bool updateShouldNotify(TransferVerifyAssociationsScope oldWidget) => api != oldWidget.api;
}
