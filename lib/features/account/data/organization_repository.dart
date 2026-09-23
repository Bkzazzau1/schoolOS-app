import '../../../core/auth/auth_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/organization_membership.dart';

enum SchoolKind {
  nursery,
  primary,
  secondary,
  nurseryPrimary,
  primarySecondary,
  nurseryPrimarySecondary,
  college,
  other,
}

extension SchoolKindDetails on SchoolKind {
  String get apiValue => switch (this) {
        SchoolKind.nursery => 'nursery',
        SchoolKind.primary => 'primary',
        SchoolKind.secondary => 'secondary',
        SchoolKind.nurseryPrimary => 'nursery_primary',
        SchoolKind.primarySecondary => 'primary_secondary',
        SchoolKind.nurseryPrimarySecondary => 'nursery_primary_secondary',
        SchoolKind.college => 'college',
        SchoolKind.other => 'other',
      };

  String get label => switch (this) {
        SchoolKind.nursery => 'Nursery',
        SchoolKind.primary => 'Primary',
        SchoolKind.secondary => 'Secondary',
        SchoolKind.nurseryPrimary => 'Nursery + Primary',
        SchoolKind.primarySecondary => 'Primary + Secondary',
        SchoolKind.nurseryPrimarySecondary => 'Nursery + Primary + Secondary',
        SchoolKind.college => 'College',
        SchoolKind.other => 'Other',
      };
}

class CreateSchoolDraft {
  const CreateSchoolDraft({
    required this.name,
    required this.kind,
    required this.location,
  });

  final String name;
  final SchoolKind kind;
  final String location;

  Map<String, Object?> toJson() => {
        'name': name.trim(),
        'schoolType': kind.apiValue,
        'location': location.trim(),
      };
}

/// Server-backed account operations that sit above an individual school tenant.
///
/// School creation is deliberately online-only. The server is responsible for
/// atomically creating the tenant, linking it to the organization, creating the
/// proprietor membership and applying the initial school defaults.
class OrganizationRepository {
  OrganizationRepository({
    required ApiClient api,
    required AuthRepository auth,
  })  : _api = api,
        _auth = auth;

  final ApiClient _api;
  final AuthRepository _auth;

  Future<SchoolMembership> createSchool(
    OrganizationMembership organization,
    CreateSchoolDraft draft,
  ) async {
    if (!organization.canCreateSchools) {
      throw const ApiException(
        403,
        'Your account role cannot create schools for this organization.',
      );
    }

    final data = await _api.post(
      'organizations/${organization.organizationId}/schools/',
      body: draft.toJson(),
    );
    if (data is! Map) {
      throw const ApiException(500, 'The server sent an unexpected answer.');
    }

    final response = Map<String, dynamic>.from(data);
    final rawMembership = response['membership'] ?? response['schoolMembership'];
    if (rawMembership is! Map) {
      throw const ApiException(
        500,
        'The school was created, but its account membership was not returned.',
      );
    }

    final created = SchoolMembership.fromJson(
      Map<String, dynamic>.from(rawMembership),
    );

    // Refresh the canonical person/session membership list before the new school
    // is opened. This prevents a locally-created membership from bypassing the
    // server-authorized session list enforced by SchoolSessionController.
    final profile = await _auth.refreshProfile();
    return profile.memberships.firstWhere(
      (membership) => membership.id == created.id,
      orElse: () => profile.memberships.firstWhere(
        (membership) => membership.schoolId == created.schoolId,
        orElse: () => throw const ApiException(
          409,
          'The school was created, but your access is not ready yet. Sign in again to refresh it.',
        ),
      ),
    );
  }
}
