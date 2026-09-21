import '../../../core/network/api_client.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/owner_access_models.dart';

/// The owner's calls for deciding who sees which screen. They need a connection
/// (unlike most of the app): what the owner decides here is the server's
/// record, and a change only means something once the server has it.
///
/// A refused change (`400 access_error`) comes back as an `ApiException` whose
/// message is written for the owner and is safe to show.
class OwnerAccessRepository {
  OwnerAccessRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  String _base(SchoolMembership owner) => 'owner/schools/${owner.schoolId}/access';

  Map<String, String> _who(SchoolMembership owner) => {'membership': owner.id};

  Future<AccessCatalogData> loadCatalog(SchoolMembership owner) async {
    final data = await _api.get('${_base(owner)}/catalog/', query: _who(owner));
    return AccessCatalogData.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<RoleAccess>> loadRoles(SchoolMembership owner) async {
    final data = await _api.get('${_base(owner)}/roles/', query: _who(owner)) as Map;
    return [for (final r in (data['roles'] as List)) RoleAccess.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> setRole(SchoolMembership owner, String role, Set<String> activities) async {
    await _api.put('${_base(owner)}/roles/$role/', body: {'activities': activities.toList()..sort()}, query: _who(owner));
  }

  Future<void> resetRole(SchoolMembership owner, String role) async {
    await _api.delete('${_base(owner)}/roles/$role/', query: _who(owner));
  }

  Future<List<PersonAccess>> loadPeople(SchoolMembership owner) async {
    final data = await _api.get('${_base(owner)}/people/', query: _who(owner)) as Map;
    return [for (final p in (data['people'] as List)) PersonAccess.fromJson(Map<String, dynamic>.from(p as Map))];
  }

  /// Grant or block one activity for one person.
  ///
  /// A block waits for the person's next sync by default, so the app can send
  /// their unsent work first; [immediately] makes it take effect at once.
  Future<void> setOverride(
    SchoolMembership owner,
    String membershipId,
    String activity, {
    required bool block,
    bool immediately = false,
    DateTime? expiresAt,
    String note = '',
  }) async {
    await _api.put(
      '${_base(owner)}/people/$membershipId/activities/$activity/',
      query: _who(owner),
      body: {
        'effect': block ? 'block' : 'grant',
        'mode': immediately ? 'immediate' : 'after_sync',
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'note': note.trim(),
      },
    );
  }

  /// Put the person back on their role's default for this activity (also cancels a waiting block).
  Future<void> clearOverride(SchoolMembership owner, String membershipId, String activity) async {
    await _api.delete('${_base(owner)}/people/$membershipId/activities/$activity/', query: _who(owner));
  }

  /// Move an activity from one person to another in one step.
  Future<void> reassign(
    SchoolMembership owner, {
    required String activity,
    required String fromMembershipId,
    required String toMembershipId,
    bool immediately = false,
    String note = '',
  }) async {
    await _api.post(
      '${_base(owner)}/reassign/',
      query: _who(owner),
      body: {
        'activity': activity,
        'fromMembershipId': fromMembershipId,
        'toMembershipId': toMembershipId,
        'mode': immediately ? 'immediate' : 'after_sync',
        'note': note.trim(),
      },
    );
  }

  Future<List<AccessChangeEntry>> loadHistory(SchoolMembership owner, {int limit = 100}) async {
    final data = await _api.get('${_base(owner)}/audit/', query: {..._who(owner), 'limit': '$limit'}) as Map;
    return [for (final c in (data['changes'] as List)) AccessChangeEntry.fromJson(Map<String, dynamic>.from(c as Map))];
  }
}
