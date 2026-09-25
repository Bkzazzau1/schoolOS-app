import '../../administrator/domain/report_card_models.dart' show ReportCardEvent;

enum PrincipalResultReleaseState { draft, awaitingApproval, approved, released }

enum PrincipalReportReviewAction { approve, returnWithComment }

extension PrincipalResultReleaseStateLabel on PrincipalResultReleaseState {
  String get label => switch (this) {
        PrincipalResultReleaseState.draft => 'Draft',
        PrincipalResultReleaseState.awaitingApproval => 'Awaiting approval',
        PrincipalResultReleaseState.approved => 'Approved',
        PrincipalResultReleaseState.released => 'Released',
      };

  static PrincipalResultReleaseState fromLabel(String value) => switch (value) {
        'Draft' => PrincipalResultReleaseState.draft,
        'Awaiting approval' => PrincipalResultReleaseState.awaitingApproval,
        'Approved' => PrincipalResultReleaseState.approved,
        'Released' => PrincipalResultReleaseState.released,
        _ => PrincipalResultReleaseState.draft,
      };
}

extension PrincipalReportReviewActionLabel on PrincipalReportReviewAction {
  String get label => switch (this) {
        PrincipalReportReviewAction.approve => 'Approve report',
        PrincipalReportReviewAction.returnWithComment => 'Return with comment',
      };
}

class PrincipalClassResult {
  const PrincipalClassResult({
    required this.className,
    required this.students,
    required this.average,
    required this.passRate,
    required this.highest,
    required this.lowest,
    required this.complete,
    required this.reportsReady,
    required this.release,
    required this.trend,
  });

  final String className;
  final int students;
  final int average;
  final int passRate;
  final int highest;
  final int lowest;
  final int complete;
  final int reportsReady;
  final PrincipalResultReleaseState release;
  final double trend;

  Map<String, Object?> toJson() => {
        'className': className,
        'students': students,
        'average': average,
        'passRate': passRate,
        'highest': highest,
        'lowest': lowest,
        'complete': complete,
        'reportsReady': reportsReady,
        'release': release.label,
        'trend': trend,
      };

  factory PrincipalClassResult.fromJson(Map<String, Object?> json) => PrincipalClassResult(
        className: json['className']! as String,
        students: json['students']! as int,
        average: json['average']! as int,
        passRate: json['passRate']! as int,
        highest: json['highest']! as int,
        lowest: json['lowest']! as int,
        complete: json['complete']! as int,
        reportsReady: json['reportsReady']! as int,
        release: PrincipalResultReleaseStateLabel.fromLabel(json['release']! as String),
        trend: (json['trend']! as num).toDouble(),
      );
}

class PrincipalStudentResult {
  const PrincipalStudentResult({
    required this.id,
    required this.name,
    required this.className,
    required this.average,
    required this.position,
    required this.attendance,
    required this.reportStatus,
    required this.teacherComment,
    this.principalComment,
    this.principalApproved = false,
    this.lastReviewedByMembershipId,
    this.lastReviewedAt,
    this.events = const [],
  });

  final String id;
  final String name;
  final String className;
  final int average;
  final String position;
  final int attendance;
  final PrincipalResultReleaseState reportStatus;
  final String teacherComment;
  final String? principalComment;
  final bool principalApproved;
  final String? lastReviewedByMembershipId;
  final String? lastReviewedAt;

  /// The underlying report card's own review history, most recent first.
  final List<ReportCardEvent> events;

  PrincipalResultReleaseState get displayStatus {
    if (reportStatus == PrincipalResultReleaseState.released) return reportStatus;
    return principalApproved ? PrincipalResultReleaseState.approved : reportStatus;
  }

  PrincipalStudentResult copyWith({
    String? principalComment,
    bool? principalApproved,
    String? lastReviewedByMembershipId,
    String? lastReviewedAt,
  }) =>
      PrincipalStudentResult(
        id: id,
        name: name,
        className: className,
        average: average,
        position: position,
        attendance: attendance,
        reportStatus: reportStatus,
        teacherComment: teacherComment,
        principalComment: principalComment ?? this.principalComment,
        principalApproved: principalApproved ?? this.principalApproved,
        lastReviewedByMembershipId: lastReviewedByMembershipId ?? this.lastReviewedByMembershipId,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'className': className,
        'average': average,
        'position': position,
        'attendance': attendance,
        'reportStatus': reportStatus.label,
        'teacherComment': teacherComment,
        'principalComment': principalComment,
        'principalApproved': principalApproved,
        'lastReviewedByMembershipId': lastReviewedByMembershipId,
        'lastReviewedAt': lastReviewedAt,
      };

