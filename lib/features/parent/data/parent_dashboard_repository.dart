import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_dashboard_models.dart';
import 'parent_dashboard_demo_data.dart';

class ParentDashboardRepository {
  ParentDashboardRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_dashboard_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentDashboardSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    _requireParentMembership(membership);

    // A family snapshot is keyed by membership, not only tenant. This prevents
    // one guardian's cached family data from being returned to another guardian
    // on the same school installation.
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      return ParentDashboardSnapshot.fromJson(record.payload);
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultDashboard.toJson(),
    );
    return parentDefaultDashboard;
  }

  Future<void> replaceFromServer({
    required ParentDashboardSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    _requireParentMembership(membership);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _requireParentMembership(SchoolMembership membership) {
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Parent family records require an active Parent membership.',
      );
    }
  }
}
