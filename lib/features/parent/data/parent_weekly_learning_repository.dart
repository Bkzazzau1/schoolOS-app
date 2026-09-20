import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_weekly_learning_models.dart';
import 'parent_weekly_learning_demo_data.dart';

class ParentWeeklyLearningRepository {
  ParentWeeklyLearningRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_weekly_learning_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentWeeklyLearningSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentWeeklyLearningSnapshot.fromJson(record.payload);
      return _parentSafeSnapshot(snapshot);
    }

    final snapshot = _parentSafeSnapshot(parentDefaultWeeklyLearning);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
    );
    return snapshot;
  }

  Future<void> replaceFromServer({
    required ParentWeeklyLearningSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    final safeSnapshot = _parentSafeSnapshot(snapshot);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: safeSnapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  ParentWeeklyLearningSnapshot _parentSafeSnapshot(
    ParentWeeklyLearningSnapshot snapshot,
  ) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Weekly learning is missing its family account id.');
    }

    final ids = <String>{};
    final published = <ParentWeeklyLearningUpdate>[];

    for (final update in snapshot.updates) {
      if (update.id.trim().isEmpty || !ids.add(update.id)) {
        throw StateError('Weekly learning contains an invalid update id.');
      }
      if (update.childId.trim().isEmpty ||
          update.childName.trim().isEmpty ||
          update.className.trim().isEmpty ||
          update.teacher.trim().isEmpty) {
        throw StateError('Weekly learning contains an incomplete child update.');
      }
      if (update.subjects.isEmpty) {
        throw StateError('A weekly learning update has no subject evidence.');
      }
      for (final subject in update.subjects) {
        if (subject.subject.trim().isEmpty ||
            subject.thisWeek.trim().isEmpty ||
            subject.learningEvidence.trim().isEmpty ||
            subject.nextTopic.trim().isEmpty) {
          throw StateError('Weekly learning contains incomplete subject evidence.');
        }
      }

      // Family accounts must never receive a teacher draft or queued publication.
      if (update.published) published.add(update);
    }

    return ParentWeeklyLearningSnapshot(
      familyAccountId: snapshot.familyAccountId,
      updates: List.unmodifiable(published),
    );
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError(
        'Weekly learning requires an active Parent membership.',
      );
    }
    return membership;
  }
}
