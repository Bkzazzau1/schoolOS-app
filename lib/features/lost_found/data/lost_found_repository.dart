import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/lost_found_models.dart';

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

  // Mirrors apps.schoollife.specs.campus.LOST_FOUND exactly: manage=MANAGERS|{"staff"} may run the
  // claims office, contribute={"teacher","parent","student","accountant","driver"} may report a
  // found item - anyone may report; only staff who run the office settle a claim.
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator, SchoolRole.staff};
  static const _contributors = {SchoolRole.teacher, SchoolRole.parent, SchoolRole.student, SchoolRole.accountant, SchoolRole.driver};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  LostFoundPermissions permissionsFor(SchoolMembership membership) {
    final isManager = _managers.contains(membership.role);
    return LostFoundPermissions(
      canReport: isManager || _contributors.contains(membership.role),
      canManageClaims: isManager,
    );
  }

  Future<LostFoundSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final items = records
        .map((record) => LostFoundItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return LostFoundSnapshot(
      items: items,
      permissions: permissionsFor(membership),
    );
  }

  /// "claimant" is deliberately never set here - it's guarded to the claims office (manage) in the
  /// real Spec, so a reporter's own report always starts honestly unclaimed, never a fabricated name.
  Future<LostFoundActionResult> report({
    required String item,
    required String category,
    required String found,
    required String date,
    required String storage,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReport) {
      return const LostFoundActionResult(
        success: false,
        message: 'This membership cannot report a found item.',
      );
    }
    final cleanItem = item.trim();
    if (cleanItem.isEmpty) {
      return const LostFoundActionResult(success: false, message: 'Describe the item found.');
    }

    final now = DateTime.now().toUtc();
    final record = LostFoundItem(
      id: 'LF-${now.microsecondsSinceEpoch}',
      item: cleanItem,
      category: category.trim(),
      found: found.trim(),
      date: date.trim(),
      storage: storage.trim(),
      status: LostFoundStatus.unclaimed,
      claimant: '',
      note: note.trim(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: record.id,
      payload: record.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: record.id,
      operation: SyncOperation.create,
      payload: record.toJson(),
    );
    return const LostFoundActionResult(success: true, message: 'Item reported and queued for sync.');
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
