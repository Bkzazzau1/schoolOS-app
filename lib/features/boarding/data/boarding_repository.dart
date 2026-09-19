import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/boarding_models.dart';
import 'boarding_demo_data.dart';

class BoardingSnapshot {
  const BoardingSnapshot({required this.dorms, required this.permissions});

  final List<BoardingDorm> dorms;
  final BoardingPermissions permissions;
}

class BoardingActionResult {
  const BoardingActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class BoardingRepository {
  BoardingRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'boarding_dorm';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  BoardingPermissions permissionsFor(SchoolMembership membership) {
    return BoardingPermissions(
      canReviewHandover: membership.role == SchoolRole.proprietor,
    );
  }

  Future<BoardingSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final dorm in boardingWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: _entityId(dorm.name),
          payload: dorm.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final dorms = records
        .map((record) => BoardingDorm.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    return BoardingSnapshot(
      dorms: dorms,
      permissions: permissionsFor(membership),
    );
  }

  Future<BoardingActionResult> toggleHandoverReview(String dormName) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canReviewHandover) {
      return const BoardingActionResult(
        success: false,
        message: 'This membership cannot review boarding handovers.',
      );
    }

    final entityId = _entityId(dormName);
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: entityId,
    );
    if (record == null) {
      return const BoardingActionResult(
        success: false,
        message: 'Dormitory was not found for this school.',
      );
    }

    final current = BoardingDorm.fromJson(record.payload);
    final updated = current.copyWith(
      handoverReviewed: !current.handoverReviewed,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: entityId,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: entityId,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    return BoardingActionResult(
      success: true,
      message: updated.handoverReviewed
          ? 'Boarding handover review saved offline.'
          : 'Boarding handover review reopened and queued for sync.',
    );
  }

  String _entityId(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
