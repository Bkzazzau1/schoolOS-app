import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_records_models.dart';
import 'administrator_records_demo_data.dart';

class AdministratorRecordsSnapshot {
  const AdministratorRecordsSnapshot({
    required this.records,
    required this.permissions,
  });

  final List<AdministratorDocumentRecord> records;
  final AdministratorRecordsPermissions permissions;
}

class AdministratorRecordsRepository {
  AdministratorRecordsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'administrator_document_record';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdministratorRecordsPermissions permissionsFor(SchoolMembership membership) {
    final allowed = membership.role == SchoolRole.administrator;
    return AdministratorRecordsPermissions(
      canViewRegister: allowed,
      canReviewRestrictedMetadata: allowed,
    );
  }

  Future<AdministratorRecordsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final item in administratorRecordsWebsiteSeed) {
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
        .map((record) => AdministratorDocumentRecord.fromJson(record.payload))
        .toList();
    final websiteOrder = <String, int>{
      for (var i = 0; i < administratorRecordsWebsiteSeed.length; i++)
        administratorRecordsWebsiteSeed[i].id: i,
    };
    items.sort((a, b) {
      final aOrder = websiteOrder[a.id] ?? 9999;
      final bOrder = websiteOrder[b.id] ?? 9999;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

    return AdministratorRecordsSnapshot(
      records: items,
      permissions: permissionsFor(membership),
    );
  }
}
