import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_cbt_models.dart';
import 'teacher_cbt_demo_data.dart' show teacherCbtInstructions;
import 'teacher_roster.dart';

/// The canonical, server-syncable entity type every role reads/writes a CBT
/// test definition through (Teacher-authored, embedded questions). A
/// Student never receives correctIndex/explanation until their own attempt
/// is submitted - see the backend's apps.cbt.visibility, mirrored nowhere on
/// the client since redaction is a server responsibility.
const teacherCbtTestEntityType = 'academic_cbt_test';

/// One recipient's own attempt, started/answered/submitted independently -
/// mirrors how a Student assignment submission is its own entity, not
/// embedded in the test.
const teacherCbtAttemptEntityType = 'academic_cbt_attempt';

class TeacherCbtSnapshot {
  const TeacherCbtSnapshot({
    required this.tests,
    required this.draft,
    required this.permissions,
    this.options = const [],
    this.canonical = false,
  });

  final List<TeacherCbtTest> tests;
  final TeacherCbtTest draft;
  final TeacherCbtPermissions permissions;

  /// The real class subjects this Teacher currently teaches. A CBT test can
  /// only be created for one of these.
  final List<TeacherCbtOption> options;
  final bool canonical;
}

class TeacherCbtActionResult {
  const TeacherCbtActionResult({required this.success, required this.message, this.test});

  final bool success;
  final String message;
  final TeacherCbtTest? test;
}

