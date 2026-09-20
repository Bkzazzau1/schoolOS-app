import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_children_models.dart';
import 'parent_children_demo_data.dart';

class ParentChildrenRepository {
  ParentChildrenRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_children_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentChildrenSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      return ParentChildrenSnapshot.fromJson(record.payload);
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultChildren.toJson(),
    );
    return parentDefaultChildren;
  }

  Future<ParentLinkedChild> childById(String childId) async {
    if (childId.trim().isEmpty) {
      throw ArgumentError.value(childId, 'childId', 'Child id is required.');
    }

    final snapshot = await load();
    for (final child in snapshot.children) {
      if (child.id == childId) return child;
    }

    throw StateError(
      'The requested child is not linked to the active guardian membership.',
    );
  }

  Future<void> replaceFromServer({
    required ParentChildrenSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();

    final ids = <String>{};
    for (final child in snapshot.children) {
      if (child.id.trim().isEmpty || !ids.add(child.id)) {
        throw StateError('Server family payload contains an invalid linked child id.');
      }
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Linked family records require an active Parent membership.');
    }
    return membership;
  }
}
