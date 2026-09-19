import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_notices_models.dart';
import 'administrator_notices_demo_data.dart';

class AdministratorNoticesSnapshot {
  const AdministratorNoticesSnapshot({
    required this.notices,
    required this.permissions,
  });

  final List<AdministratorNotice> notices;
  final AdministratorNoticePermissions permissions;
}

class AdministratorNoticeActionResult {
  const AdministratorNoticeActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class AdministratorNoticesRepository {
  AdministratorNoticesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_notice';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorNoticePermissions permissionsFor(SchoolMembership membership) {
    return AdministratorNoticePermissions(
      canCreateDrafts: membership.role == SchoolRole.administrator,
    );
  }

  Future<AdministratorNoticesSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final notice in administratorNoticesWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: notice.id,
          payload: notice.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final notices = records
        .map((record) => AdministratorNotice.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.id.compareTo(a.id));

    return AdministratorNoticesSnapshot(
      notices: notices,
      permissions: permissionsFor(membership),
    );
  }

  Future<AdministratorNoticeActionResult> saveDraft({
    required AdministratorNoticeAudience audience,
    required AdministratorNoticeType type,
    required String message,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateDrafts) {
      return const AdministratorNoticeActionResult(
        success: false,
        message: 'This membership cannot create administrative notice drafts.',
      );
    }

    final normalizedMessage = message.trim();
    if (normalizedMessage.isEmpty) {
      return const AdministratorNoticeActionResult(
        success: false,
        message: 'Add a message first.',
      );
    }

    final id = 'NOTICE-${DateTime.now().microsecondsSinceEpoch}';
    final compact = normalizedMessage.replaceAll(RegExp(r'\s+'), ' ');
    final title = compact.length <= 56
        ? compact
        : '${compact.substring(0, 53).trimRight()}...';
    final notice = AdministratorNotice(
      id: id,
      title: title,
      audience: audience,
      type: type,
      message: normalizedMessage,
      status: AdministratorNoticeStatus.draft,
      createdLabel: 'Local draft',
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: notice.id,
      payload: notice.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: notice.id,
      operation: SyncOperation.create,
      payload: notice.toJson(),
    );

    return const AdministratorNoticeActionResult(
      success: true,
      message: 'Notice draft saved offline and queued for sync. Publishing still requires the governed approval workflow.',
    );
  }
}
