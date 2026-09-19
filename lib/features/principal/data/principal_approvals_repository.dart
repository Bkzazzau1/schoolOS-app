import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/principal_approvals_models.dart';
import 'principal_approvals_demo_data.dart';

class PrincipalApprovalsSnapshot {
  const PrincipalApprovalsSnapshot({
    required this.items,
    required this.decisions,
    required this.permissions,
  });

  final List<PrincipalApprovalItem> items;
  final List<PrincipalApprovalDecision> decisions;
  final PrincipalApprovalPermissions permissions;

  int get pendingCount => items.where((item) => item.status == PrincipalApprovalStatus.pending).length;
  int get highPriorityPendingCount => items
      .where((item) => item.status == PrincipalApprovalStatus.pending && item.priority == PrincipalApprovalPriority.high)
      .length;
  int get approvedCount => items.where((item) => item.status == PrincipalApprovalStatus.approved).length;
  int get returnedCount => items.where((item) => item.status == PrincipalApprovalStatus.returned).length;
}

class PrincipalApprovalActionResult {
  const PrincipalApprovalActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class PrincipalApprovalsRepository {
  PrincipalApprovalsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _itemType = 'principal_approval_item';
  static const _decisionType = 'principal_approval_decision';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  PrincipalApprovalPermissions permissionsFor(SchoolMembership membership) => PrincipalApprovalPermissions(
        canViewSecondaryApprovals: membership.role == SchoolRole.principal,
        canDecideSecondaryApprovals: membership.role == SchoolRole.principal,
        canReleaseReportsDirectly: false,
        canRewriteScoresDirectly: false,
        canManagePrimary: false,
      );

  Future<PrincipalApprovalsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    await _seedIfNeeded(membership);

    final itemRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _itemType,
    );
    final decisionRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _decisionType,
    );

    final items = itemRecords
        .map((record) => PrincipalApprovalItem.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => _sortKey(a.id).compareTo(_sortKey(b.id)));
    final decisions = decisionRecords
        .map((record) => PrincipalApprovalDecision.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));

    return PrincipalApprovalsSnapshot(
      items: items,
      decisions: decisions,
      permissions: permissionsFor(membership),
    );
  }

  Future<PrincipalApprovalActionResult> decide({
    required String approvalId,
    required PrincipalApprovalStatus status,
    required String comment,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canDecideSecondaryApprovals) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'This membership cannot decide Secondary academic approvals.',
      );
    }
    if (status == PrincipalApprovalStatus.pending) {
      return const PrincipalApprovalActionResult(
        success: false,
        message: 'Choose Approve or Return for changes.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _itemType,
      entityId: approvalId,
    );
    if (record == null) {
      return const PrincipalApprovalActionResult(success: false, message: 'Approval item not found.');
    }

    final current = PrincipalApprovalItem.fromJson(record.payload);
    final reviewedAt = DateTime.now().toUtc().toIso8601String();
    final updated = current.copyWith(
      status: status,
      lastReviewedByMembershipId: membership.id,
      lastReviewedAt: reviewedAt,
      lastComment: comment.trim(),
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _itemType,
      entityId: updated.id,
      payload: updated.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _itemType,
      entityId: updated.id,
      operation: SyncOperation.update,
      payload: updated.toJson(),
    );

    final decision = PrincipalApprovalDecision(
      id: '${updated.id}-${DateTime.now().microsecondsSinceEpoch}',
      approvalId: updated.id,
      previousStatus: current.status,
      newStatus: status,
      reviewerMembershipId: membership.id,
      reviewedAt: reviewedAt,
      comment: comment.trim(),
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _decisionType,
      entityId: decision.id,
      payload: decision.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _decisionType,
      entityId: decision.id,
      operation: SyncOperation.create,
      payload: decision.toJson(),
    );

    final downstream = switch (updated.type) {
      'Report Cards' => ' Report release remains a separate governed step.',
      'Score Correction' => ' The student score remains unchanged until the authorized correction workflow applies this decision.',
      _ => '',
    };
    return PrincipalApprovalActionResult(
      success: true,
      message: status == PrincipalApprovalStatus.approved
          ? 'Approved offline and queued for synchronization.$downstream'
          : 'Returned for changes offline and queued for synchronization.',
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _itemType,
    );
    if (existing.isNotEmpty) return;

    for (final item in principalApprovalItems) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _itemType,
        entityId: item.id,
        payload: item.toJson(),
      );
    }
  }

  int _sortKey(String id) {
    final value = int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 0;
    return -value;
  }
}
