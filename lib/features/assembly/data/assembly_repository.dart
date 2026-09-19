import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/assembly_models.dart';
import 'assembly_demo_data.dart';

class AssemblySnapshot {
  const AssemblySnapshot({
    required this.sessions,
    required this.permissions,
  });

  final List<AssemblySession> sessions;
  final AssemblyPermissions permissions;
}

class AssemblyRepository {
  AssemblyRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'assembly_session';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AssemblyPermissions permissionsFor(SchoolMembership membership) {
    return AssemblyPermissions(
      canConfigureSchoolWide: membership.role == SchoolRole.proprietor,
    );
  }

  Future<AssemblySnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final session in assemblyWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: session.id,
          payload: session.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final sessions = records
        .map((record) => AssemblySession.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));

    return AssemblySnapshot(
      sessions: sessions,
      permissions: permissionsFor(membership),
    );
  }
}
