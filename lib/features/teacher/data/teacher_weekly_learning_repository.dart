import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_weekly_learning_models.dart';
import 'teacher_weekly_learning_demo_data.dart';

class TeacherWeeklyLearningSnapshot {
  const TeacherWeeklyLearningSnapshot({
    required this.update,
    required this.events,
    required this.permissions,
  });

  final TeacherWeeklyLearningUpdate update;
  final List<TeacherWeeklyLearningEvent> events;
  final TeacherWeeklyLearningPermissions permissions;
}

class TeacherWeeklyLearningActionResult {
  const TeacherWeeklyLearningActionResult({
    required this.success,
    required this.message,
    this.update,
  });

  final bool success;
  final String message;
  final TeacherWeeklyLearningUpdate? update;
}

class TeacherWeeklyLearningRepository {
  TeacherWeeklyLearningRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _updateType = 'teacher_weekly_learning_update';
  static const _eventType = 'teacher_weekly_learning_event';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherWeeklyLearningPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherWeeklyLearningPermissions(
      canViewAssignedClassUpdates: teacher,
      canEditDraft: teacher,
      canQueuePublication: teacher,
      canConfirmParentDelivery: false,
      canIncludePrivateRecords: false,
    );
  }

  Future<TeacherWeeklyLearningSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _updateType,
    );
    final events = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _eventType,
    );

    final update = TeacherWeeklyLearningUpdate.fromJson(records.first.payload);
    final parsedEvents = events
        .map((record) => TeacherWeeklyLearningEvent.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return TeacherWeeklyLearningSnapshot(
      update: update,
      events: parsedEvents,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherWeeklyLearningActionResult> saveDraft(
    TeacherWeeklyLearningUpdate draft,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canEditDraft) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This membership cannot edit Teacher weekly learning drafts.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'A queued or published parent update cannot be silently rewritten. Start an auditable correction workflow instead.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherWeeklyPublicationState.draft,
      version: draft.version + 1,
      updatedAt: now,
    );
    await _persistUpdate(membership, updated);
    await _appendEvent(
      membership,
      update: updated,
      action: TeacherWeeklyEventAction.savedDraft,
      occurredAt: now,
    );

    return TeacherWeeklyLearningActionResult(
      success: true,
      message: 'Weekly learning draft saved locally and queued for synchronization.',
      update: updated,
    );
  }

  Future<TeacherWeeklyLearningActionResult> queuePublication(
    TeacherWeeklyLearningUpdate draft,
  ) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canQueuePublication) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This membership cannot publish Teacher weekly learning updates.',
      );
    }
    if (!draft.teacherEditable) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This update is already queued or published and cannot be silently replaced.',
      );
    }
    if (draft.subjects.isEmpty ||
        draft.subjects.any((item) =>
            item.covered.trim().isEmpty ||
            item.evidence.trim().isEmpty ||
            item.next.trim().isEmpty)) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'Complete actual coverage, evidence and next-step information for every subject before publication.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherWeeklyPublicationState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: now,
      queuedAt: now,
    );
    await _persistUpdate(membership, updated);
    await _appendEvent(
      membership,
      update: updated,
      action: TeacherWeeklyEventAction.queuedForPublication,
      occurredAt: now,
    );

    return TeacherWeeklyLearningActionResult(
      success: true,
      message: 'Weekly update queued for parent publication. Delivery is not confirmed until the server or messaging provider acknowledges it.',
      update: updated,
    );
  }

  Future<void> _persistUpdate(
    SchoolMembership membership,
    TeacherWeeklyLearningUpdate update,
  ) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _updateType,
      entityId: update.id,
      payload: update.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _updateType,
      entityId: update.id,
      operation: SyncOperation.update,
      payload: update.toJson(),
    );
  }

  Future<void> _appendEvent(
    SchoolMembership membership, {
    required TeacherWeeklyLearningUpdate update,
    required TeacherWeeklyEventAction action,
    required String occurredAt,
  }) async {
    final event = TeacherWeeklyLearningEvent(
      id: '${update.id}-${DateTime.now().microsecondsSinceEpoch}',
      updateId: update.id,
      action: action,
      actorMembershipId: membership.id,
      version: update.version,
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
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _updateType,
    );
    if (records.isNotEmpty) return;

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _updateType,
      entityId: teacherWeeklyInitialUpdate.id,
      payload: teacherWeeklyInitialUpdate.toJson(),
    );
  }
}
