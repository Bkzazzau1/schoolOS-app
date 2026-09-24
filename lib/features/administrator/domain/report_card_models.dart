/// The canonical, server-syncable entity type every role (Administrator,
/// Proprietor, Principal, Student, Parent) reads and writes a compiled term
/// report through. Born server-side when an Administrator compiles a class
/// (see [reportCardBatchEntityType]), never created directly by a device.
const reportCardEntityType = 'academic_report_card';

/// entity_id is `"{classId}:{termId}"`. A compile mutation on this entity
/// regenerates every roster student's report card for that class and term
/// and ranks them - class position is inherently class-wide, so it is never
/// computed for one student alone.
const reportCardBatchEntityType = 'academic_report_card_batch';

enum ReportCardState { draft, submitted, reviewed, released }

class ReportCardSubjectLine {
  const ReportCardSubjectLine({
    required this.classSubjectId,
    required this.subject,
    required this.percent,
    required this.grade,
    required this.assessmentsIncluded,
  });

  final String classSubjectId;
  final String subject;
  final double? percent;
  final String grade;
  final int assessmentsIncluded;

  factory ReportCardSubjectLine.fromJson(Map<String, dynamic> json) => ReportCardSubjectLine(
        classSubjectId: json['classSubjectId'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        percent: (json['percent'] as num?)?.toDouble(),
        grade: json['grade'] as String? ?? '',
        assessmentsIncluded: (json['assessmentsIncluded'] as num?)?.toInt() ?? 0,
      );
}

class ReportCard {
  const ReportCard({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.termId,
    required this.term,
    required this.className,
    required this.section,
    required this.state,
    required this.subjects,
    this.overallAverage,
    this.overallGrade = '',
    this.classPosition,
    this.classSize,
    this.attendancePercent,
    this.principalComment = '',
    this.classTeacherComment = '',
    this.generatedAt,
    this.submittedAt,
    this.reviewedAt,
    this.releasedAt,
    this.version = 1,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String termId;
  final String term;
  final String className;
  final String section;
  final ReportCardState state;
  final List<ReportCardSubjectLine> subjects;
  final double? overallAverage;
  final String overallGrade;
  final int? classPosition;
  final int? classSize;
  final int? attendancePercent;
  final String principalComment;

  /// Written by whoever holds the active class-teacher assignment (see
  /// PrincipalClassTeachersRepository) for this class and session. Empty
  /// when no class teacher has commented yet - never fabricated.
  final String classTeacherComment;
  final String? generatedAt;
  final String? submittedAt;
  final String? reviewedAt;
  final String? releasedAt;
  final int version;
  final bool pendingSync;
  final int? serverVersion;

  bool get hasEvidence => overallAverage != null;
  bool get isSecondary => section.trim().toLowerCase() == 'secondary';
  bool get canSubmit => state == ReportCardState.draft && !pendingSync;
  bool get canPrincipalReview =>
      state == ReportCardState.submitted && isSecondary && !pendingSync;
  bool get canRelease =>
      !pendingSync &&
      (state == ReportCardState.reviewed ||
          (state == ReportCardState.submitted && !isSecondary));

  ReportCard copyWith({
    ReportCardState? state,
    int? version,
    bool? pendingSync,
    int? serverVersion,
  }) =>
      ReportCard(
        id: id,
        studentId: studentId,
        studentName: studentName,
        admissionNumber: admissionNumber,
        termId: termId,
        term: term,
        className: className,
        section: section,
        state: state ?? this.state,
        subjects: subjects,
        overallAverage: overallAverage,
        overallGrade: overallGrade,
        classPosition: classPosition,
        classSize: classSize,
        attendancePercent: attendancePercent,
        principalComment: principalComment,
        classTeacherComment: classTeacherComment,
        generatedAt: generatedAt,
        submittedAt: submittedAt,
        reviewedAt: reviewedAt,
        releasedAt: releasedAt,
        version: version ?? this.version,
        pendingSync: pendingSync ?? this.pendingSync,
        serverVersion: serverVersion ?? this.serverVersion,
      );

  factory ReportCard.fromJson(Map<String, dynamic> json) {
    final state = ReportCardState.values.firstWhere(
      (item) => item.name == (json['state'] as String? ?? 'draft'),
      orElse: () => ReportCardState.draft,
    );
    return ReportCard(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      admissionNumber: json['admissionNumber'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      className: json['className'] as String? ?? '',
      section: json['section'] as String? ?? '',
      state: state,
      subjects: (json['subjects'] as List<dynamic>? ?? const [])
          .map((item) => ReportCardSubjectLine.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      overallAverage: (json['overallAverage'] as num?)?.toDouble(),
      overallGrade: json['overallGrade'] as String? ?? '',
      classPosition: (json['classPosition'] as num?)?.toInt(),
      classSize: (json['classSize'] as num?)?.toInt(),
      attendancePercent: (json['attendancePercent'] as num?)?.toInt(),
      principalComment: json['principalComment'] as String? ?? '',
      classTeacherComment: json['classTeacherComment'] as String? ?? '',
      generatedAt: json['generatedAt'] as String?,
      submittedAt: json['submittedAt'] as String?,
      reviewedAt: json['reviewedAt'] as String?,
      releasedAt: json['releasedAt'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

String reportCardStateLabel(ReportCardState state) => switch (state) {
      ReportCardState.draft => 'Draft',
      ReportCardState.submitted => 'Submitted for review',
      ReportCardState.reviewed => 'Reviewed · awaiting release',
      ReportCardState.released => 'Released',
    };

const reportCardReleaseBoundary =
    'Compiling and submitting are an Administrator/Proprietor action. Release to Students and their linked Parents is a separate, explicit step with its own audit trail - compiling or submitting never makes a report card visible to a family.';

const reportCardPrincipalReviewBoundary =
    'Principal review is a Secondary-only, advisory decision. It never releases a report card by itself and never rewrites a subject score.';
