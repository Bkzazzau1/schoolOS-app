import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_operations_models.dart';
import 'administrator_operations_demo_data.dart';

class AdministratorOperationsSnapshot {
  const AdministratorOperationsSnapshot({
    required this.tasks,
    required this.permissions,
  });

  final List<AdministratorOperationTask> tasks;
  final AdministratorOperationsPermissions permissions;
}

class AdministratorOperationsRepository {
  AdministratorOperationsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_operations_queue';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorOperationsPermissions permissionsFor(
    SchoolMembership membership,
  ) {
    return AdministratorOperationsPermissions(
      canView: membership.role == SchoolRole.administrator,
    );
  }

  Future<AdministratorOperationsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (var i = 0; i < administratorOperationsWebsiteSeed.length; i++) {
        final item = administratorOperationsWebsiteSeed[i];
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: 'operations-${i + 1}',
          payload: item.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final tasks = records
        .map((record) => AdministratorOperationTask.fromJson(record.payload))
        .toList();

    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorOperationsWebsiteSeed.length; i++)
        administratorOperationsWebsiteSeed[i].title: i,
    };
    tasks.sort((a, b) {
      final aOrder = websiteOrder[a.title] ?? 9999;
      final bOrder = websiteOrder[b.title] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.title.compareTo(b.title);
    });

    return AdministratorOperationsSnapshot(
      tasks: tasks,
      permissions: permissionsFor(membership),
    );
  }
}
