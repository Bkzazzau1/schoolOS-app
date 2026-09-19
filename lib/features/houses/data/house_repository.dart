import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/house_models.dart';
import 'house_demo_data.dart';

class HouseSnapshot {
  const HouseSnapshot({required this.houses, required this.permissions});

  final List<SchoolHouse> houses;
  final HousePermissions permissions;
}

class HouseRepository {
  HouseRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'school_house';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  HousePermissions permissionsFor(SchoolMembership membership) {
    return HousePermissions(canManageAll: membership.role == SchoolRole.proprietor);
  }

  Future<HouseSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final house in houseWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: house.id,
          payload: house.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final houses = records
        .map((record) => SchoolHouse.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.points.compareTo(a.points));

    return HouseSnapshot(
      houses: houses,
      permissions: permissionsFor(membership),
    );
  }
}
