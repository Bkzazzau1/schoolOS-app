import '../domain/principal_approvals_models.dart';

const principalApprovalItems = <PrincipalApprovalItem>[
  PrincipalApprovalItem(
    id: 'APR-101',
    type: 'Lesson Plan',
    title: 'Linear Equations · Week 6',
    teacher: 'Mrs. Amina Yusuf',
    className: 'JSS 2A',
    submitted: '18 min ago',
    priority: PrincipalApprovalPriority.normal,
    status: PrincipalApprovalStatus.pending,
    summary: 'Objectives, guided practice, independent task and exit ticket are included.',
    details: [
      PrincipalApprovalDetail(label: 'Learning objectives', value: 'Clear and measurable'),
      PrincipalApprovalDetail(label: 'Syllabus alignment', value: 'Week 6 · Linear Equations'),
      PrincipalApprovalDetail(label: 'Assessment', value: 'Exit ticket included'),
      PrincipalApprovalDetail(label: 'Resources', value: 'Worksheet + whiteboard'),
    ],
  ),
  PrincipalApprovalItem(
    id: 'APR-102',
    type: 'Assessment',
    title: 'Topic Test · Simultaneous Equations',
    teacher: 'Mr. Daniel John',
    className: 'JSS 3A',
    submitted: '42 min ago',
    priority: PrincipalApprovalPriority.normal,
    status: PrincipalApprovalStatus.pending,
    summary: '30-mark topic test with short-answer and structured-response sections.',
    details: [
      PrincipalApprovalDetail(label: 'Total marks', value: '30'),
      PrincipalApprovalDetail(label: 'Questions', value: '12'),
      PrincipalApprovalDetail(label: 'Coverage', value: '3 syllabus objectives'),
      PrincipalApprovalDetail(label: 'Duration', value: '45 minutes'),
    ],
  ),
  PrincipalApprovalItem(
    id: 'APR-103',
    type: 'Report Cards',
    title: 'First Term Report Batch',
    teacher: 'Mrs. Fatima Bello',
    className: 'JSS 2B',
    submitted: '1 hr ago',
    priority: PrincipalApprovalPriority.high,
    status: PrincipalApprovalStatus.pending,
    summary: '39 student report cards prepared for principal review before release.',
    details: [
      PrincipalApprovalDetail(label: 'Students', value: '39'),
      PrincipalApprovalDetail(label: 'Scores complete', value: '39 / 39'),
      PrincipalApprovalDetail(label: 'Teacher comments', value: 'Complete'),
      PrincipalApprovalDetail(label: 'Release state', value: 'Waiting for approval'),
    ],
  ),
  PrincipalApprovalItem(
    id: 'APR-104',
    type: 'Score Correction',
    title: 'CA 1 correction request',
    teacher: 'Mr. Peter James',
    className: 'SS 1A',
    submitted: '2 hrs ago',
    priority: PrincipalApprovalPriority.high,
    status: PrincipalApprovalStatus.pending,
    summary: 'Teacher requests correction to one submitted CA score after rechecking the marked script.',
    details: [
      PrincipalApprovalDetail(label: 'Current score', value: '11 / 20'),
      PrincipalApprovalDetail(label: 'Requested score', value: '15 / 20'),
      PrincipalApprovalDetail(label: 'Reason', value: 'Marked-script recheck'),
      PrincipalApprovalDetail(label: 'Evidence', value: 'Attached'),
    ],
  ),
  PrincipalApprovalItem(
    id: 'APR-099',
    type: 'Lesson Plan',
    title: 'Functions · Week 5',
    teacher: 'Mr. Peter James',
    className: 'SS 1A',
    submitted: 'Yesterday',
    priority: PrincipalApprovalPriority.normal,
    status: PrincipalApprovalStatus.approved,
    summary: 'Previously reviewed and approved lesson plan.',
    details: [
      PrincipalApprovalDetail(label: 'Learning objectives', value: 'Clear and measurable'),
      PrincipalApprovalDetail(label: 'Syllabus alignment', value: 'Week 6 · Linear Equations'),
      PrincipalApprovalDetail(label: 'Assessment', value: 'Exit ticket included'),
      PrincipalApprovalDetail(label: 'Resources', value: 'Worksheet + whiteboard'),
    ],
  ),
];

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
