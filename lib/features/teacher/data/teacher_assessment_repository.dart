import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_assessment_models.dart';
import 'teacher_roster.dart';

/// The canonical, server-syncable entity type every role (Teacher, Student,
/// Parent, Principal, Administrator/Proprietor) reads and writes an
/// assessment through. One entity holds the whole definition plus its
/// embedded per-student entries, matching how a Teacher actually works with
/// one assessment: many students' marks entered and saved together, not one
/// sync mutation per student.
const teacherAssessmentEntityType = 'academic_assessment';

class TeacherAssessmentSnapshot {
  const TeacherAssessmentSnapshot({
    required this.assessments,
    required this.draft,
    required this.permissions,
    this.options = const [],
    this.canonical = false,
  });

  /// The Teacher's own assessments (authored by them or for a class subject
  /// they currently teach), most recent first, excluding [draft].
  final List<TeacherAssessment> assessments;
  final TeacherAssessment draft;
  final TeacherAssessmentPermissions permissions;

  /// The real class subjects this Teacher currently teaches, from the same
  /// canonical Teaching Assignment source used across every other Teacher
  /// feature. An assessment can only be created for one of these.
  final List<TeacherAssessmentOption> options;
  final bool canonical;
}

class TeacherAssessmentActionResult {
  const TeacherAssessmentActionResult({
    required this.success,
    required this.message,
    this.assessment,
  });

  final bool success;
  final String message;
  final TeacherAssessment? assessment;
}

