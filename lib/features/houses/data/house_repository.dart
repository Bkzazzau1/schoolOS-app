import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/house_models.dart';

class HouseSnapshot {
  const HouseSnapshot({required this.houses, required this.permissions});

  final List<SchoolHouse> houses;
  final HousePermissions permissions;
}

class HouseActionResult {
  const HouseActionResult(this.success, this.message);
  final bool success;
  final String message;
}

class HouseRepository {
  HouseRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_house';

  // Mirrors apps.schoollife.framework.MANAGERS exactly, the same roles the real HOUSES Spec
  // authorizes to manage a house - never proprietor alone.
  static const _managers = {SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator};

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  HousePermissions permissionsFor(SchoolMembership membership) {
    return HousePermissions(canManageAll: _managers.contains(membership.role));
  }

  Future<HouseSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    final houses = records
        .map((record) => SchoolHouse.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.points.compareTo(a.points));

    return HouseSnapshot(
      houses: houses,
      permissions: permissionsFor(membership),
    );
  }

  Future<HouseActionResult> create({
    required String name,
    required String captain,
    required String coordinator,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const HouseActionResult(false, 'This membership cannot add a house.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const HouseActionResult(false, 'Enter a house name.');
    }

    final now = DateTime.now().toUtc();
    final house = SchoolHouse(
      id: 'HOUSE-${now.microsecondsSinceEpoch}',
      name: cleanName,
      captain: captain.trim(),
      coordinator: coordinator.trim(),
      members: 0,
      points: 0,
      sports: 0,
      academicCompetitions: 0,
      service: 0,
      status: 'Active',
    );
    await _save(house, SyncOperation.create);
    return const HouseActionResult(true, 'House added and queued for sync.');
  }

  /// Points, members and component scores are maintained by hand here - nothing in the app yet
  /// records a real sports/quiz/service event, so there is no automated total to compute instead.
  Future<HouseActionResult> edit({
    required String id,
    required String name,
    required String captain,
    required String coordinator,
    required int members,
    required int points,
    required int sports,
    required int academicCompetitions,
    required int service,
    required String status,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManageAll) {
      return const HouseActionResult(false, 'This membership cannot edit a house.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const HouseActionResult(false, 'Enter a house name.');
    }
    final house = await _requireHouse(id);
    final updated = house.copyWith(
      name: cleanName,
      captain: captain.trim(),
      coordinator: coordinator.trim(),
      members: members,
      points: points,
      sports: sports,
      academicCompetitions: academicCompetitions,
      service: service,
      status: status.trim().isEmpty ? house.status : status.trim(),
    );
    await _save(updated, SyncOperation.update);
    return const HouseActionResult(true, 'House update saved and queued for sync.');
  }

  Future<SchoolHouse> _requireHouse(String id) async {
    final membership = _schoolSession.requireActiveMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: id,
    );
    if (record == null) throw StateError('House $id was not found in this school.');
    return SchoolHouse.fromJson(record.payload);
  }

  Future<void> _save(SchoolHouse house, SyncOperation operation) async {
    final membership = _schoolSession.requireActiveMembership();
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: house.id,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: house.id,
      payload: house.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: house.id,
      operation: operation,
      payload: house.toJson(),
      baseVersion: existing?.serverVersion,
    );
  }
}
