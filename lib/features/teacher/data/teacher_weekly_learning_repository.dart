import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_weekly_learning_models.dart';
import 'teacher_roster.dart';
import 'teacher_weekly_learning_demo_data.dart';

class TeacherWeeklyLearningSnapshot {
  const TeacherWeeklyLearningSnapshot({
    required this.update,
    required this.events,
    required this.permissions,
    this.updates = const [],
    this.options = const [],
    this.canonical = false,
  });

  final TeacherWeeklyLearningUpdate update;
  final List<TeacherWeeklyLearningEvent> events;
  final TeacherWeeklyLearningPermissions permissions;
  final List<TeacherWeeklyLearningUpdate> updates;
  final List<TeacherWeeklyLearningOption> options;
  final bool canonical;
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

/// Canonical weekly subject reports live under this entity type. In connected
/// mode the server decides subject/class/Teacher authority, factual learning
/// evidence and whether publication actually succeeded.
const teacherWeeklyLearningUpdateEntityType = 'teacher_weekly_learning_update';

class TeacherWeeklyLearningRepository {
  TeacherWeeklyLearningRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _updateType = teacherWeeklyLearningUpdateEntityType;
  static const _eventType = 'teacher_weekly_learning_event';
  static const _classAssignmentType = TeacherRoster.assignmentType;

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
    if (!LocalDatabase.blockDemoSeeds) {
      return _loadDemo(membership);
    }

    final options = await _canonicalOptions(membership);
    final optionIds = {for (final option in options) option.classSubjectId};
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _updateType,
    );
    final updates = <TeacherWeeklyLearningUpdate>[];
    for (final record in records) {
      final parsed = TeacherWeeklyLearningUpdate.fromJson(record.payload);
      final assignedNow = optionIds.contains(parsed.classSubjectId);
      final visibleToTeacher = parsed.authorMembershipId.isEmpty ||
          parsed.authorMembershipId == membership.id ||
          parsed.currentTeacherId == membership.id ||
          assignedNow;
      if (!visibleToTeacher) continue;
      updates.add(
        parsed.copyWith(
          pendingSync: record.isDirty,
          currentTeacherAuthorized: assignedNow &&
              (parsed.currentTeacherId.isEmpty ||
                  parsed.currentTeacherId == membership.id),
        ),
      );
    }
    updates.sort(_updateOrder);

    final placeholder = updates.isNotEmpty
        ? updates.first
        : const TeacherWeeklyLearningUpdate(
            id: '',
            className: '',
            week: '',
            subjects: [],
            note: '',
            state: TeacherWeeklyPublicationState.draft,
            currentTeacherAuthorized: false,
          );

