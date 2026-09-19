import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_profile_models.dart';
import 'principal_profile_demo_data.dart';

class PrincipalProfileSnapshot {
  const PrincipalProfileSnapshot({
    required this.account,
    required this.preferences,
    required this.permissions,
  });
  final PrincipalAccountProfile account;
  final PrincipalNotificationPreferences preferences;
  final PrincipalProfilePermissions permissions;
}

class PrincipalProfileActionResult {
  const PrincipalProfileActionResult({required this.success, required this.message});
  final bool success;
  final String message;
}

class PrincipalProfileRepository {
  PrincipalProfileRepository({required LocalDatabase localDatabase, required SchoolSessionController schoolSession})
      : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _accountType = 'principal_account_profile';
  static const _preferencesType = 'principal_notification_preferences';
  static const _accountId = 'current';
  static const _preferencesId = 'current';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalProfilePermissions permissionsFor(SchoolMembership membership) => PrincipalProfilePermissions(
        canEditOwnContactProfile: membership.role == SchoolRole.principal,
        canEditNotificationPreferences: membership.role == SchoolRole.principal,
        canEditSchoolIdentity: false,
        canAccessFinance: false,
        canLeadPrimaryOrNursery: false,
      );

  Future<PrincipalProfileSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final accountRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _accountType,
      entityId: _accountId,
    );
    final prefRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _preferencesType,
      entityId: _preferencesId,
    );
    return PrincipalProfileSnapshot(
      account: PrincipalAccountProfile.fromJson(accountRecord!.payload),
      preferences: PrincipalNotificationPreferences.fromJson(prefRecord!.payload),
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalProfileActionResult> saveAccount(PrincipalAccountProfile account) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEditOwnContactProfile) {
      return const PrincipalProfileActionResult(success: false, message: 'This membership cannot edit the Principal profile.');
    }
    if (account.fullName.trim().isEmpty || account.displayName.trim().isEmpty || account.email.trim().isEmpty || account.phone.trim().isEmpty) {
      return const PrincipalProfileActionResult(success: false, message: 'Full name, display name, email and phone are required.');
    }
    final payload = account.toJson();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _accountType,
      entityId: _accountId,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _accountType,
      entityId: _accountId,
      operation: SyncOperation.update,
      payload: payload,
    );
    return const PrincipalProfileActionResult(success: true, message: 'Profile saved offline and queued for sync.');
  }

  Future<PrincipalProfileActionResult> savePreferences(PrincipalNotificationPreferences preferences) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEditNotificationPreferences) {
      return const PrincipalProfileActionResult(success: false, message: 'This membership cannot edit Principal notification preferences.');
    }
    final payload = preferences.toJson();
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _preferencesType,
      entityId: _preferencesId,
      payload: payload,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _preferencesType,
      entityId: _preferencesId,
      operation: SyncOperation.update,
      payload: payload,
    );
    return const PrincipalProfileActionResult(success: true, message: 'Notification preferences saved offline and queued for sync.');
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final account = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _accountType,
      entityId: _accountId,
    );
    if (account == null) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _accountType,
        entityId: _accountId,
        payload: principalDefaultProfile.toJson(),
      );
    }
    final prefs = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _preferencesType,
      entityId: _preferencesId,
    );
    if (prefs == null) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _preferencesType,
        entityId: _preferencesId,
        payload: principalDefaultPreferences.toJson(),
      );
    }
  }
}
