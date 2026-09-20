import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_learning_progress_models.dart';
import 'parent_learning_progress_demo_data.dart';

class ParentLearningProgressRepository {
  ParentLearningProgressRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_learning_progress_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentLearningProgressSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentLearningProgressSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultLearningProgress.toJson(),
    );
    return parentDefaultLearningProgress;
  }

  Future<ParentLearningChild> childById(String childId) async {
    final normalized = childId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(childId, 'childId', 'Child id is required.');
    }

    final snapshot = await load();
    final child = snapshot.childById(normalized);
    if (child == null) {
      throw StateError(
        'Learning progress is unavailable because this child is not linked to the active guardian membership.',
      );
    }
    return child;
  }

  Future<void> replaceFromServer({
    required ParentLearningProgressSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _validateSnapshot(ParentLearningProgressSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Family learning progress is missing its family account id.');
    }

    final childIds = <String>{};
    for (final child in snapshot.children) {
      if (child.id.trim().isEmpty || !childIds.add(child.id)) {
        throw StateError('Family learning progress contains an invalid child id.');
      }
      if (child.averagePercent < 0 || child.averagePercent > 100) {
        throw StateError('A child learning average is outside the valid range.');
      }
      if (child.attendancePercent < 0 || child.attendancePercent > 100) {
        throw StateError('A child attendance value is outside the valid range.');
      }
      if (child.history.any((value) => value < 0 || value > 100)) {
        throw StateError('Historical learning evidence is outside the valid range.');
      }
      if (child.topics.any((topic) => topic.scorePercent < 0 || topic.scorePercent > 100)) {
        throw StateError('Topic learning evidence is outside the valid range.');
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Family learning progress requires an active Parent membership.',
      );
    }
    return membership;
  }
}
