import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_assignment_models.dart';
import 'teacher_assignment_demo_data.dart';
import 'teacher_roster.dart';

const teacherAssignmentEntityType = 'academic_assignment';
const teacherAssignmentSubmissionEntityType = 'student_assignment_submission';

class TeacherAssignmentSnapshot {
  const TeacherAssignmentSnapshot({
    required this.assignments,
    required this.draft,
    required this.permissions,
    this.options = const [],
    this.submissions = const [],
    this.canonical = false,
  });

  final List<TeacherAssignment> assignments;
  final TeacherAssignment draft;
  final TeacherAssignmentPermissions permissions;
  final List<TeacherAssignmentOption> options;
  final List<TeacherAssignmentSubmission> submissions;
  final bool canonical;
}

class TeacherAssignmentActionResult {
  const TeacherAssignmentActionResult({
    required this.success,
    required this.message,
    this.assignment,
  });

  final bool success;
  final String message;
  final TeacherAssignment? assignment;
}

class TeacherAssignmentRepository {
  TeacherAssignmentRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _assignmentType = teacherAssignmentEntityType;
  static const _submissionType = teacherAssignmentSubmissionEntityType;
  static const _eventType = 'teacher_assignment_event';
  static const _classAssignmentType = TeacherRoster.assignmentType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  TeacherAssignmentPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherAssignmentPermissions(
      canViewAssignedClassAssignments: teacher,
      canCreateDraft: teacher,
      canQueuePublication: teacher,
      canConfirmPublication: false,
      canConfirmScores: teacher,
      canAutoGrade: false,
    );
  }

  Future<TeacherAssignmentSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) return _loadDemo(membership);

    final options = await _canonicalOptions(membership);
    final currentIds = {for (final option in options) option.classSubjectId};
    final assignmentRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = <TeacherAssignment>[];
    for (final record in assignmentRecords) {
      final parsed = TeacherAssignment.fromJson(record.payload);
      final visible = parsed.authorMembershipId == membership.id ||
          parsed.currentTeacherId == membership.id ||
          currentIds.contains(parsed.classSubjectId);
      if (!visible) continue;
      assignments.add(
        parsed.copyWith(
          pendingSync: record.isDirty,
          serverVersion: record.serverVersion,
        ),
      );
    }
    assignments.sort(_assignmentOrder);

    final assignmentIds = {for (final item in assignments) item.id};
    final submissionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _submissionType,
    );
    final submissions = <TeacherAssignmentSubmission>[];
    for (final record in submissionRecords) {
      final parsed = TeacherAssignmentSubmission.fromJson(record.payload);
      if (!assignmentIds.contains(parsed.assignmentId)) continue;
      if (parsed.state == TeacherSubmissionState.draft) continue;
      submissions.add(
        TeacherAssignmentSubmission(
          id: parsed.id,
          assignmentId: parsed.assignmentId,
          title: parsed.title,
          className: parsed.className,
          subject: parsed.subject,
          studentId: parsed.studentId,
          studentName: parsed.studentName,
          admissionNumber: parsed.admissionNumber,
          state: parsed.state,
          responseText: parsed.responseText,
          maximumScore: parsed.maximumScore,
          attemptNumber: parsed.attemptNumber,
          submittedAt: parsed.submittedAt,
          isLate: parsed.isLate,
          score: parsed.score,
          feedback: parsed.feedback,
          gradedAt: parsed.gradedAt,
          pendingSync: record.isDirty,
          serverVersion: record.serverVersion,
        ),
      );
    }
    submissions.sort((a, b) => (b.submittedAt ?? '').compareTo(a.submittedAt ?? ''));

    final existingDraft = assignments.where((item) => item.state == TeacherAssignmentState.draft).firstOrNull;
    final draft = existingDraft ?? _emptyDraft(options);
    final library = assignments.where((item) => item.id != draft.id).toList(growable: false);
    return TeacherAssignmentSnapshot(
      assignments: library,
      draft: draft,
      permissions: permissionsFor(membership),
      options: options,
      submissions: submissions,
      canonical: true,
    );
  }

  Future<TeacherAssignmentActionResult> saveDraft(TeacherAssignment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canCreateDraft) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'This membership cannot create Teacher assignment drafts.',
      );
    }
    if (!LocalDatabase.blockDemoSeeds) return _saveDemoDraft(membership, draft);
    if (draft.classSubjectId.isEmpty || draft.termId.isEmpty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Choose one of your current class subjects before saving.',
      );
    }
    if (draft.title.trim().isEmpty || draft.instructions.trim().isEmpty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Add an assignment title and instructions before saving.',
      );
    }
    final options = await _canonicalOptions(membership);
    if (!options.any((item) =>
        item.classSubjectId == draft.classSubjectId && item.termId == draft.termId)) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'This class subject is no longer assigned to your Teacher membership.',
      );
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: draft.id,
    );
    if (existing != null) {
      final current = TeacherAssignment.fromJson(existing.payload);
      if (current.state != TeacherAssignmentState.draft) {
        return const TeacherAssignmentActionResult(
          success: false,
          message: 'Published work requires an explicit revision instead of a silent edit.',
        );
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssignmentState.draft,
      version: draft.version + 1,
      updatedAt: now,
      authorMembershipId: draft.authorMembershipId.isEmpty ? membership.id : draft.authorMembershipId,
      currentTeacherId: membership.id,
      pendingSync: true,
      serverVersion: existing?.serverVersion,
    );
    await _persistCanonical(
      membership: membership,
      assignment: updated,
      action: 'saveDraft',
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      localServerVersion: existing?.serverVersion,
      mutationBaseVersion: existing?.isDirty == true ? null : existing?.serverVersion,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment draft saved locally and queued. Publish becomes available after the server acknowledges this draft.',
      assignment: updated,
    );
  }

  Future<TeacherAssignmentActionResult> queuePublication(TeacherAssignment draft) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canQueuePublication) {
      return const TeacherAssignmentActionResult(success: false, message: 'This membership cannot publish Teacher assignments.');
    }
    if (!LocalDatabase.blockDemoSeeds) return _queueDemoPublication(membership, draft);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: draft.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Save and synchronize this draft before publishing it to students.',
      );
    }
    final current = TeacherAssignment.fromJson(existing.payload).copyWith(
      pendingSync: false,
      serverVersion: existing.serverVersion,
    );
    if (current.state != TeacherAssignmentState.draft) {
      return const TeacherAssignmentActionResult(success: false, message: 'Only a synchronized draft can be published.');
    }
    if (draft.title.trim().isEmpty ||
        draft.instructions.trim().isEmpty ||
        draft.maximumScore <= 0 ||
        draft.dueDate.trim().isEmpty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Complete title, instructions, due date/time and maximum score before publication.',
      );
    }

    final queued = draft.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      pendingSync: true,
      serverVersion: existing.serverVersion,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _persistCanonical(
      membership: membership,
      assignment: queued,
      action: 'publish',
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Publication queued. Students have not received it until the server accepts it and freezes the recipient roster.',
      assignment: queued,
    );
  }

  Future<TeacherAssignmentActionResult> revise(TeacherAssignment assignment) async {
    return _queueLifecycleAction(assignment, action: 'revise');
  }

  Future<TeacherAssignmentActionResult> close(TeacherAssignment assignment) async {
    return _queueLifecycleAction(assignment, action: 'close');
  }

  Future<TeacherAssignmentActionResult> _queueLifecycleAction(
    TeacherAssignment assignment, {
    required String action,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Revision and closure are canonical server workflows in connected mode.',
      );
    }
    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
    );
    if (existing == null || existing.serverVersion == null || existing.isDirty) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Synchronize the current assignment before changing its lifecycle.',
      );
    }
    final current = TeacherAssignment.fromJson(existing.payload);
    if (!current.serverPublished) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Only a server-published assignment can be revised or closed.',
      );
    }
    final queued = assignment.copyWith(pendingSync: true, serverVersion: existing.serverVersion);
    await _persistCanonical(
      membership: membership,
      assignment: queued,
      action: action,
      operation: SyncOperation.update,
      localServerVersion: existing.serverVersion,
      mutationBaseVersion: existing.serverVersion,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: action == 'close'
          ? 'Closure queued. The assignment remains published until the server acknowledges the change.'
          : 'Revision queued. The previous learner-facing revision remains authoritative until server acknowledgement.',
      assignment: queued,
    );
  }

  Future<TeacherAssignmentActionResult> gradeSubmission(
    TeacherAssignmentSubmission submission, {
    required double score,
    required String feedback,
  }) async {
    return _markSubmission(submission, action: 'grade', score: score, feedback: feedback);
  }

  Future<TeacherAssignmentActionResult> returnSubmission(
    TeacherAssignmentSubmission submission, {
    required String feedback,
  }) async {
    return _markSubmission(submission, action: 'return', feedback: feedback);
  }

  Future<TeacherAssignmentActionResult> _markSubmission(
    TeacherAssignmentSubmission submission, {
    required String action,
    double? score,
    required String feedback,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!LocalDatabase.blockDemoSeeds) {
      return const TeacherAssignmentActionResult(success: false, message: 'Demo submissions are read-only evidence.');
    }
    if (!submission.markable || submission.pendingSync) {
      return const TeacherAssignmentActionResult(
        success: false,
        message: 'Only synchronized submitted work can be graded or returned.',
      );
    }
    if (action == 'return' && feedback.trim().isEmpty) {
      return const TeacherAssignmentActionResult(success: false, message: 'Add feedback before returning work for revision.');
    }
    if (action == 'grade' && (score == null || score < 0 || score > submission.maximumScore)) {
      return TeacherAssignmentActionResult(
        success: false,
        message: 'Score must be between 0 and ${submission.maximumScore}.',
      );
    }
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _submissionType,
      entityId: submission.id,
    );
    if (record == null || record.serverVersion == null || record.isDirty) {
      return const TeacherAssignmentActionResult(success: false, message: 'Synchronize this submission before marking it.');
    }
    final payload = <String, Object?>{
      'id': submission.id,
      'action': action,
      'score': score,
      'feedback': feedback.trim(),
    };
    final local = Map<String, Object?>.from(record.payload)
      ..['pendingTeacherAction'] = action
      ..['pendingTeacherFeedback'] = feedback.trim()
      ..['pendingTeacherScore'] = score;
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _submissionType,
      entityId: submission.id,
      payload: local,
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _submissionType,
      entityId: submission.id,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: record.serverVersion,
    );
    return TeacherAssignmentActionResult(
      success: true,
      message: action == 'grade'
          ? 'Grade queued. It is not canonical until the server acknowledges it.'
          : 'Return-for-revision queued. The Student sees it only after server acknowledgement.',
    );
  }

  Future<List<TeacherAssignmentOption>> _canonicalOptions(SchoolMembership membership) async {
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _classAssignmentType,
      entityId: membership.id,
    );
    final options = <TeacherAssignmentOption>[];
    for (final raw in (record?.payload['classes'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final item = AssignedClass.fromJson(Map<String, Object?>.from(raw));
      if (item.classSubjectId.isEmpty || item.currentTermId.isEmpty) continue;
      options.add(
        TeacherAssignmentOption(
          classSubjectId: item.classSubjectId,
          termId: item.currentTermId,
          term: item.currentTerm,
          className: item.className,
          subject: item.subject,
          topics: [
            for (final topic in item.topics)
              TeacherAssignmentTopic(id: topic.id, title: topic.title),
          ],
        ),
      );
    }
    options.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return options;
  }

  TeacherAssignment _emptyDraft(List<TeacherAssignmentOption> options) {
    final option = options.firstOrNull;
    return TeacherAssignment(
      id: 'asg-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      className: option?.className ?? '',
      subject: option?.subject ?? '',
      classSubjectId: option?.classSubjectId ?? '',
      termId: option?.termId ?? '',
      term: option?.term ?? '',
      type: TeacherAssignmentType.homework,
      instructions: '',
      dueDate: '',
      maximumScore: 20,
      submissions: 0,
      totalStudents: 0,
      marked: 0,
      lateSubmissions: 0,
      state: TeacherAssignmentState.draft,
    );
  }

  Future<void> _persistCanonical({
    required SchoolMembership membership,
    required TeacherAssignment assignment,
    required String action,
    required SyncOperation operation,
    required int? localServerVersion,
    required int? mutationBaseVersion,
  }) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: assignment.toJson(),
      serverVersion: localServerVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: operation,
      payload: assignment.toMutationJson(action: action),
      baseVersion: mutationBaseVersion,
    );
  }

  Future<TeacherAssignmentSnapshot> _loadDemo(SchoolMembership membership) async {
    await _seedDemoIfNeeded(membership);
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    final assignments = records
        .map((record) => TeacherAssignment.fromJson(record.payload))
        .toList(growable: false);
    final draft = assignments.firstWhere(
      (item) => item.id == teacherAssignmentDraft.id,
      orElse: () => teacherAssignmentDraft,
    );
    final library = assignments.where((item) => item.id != draft.id).toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return TeacherAssignmentSnapshot(
      assignments: library,
      draft: draft,
      permissions: permissionsFor(membership),
    );
  }

  Future<TeacherAssignmentActionResult> _saveDemoDraft(
    SchoolMembership membership,
    TeacherAssignment draft,
  ) async {
    if (!draft.teacherEditable) {
      return const TeacherAssignmentActionResult(success: false, message: 'A queued or published assignment cannot be silently rewritten.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssignmentState.draft,
      version: draft.version + 1,
      updatedAt: now,
    );
    await _persistDemo(membership, updated);
    await _appendDemoEvent(membership, assignment: updated, action: TeacherAssignmentEventAction.savedDraft, occurredAt: now);
    return TeacherAssignmentActionResult(success: true, message: 'Assignment draft saved locally and queued for synchronization.', assignment: updated);
  }

  Future<TeacherAssignmentActionResult> _queueDemoPublication(
    SchoolMembership membership,
    TeacherAssignment draft,
  ) async {
    if (!draft.teacherEditable) {
      return const TeacherAssignmentActionResult(success: false, message: 'This assignment is already queued or published.');
    }
    if (draft.title.trim().isEmpty || draft.instructions.trim().isEmpty || draft.maximumScore <= 0 || draft.dueDate.trim().isEmpty) {
      return const TeacherAssignmentActionResult(success: false, message: 'Complete title, instructions, due date and maximum score before publication.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = draft.copyWith(
      state: TeacherAssignmentState.queuedForPublication,
      version: draft.version + 1,
      updatedAt: now,
      queuedAt: now,
    );
    await _persistDemo(membership, updated);
    await _appendDemoEvent(membership, assignment: updated, action: TeacherAssignmentEventAction.queuedForPublication, occurredAt: now);
    return TeacherAssignmentActionResult(
      success: true,
      message: 'Assignment queued for publication. Student delivery is not confirmed until the server acknowledges it.',
      assignment: updated,
    );
  }

  Future<void> _persistDemo(SchoolMembership membership, TeacherAssignment assignment) async {
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
      entityId: assignment.id,
      payload: assignment.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _assignmentType,
      entityId: assignment.id,
      operation: SyncOperation.update,
      payload: assignment.toJson(),
    );
  }

  Future<void> _appendDemoEvent(
    SchoolMembership membership, {
    required TeacherAssignment assignment,
    required TeacherAssignmentEventAction action,
    required String occurredAt,
  }) async {
    final event = TeacherAssignmentEvent(
      id: '${assignment.id}-${DateTime.now().microsecondsSinceEpoch}',
      assignmentId: assignment.id,
      action: action,
      actorMembershipId: membership.id,
      version: assignment.version,
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
      entityType: _assignmentType,
    );
    if (records.isNotEmpty) return;
    for (final assignment in [...teacherAssignments, teacherAssignmentDraft]) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _assignmentType,
        entityId: assignment.id,
        payload: assignment.toJson(),
      );
    }
  }

  int _assignmentOrder(TeacherAssignment a, TeacherAssignment b) {
    final byDue = b.dueDate.compareTo(a.dueDate);
    if (byDue != 0) return byDue;
    return a.title.compareTo(b.title);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
