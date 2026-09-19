import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_staff_models.dart';
import 'administrator_staff_demo_data.dart';

class AdministratorStaffSnapshot {
  const AdministratorStaffSnapshot({
    required this.staff,
    required this.permissions,
  });

  final List<AdministratorStaffRecord> staff;
  final AdministratorStaffPermissions permissions;
}

class AdministratorStaffRepository {
  AdministratorStaffRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_staff_directory';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorStaffPermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorStaffPermissions(
      canViewDirectory: allowed,
      canReviewOperationalFile: allowed,
    );
  }

  Future<AdministratorStaffSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in administratorStaffWebsiteSeed) {
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

    final staff = records
        .map((record) => AdministratorStaffRecord.fromJson(record.payload))
        .toList();

    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorStaffWebsiteSeed.length; i++)
        administratorStaffWebsiteSeed[i].id: i,
    };
    staff.sort((a, b) {
      final aOrder = websiteOrder[a.id] ?? 9999;
      final bOrder = websiteOrder[b.id] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

    return AdministratorStaffSnapshot(
      staff: staff,
      permissions: permissionsFor(membership),
    );
  }
}
