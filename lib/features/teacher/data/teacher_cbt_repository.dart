import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_cbt_models.dart';
import 'teacher_cbt_demo_data.dart';

class TeacherCbtSnapshot {
  const TeacherCbtSnapshot({
    required this.sets,
    required this.permissions,
  });

  final List<TeacherCbtPracticeSet> sets;
  final TeacherCbtPermissions permissions;
}

class TeacherCbtActionResult {
  const TeacherCbtActionResult({
    required this.success,
    required this.message,
    this.set,
  });

  final bool success;
  final String message;
  final TeacherCbtPracticeSet? set;
}

class TeacherCbtRepository {
  TeacherCbtRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _setType = 'teacher_cbt_practice_set';
  static const _eventType = 'teacher_cbt_practice_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherCbtPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherCbtPermissions(
      canViewAssignedPractice: teacher,
      canEditDrafts: teacher,
      canQueuePublication: teacher,
      canConfirmPublication: false,
      canUsePracticeEvidence: teacher,
      canMakeHighStakesDecision: false,
    );
  }

  Future<TeacherCbtSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _setType,
    );
    final sets = records
        .map((record) => TeacherCbtPracticeSet.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) {
        final aIndex = teacherCbtSets.indexWhere((seed) => seed.id == a.id);
        final bIndex = teacherCbtSets.indexWhere((seed) => seed.id == b.id);
        final safeA = aIndex < 0 ? 999 : aIndex;
        final safeB = bIndex < 0 ? 999 : bIndex;
        final bySeed = safeA.compareTo(safeB);
        return bySeed != 0 ? bySeed : a.id.compareTo(b.id);
      });
    return TeacherCbtSnapshot(
      sets: sets,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherCbtActionResult> saveDraft(TeacherCbtPracticeSet value) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canEditDrafts) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'This membership cannot edit Teacher CBT practice drafts.',
      );
    }
    if (!value.teacherEditable) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'Published, queued or closed practice sets cannot be silently rewritten.',
      );
    }
    final validation = _validate(value);
    if (validation != null) {
      return TeacherCbtActionResult(success: false, message: validation);
    }
    final updated = value.copyWith(version: value.version + 1);
    final now = DateTime.now().toUtc().toIso8601String();
    await _persist(membership, updated);
    await _appendEvent(
      membership,
      set: updated,
      action: TeacherCbtEventAction.savedDraft,
      occurredAt: now,
    );
    return TeacherCbtActionResult(
      success: true,
      message: 'CBT practice draft saved locally and queued for synchronization.',
      set: updated,
    );
  }

  Future<TeacherCbtActionResult> queuePublication(
    TeacherCbtPracticeSet value,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canQueuePublication) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'This membership cannot publish Teacher CBT practice.',
      );
    }
    if (!value.teacherEditable) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'This practice set is already queued, published or closed.',
      );
    }
    final validation = _validate(value);
    if (validation != null) {
      return TeacherCbtActionResult(success: false, message: validation);
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = value.copyWith(
      state: TeacherCbtSetState.queuedForPublication,
      version: value.version + 1,
      queuedAt: now,
    );
    await _persist(membership, updated);
    await _appendEvent(
      membership,
      set: updated,
      action: TeacherCbtEventAction.queuedForPublication,
      occurredAt: now,
    );
    return TeacherCbtActionResult(
      success: true,
      message: 'CBT practice queued for publication. Student availability is not confirmed until the server acknowledges it.',
      set: updated,
    );
  }

  String? _validate(TeacherCbtPracticeSet value) {
    if (value.title.trim().isEmpty) return 'Add a practice title before saving.';
    if (value.questions <= 0) return 'Question count must be greater than zero.';
    if (value.durationMinutes <= 0) return 'Duration must be greater than zero.';
    if (value.instructions.trim().isEmpty) return 'Add learner instructions before saving.';
    return null;
  }

  Future<void> _persist(
    SchoolMembership membership,
    TeacherCbtPracticeSet value,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _setType,
      entityId: value.id,
      payload: value.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _setType,
      entityId: value.id,
      operation: SyncOperation.update,
      payload: value.toJson(),
    );
  }

  Future<void> _appendEvent(
    SchoolMembership membership, {
    required TeacherCbtPracticeSet set,
    required TeacherCbtEventAction action,
    required String occurredAt,
  }) async {
    final event = TeacherCbtEvent(
      id: '${set.id}-${DateTime.now().microsecondsSinceEpoch}',
      setId: set.id,
      action: action,
      actorMembershipId: membership.id,
      version: set.version,
      occurredAt: occurredAt,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _eventType,
      entityId: event.id,
      payload: event.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _eventType,
      entityId: event.id,
      operation: SyncOperation.create,
      payload: event.toJson(),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _setType,
    );
    if (existing.isNotEmpty) return;
    for (final set in teacherCbtSets) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _setType,
        entityId: set.id,
        payload: set.toJson(),
      );
    }
  }
}