class TeacherCbtRepository {
  TeacherCbtRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _entityType = teacherCbtTestEntityType;
  static const _classAssignmentType = TeacherRoster.assignmentType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherCbtPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherCbtPermissions(
      canViewAssignedClassTests: teacher,
      canCreateDraft: teacher,
      canPublish: teacher,
      canClose: teacher,
      canUsePracticeEvidence: teacher,
    );
  }

  Future<TeacherCbtSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) return _loadDemo(membership);

    final options = await _canonicalOptions(membership);
    final currentIds = {for (final option in options) option.classSubjectId};
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );
    final tests = <TeacherCbtTest>[];
    for (final record in records) {
      final parsed = TeacherCbtTest.fromJson(record.payload);
      final visible = parsed.authorMembershipId == membership.id ||
          parsed.currentTeacherId == membership.id ||
          currentIds.contains(parsed.classSubjectId);
      if (!visible) continue;
      tests.add(parsed.copyWith(pendingSync: record.isDirty, serverVersion: record.serverVersion));
    }
    tests.sort(_order);

    final existingDraft = tests.where((t) => t.state == TeacherCbtTestState.draft).firstOrNull;
    final draft = existingDraft ?? _emptyDraft(options);
    final library = tests.where((t) => t.id != draft.id).toList(growable: false);
    return TeacherCbtSnapshot(
      tests: library,
      draft: draft,
      permissions: permissionsFor(membership),
      options: options,
      canonical: true,
    );
  }

  Future<TeacherCbtActionResult> saveDraft(TeacherCbtTest draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateDraft) {
      return const TeacherCbtActionResult(success: false, message: 'This membership cannot create CBT drafts.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _saveDemoDraft(membership, draft);

    if (draft.classSubjectId.isEmpty || draft.termId.isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Choose one of your current class subjects before saving.');
    }
    if (draft.title.trim().isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Enter a title for the CBT test.');
    }
    final options = await _canonicalOptions(membership);
    if (!options.any((o) => o.classSubjectId == draft.classSubjectId && o.termId == draft.termId)) {
      return const TeacherCbtActionResult(success: false, message: 'This class subject is no longer assigned to your Teacher membership.');
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: draft.id,
    );
    if (existing != null) {
      final current = TeacherCbtTest.fromJson(existing.payload);
      if (current.state != TeacherCbtTestState.draft) {
        return const TeacherCbtActionResult(success: false, message: 'A published or closed CBT test requires an explicit revision instead of a silent edit.');
      }
    }

    final updated = draft.copyWith(
      state: TeacherCbtTestState.draft,
      version: draft.version + 1,
      authorMembershipId: draft.authorMembershipId.isEmpty ? membership.id : draft.authorMembershipId,
      currentTeacherId: membership.id,
      pendingSync: true,
      serverVersion: existing?.serverVersion,
    );
    await _persist(
      membership: membership,
      test: updated,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      localServerVersion: existing?.serverVersion,
      mutationPayload: updated.toDefinitionMutationJson(action: 'saveDraft'),
      mutationBaseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return TeacherCbtActionResult(
      success: true,
      message: 'CBT draft saved locally and queued. Publishing opens it to students once the server acknowledges this draft.',
      test: updated,
    );
  }

  Future<TeacherCbtActionResult> publish(TeacherCbtTest draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canPublish) {
      return const TeacherCbtActionResult(success: false, message: 'This membership cannot publish CBT tests.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _publishDemo(membership, draft);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: draft.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherCbtActionResult(success: false, message: 'Save and synchronize this draft before publishing it.');
    }
    final current = TeacherCbtTest.fromJson(existing.payload);
    if (current.state != TeacherCbtTestState.draft) {
      return const TeacherCbtActionResult(success: false, message: 'Only a synchronized draft can be published.');
    }
    if (draft.title.trim().isEmpty || draft.durationMinutes <= 0) {
      return const TeacherCbtActionResult(success: false, message: 'Add a title and a duration above zero before publishing.');
    }
    if (draft.questions.isEmpty || draft.questions.any((q) => !q.isValid)) {
      return const TeacherCbtActionResult(success: false, message: 'Every question needs a prompt, at least two options and a chosen correct answer.');
    }

    final queued = draft.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persist(
      membership: membership,
      test: queued,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationPayload: queued.toDefinitionMutationJson(action: 'publish'),
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherCbtActionResult(
      success: true,
      message: 'Publication queued. Students cannot start it until the server accepts it and freezes the eligible-student roster.',
      test: queued,
    );
  }

  Future<TeacherCbtActionResult> close(TeacherCbtTest test) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canClose) {
      return const TeacherCbtActionResult(success: false, message: 'This membership cannot close CBT tests.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _closeDemo(membership, test);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: test.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherCbtActionResult(success: false, message: 'Synchronize this test before closing it.');
    }
    final current = TeacherCbtTest.fromJson(existing.payload);
    if (current.state != TeacherCbtTestState.published) {
      return const TeacherCbtActionResult(success: false, message: 'Only a published CBT test can be closed.');
    }
    final queued = test.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persist(
      membership: membership,
      test: queued,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationPayload: {'id': queued.id, 'action': 'close'},
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherCbtActionResult(success: true, message: 'Closure queued. No new attempt can start once the server acknowledges it.', test: queued);
  }

  Future<List<TeacherCbtOption>> _canonicalOptions(SchoolMembership membership) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classAssignmentType,
      entityId: membership.id,
    );
    final options = <TeacherCbtOption>[];
    for (final raw in (record?.payload['classes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = AssignedClass.fromJson(Map<String, Object?>.from(raw));
      if (item.classSubjectId.isEmpty || item.currentTermId.isEmpty) continue;
      options.add(
        TeacherCbtOption(
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

  TeacherCbtTest _emptyDraft(List<TeacherCbtOption> options) {
    final option = options.firstOrNull;
    return TeacherCbtTest(
      id: 'cbt-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      className: option?.className ?? '',
      subject: option?.subject ?? '',
      classSubjectId: option?.classSubjectId ?? '',
      termId: option?.termId ?? '',
      term: option?.term ?? '',
      questions: const [],
      durationMinutes: 15,
      state: TeacherCbtTestState.draft,
      resultMode: TeacherCbtResultMode.scoreOnly,
      instructions: teacherCbtInstructions,
    );
  }

  Future<void> _persist({
    required SchoolMembership membership,
    required TeacherCbtTest test,
    required SyncOperation operation,
    required int? localServerVersion,
    required Map<String, Object?> mutationPayload,
    required int? mutationBaseVersion,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: test.id,
      payload: test.toJson(),
      serverVersion: localServerVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: test.id,
      operation: operation,
      payload: mutationPayload,
      baseVersion: mutationBaseVersion,
    );
  }

  // --- Standalone demo mode -------------------------------------------------
  //
  // No demo test is pre-seeded, so a fresh demo session honestly starts
  // empty until the Teacher creates one - matching the same precedent
  // Assessments already established (see TeacherAssessmentRepository).

  Future<TeacherCbtSnapshot> _loadDemo(SchoolMembership membership) async {
    final assigned = await _roster.assignedClasses(membership);
    final options = [
      for (final c in assigned)
        TeacherCbtOption(classSubjectId: '', termId: '', term: '', className: c.className, subject: c.subject),
    ];
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: _entityType);
    final attemptRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: teacherCbtAttemptEntityType);
    final attempts = attemptRecords.map((r) => TeacherCbtAttempt.fromJson(r.payload)).toList(growable: false);
    final tests = records
        .map((record) => TeacherCbtTest.fromJson(record.payload))
        .where((item) => item.authorMembershipId == membership.id)
        .map((item) => _withLiveEvidence(item, attempts))
        .toList(growable: false)
      ..sort(_order);
    final existingDraft = tests.where((t) => t.state == TeacherCbtTestState.draft).firstOrNull;
    final draft = existingDraft ?? _emptyDemoDraft(membership, options);
    final library = tests.where((t) => t.id != draft.id).toList(growable: false);
    return TeacherCbtSnapshot(tests: library, draft: draft, permissions: permissionsFor(membership), options: options);
  }

  /// A demo Student's submission never goes through this Teacher's own
  /// actions, so evidence is recomputed live from real attempts on every
  /// load rather than trusted from whatever this repository last persisted -
  /// the same reason the canonical serializer always recomputes it too.
  TeacherCbtTest _withLiveEvidence(TeacherCbtTest test, List<TeacherCbtAttempt> attempts) {
    if (test.state == TeacherCbtTestState.draft) return test;
    final mine = attempts.where((a) => a.testId == test.id && a.submitted).toList(growable: false);
    if (mine.isEmpty) return test;
    final totalPercent = mine.fold<double>(
      0,
      (sum, a) => sum + (a.questionCount == 0 ? 0 : (a.score ?? 0) / a.questionCount * 100),
    );
    return test.copyWith(submittedCount: mine.length, averageScorePercent: totalPercent / mine.length);
  }

  TeacherCbtTest _emptyDemoDraft(SchoolMembership membership, List<TeacherCbtOption> options) {
    final option = options.firstOrNull;
    return TeacherCbtTest(
      id: 'cbt-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      className: option?.className ?? '',
      subject: option?.subject ?? '',
      questions: const [],
      durationMinutes: 15,
      state: TeacherCbtTestState.draft,
      resultMode: TeacherCbtResultMode.scoreOnly,
      instructions: teacherCbtInstructions,
      authorMembershipId: membership.id,
      currentTeacherId: membership.id,
    );
  }

  Future<TeacherCbtActionResult> _saveDemoDraft(SchoolMembership membership, TeacherCbtTest draft) async {
    if (draft.className.trim().isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Choose one of your classes before saving.');
    }
    if (draft.title.trim().isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'Enter a title for the CBT test.');
    }
    final existing = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: _entityType, entityId: draft.id);
    if (existing != null && TeacherCbtTest.fromJson(existing.payload).state != TeacherCbtTestState.draft) {
      return const TeacherCbtActionResult(success: false, message: 'A published or closed CBT test cannot be silently rewritten.');
    }
    final updated = draft.copyWith(
      state: TeacherCbtTestState.draft,
      version: draft.version + 1,
      authorMembershipId: membership.id,
      currentTeacherId: membership.id,
    );
    await _persistDemo(membership, updated);
    return TeacherCbtActionResult(success: true, message: 'CBT draft saved locally and queued for synchronization.', test: updated);
  }

  Future<TeacherCbtActionResult> _publishDemo(SchoolMembership membership, TeacherCbtTest draft) async {
    if (!draft.teacherEditable) {
      return const TeacherCbtActionResult(success: false, message: 'This test is already published or closed.');
    }
    if (draft.title.trim().isEmpty || draft.durationMinutes <= 0) {
      return const TeacherCbtActionResult(success: false, message: 'Add a title and a duration above zero before publishing.');
    }
    if (draft.questions.isEmpty || draft.questions.any((q) => !q.isValid)) {
      return const TeacherCbtActionResult(success: false, message: 'Every question needs a prompt, at least two options and a chosen correct answer.');
    }
    final students = await _roster.studentsIn(draft.className);
    if (students.isEmpty) {
      return const TeacherCbtActionResult(success: false, message: 'There are no students on the register for this class yet.');
    }
    final updated = draft.copyWith(
      state: TeacherCbtTestState.published,
      version: draft.version + 1,
      publishedAt: DateTime.now().toUtc().toIso8601String(),
      totalRecipients: students.length,
    );
    await _persistDemo(membership, updated);

    // One attempt record per real roster student, mirroring how the
    // canonical server births each attempt at publish time - a demo Student
    // only ever updates an existing record too, never creates their own.
    for (final student in students) {
      final attempt = TeacherCbtAttempt(
        id: 'cbt-attempt-${updated.id}-${student.id}',
        testId: updated.id,
        testTitle: updated.title,
        className: updated.className,
        subject: updated.subject,
        durationMinutes: updated.durationMinutes,
        questionCount: updated.questions.length,
        studentId: student.id,
        studentName: student.name,
      );
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: teacherCbtAttemptEntityType,
        entityId: attempt.id,
        payload: attempt.toJson(),
      );
    }
    return TeacherCbtActionResult(success: true, message: 'CBT test published locally. Your class can start it now.', test: updated);
  }

  Future<TeacherCbtActionResult> _closeDemo(SchoolMembership membership, TeacherCbtTest test) async {
    if (test.state != TeacherCbtTestState.published) {
      return const TeacherCbtActionResult(success: false, message: 'Only a published CBT test can be closed.');
    }
    final updated = test.copyWith(state: TeacherCbtTestState.closed, version: test.version + 1, closedAt: DateTime.now().toUtc().toIso8601String());
    await _persistDemo(membership, updated);
    return TeacherCbtActionResult(success: true, message: 'CBT test closed locally. No new attempt can start.', test: updated);
  }

  Future<void> _persistDemo(SchoolMembership membership, TeacherCbtTest test) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: test.id,
      payload: test.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: test.id,
      operation: SyncOperation.update,
      payload: test.toJson(),
    );

    // Real evidence recomputed live from real attempts, matching how canonical
    // averageScorePercent is always server-computed rather than trusted from
    // whatever this Teacher last persisted on the test itself.
    if (test.state != TeacherCbtTestState.draft) {
      final attemptRecords = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: teacherCbtAttemptEntityType);
      final attempts = attemptRecords
          .map((r) => TeacherCbtAttempt.fromJson(r.payload))
          .where((a) => a.testId == test.id && a.submitted)
          .toList(growable: false);
      if (attempts.isNotEmpty) {
        final totalPercent = attempts.fold<double>(
          0,
          (sum, a) => sum + (a.questionCount == 0 ? 0 : (a.score ?? 0) / a.questionCount * 100),
        );
        final recomputed = test.copyWith(submittedCount: attempts.length, averageScorePercent: totalPercent / attempts.length);
        if (recomputed.submittedCount != test.submittedCount || recomputed.averageScorePercent != test.averageScorePercent) {
          await _localDatabase.upsertLocalRecord(
            tenantId: membership.schoolId,
            entityType: _entityType,
            entityId: recomputed.id,
            payload: recomputed.toJson(),
            isDirty: true,
          );
        }
      }
    }
  }

  int _order(TeacherCbtTest a, TeacherCbtTest b) {
    final byUpdated = (b.publishedAt ?? '').compareTo(a.publishedAt ?? '');
    if (byUpdated != 0) return byUpdated;
    return a.title.compareTo(b.title);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
