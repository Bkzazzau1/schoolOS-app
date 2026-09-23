import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_cbt_models.dart';
import 'teacher_cbt_demo_data.dart';
import 'teacher_roster.dart';

class TeacherCbtSnapshot {
  const TeacherCbtSnapshot({
    required this.sets,
    required this.classOptions,
    required this.permissions,
  });

  final List<TeacherCbtPracticeSet> sets;

  /// The teacher's real assigned classes; a practice set can only be created for one of these.
  final List<String> classOptions;

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

/// The local record entity type real practice sets are stored under, exposed so the real student
/// CBT-taking pipeline (`StudentCbtRepository`) can read a real published set for a real student's
/// class without needing a teacher's own assigned-class scope.
const teacherCbtPracticeSetEntityType = 'teacher_cbt_practice_set';

/// The local record entity type real student attempts are stored under, exposed for the same reason:
/// `StudentCbtRepository` writes a real attempt here when a student submits, and
/// `TeacherCbtRepository.load()` reads them back to compute a set's real attempts/average accuracy.
const teacherCbtAttemptEntityType = 'teacher_cbt_attempt';

/// Seeds the sample practice sets for this tenant if none exist yet. Records are tenant-scoped, not
/// per-teacher, so whichever role — Teacher or Student — reads this data first makes them available to
/// both; a student opening CBT before any teacher has opened theirs in this session must still see the
/// real seeded published set, not an empty list.
Future<void> ensureTeacherCbtSeeded(LocalDatabase localDatabase, String tenantId) async {
  final existing = await localDatabase.getLocalRecords(
    tenantId: tenantId,
    entityType: teacherCbtPracticeSetEntityType,
  );
  if (existing.isNotEmpty) return;
  for (final set in teacherCbtSets) {
    await localDatabase.upsertLocalRecord(
      tenantId: tenantId,
      entityType: teacherCbtPracticeSetEntityType,
      entityId: set.id,
      payload: set.toJson(),
    );
  }
}

class TeacherCbtRepository {
  TeacherCbtRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _setType = teacherCbtPracticeSetEntityType;
  static const _eventType = 'teacher_cbt_practice_event';
  static const _attemptType = teacherCbtAttemptEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

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

  Future<List<String>> _assignedClassNames(SchoolMembership membership) async {
    final classes = await _roster.assignedClasses(membership);
    return {for (final c in classes) c.className}.toList()..sort();
  }

  Future<TeacherCbtSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await ensureTeacherCbtSeeded(_localDatabase, membership.schoolId);
    final assigned = await _assignedClassNames(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _setType,
    );
    var sets = records
        .map((record) => TeacherCbtPracticeSet.fromJson(record.payload))
        .where((set) => assigned.contains(set.className))
        .toList(growable: false);

    // Real evidence only: attempts/averageAccuracy are always recomputed from real student
    // submissions here, never trusted from whatever was last persisted on the set itself.
    final attemptsBySet = await _realAttemptsBySet(membership, {for (final s in sets) s.id});
    sets = [
      for (final set in sets)
        set.copyWith(
          attempts: (attemptsBySet[set.id] ?? const []).length,
          averageAccuracy: _averageAccuracy(attemptsBySet[set.id] ?? const []),
        ),
    ]..sort((a, b) {
        final aIndex = teacherCbtSets.indexWhere((seed) => seed.id == a.id);
        final bIndex = teacherCbtSets.indexWhere((seed) => seed.id == b.id);
        final safeA = aIndex < 0 ? 999 : aIndex;
        final safeB = bIndex < 0 ? 999 : bIndex;
        final bySeed = safeA.compareTo(safeB);
        return bySeed != 0 ? bySeed : a.id.compareTo(b.id);
      });

    return TeacherCbtSnapshot(
      sets: sets,
      classOptions: assigned,
      permissions: permissionsFor(membership),
    );
  }

  Future<Map<String, List<TeacherCbtAttempt>>> _realAttemptsBySet(
    SchoolMembership membership,
    Set<String> setIds,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _attemptType,
    );
    final bySet = <String, List<TeacherCbtAttempt>>{};
    for (final record in records) {
      final attempt = TeacherCbtAttempt.fromJson(record.payload);
      if (!setIds.contains(attempt.setId)) continue;
      bySet.putIfAbsent(attempt.setId, () => []).add(attempt);
    }
    return bySet;
  }

  int _averageAccuracy(List<TeacherCbtAttempt> attempts) {
    if (attempts.isEmpty) return 0;
    final total = attempts.fold<int>(0, (sum, a) => sum + a.accuracyPercent);
    return (total / attempts.length).round();
  }

  /// Creates a new draft practice set for a real assigned class. It starts with no real questions and
  /// no real attempts — a teacher adds real questions before it can be published (see
  /// [_validatePublishable]).
  Future<TeacherCbtActionResult> createDraft({
    required String className,
    required String title,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEditDrafts) {
      return const TeacherCbtActionResult(success: false, message: 'This membership cannot create CBT practice.');
    }
    if (!(await _assignedClassNames(membership)).contains(className)) {
      return const TeacherCbtActionResult(success: false, message: 'You are not assigned to this class.');
    }
    if (title.trim().isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Enter a title for the practice set.');
    }
    final set = TeacherCbtPracticeSet(
      id: 'CBT-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      className: className,
      items: const [],
      durationMinutes: 15,
      state: TeacherCbtSetState.draft,
      attempts: 0,
      averageAccuracy: 0,
      resultMode: 'Show score + topic feedback',
      instructions: teacherCbtInstructions,
    );
    await _persist(membership, set);
    return TeacherCbtActionResult(
      success: true,
      message: 'Practice set created as a draft. Add real questions, then save or publish when ready.',
      set: set,
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
    if (!(await _assignedClassNames(membership)).contains(value.className)) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'This class is not one of your assigned classes.',
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
    if (!(await _assignedClassNames(membership)).contains(value.className)) {
      return const TeacherCbtActionResult(
        success: false,
        message: 'This class is not one of your assigned classes.',
      );
    }
    final validation = _validate(value) ?? _validatePublishable(value);
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
    if (value.durationMinutes <= 0) return 'Duration must be greater than zero.';
    if (value.instructions.trim().isEmpty) return 'Add learner instructions before saving.';
    return null;
  }

  /// A practice set can only reach students with real, complete questions — never an empty or
  /// half-written set that a student could open and find nothing in.
  String? _validatePublishable(TeacherCbtPracticeSet value) {
    if (value.items.isEmpty) return 'Add at least one real question before publishing.';
    if (value.items.any((item) => !item.isValid)) {
      return 'Every question needs a prompt, at least two options and a valid correct answer.';
    }
    return null;
  }

  Future<void> _persist(
    SchoolMembership membership,
    TeacherCbtPracticeSet value,
  ) async {
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _setType,
      entityId: value.id,
    );
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
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
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

}