class TeacherAssessmentRepository {
  TeacherAssessmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _entityType = teacherAssessmentEntityType;
  static const _classAssignmentType = TeacherRoster.assignmentType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherAssessmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssessmentPermissions(
      canViewAssignedClassAssessments: teacher,
      canCreateDraft: teacher,
      canPublish: teacher,
      canEnterScores: teacher,
      canSubmitScores: teacher,
      canCorrectScores: teacher,
      canLockScores: false,
      canReleaseResults: false,
      canAiAlterMarks: false,
    );
  }

  Future<TeacherAssessmentSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) return _loadDemo(membership);

    final options = await _canonicalOptions(membership);
    final currentIds = {for (final option in options) option.classSubjectId};
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );
    final assessments = <TeacherAssessment>[];
    for (final record in records) {
      final parsed = TeacherAssessment.fromJson(record.payload);
      final visible = parsed.authorMembershipId == membership.id ||
          parsed.currentTeacherId == membership.id ||
          currentIds.contains(parsed.classSubjectId);
      if (!visible) continue;
      assessments.add(
        parsed.copyWith(pendingSync: record.isDirty, serverVersion: record.serverVersion),
      );
    }
    assessments.sort(_order);

    final existingDraft = assessments.where((a) => a.state == TeacherAssessmentState.draft).firstOrNull;
    final draft = existingDraft ?? _emptyDraft(options);
    final library = assessments.where((a) => a.id != draft.id).toList(growable: false);
    return TeacherAssessmentSnapshot(
      assessments: library,
      draft: draft,
      permissions: permissionsFor(membership),
      options: options,
      canonical: true,
    );
  }

  Future<TeacherAssessmentActionResult> saveDraft(TeacherAssessment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateDraft) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This membership cannot create assessment drafts.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) return _saveDemoDraft(membership, draft);

    if (draft.classSubjectId.isEmpty || draft.termId.isEmpty) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Choose one of your current class subjects before saving.',
      );
    }
    if (draft.title.trim().isEmpty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Enter a title for the assessment.');
    }
    final options = await _canonicalOptions(membership);
    if (!options.any((o) => o.classSubjectId == draft.classSubjectId && o.termId == draft.termId)) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'This class subject is no longer assigned to your Teacher membership.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: draft.id,
    );
    if (existing != null) {
      final current = TeacherAssessment.fromJson(existing.payload);
      if (current.state != TeacherAssessmentState.draft) {
        return const TeacherAssessmentActionResult(
          success: false,
          message: 'A published assessment requires an explicit revision instead of a silent edit.',
        );
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssessmentState.draft,
      version: draft.version + 1,
      updatedAt: now,
      authorMembershipId: draft.authorMembershipId.isEmpty ? membership.id : draft.authorMembershipId,
      currentTeacherId: membership.id,
      pendingSync: true,
      serverVersion: existing?.serverVersion,
    );
    await _persist(
      membership: membership,
      assessment: updated,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      localServerVersion: existing?.serverVersion,
      mutationPayload: updated.toDefinitionMutationJson(action: 'saveDraft'),
      mutationBaseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment draft saved locally and queued. Publishing opens it for scoring once the server acknowledges this draft.',
      assessment: updated,
    );
  }

  Future<TeacherAssessmentActionResult> publish(TeacherAssessment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canPublish) {
      return const TeacherAssessmentActionResult(success: false, message: 'This membership cannot publish assessments.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _publishDemo(membership, draft);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: draft.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Save and synchronize this draft before publishing it.',
      );
    }
    final current = TeacherAssessment.fromJson(existing.payload);
    if (current.state != TeacherAssessmentState.draft) {
      return const TeacherAssessmentActionResult(success: false, message: 'Only a synchronized draft can be published.');
    }
    if (draft.title.trim().isEmpty || draft.maximumScore <= 0) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Add a title and a maximum score above zero before publishing.',
      );
    }

    final queued = draft.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persist(
      membership: membership,
      assessment: queued,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationPayload: queued.toDefinitionMutationJson(action: 'publish'),
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Publication queued. Scores cannot be entered until the server accepts it and freezes the eligible-student roster.',
      assessment: queued,
    );
  }

  Future<TeacherAssessmentActionResult> saveScores(TeacherAssessment assessment) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canEnterScores) {
      return const TeacherAssessmentActionResult(success: false, message: 'This membership cannot enter assessment scores.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _saveDemoScores(membership, assessment);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Synchronize this assessment before entering scores.');
    }
    final current = TeacherAssessment.fromJson(existing.payload);
    if (!current.scoresEditable) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Scores can only be entered while the assessment is open (published).',
      );
    }
    final invalid = assessment.entries.where(
      (e) => e.score != null && (e.score! < 0 || e.score! > assessment.maximumScore),
    );
    if (invalid.isNotEmpty) {
      return TeacherAssessmentActionResult(
        success: false,
        message: 'Every score must stay between 0 and ${assessment.maximumScore}.',
      );
    }

    final queued = assessment.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persist(
      membership: membership,
      assessment: queued,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationPayload: {
        'id': queued.id,
        'action': 'saveScores',
        'entries': queued.entries.map((e) => e.toEntryMutationJson()).toList(),
      },
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      assessment: queued,
    );
  }

  Future<TeacherAssessmentActionResult> submit(TeacherAssessment assessment) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canSubmitScores) {
      return const TeacherAssessmentActionResult(success: false, message: 'This membership cannot submit assessment scores.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _submitDemo(membership, assessment);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Synchronize this assessment before submitting it.');
    }
    final current = TeacherAssessment.fromJson(existing.payload);
    if (!current.canSubmit) {
      return const TeacherAssessmentActionResult(success: false, message: 'Only an open, published assessment can be submitted.');
    }

    final queued = assessment.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persist(
      membership: membership,
      assessment: queued,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationPayload: {'id': queued.id, 'action': 'submit'},
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted for review and queued for synchronization. They are not locked or released yet - '
          'that is a separate Administrator/Proprietor action.',
      assessment: queued,
    );
  }

  /// An explicit, audited score change after normal entry has closed off
  /// (submitted, locked or already released). Never a silent overwrite.
  Future<TeacherAssessmentActionResult> correctScore(
    TeacherAssessment assessment, {
    required String studentId,
    required double? score,
    required String comment,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCorrectScores) {
      return const TeacherAssessmentActionResult(success: false, message: 'This membership cannot correct assessment scores.');
    }
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Score correction after submission is a canonical server workflow in connected mode.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Synchronize this assessment before correcting a score.');
    }
    final current = TeacherAssessment.fromJson(existing.payload);
    if (!current.canCorrect) {
      return const TeacherAssessmentActionResult(
        success: false,
        message: 'Use ordinary score entry while the assessment is still open, not a correction.',
      );
    }
    if (score != null && (score < 0 || score > assessment.maximumScore)) {
      return TeacherAssessmentActionResult(success: false, message: 'Score must be between 0 and ${assessment.maximumScore}.');
    }

    final payload = <String, Object?>{
      'id': assessment.id,
      'action': 'correctScore',
      'studentId': studentId,
      'score': score,
      'comment': comment.trim(),
    };
    final localEntries = current.entries
        .map((e) => e.studentId == studentId ? e.copyWith(score: score, clearScore: score == null) : e)
        .toList(growable: false);
    final local = current.copyWith(entries: localEntries, pendingSync: true, serverVersion: existing.serverVersion);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
      payload: local.toJson(),
      serverVersion: existing.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: assessment.id,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: existing.serverVersion,
    );
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Correction queued and will be recorded with the previous value once the server accepts it.',
      assessment: local,
    );
  }

  Future<List<TeacherAssessmentOption>> _canonicalOptions(SchoolMembership membership) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classAssignmentType,
      entityId: membership.id,
    );
    final options = <TeacherAssessmentOption>[];
    for (final raw in (record?.payload['classes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = AssignedClass.fromJson(Map<String, Object?>.from(raw));
      if (item.classSubjectId.isEmpty || item.currentTermId.isEmpty) continue;
      options.add(
        TeacherAssessmentOption(
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

  TeacherAssessment _emptyDraft(List<TeacherAssessmentOption> options) {
    final option = options.firstOrNull;
    return TeacherAssessment(
      id: 'assessment-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      className: option?.className ?? '',
      subject: option?.subject ?? '',
      classSubjectId: option?.classSubjectId ?? '',
      termId: option?.termId ?? '',
      term: option?.term ?? '',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
      state: TeacherAssessmentState.draft,
      entries: const [],
    );
  }

  Future<void> _persist({
    required SchoolMembership membership,
    required TeacherAssessment assessment,
    required SyncOperation operation,
    required int? localServerVersion,
    required Map<String, Object?> mutationPayload,
    required int? mutationBaseVersion,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
      payload: assessment.toJson(),
      serverVersion: localServerVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: assessment.id,
      operation: operation,
      payload: mutationPayload,
      baseVersion: mutationBaseVersion,
    );
  }

  // --- Standalone demo mode -------------------------------------------------
  //
  // No demo assessment is pre-seeded (there never was one in this feature),
  // so a fresh demo session honestly starts empty until the Teacher creates
  // one. Locking and release stay canonical-only, matching how revision and
  // closure already work for demo Assignments: standalone demo shows the
  // Teacher's own open/submitted work, not a fabricated official release.

  Future<TeacherAssessmentSnapshot> _loadDemo(SchoolMembership membership) async {
    final assigned = await _roster.assignedClasses(membership);
    final options = [
      for (final c in assigned)
        TeacherAssessmentOption(
          classSubjectId: '',
          termId: '',
          term: '',
          className: c.className,
          subject: '',
        ),
    ];
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );
    final assessments = records
        .map((record) => TeacherAssessment.fromJson(record.payload))
        .where((item) => item.authorMembershipId == membership.id)
        .toList(growable: false)
      ..sort(_order);
    final existingDraft = assessments.where((a) => a.state == TeacherAssessmentState.draft).firstOrNull;
    final draft = existingDraft ?? _emptyDemoDraft(membership, options);
    final library = assessments.where((a) => a.id != draft.id).toList(growable: false);
    return TeacherAssessmentSnapshot(
      assessments: library,
      draft: draft,
      permissions: permissionsFor(membership),
      options: options,
    );
  }

  TeacherAssessment _emptyDemoDraft(SchoolMembership membership, List<TeacherAssessmentOption> options) {
    final option = options.firstOrNull;
    return TeacherAssessment(
      id: 'assessment-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      className: option?.className ?? '',
      subject: '',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
      state: TeacherAssessmentState.draft,
      entries: const [],
      authorMembershipId: membership.id,
      currentTeacherId: membership.id,
    );
  }

  Future<TeacherAssessmentActionResult> _saveDemoDraft(SchoolMembership membership, TeacherAssessment draft) async {
    if (draft.className.trim().isEmpty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Choose one of your classes before saving.');
    }
    if (draft.title.trim().isEmpty) {
      return const TeacherAssessmentActionResult(success: false, message: 'Enter a title for the assessment.');
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: draft.id,
    );
    if (existing != null && TeacherAssessment.fromJson(existing.payload).state != TeacherAssessmentState.draft) {
      return const TeacherAssessmentActionResult(success: false, message: 'A published assessment cannot be silently rewritten.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssessmentState.draft,
      version: draft.version + 1,
      updatedAt: now,
      authorMembershipId: membership.id,
      currentTeacherId: membership.id,
    );
    await _persistDemo(membership, updated);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment draft saved locally and queued for synchronization.',
      assessment: updated,
    );
  }

  Future<TeacherAssessmentActionResult> _publishDemo(SchoolMembership membership, TeacherAssessment draft) async {
    if (!draft.teacherEditable) {
      return const TeacherAssessmentActionResult(success: false, message: 'This assessment is already open, submitted or locked.');
    }
    if (draft.title.trim().isEmpty || draft.maximumScore <= 0) {
      return const TeacherAssessmentActionResult(success: false, message: 'Add a title and a maximum score above zero before publishing.');
    }
    final students = await _roster.studentsIn(draft.className);
    if (students.isEmpty) {
      return const TeacherAssessmentActionResult(success: false, message: 'There are no students on the register for this class yet.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssessmentState.published,
      version: draft.version + 1,
      updatedAt: now,
      entries: [
        for (final s in students) TeacherAssessmentEntry(studentId: s.id, studentName: s.name),
      ],
      totalStudents: students.length,
    );
    await _persistDemo(membership, updated);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Assessment published locally. Enter scores below and save progress or submit when ready.',
      assessment: updated,
    );
  }

  Future<TeacherAssessmentActionResult> _saveDemoScores(SchoolMembership membership, TeacherAssessment assessment) async {
    if (!assessment.scoresEditable) {
      return const TeacherAssessmentActionResult(success: false, message: 'Scores can only be entered while the assessment is open.');
    }
    final invalid = assessment.entries.where((e) => e.score != null && (e.score! < 0 || e.score! > assessment.maximumScore));
    if (invalid.isNotEmpty) {
      return TeacherAssessmentActionResult(success: false, message: 'Every score must stay between 0 and ${assessment.maximumScore}.');
    }
    final entered = assessment.entries.where((e) => e.score != null).length;
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = assessment.copyWith(version: assessment.version + 1, updatedAt: now, entered: entered);
    await _persistDemo(membership, updated);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Score-entry progress saved locally and queued for synchronization.',
      assessment: updated,
    );
  }

  Future<TeacherAssessmentActionResult> _submitDemo(SchoolMembership membership, TeacherAssessment assessment) async {
    if (!assessment.canSubmit) {
      return const TeacherAssessmentActionResult(success: false, message: 'Only an open, published assessment can be submitted.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = assessment.copyWith(state: TeacherAssessmentState.submitted, version: assessment.version + 1, updatedAt: now, submittedAt: now);
    await _persistDemo(membership, updated);
    return TeacherAssessmentActionResult(
      success: true,
      message: 'Scores submitted locally for review or locking and queued for synchronization. They are not locked or released yet.',
      assessment: updated,
    );
  }

  Future<void> _persistDemo(SchoolMembership membership, TeacherAssessment assessment) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: assessment.id,
      payload: assessment.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: assessment.id,
      operation: SyncOperation.update,
      payload: assessment.toJson(),
    );
  }

  int _order(TeacherAssessment a, TeacherAssessment b) {
    final byUpdated = (b.updatedAt ?? '').compareTo(a.updatedAt ?? '');
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
