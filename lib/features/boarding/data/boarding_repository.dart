import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/boarding_models.dart';

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

  // Mirrors apps.schoollife.specs.campus.BOARDING exactly: manage=MANAGERS for the dorm record
  // itself, but the guarded handoverReviewed field is narrower - LEADERS only (proprietor,
  // principal - never administrator).
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator};
  static const _leaders = {SchoolRole.proprietor, SchoolRole.principal};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  BoardingPermissions permissionsFor(SchoolMembership membership) {
    return BoardingPermissions(
      canManageAll: _managers.contains(membership.role),
      canReviewHandover: _leaders.contains(membership.role),
    );
  }

  Future<BoardingSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final dorms = records
        .map((record) => BoardingDorm.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    return BoardingSnapshot(
      dorms: dorms,
      permissions: permissionsFor(membership),
    );
  }

  Future<BoardingActionResult> create({
    required String name,
    required String houseParent,
    required int capacity,
    required DormStatus status,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const BoardingActionResult(
        success: false,
        message: 'This membership cannot add a dormitory.',
      );
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const BoardingActionResult(success: false, message: 'Enter a dormitory name.');
    }
    final entityId = _entityId(cleanName);
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: entityId,
    );
    if (existing != null) {
      return const BoardingActionResult(
        success: false,
        message: 'A dormitory with this name already exists.',
      );
    }

    final dorm = BoardingDorm(
      name: cleanName,
      houseParent: houseParent.trim(),
      capacity: capacity < 0 ? 0 : capacity,
      occupied: 0,
      onCampus: 0,
      approvedLeave: 0,
      maintenance: 0,
      status: status,
      note: note.trim(),
    );
    await _save(dorm, SyncOperation.create);
    return const BoardingActionResult(success: true, message: 'Dormitory added and queued for sync.');
  }

  Future<BoardingActionResult> edit({
    required String name,
    required String houseParent,
    required int capacity,
    required int occupied,
    required int onCampus,
    required int approvedLeave,
    required int maintenance,
    required DormStatus status,
    required String note,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const BoardingActionResult(
        success: false,
        message: 'This membership cannot edit a dormitory.',
      );
    }
    final current = await _requireDorm(name);
    final updated = current.copyWith(
      houseParent: houseParent.trim(),
      capacity: capacity < 0 ? 0 : capacity,
      occupied: occupied < 0 ? 0 : occupied,
      onCampus: onCampus < 0 ? 0 : onCampus,
      approvedLeave: approvedLeave < 0 ? 0 : approvedLeave,
      maintenance: maintenance < 0 ? 0 : maintenance,
      status: status,
      note: note.trim(),
    );
    await _save(updated, SyncOperation.update);
    return const BoardingActionResult(success: true, message: 'Dormitory update saved and queued for sync.');
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
    await _save(updated, SyncOperation.update);

    return BoardingActionResult(
      success: true,
      message: updated.handoverReviewed
          ? 'Boarding handover review saved offline.'
          : 'Boarding handover review reopened and queued for sync.',
    );
  }

  Future<BoardingDorm> _requireDorm(String name) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: _entityId(name),
    );
    if (record == null) {
      throw StateError('Dormitory $name was not found in this school.');
    }
    return BoardingDorm.fromJson(record.payload);
  }

  Future<void> _save(BoardingDorm dorm, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    final entityId = _entityId(dorm.name);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: entityId,
      payload: dorm.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: entityId,
      operation: operation,
      payload: dorm.toJson(),
    );
  }

  String _entityId(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
