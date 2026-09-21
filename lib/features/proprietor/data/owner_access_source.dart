import '../../../shared/models/school_membership.dart';
import '../domain/owner_access_models.dart';

/// What the Access & Activities screen needs: read who has what, and change it.
///
/// With a school server the answers come from the server (`OwnerAccessRepository`). In the demo,
/// with no server, they come from decisions kept on the device (`LocalOwnerAccess`). The screen
/// does not know or care which.
///
/// A refused change throws (an `ApiException` from the server, a `StateError` locally) with words
/// written for the owner.
abstract interface class OwnerAccessSource {
  /// The owner can also give a person an extra role or take one away. Only the demo does this so far.
  bool get supportsExtraRoles;

  Future<AccessCatalogData> loadCatalog(SchoolMembership owner);
  Future<List<RoleAccess>> loadRoles(SchoolMembership owner);
  Future<void> setRole(SchoolMembership owner, String role, Set<String> activities);
  Future<void> resetRole(SchoolMembership owner, String role);
  Future<List<PersonAccess>> loadPeople(SchoolMembership owner);

  Future<void> setOverride(
    SchoolMembership owner,
    String membershipId,
    String activity, {
    required bool block,
    bool immediately = false,
    DateTime? expiresAt,
    String note = '',
  });

  Future<void> clearOverride(SchoolMembership owner, String membershipId, String activity);

  Future<void> reassign(
    SchoolMembership owner, {
    required String activity,
    required String fromMembershipId,
    required String toMembershipId,
    bool immediately = false,
    String note = '',
  });

  Future<List<AccessChangeEntry>> loadHistory(SchoolMembership owner, {int limit = 100});

  /// Gives a person another role (for example a teacher who is also a parent).
  Future<void> addRole(SchoolMembership owner, String personId, String role);

  /// Takes an extra role away from a person. Their main role cannot be removed.
  Future<void> removeRole(SchoolMembership owner, String personId, String role);
}