  factory PrincipalStudentResult.fromJson(Map<String, Object?> json) => PrincipalStudentResult(
        id: json['id']! as String,
        name: json['name']! as String,
        className: json['className']! as String,
        average: json['average']! as int,
        position: json['position']! as String,
        attendance: json['attendance']! as int,
        reportStatus: PrincipalResultReleaseStateLabel.fromLabel(json['reportStatus']! as String),
        teacherComment: json['teacherComment']! as String,
        principalComment: json['principalComment'] as String?,
        principalApproved: json['principalApproved'] as bool? ?? false,
        lastReviewedByMembershipId: json['lastReviewedByMembershipId'] as String?,
        lastReviewedAt: json['lastReviewedAt'] as String?,
      );
}

class PrincipalSubjectResult {
  const PrincipalSubjectResult({
    required this.subject,
    required this.ca,
    required this.exam,
    required this.total,
    required this.grade,
    required this.remark,
  });

  final String subject;
  final int ca;
  final int exam;
  final int total;
  final String grade;
  final String remark;

  Map<String, Object?> toJson() => {
        'subject': subject,
        'ca': ca,
        'exam': exam,
        'total': total,
        'grade': grade,
        'remark': remark,
      };

  factory PrincipalSubjectResult.fromJson(Map<String, Object?> json) => PrincipalSubjectResult(
        subject: json['subject']! as String,
        ca: json['ca']! as int,
        exam: json['exam']! as int,
        total: json['total']! as int,
        grade: json['grade']! as String,
        remark: json['remark']! as String,
      );
}

class PrincipalReportReviewDecision {
  const PrincipalReportReviewDecision({
    required this.id,
    required this.studentId,
    required this.action,
    required this.previousReleaseState,
    required this.reviewerMembershipId,
    required this.reviewedAt,
    required this.comment,
  });

  final String id;
  final String studentId;
  final PrincipalReportReviewAction action;
  final PrincipalResultReleaseState previousReleaseState;
  final String reviewerMembershipId;
  final String reviewedAt;
  final String comment;

  Map<String, Object?> toJson() => {
        'id': id,
        'studentId': studentId,
        'action': action.name,
        'previousReleaseState': previousReleaseState.label,
        'reviewerMembershipId': reviewerMembershipId,
        'reviewedAt': reviewedAt,
        'comment': comment,
        'doesNotRelease': true,
        'doesNotRewriteScores': true,
      };

  factory PrincipalReportReviewDecision.fromJson(Map<String, Object?> json) => PrincipalReportReviewDecision(
        id: json['id']! as String,
        studentId: json['studentId']! as String,
        action: PrincipalReportReviewAction.values.byName(json['action']! as String),
        previousReleaseState: PrincipalResultReleaseStateLabel.fromLabel(json['previousReleaseState']! as String),
        reviewerMembershipId: json['reviewerMembershipId']! as String,
        reviewedAt: json['reviewedAt']! as String,
        comment: json['comment']! as String,
      );
}

class PrincipalResultsPermissions {
  const PrincipalResultsPermissions({
    required this.canViewSecondaryResults,
    required this.canReviewReports,
    required this.canOpenPrintPreview,
    required this.canReleaseToParents,
    required this.canEditScores,
    required this.canManageSchoolIdentity,
    required this.canManagePrimary,
  });

  final bool canViewSecondaryResults;
  final bool canReviewReports;
  final bool canOpenPrintPreview;
  final bool canReleaseToParents;
  final bool canEditScores;
  final bool canManageSchoolIdentity;
  final bool canManagePrimary;
}

const principalResultsAuthorityBoundary =
    'Principal Results & Reports is limited to Secondary leadership. Principal may review report readiness and record a report decision, but does not gain Primary/Early Years authority.';
const principalResultsReleaseBoundary =
    'Principal approval is a review decision, not publication. Release to parents/students remains a separate controlled school action with its own authorization and audit trail.';
const principalResultsScoreBoundary =
    'This workspace never rewrites CA, exam or total scores. Score corrections must pass through the authorized correction workflow and preserve evidence/history.';
const principalResultsIdentityBoundary =
    'Official school identity, letterhead and registration details are centrally managed and read-only to the Principal role.';
const principalResultsOfflineBoundary =
    'Report review works offline. Decisions retain student, action, reviewer membership, timestamp and comment, then synchronize later without silently changing release state.';
const principalResultsAiBoundary =
    'Principal AI may identify result patterns for human review, but must not autonomously change scores, approve reports, publish reports, rank student worth or make disciplinary decisions.';

const principalResultsPermissions = PrincipalResultsPermissions(
  canViewSecondaryResults: true,
  canReviewReports: true,
  canOpenPrintPreview: true,
  canReleaseToParents: false,
  canEditScores: false,
  canManageSchoolIdentity: false,
  canManagePrimary: false,
);
