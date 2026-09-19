import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/noticeboard_models.dart';
import 'noticeboard_demo_data.dart';

class NoticeboardSnapshot {
  const NoticeboardSnapshot({required this.notices, required this.permissions});
  final List<NoticeboardNotice> notices;
  final NoticeboardPermissions permissions;
}

class NoticeboardActionResult {
  const NoticeboardActionResult(this.success, this.message);
  final bool success;
  final String message;
}

class NoticeboardRepository {
  NoticeboardRepository({required LocalDatabase localDatabase, required SchoolSessionController schoolSession})
      : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'noticeboard_notice';
  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  NoticeboardPermissions permissionsFor(SchoolMembership membership) {
    if (membership.role == SchoolRole.proprietor) {
      return const NoticeboardPermissions(
        canPublish: true,
        canPin: true,
        canEdit: true,
        canViewDeliveryReport: true,
        allowedAudiences: NoticeAudience.values,
      );
    }
    return const NoticeboardPermissions(
      canPublish: false,
      canPin: false,
      canEdit: false,
      canViewDeliveryReport: false,
      allowedAudiences: [],
    );
  }

  Future<NoticeboardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _entityType);
    if (records.isEmpty) {
      for (final notice in noticeboardSeedNotices) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: notice.id,
          payload: notice.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _entityType);
    }
    final notices = records.map((r) => NoticeboardNotice.fromJson(r.payload)).toList();
    return NoticeboardSnapshot(notices: filterNotices(notices: notices), permissions: permissionsFor(membership));
  }

  Future<NoticeboardActionResult> publish({
    required String title,
    required String body,
    required NoticeAudience audience,
    required NoticePriority priority,
    required bool acknowledgementRequired,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canPublish) return const NoticeboardActionResult(false, 'This membership cannot publish official notices.');
    if (!permissions.allowedAudiences.contains(audience)) return const NoticeboardActionResult(false, 'This audience is outside your Noticeboard scope.');
    if (title.trim().isEmpty || body.trim().isEmpty) return const NoticeboardActionResult(false, 'Add a notice title and message first.');

    final now = DateTime.now().toUtc();
    final notice = NoticeboardNotice(
      id: 'NB-${now.microsecondsSinceEpoch}',
      title: title.trim(),
      body: body.trim(),
      author: membership.role == SchoolRole.proprietor ? 'School Proprietor Office' : membership.roleLabel,
      role: membership.roleLabel,
      priority: priority,
      audience: audience,
      publishedLabel: 'Just now · offline',
      expiresLabel: 'Not set',
      acknowledgementRequired: acknowledgementRequired,
      readCount: 0,
      totalRecipients: audience == NoticeAudience.wholeSchool ? 1084 : 120,
      pinned: priority == NoticePriority.emergency,
      createdAt: now,
    );
    await _save(notice, SyncOperation.create);
    return const NoticeboardActionResult(true, 'Official notice saved offline and queued for sync.');
  }

  Future<NoticeboardActionResult> togglePin(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canPin) return const NoticeboardActionResult(false, 'This membership cannot pin official notices.');
    final notice = await _requireNotice(id);
    await _save(notice.copyWith(pinned: !notice.pinned), SyncOperation.update);
    return NoticeboardActionResult(true, notice.pinned ? 'Notice unpinned offline.' : 'Notice pinned offline.');
  }

  Future<NoticeboardActionResult> edit({required String id, required String title, required String body}) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEdit) return const NoticeboardActionResult(false, 'This membership cannot edit official notices.');
    if (title.trim().isEmpty || body.trim().isEmpty) return const NoticeboardActionResult(false, 'Title and message are required.');
    final notice = await _requireNotice(id);
    await _save(notice.copyWith(title: title.trim(), body: body.trim()), SyncOperation.update);
    return const NoticeboardActionResult(true, 'Notice update saved offline and queued for sync.');
  }

  Future<NoticeboardNotice> _requireNotice(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: _entityType, entityId: id);
    if (record == null) throw StateError('Notice $id was not found in this school.');
    return NoticeboardNotice.fromJson(record.payload);
  }

  Future<void> _save(NoticeboardNotice notice, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    final existing = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: _entityType, entityId: notice.id);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: notice.id,
      payload: notice.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: notice.id,
      operation: operation,
      payload: notice.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }
}