    return TeacherWeeklyLearningSnapshot(
      update: placeholder,
      updates: updates,
      options: options,
      events: const [],
      permissions: permissionsFor(membership),
      canonical: true,
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

    if (!LocalDatabase.blockDemoSeeds) {
      return _saveDemoDraft(membership, draft);
    }
    if (!draft.canonical || draft.id.isEmpty || draft.subjects.length != 1) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'Choose a real assigned subject and academic week first.',
      );
    }

    final options = await _canonicalOptions(membership);
    if (!options.any((item) =>
        item.classSubjectId == draft.classSubjectId &&
        item.termId == draft.termId)) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This class subject is no longer assigned to your Teacher membership.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _updateType,
      entityId: draft.id,
    );
    final current = existing == null
        ? null
        : TeacherWeeklyLearningUpdate.fromJson(existing.payload).copyWith(
            pendingSync: existing.isDirty,
            currentTeacherAuthorized: true,
          );
    if (current != null && !current.teacherEditable) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'A queued or published family update cannot be silently rewritten.',
      );
    }

    final input = draft.subjects.first;
    final factual = current?.subjectUpdate;
    final subject = TeacherWeeklySubjectUpdate(
      subject: input.subject,
      planned: factual?.planned ?? input.planned,
      covered: factual?.covered ?? input.covered,
      evidence: factual?.evidence ?? input.evidence,
      next: input.next.trim(),
      support: input.support.trim(),
      linkedPlanId: factual?.linkedPlanId ?? input.linkedPlanId,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      subjects: [subject],
      state: TeacherWeeklyPublicationState.draft,
      version: (current?.version ?? draft.version) + 1,
      updatedAt: now,
      authorMembershipId: current?.authorMembershipId.isNotEmpty == true
          ? current!.authorMembershipId
          : membership.id,
      currentTeacherId: membership.id,
      currentTeacherAuthorized: true,
      pendingSync: true,
    );
    await _persistCanonical(
      membership: membership,
      update: updated,
      action: 'saveDraft',
      existingServerVersion: existing?.serverVersion,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
    );
    return TeacherWeeklyLearningActionResult(
      success: true,
      message:
          'Weekly subject draft saved locally and queued. Covered learning and evidence remain server-controlled.',
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

    if (!LocalDatabase.blockDemoSeeds) {
      return _queueDemoPublication(membership, draft);
    }
    if (!draft.teacherEditable || draft.subjects.length != 1) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This weekly subject update is not editable by the current Teacher.',
      );
    }
    final subject = draft.subjects.first;
    if (draft.deliveredLessons < 1) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message:
            'No server-accepted delivered lesson evidence is available for this subject/week yet.',
      );
    }
    if (subject.next.trim().isEmpty) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'Add the next learning focus before publication.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _updateType,
      entityId: draft.id,
    );
    if (existing == null) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'Save and synchronize this weekly draft before publishing it.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final queued = draft.copyWith(
      state: TeacherWeeklyPublicationState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: now,
      queuedAt: now,
      pendingSync: true,
    );
    await _persistCanonical(
      membership: membership,
      update: queued,
      action: 'publish',
      existingServerVersion: existing.serverVersion,
      operation: SyncOperation.update,
    );
    return TeacherWeeklyLearningActionResult(
      success: true,
      message:
          'Weekly subject update queued. It remains unpublished until the server accepts and freezes the family snapshot.',
      update: queued,
    );
  }

  Future<List<TeacherWeeklyLearningOption>> _canonicalOptions(
    SchoolMembership membership,
  ) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classAssignmentType,
      entityId: membership.id,
    );
    final options = <TeacherWeeklyLearningOption>[];
    for (final raw in (record?.payload['classes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = AssignedClass.fromJson(Map<String, Object?>.from(raw));
      if (item.classSubjectId.isEmpty || item.currentTermId.isEmpty) continue;
      options.add(
        TeacherWeeklyLearningOption(
          classSubjectId: item.classSubjectId,
          termId: item.currentTermId,
          term: item.currentTerm,
          className: item.className,
          subject: item.subject,
        ),
      );
    }
    options.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return options;
  }

  Future<void> _persistCanonical({
    required SchoolMembership membership,
    required TeacherWeeklyLearningUpdate update,
    required String action,
    required int? existingServerVersion,
    required SyncOperation operation,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _updateType,
      entityId: update.id,
      payload: update.toJson(),
      serverVersion: existingServerVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _updateType,
      entityId: update.id,
      operation: operation,
      payload: update.toMutationJson(action: action),
      baseVersion: existingServerVersion,
    );
  }

  Future<TeacherWeeklyLearningSnapshot> _loadDemo(
    SchoolMembership membership,
  ) async {
    await _seedDemoIfNeeded(membership);
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
      updates: [update],
      events: parsedEvents,
      permissions: permissionsFor(membership),
      canonical: false,
    );
  }

  Future<TeacherWeeklyLearningActionResult> _saveDemoDraft(
    SchoolMembership membership,
    TeacherWeeklyLearningUpdate draft,
  ) async {
    if (!draft.teacherEditable) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'A queued or published parent update cannot be silently rewritten.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherWeeklyPublicationState.draft,
      version: draft.version + 1,
      updatedAt: now,
    );
    await _persistDemoUpdate(membership, updated);
    await _appendDemoEvent(
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

  Future<TeacherWeeklyLearningActionResult> _queueDemoPublication(
    SchoolMembership membership,
    TeacherWeeklyLearningUpdate draft,
  ) async {
    if (!draft.teacherEditable) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message: 'This update is already queued or published.',
      );
    }
    if (draft.subjects.isEmpty ||
        draft.subjects.any((item) =>
            item.covered.trim().isEmpty ||
            item.evidence.trim().isEmpty ||
            item.next.trim().isEmpty)) {
      return const TeacherWeeklyLearningActionResult(
        success: false,
        message:
            'Complete actual coverage, evidence and next-step information for every subject before publication.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherWeeklyPublicationState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: now,
      queuedAt: now,
    );
    await _persistDemoUpdate(membership, updated);
    await _appendDemoEvent(
      membership,
      update: updated,
      action: TeacherWeeklyEventAction.queuedForPublication,
      occurredAt: now,
    );
    return TeacherWeeklyLearningActionResult(
      success: true,
      message:
          'Weekly update queued for parent publication. Delivery is not confirmed until the server or messaging provider acknowledges it.',
      update: updated,
    );
  }

  Future<void> _persistDemoUpdate(
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

  Future<void> _appendDemoEvent(
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

  Future<void> _seedDemoIfNeeded(SchoolMembership membership) async {
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

  int _updateOrder(
    TeacherWeeklyLearningUpdate a,
    TeacherWeeklyLearningUpdate b,
  ) {
    final byWeek = b.weekStart.compareTo(a.weekStart);
    if (byWeek != 0) return byWeek;
    final byClass = a.className.compareTo(b.className);
    return byClass != 0
        ? byClass
        : (a.subjectUpdate?.subject ?? '')
            .compareTo(b.subjectUpdate?.subject ?? '');
  }
}
