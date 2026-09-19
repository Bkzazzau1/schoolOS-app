enum PrincipalApprovalStatus { pending, approved, returned }

enum PrincipalApprovalPriority { normal, high }

extension PrincipalApprovalStatusLabel on PrincipalApprovalStatus {
  String get label => switch (this) {
        PrincipalApprovalStatus.pending => 'Pending',
        PrincipalApprovalStatus.approved => 'Approved',
        PrincipalApprovalStatus.returned => 'Returned',
      };

  static PrincipalApprovalStatus fromLabel(String value) => switch (value) {
        'Approved' => PrincipalApprovalStatus.approved,
        'Returned' => PrincipalApprovalStatus.returned,
        _ => PrincipalApprovalStatus.pending,
      };
}

extension PrincipalApprovalPriorityLabel on PrincipalApprovalPriority {
  String get label => switch (this) {
        PrincipalApprovalPriority.normal => 'Normal',
        PrincipalApprovalPriority.high => 'High',
      };

  static PrincipalApprovalPriority fromLabel(String value) =>
      value == 'High' ? PrincipalApprovalPriority.high : PrincipalApprovalPriority.normal;
}

class PrincipalApprovalDetail {
  const PrincipalApprovalDetail({required this.label, required this.value});

  final String label;
  final String value;

  Map<String, Object?> toJson() => {'label': label, 'value': value};

  factory PrincipalApprovalDetail.fromJson(Map<String, Object?> json) => PrincipalApprovalDetail(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
      );
}

class PrincipalApprovalItem {
  const PrincipalApprovalItem({
    required this.id,
    required this.type,
    required this.title,
    required this.teacher,
    required this.className,
    required this.submitted,
    required this.priority,
    required this.status,
    required this.summary,
    required this.details,
    this.lastReviewedByMembershipId,
    this.lastReviewedAt,
    this.lastComment,
  });

  final String id;
  final String type;
  final String title;
  final String teacher;
  final String className;
  final String submitted;
  final PrincipalApprovalPriority priority;
  final PrincipalApprovalStatus status;
  final String summary;
  final List<PrincipalApprovalDetail> details;
  final String? lastReviewedByMembershipId;
  final String? lastReviewedAt;
  final String? lastComment;

  PrincipalApprovalItem copyWith({
    PrincipalApprovalStatus? status,
    String? lastReviewedByMembershipId,
    String? lastReviewedAt,
    String? lastComment,
  }) {
    return PrincipalApprovalItem(
      id: id,
      type: type,
      title: title,
      teacher: teacher,
      className: className,
      submitted: submitted,
      priority: priority,
      status: status ?? this.status,
      summary: summary,
      details: details,
      lastReviewedByMembershipId: lastReviewedByMembershipId ?? this.lastReviewedByMembershipId,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      lastComment: lastComment ?? this.lastComment,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'teacher': teacher,
        'className': className,
        'submitted': submitted,
        'priority': priority.label,
        'status': status.label,
        'summary': summary,
        'details': details.map((item) => item.toJson()).toList(),
        'lastReviewedByMembershipId': lastReviewedByMembershipId,
        'lastReviewedAt': lastReviewedAt,
        'lastComment': lastComment,
      };

  factory PrincipalApprovalItem.fromJson(Map<String, Object?> json) => PrincipalApprovalItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        className: json['className'] as String? ?? '',
        submitted: json['submitted'] as String? ?? '',
        priority: PrincipalApprovalPriorityLabel.fromLabel(json['priority'] as String? ?? 'Normal'),
        status: PrincipalApprovalStatusLabel.fromLabel(json['status'] as String? ?? 'Pending'),
        summary: json['summary'] as String? ?? '',
        details: ((json['details'] as List?) ?? const [])
            .map((item) => PrincipalApprovalDetail.fromJson((item as Map).cast<String, Object?>()))
            .toList(growable: false),
        lastReviewedByMembershipId: json['lastReviewedByMembershipId'] as String?,
        lastReviewedAt: json['lastReviewedAt'] as String?,
        lastComment: json['lastComment'] as String?,
      );
}

class PrincipalApprovalDecision {
  const PrincipalApprovalDecision({
    required this.id,
    required this.approvalId,
    required this.previousStatus,
    required this.newStatus,
    required this.reviewerMembershipId,
    required this.reviewedAt,
    required this.comment,
  });

  final String id;
  final String approvalId;
  final PrincipalApprovalStatus previousStatus;
  final PrincipalApprovalStatus newStatus;
  final String reviewerMembershipId;
  final String reviewedAt;
  final String comment;

  Map<String, Object?> toJson() => {
        'id': id,
        'approvalId': approvalId,
        'previousStatus': previousStatus.label,
        'newStatus': newStatus.label,
        'reviewerMembershipId': reviewerMembershipId,
        'reviewedAt': reviewedAt,
        'comment': comment,
      };

  factory PrincipalApprovalDecision.fromJson(Map<String, Object?> json) => PrincipalApprovalDecision(
        id: json['id'] as String? ?? '',
        approvalId: json['approvalId'] as String? ?? '',
        previousStatus: PrincipalApprovalStatusLabel.fromLabel(json['previousStatus'] as String? ?? 'Pending'),
        newStatus: PrincipalApprovalStatusLabel.fromLabel(json['newStatus'] as String? ?? 'Pending'),
        reviewerMembershipId: json['reviewerMembershipId'] as String? ?? '',
        reviewedAt: json['reviewedAt'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
      );
}

class PrincipalApprovalPermissions {
  const PrincipalApprovalPermissions({
    required this.canViewSecondaryApprovals,
    required this.canDecideSecondaryApprovals,
    required this.canReleaseReportsDirectly,
    required this.canRewriteScoresDirectly,
    required this.canManagePrimary,
  });

  final bool canViewSecondaryApprovals;
  final bool canDecideSecondaryApprovals;
  final bool canReleaseReportsDirectly;
  final bool canRewriteScoresDirectly;
  final bool canManagePrimary;
}

const principalApprovalAuthorityBoundary =
    'Principal approval authority is limited to Secondary academic workflows. Primary and Early Years remain under their own leadership scopes.';

const principalApprovalAuditBoundary =
    'Every approval or return decision keeps the reviewer membership, timestamp, previous status, new status and comment as an append-only audit event.';

const principalApprovalDownstreamBoundary =
    'Approval records authorize downstream workflow steps; approving report cards does not itself publish them, and approving a score correction does not itself rewrite the student score.';

const principalApprovalAiBoundary =
    'AI may summarize evidence or highlight missing context, but the Principal remains the human decision-maker for academic approvals.';
