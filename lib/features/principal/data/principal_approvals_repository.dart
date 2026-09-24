import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../domain/principal_approvals_models.dart';

class PrincipalApprovalsSnapshot {
  const PrincipalApprovalsSnapshot({
    required this.items,
    required this.decisions,
    required this.permissions,
  });

  final List<PrincipalApprovalItem> items;
  final List<PrincipalApprovalDecision> decisions;
  final PrincipalApprovalPermissions permissions;

  int get pendingCount =>
      items.where((item) => item.status == PrincipalApprovalStatus.pending).length;
  int get highPriorityPendingCount => items
      .where(
        (item) =>
            item.status == PrincipalApprovalStatus.pending &&
            item.priority == PrincipalApprovalPriority.high,
      )
      .length;
  int get approvedCount =>
      items.where((item) => item.status == PrincipalApprovalStatus.approved).length;
  int get returnedCount =>
      items.where((item) => item.status == PrincipalApprovalStatus.returned).length;
}

class PrincipalApprovalActionResult {
  const PrincipalApprovalActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class PrincipalApprovalsRepository {
  PrincipalApprovalsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _db = localDatabase,
        _session = schoolSession;

  static const assessmentDecisionType = 'principal_submission_review';
  static const lessonPlanReviewType = 'lesson_plan_review';
  static const lessonPlanType = 'teacher_lesson_plan';
  static const assessmentType = 'teacher_assessment_score_sheet';

  final LocalDatabase _db;
  final SchoolSessionController _session;

  PrincipalApprovalPermissions permissionsFor(SchoolMembership membership) =>
      PrincipalApprovalPermissions(
        canViewSecondaryApprovals: membership.role == SchoolRole.principal,
        canDecideSecondaryApprovals: membership.role == SchoolRole.principal,
        canReleaseReportsDirectly: false,
        canRewriteScoresDirectly: false,
        canManagePrimary: false,
      );

  Future<PrincipalApprovalsSnapshot> load() async {
    final membership = _session.requireActiveMembership();
    final permissions = permissionsFor(membership);
    if (!permissions.canViewSecondaryApprovals) {
      return PrincipalApprovalsSnapshot(
        items: const [],
        decisions: const [],
        permissions: permissions,
      );
    }

    final register = await AdministratorStudentsRepository(
      localDatabase: _db,
      schoolSession: _session,
    ).load();
    final secondaryClasses = {
      for (final student in register.students)
        if (student.status != AdministratorStudentStatus.transferredOut &&
            sectionOfClass(student.className) == 'Secondary')
          student.className,
    };

    // Only server-acknowledged decisions are allowed to change visible approval
    // state. A dirty local decision is merely queued and must remain Pending
    // until the sync engine replaces it with the canonical server record.
    final decisions = <PrincipalApprovalDecision>[];
    for (final entityType in [assessmentDecisionType, lessonPlanReviewType]) {
      final records = await _db.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: entityType,
      );
      for (final record in records) {
        if (record.isDirty) continue;
        decisions.add(PrincipalApprovalDecision.fromJson(record.payload));
      }
    }
    decisions.sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));

    final items = <PrincipalApprovalItem>[];
    await _appendLessonPlanApprovals(
      membership: membership,
      secondaryClasses: secondaryClasses,
      decisions: decisions,
      items: items,
    );
    await _appendAssessmentApprovals(
      membership: membership,
      secondaryClasses: secondaryClasses,
      decisions: decisions,
      items: items,
    );
    items.sort((a, b) => b.submitted.compareTo(a.submitted));

    return PrincipalApprovalsSnapshot(
      items: items,
      decisions: decisions
          .where((decision) =>
              items.any((item) => item.id == decision.approvalId))
          .toList(growable: false),
      permissions: permissions,
    );
  }

  Future<void> _appendLessonPlanApprovals({
    required SchoolMembership membership,
    required Set<String> secondaryClasses,
    required List<PrincipalApprovalDecision> decisions,
    required List<PrincipalApprovalItem> items,
  }) async {
    final records = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: lessonPlanType,
    );
    for (final record in records) {
      final payload = record.payload;
      final className = payload['className'] as String? ?? '';
      if (!secondaryClasses.contains(className) || payload['state'] != 'submitted') {
        continue;
      }
      final version = payload['version'] as int? ?? 0;
      if (version <= 0) continue;
      final planId = payload['id'] as String? ?? record.entityId;
      final approvalId = '$lessonPlanType:$planId:v$version';
      final review = decisions
          .where((decision) => decision.approvalId == approvalId)
          .firstOrNull;
      items.add(
        PrincipalApprovalItem(
          id: approvalId,
          type: 'Lesson Plan',
          title: payload['topic'] as String? ?? 'Lesson plan',
          teacher: payload['effectiveTeacher'] as String? ??
              payload['author'] as String? ??
              payload['submittedByMembershipId'] as String? ??
              '',
          className: className,
          submitted: payload['submittedAt'] as String? ??
              payload['updatedAt'] as String? ??
              '',
          priority: PrincipalApprovalPriority.normal,
          status: review?.newStatus ?? PrincipalApprovalStatus.pending,
          summary: payload['objectives'] as String? ?? '',
          details: [
            PrincipalApprovalDetail(
              label: 'Occurrence',
              value:
                  '${payload['lessonDate'] ?? ''} · ${payload['time'] ?? ''} · ${payload['subject'] ?? ''}',
            ),
            PrincipalApprovalDetail(
              label: 'Activities',
              value: payload['activities'] as String? ?? '',
            ),
            PrincipalApprovalDetail(
              label: 'Assessment',
              value: payload['assessment'] as String? ?? '',
            ),
            PrincipalApprovalDetail(
              label: 'Resources',
              value: payload['resources'] as String? ?? '',
            ),
          ],
          lastReviewedByMembershipId: review?.reviewerMembershipId,
          lastReviewedAt: review?.reviewedAt,
          lastComment: review?.comment,
        ),
      );
    }
  }

  Future<void> _appendAssessmentApprovals({
    required SchoolMembership membership,
    required Set<String> secondaryClasses,
    required List<PrincipalApprovalDecision> decisions,
    required List<PrincipalApprovalItem> items,
  }) async {
    final records = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: assessmentType,
    );
    final events = await _db.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: 'teacher_assessment_event',
    );
    for (final record in records) {
      final payload = record.payload;
      final className = payload['className'] as String? ?? '';
      if (!secondaryClasses.contains(className) ||
          payload['state'] != 'submittedForReview') {
        continue;
      }
      final submittedEvents = events
          .where(
            (event) =>
                event.payload['sheetId'] == payload['id'] &&
                event.payload['version'] == payload['version'] &&
                event.payload['action'] == 'submittedForReview',
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (submittedEvents.isEmpty) continue;
      final event = submittedEvents.first.payload;
      final approvalId = '$assessmentType:${record.entityId}:v${payload['version']}';
      final review = decisions
          .where((decision) => decision.approvalId == approvalId)
          .firstOrNull;
      final entries = payload['entries'] as List? ?? const [];
      items.add(
        PrincipalApprovalItem(
          id: approvalId,
          type: 'Assessment',
          title: payload['assessmentLabel'] as String? ?? 'Assessment',
          teacher: event['actorMembershipId'] as String? ?? '',
          className: className,
          submitted: event['occurredAt'] as String? ?? '',
          priority: PrincipalApprovalPriority.normal,
          status: review?.newStatus ?? PrincipalApprovalStatus.pending,
          summary:
              'Submitted score sheet; review does not alter marks or publish results.',
          details: [
            PrincipalApprovalDetail(
              label: 'Maximum score',
              value: '${payload['maximumScore'] ?? ''}',
            ),
            PrincipalApprovalDetail(
              label: 'Score entries',
              value: '${entries.length}',
            ),
          ],
          lastReviewedByMembershipId: review?.reviewerMembershipId,
          lastReviewedAt: review?.reviewedAt,
          lastComment: review?.comment,
        ),
      );
    }
  }

  Future<PrincipalApprovalActionResult> decide({
    required String approvalId,
    required PrincipalApprovalStatus status,
    required String comment,
  }) async {
    final membership = _session.requireActiveMembership();
    if (!permissionsFor(membership).canDecideSecondaryApprovals ||
        status == PrincipalApprovalStatus.pending) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'This decision is not permitted.',
      );
    }
    if (status == PrincipalApprovalStatus.returned && comment.trim().isEmpty) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'Explain the changes needed.',
      );
    }
    if (await _hasQueuedDecision(membership.schoolId, approvalId)) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'A review decision for this submission is already queued for synchronization.',
      );
    }

    final item = (await load()).items
        .where((candidate) => candidate.id == approvalId)
        .firstOrNull;
    if (item == null || item.status != PrincipalApprovalStatus.pending) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'No current pending submission matches this decision.',
      );
    }
    if (_session.requireActiveMembership().id != membership.id) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'School membership changed. Reload before reviewing.',
      );
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = 'review-${DateTime.now().microsecondsSinceEpoch}';
    final decision = PrincipalApprovalDecision(
      id: id,
      approvalId: approvalId,
      previousStatus: item.status,
      newStatus: status,
      reviewerMembershipId: membership.id,
      reviewedAt: now,
      comment: comment.trim(),
    );

    if (item.type == 'Lesson Plan') {
      final parsed = _parseLessonPlanApprovalId(approvalId);
      if (parsed == null) {
        return const PrincipalApprovalActionResult(
          success: false,
          message: 'Lesson-plan approval reference is invalid. Reload first.',
        );
      }
      final payload = {
        ...decision.toJson(),
        'planId': parsed.$1,
        'planVersion': parsed.$2,
        'decision': status == PrincipalApprovalStatus.approved
            ? 'approved'
            : 'returned',
      };
      await _db.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: lessonPlanReviewType,
        entityId: id,
        payload: payload,
        isDirty: true,
      );
      await _db.queueMutation(
        tenantId: membership.schoolId,
        membershipId: membership.id,
        entityType: lessonPlanReviewType,
        entityId: id,
        operation: SyncOperation.create,
        payload: payload,
      );
      return const PrincipalApprovalActionResult(
        success: true,
        message:
            'Lesson-plan review queued. The plan remains Pending here until the server acknowledges the decision.',
      );
    }

    await _db.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: assessmentDecisionType,
      entityId: id,
      payload: decision.toJson(),
      isDirty: true,
    );
    await _db.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: assessmentDecisionType,
      entityId: id,
      operation: SyncOperation.create,
      payload: decision.toJson(),
    );
    return const PrincipalApprovalActionResult(
      success: true,
      message:
          'Assessment review queued. It remains Pending until the server acknowledges the decision.',
    );
  }

  Future<bool> _hasQueuedDecision(String schoolId, String approvalId) async {
    for (final entityType in [assessmentDecisionType, lessonPlanReviewType]) {
      final records = await _db.getLocalRecords(
        tenantId: schoolId,
        entityType: entityType,
      );
      if (records.any(
        (record) =>
            record.isDirty && record.payload['approvalId'] == approvalId,
      )) {
        return true;
      }
    }
    return false;
  }

  (String, int)? _parseLessonPlanApprovalId(String value) {
    const prefix = '$lessonPlanType:';
    if (!value.startsWith(prefix)) return null;
    final marker = value.lastIndexOf(':v');
    if (marker <= prefix.length) return null;
    final planId = value.substring(prefix.length, marker);
    final version = int.tryParse(value.substring(marker + 2));
    if (planId.isEmpty || version == null || version < 1) return null;
    return (planId, version);
  }
}
