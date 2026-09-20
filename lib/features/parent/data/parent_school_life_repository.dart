import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_school_life_models.dart';
import 'parent_school_life_demo_data.dart';

class ParentSchoolLifeRepository {
  ParentSchoolLifeRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'parent_school_life_snapshot';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentSchoolLifeSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentSchoolLifeSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: membership.id,
      payload: parentDefaultSchoolLife.toJson(),
    );
    return parentDefaultSchoolLife;
  }

  Future<void> replaceFromServer({
    required ParentSchoolLifeSnapshot snapshot,
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

  void _validateSnapshot(ParentSchoolLifeSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('School-life data is missing its family account id.');
    }

    for (final activity in snapshot.activities) {
      if (activity.childName.trim().isEmpty ||
          activity.activity.trim().isEmpty ||
          activity.schedule.trim().isEmpty ||
          activity.status.trim().isEmpty) {
        throw StateError('School-life activity data is incomplete.');
      }
    }

    for (final event in snapshot.events) {
      if (event.dateLabel.trim().isEmpty ||
          event.title.trim().isEmpty ||
          event.scope.trim().isEmpty) {
        throw StateError('School-life event data is incomplete.');
      }
    }

    for (final item in snapshot.transport) {
      if (item.childName.trim().isEmpty ||
          item.serviceCode.trim().isEmpty ||
          item.status.trim().isEmpty ||
          item.guardianSafeSummary.trim().isEmpty) {
        throw StateError('School-life transport data is incomplete.');
      }
    }

    for (final meal in snapshot.mealPlans) {
      if (meal.childName.trim().isEmpty || meal.planLabel.trim().isEmpty) {
        throw StateError('School-life meal data is incomplete.');
      }
    }

    for (final recognition in snapshot.recognition) {
      if (recognition.childName.trim().isEmpty ||
          recognition.title.trim().isEmpty ||
          recognition.periodLabel.trim().isEmpty) {
        throw StateError('School-life recognition data is incomplete.');
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('School Life requires an active Parent membership.');
    }
    return membership;
  }
}
