import '../domain/principal_approvals_models.dart';

const principalApprovalFilters = ['Pending', 'Approved', 'Returned', 'All'];

const principalApprovalRules = <PrincipalApprovalDetail>[
  PrincipalApprovalDetail(label: 'ACADEMIC CONTROL', value: 'Teacher submits → Principal reviews → Approve or return'),
  PrincipalApprovalDetail(label: 'REPORT RELEASE', value: 'Report cards can be reviewed before school release'),
  PrincipalApprovalDetail(label: 'AUDITABILITY', value: 'Decision, reviewer and comments remain part of the workflow'),
];

const principalApprovalPermissions = PrincipalApprovalPermissions(
  canViewSecondaryApprovals: true,
  canDecideSecondaryApprovals: true,
  canReleaseReportsDirectly: false,
  canRewriteScoresDirectly: false,
  canManagePrimary: false,
);
