import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/lost_found_models.dart';
import 'lost_found_demo_data.dart';

class LostFoundSnapshot {
  const LostFoundSnapshot({required this.items, required this.permissions});

  final List<LostFoundItem> items;
  final LostFoundPermissions permissions;
}

class LostFoundActionResult {
  const LostFoundActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class LostFoundRepository {
  LostFoundRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'lost_found_item';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  LostFoundPermissions permissionsFor(SchoolMembership membership) {
    return LostFoundPermissions(
      canManageClaims: membership.role == SchoolRole.proprietor,
    );
  }

  Future<LostFoundSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in lostFoundWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: item.id,
          payload: item.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final items = records
        .map((record) => LostFoundItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return LostFoundSnapshot(
      items: items,
      permissions: permissionsFor(membership),
    );
  }

  Future<LostFoundActionResult> startClaimReview(String itemId) async {
    return _setStatus(itemId, LostFoundStatus.claimReview);
  }

  Future<LostFoundActionResult> markReturned(String itemId) async {
    return _setStatus(itemId, LostFoundStatus.returned);
  }

  Future<LostFoundActionResult> _setStatus(
    String itemId,
    LostFoundStatus status,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageClaims) {
      return const LostFoundActionResult(
        success: false,
        message: 'This membership cannot manage lost-and-found claims.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: itemId,
    );
    if (record == null) {
      return const LostFoundActionResult(
        success: false,
        message: 'Lost-and-found item was not found for this school.',
      );
    }

    final current = LostFoundItem.fromJson(record.payload);
    final updated = current.copyWith(status: status);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    return LostFoundActionResult(
      success: true,
      message: status == LostFoundStatus.returned
          ? 'Item marked returned offline and queued for sync.'
          : 'Claim review started offline and queued for sync.',
    );
  }
}
