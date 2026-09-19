import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_website_models.dart';
import 'administrator_website_demo_data.dart';

class AdministratorWebsiteSnapshot {
  const AdministratorWebsiteSnapshot({
    required this.settings,
    required this.permissions,
  });

  final AdministratorWebsiteSettings settings;
  final AdministratorWebsitePermissions permissions;
}

class AdministratorWebsiteActionResult {
  const AdministratorWebsiteActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class AdministratorWebsiteRepository {
  AdministratorWebsiteRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'public_website_settings';
  static const _entityId = 'homepage';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorWebsitePermissions permissionsFor(SchoolMembership membership) {
    return AdministratorWebsitePermissions(
      canManageWebsite: membership.role == SchoolRole.administrator,
    );
  }

  Future<AdministratorWebsiteSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );

    if (record == null) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _entityType,
        entityId: _entityId,
        payload: administratorWebsiteSeed.toJson(),
      );
      record = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _entityType,
        entityId: _entityId,
      );
    }

    return AdministratorWebsiteSnapshot(
      settings: AdministratorWebsiteSettings.fromJson(record!.payload),
      permissions: permissionsFor(membership),
    );
  }

  Future<AdministratorWebsiteActionResult> save(
    AdministratorWebsiteSettings settings,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageWebsite) {
      return const AdministratorWebsiteActionResult(
        success: false,
        message: 'This membership cannot manage public website settings.',
      );
    }

    if (settings.heroHeadline.trim().isEmpty ||
        settings.heroSupportingText.trim().isEmpty) {
      return const AdministratorWebsiteActionResult(
        success: false,
        message: 'Homepage headline and supporting text are required.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
    );
    final payload = settings.copyWith(
      heroHeadline: settings.heroHeadline.trim(),
      heroSupportingText: settings.heroSupportingText.trim(),
    ).toJson();

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: _entityId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );

    return const AdministratorWebsiteActionResult(
      success: true,
      message: 'Website changes saved offline and queued for sync.',
    );
  }
}
