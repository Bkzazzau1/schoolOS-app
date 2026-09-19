import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/principal/data/principal_approvals_demo_data.dart';
import 'package:schoolos_app/features/principal/domain/principal_approvals_models.dart';

void main() {
  test('principal approvals preserve exact website seed and KPI state', () {
    expect(principalApprovalItems.length, 5);
    expect(principalApprovalItems.map((item) => item.id).toList(), ['APR-101', 'APR-102', 'APR-103', 'APR-104', 'APR-099']);
    expect(principalApprovalItems.where((item) => item.status == PrincipalApprovalStatus.pending).length, 4);
    expect(
      principalApprovalItems
          .where((item) => item.status == PrincipalApprovalStatus.pending && item.priority == PrincipalApprovalPriority.high)
          .length,
      2,
    );
    expect(principalApprovalItems.where((item) => item.status == PrincipalApprovalStatus.approved).length, 1);
    expect(principalApprovalItems.where((item) => item.status == PrincipalApprovalStatus.returned).length, 0);
  });

  test('all four approval work types and website preview evidence are preserved', () {
    final byType = {for (final item in principalApprovalItems) item.type: item};
    expect(byType.keys, containsAll(['Lesson Plan', 'Assessment', 'Report Cards', 'Score Correction']));
    expect(byType['Report Cards']!.details.any((detail) => detail.label == 'Students' && detail.value == '39'), isTrue);
    expect(byType['Report Cards']!.details.any((detail) => detail.label == 'Scores complete' && detail.value == '39 / 39'), isTrue);
    expect(byType['Score Correction']!.details.any((detail) => detail.label == 'Current score' && detail.value == '11 / 20'), isTrue);
    expect(byType['Score Correction']!.details.any((detail) => detail.label == 'Requested score' && detail.value == '15 / 20'), isTrue);
    expect(byType['Score Correction']!.details.any((detail) => detail.label == 'Evidence' && detail.value == 'Attached'), isTrue);
  });

  test('approval item and audit decision serialize without losing reviewer context', () {
    final original = principalApprovalItems.first.copyWith(
      status: PrincipalApprovalStatus.approved,
      lastReviewedByMembershipId: 'MEM-PRINCIPAL-01',
      lastReviewedAt: '2026-09-19T16:30:00Z',
      lastComment: 'Approved after review.',
    );
    final restored = PrincipalApprovalItem.fromJson(original.toJson());
    expect(restored.status, PrincipalApprovalStatus.approved);
    expect(restored.lastReviewedByMembershipId, 'MEM-PRINCIPAL-01');
    expect(restored.lastComment, 'Approved after review.');

    final decision = PrincipalApprovalDecision(
      id: 'APR-101-1',
      approvalId: 'APR-101',
      previousStatus: PrincipalApprovalStatus.pending,
      newStatus: PrincipalApprovalStatus.approved,
      reviewerMembershipId: 'MEM-PRINCIPAL-01',
      reviewedAt: '2026-09-19T16:30:00Z',
      comment: 'Approved after review.',
    );
    final decisionRestored = PrincipalApprovalDecision.fromJson(decision.toJson());
    expect(decisionRestored.previousStatus, PrincipalApprovalStatus.pending);
    expect(decisionRestored.newStatus, PrincipalApprovalStatus.approved);
    expect(decisionRestored.reviewerMembershipId, 'MEM-PRINCIPAL-01');
  });

  test('principal approval permissions remain Secondary scoped and downstream safe', () {
    expect(principalApprovalPermissions.canViewSecondaryApprovals, isTrue);
    expect(principalApprovalPermissions.canDecideSecondaryApprovals, isTrue);
    expect(principalApprovalPermissions.canManagePrimary, isFalse);
    expect(principalApprovalPermissions.canReleaseReportsDirectly, isFalse);
    expect(principalApprovalPermissions.canRewriteScoresDirectly, isFalse);
    expect(principalApprovalAuthorityBoundary, contains('Secondary'));
    expect(principalApprovalAuditBoundary, contains('previous status'));
    expect(principalApprovalAuditBoundary, contains('timestamp'));
    expect(principalApprovalDownstreamBoundary, contains('does not itself publish'));
    expect(principalApprovalDownstreamBoundary, contains('does not itself rewrite'));
  });

  test('AI boundary keeps approval decision with human Principal', () {
    expect(principalApprovalAiBoundary, contains('human decision-maker'));
  });
}
