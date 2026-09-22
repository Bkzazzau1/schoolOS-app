import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
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
      items.where((i) => i.status == PrincipalApprovalStatus.pending).length;
  int get highPriorityPendingCount => items
      .where(
        (i) =>
            i.status == PrincipalApprovalStatus.pending &&
            i.priority == PrincipalApprovalPriority.high,
      )
      .length;
  int get approvedCount =>
      items.where((i) => i.status == PrincipalApprovalStatus.approved).length;
  int get returnedCount =>
      items.where((i) => i.status == PrincipalApprovalStatus.returned).length;
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
  }) : _db = localDatabase,
       _session = schoolSession;
  final LocalDatabase _db;
  final SchoolSessionController _session;
  static const decisionType = 'principal_submission_review';
  PrincipalApprovalPermissions permissionsFor(SchoolMembership m) =>
      PrincipalApprovalPermissions(
        canViewSecondaryApprovals: m.role == SchoolRole.principal,
        canDecideSecondaryApprovals: m.role == SchoolRole.principal,
        canReleaseReportsDirectly: false,
        canRewriteScoresDirectly: false,
        canManagePrimary: false,
      );
  Future<PrincipalApprovalsSnapshot> load() async {
    final m = _session.requireActiveMembership();
    final permissions = permissionsFor(m);
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
    final classes = {
      for (final s in register.students)
        if (s.status != AdministratorStudentStatus.transferredOut &&
            sectionOfClass(s.className) == 'Secondary')
          s.className,
    };
    final reviews = await _db.getLocalRecords(
      tenantId: m.schoolId,
      entityType: decisionType,
    );
    final decisions =
        reviews
            .map((r) => PrincipalApprovalDecision.fromJson(r.payload))
            .toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    final items = <PrincipalApprovalItem>[];
    for (final lesson in [true, false]) {
      final type = lesson
          ? 'teacher_lesson_plan'
          : 'teacher_assessment_score_sheet';
      final records = await _db.getLocalRecords(
        tenantId: m.schoolId,
        entityType: type,
      );
      final events = await _db.getLocalRecords(
        tenantId: m.schoolId,
        entityType: lesson
            ? 'teacher_lesson_plan_event'
            : 'teacher_assessment_event',
      );
      for (final record in records) {
        final p = record.payload;
        if (!classes.contains(p['className']) ||
            p[lesson ? 'status' : 'state'] !=
                (lesson ? 'submitted' : 'submittedForReview')) {
          continue;
        }
        final submitted =
            events
                .where(
                  (e) =>
                      e.payload[lesson ? 'planId' : 'sheetId'] == p['id'] &&
                      e.payload['version'] == p['version'] &&
                      e.payload['action'] ==
                          (lesson ? 'submitted' : 'submittedForReview'),
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (submitted.isEmpty) continue;
        final event = submitted.first.payload;
        final id = '$type:${record.entityId}:v${p['version']}';
        final review = decisions.where((d) => d.approvalId == id).firstOrNull;
        items.add(
          PrincipalApprovalItem(
            id: id,
            type: lesson ? 'Lesson Plan' : 'Assessment',
            title: p[lesson ? 'topic' : 'assessmentLabel']! as String,
            teacher: event['actorMembershipId']! as String,
            className: p['className']! as String,
            submitted: event['occurredAt']! as String,
            priority: PrincipalApprovalPriority.normal,
            status: review?.newStatus ?? PrincipalApprovalStatus.pending,
            summary: lesson
                ? (p['objectives'] as String? ?? '')
                : 'Submitted score sheet; review does not alter marks or publish results.',
            details: lesson
                ? [
                    PrincipalApprovalDetail(
                      label: 'Activities',
                      value: p['activities'] as String? ?? '',
                    ),
                    PrincipalApprovalDetail(
                      label: 'Assessment',
                      value: p['assessment'] as String? ?? '',
                    ),
                  ]
                : [
                    PrincipalApprovalDetail(
                      label: 'Maximum score',
                      value: '${p['maximumScore']}',
                    ),
                    PrincipalApprovalDetail(
                      label: 'Score entries',
                      value: '${(p['entries'] as List).length}',
                    ),
                  ],
            lastReviewedByMembershipId: review?.reviewerMembershipId,
            lastReviewedAt: review?.reviewedAt,
            lastComment: review?.comment,
          ),
        );
      }
    }
    return PrincipalApprovalsSnapshot(
      items: items,
      decisions: decisions
          .where((d) => items.any((i) => i.id == d.approvalId))
          .toList(),
      permissions: permissions,
    );
  }

  Future<PrincipalApprovalActionResult> decide({
    required String approvalId,
    required PrincipalApprovalStatus status,
    required String comment,
  }) async {
    final m = _session.requireActiveMembership();
    if (!permissionsFor(m).canDecideSecondaryApprovals ||
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
    final item = (await load()).items
        .where((i) => i.id == approvalId)
        .firstOrNull;
    if (item == null || item.status != PrincipalApprovalStatus.pending) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'No current pending submission matches this decision.',
      );
    }
    if (_session.requireActiveMembership().id != m.id) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'School membership changed. Reload before reviewing.',
      );
    }
    final decision = PrincipalApprovalDecision(
      id: 'review-${DateTime.now().microsecondsSinceEpoch}',
      approvalId: approvalId,
      previousStatus: item.status,
      newStatus: status,
      reviewerMembershipId: m.id,
      reviewedAt: DateTime.now().toUtc().toIso8601String(),
      comment: comment.trim(),
    );
    await _db.upsertLocalRecord(
      tenantId: m.schoolId,
      entityType: decisionType,
      entityId: decision.id,
      payload: decision.toJson(),
      isDirty: true,
    );
    await _db.queueMutation(
      tenantId: m.schoolId,
      membershipId: m.id,
      entityType: decisionType,
      entityId: decision.id,
      operation: SyncOperation.create,
      payload: decision.toJson(),
    );
    return const PrincipalApprovalActionResult(
      success: true,
      message:
          'Review recorded offline and queued for sync. Teacher source records, marks and publication are unchanged.',
    );
  }
}
