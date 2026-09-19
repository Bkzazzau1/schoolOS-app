import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/award_models.dart';
import 'award_demo_data.dart';

class AwardSnapshot {
  const AwardSnapshot({required this.awards, required this.permissions});

  final List<AwardRecognition> awards;
  final AwardPermissions permissions;
}

class AwardActionResult {
  const AwardActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AwardRepository {
  AwardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'award_recognition';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AwardPermissions permissionsFor(SchoolMembership membership) {
    return AwardPermissions(
      canCreateDrafts: membership.role == SchoolRole.proprietor,
    );
  }

  Future<AwardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final award in awardsWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: award.id,
          payload: award.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final awards = records
        .map((record) => AwardRecognition.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.id.compareTo(a.id));

    return AwardSnapshot(
      awards: awards,
      permissions: permissionsFor(membership),
    );
  }

  Future<AwardActionResult> addDraft({
    required String title,
    required String recipient,
    required AwardRecipientType recipientType,
    required String section,
    required String category,
    required String citation,
    required String issuer,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateDrafts) {
      return const AwardActionResult(
        success: false,
        message: 'This membership cannot create recognition drafts.',
      );
    }

    if (title.trim().isEmpty || recipient.trim().isEmpty) {
      return const AwardActionResult(
        success: false,
        message: 'Award title and recipient are required.',
      );
    }

    final id = 'AW-${DateTime.now().microsecondsSinceEpoch}';
    final award = AwardRecognition(
      id: id,
      title: title.trim(),
      recipient: recipient.trim(),
      recipientType: recipientType,
      section: section.trim().isEmpty ? 'School' : section.trim(),
      category: category.trim().isEmpty ? 'Achievement' : category.trim(),
      citation: citation.trim().isEmpty
          ? 'Recognition draft awaiting authorized review.'
          : citation.trim(),
      issuer: issuer.trim().isEmpty ? membership.roleLabel : issuer.trim(),
      date: 'Local draft',
      visibility: AwardVisibility.internalOnly,
      badge: '★',
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: award.id,
      payload: award.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: award.id,
      operation: SyncOperation.create,
      payload: award.toJson(),
    );

    return const AwardActionResult(
      success: true,
      message:
          'Recognition draft saved offline as Internal only and queued for sync.',
    );
  }
}
