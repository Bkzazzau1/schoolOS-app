import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_lifecycle_models.dart';
import 'administrator_lifecycle_demo_data.dart';

class AdministratorLifecycleSnapshot {
  const AdministratorLifecycleSnapshot({
    required this.records,
    required this.permissions,
  });

  final List<AdministratorLifecycleRecord> records;
  final AdministratorLifecyclePermissions permissions;
}

class AdministratorLifecycleRepository {
  AdministratorLifecycleRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_student_lifecycle';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorLifecyclePermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorLifecyclePermissions(
      canViewRegister: allowed,
      canOpenOperationalReview: allowed,
    );
  }

  Future<AdministratorLifecycleSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in administratorLifecycleWebsiteSeed) {
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
        .map((record) => AdministratorLifecycleRecord.fromJson(record.payload))
        .toList();

    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorLifecycleWebsiteSeed.length; i++)
        administratorLifecycleWebsiteSeed[i].id: i,
    };
    items.sort((a, b) {
      final aOrder = websiteOrder[a.id] ?? 9999;
      final bOrder = websiteOrder[b.id] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

    return AdministratorLifecycleSnapshot(
      records: items,
      permissions: permissionsFor(membership),
    );
  }
}
