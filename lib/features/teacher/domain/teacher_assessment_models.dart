enum TeacherAssessmentType { ca, quiz, test, exam, practical, project }

enum TeacherAssessmentState { draft, published, submitted, locked, released }

/// A canonical class subject this Teacher currently teaches, from the same
/// canonical Teaching Assignment source every other Teacher feature reads
/// (see [TeacherRoster]/[AssignedClass]). One assessment always belongs to
/// exactly one of these plus the current active term.
class TeacherAssessmentOption {
  const TeacherAssessmentOption({
    required this.classSubjectId,
    required this.termId,
    required this.term,
    required this.className,
    required this.subject,
  });

  final String classSubjectId;
  final String termId;
  final String term;
  final String className;
  final String subject;

  String get label => '$className · $subject';
}

/// One student's mark within an assessment. [score] is null while not yet
/// entered - honestly distinct from an entered zero, unlike the earlier
/// local-only prototype which could not tell the two apart.
class TeacherAssessmentEntry {
  const TeacherAssessmentEntry({
    required this.studentId,
    required this.studentName,
    this.admissionNumber = '',
    this.score,
    this.percent,
    this.grade = '',
  });

  final String studentId;
  final String studentName;
  final String admissionNumber;
  final double? score;
  final double? percent;
  final String grade;

  TeacherAssessmentEntry copyWith({double? score, bool clearScore = false}) =>
      TeacherAssessmentEntry(
        studentId: studentId,
        studentName: studentName,
        admissionNumber: admissionNumber,
        score: clearScore ? null : (score ?? this.score),
        percent: percent,
        grade: grade,
      );

  Map<String, Object?> toEntryMutationJson() => {'studentId': studentId, 'score': score};

  factory TeacherAssessmentEntry.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentEntry(
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        admissionNumber: json['admissionNumber'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble(),
        percent: (json['percent'] as num?)?.toDouble(),
        grade: json['grade'] as String? ?? '',
      );
}

class TeacherAssessment {
  const TeacherAssessment({
    required this.id,
    required this.title,
    required this.className,
    required this.subject,
    required this.type,
    required this.maximumScore,
    required this.state,
    required this.entries,
    this.classSubjectId = '',
    this.termId = '',
    this.term = '',
    this.weight = 1,
    this.version = 1,
    this.totalStudents = 0,
    this.entered = 0,
    this.averagePercent,
    this.authorMembershipId = '',
    this.currentTeacherId = '',
    this.currentTeacher = '',
    this.updatedAt,
    this.submittedAt,
    this.lockedAt,
    this.releasedAt,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String title;
  final String className;
  final String subject;
  final TeacherAssessmentType type;
  final int maximumScore;
  final TeacherAssessmentState state;
  final List<TeacherAssessmentEntry> entries;
  final String classSubjectId;
  final String termId;
  final String term;
  final double weight;
  final int version;
  final int totalStudents;
  final int entered;
  final double? averagePercent;
  final String authorMembershipId;
  final String currentTeacherId;
  final String currentTeacher;
  final String? updatedAt;
  final String? submittedAt;
  final String? lockedAt;
  final String? releasedAt;
  final bool pendingSync;
  final int? serverVersion;

  bool get teacherEditable => state == TeacherAssessmentState.draft && !pendingSync;
  bool get scoresEditable => state == TeacherAssessmentState.published && !pendingSync;
  bool get canSubmit => scoresEditable;
  bool get canLock => state == TeacherAssessmentState.submitted && !pendingSync;
  bool get canRelease => state == TeacherAssessmentState.locked && !pendingSync;
  bool get canCorrect =>
      !pendingSync &&
      (state == TeacherAssessmentState.submitted ||
          state == TeacherAssessmentState.locked ||
          state == TeacherAssessmentState.released);
  double get average => entries.isEmpty
      ? 0
      : entries.fold<double>(0, (sum, item) => sum + (item.score ?? 0)) / entries.length;

  TeacherAssessment copyWith({
    String? title,
    String? className,
    String? subject,
    TeacherAssessmentType? type,
    int? maximumScore,
    TeacherAssessmentState? state,
    List<TeacherAssessmentEntry>? entries,
    String? classSubjectId,
    String? termId,
    String? term,
    double? weight,
    int? version,
    int? totalStudents,
    int? entered,
    double? averagePercent,
    String? authorMembershipId,
    String? currentTeacherId,
    String? currentTeacher,
    String? updatedAt,
    String? submittedAt,
    String? lockedAt,
    String? releasedAt,
    bool? pendingSync,
    int? serverVersion,
  }) =>
      TeacherAssessment(
        id: id,
        title: title ?? this.title,
        className: className ?? this.className,
        subject: subject ?? this.subject,
        type: type ?? this.type,
        maximumScore: maximumScore ?? this.maximumScore,
        state: state ?? this.state,
        entries: entries ?? this.entries,
        classSubjectId: classSubjectId ?? this.classSubjectId,
        termId: termId ?? this.termId,
        term: term ?? this.term,
        weight: weight ?? this.weight,
        version: version ?? this.version,
        totalStudents: totalStudents ?? this.totalStudents,
        entered: entered ?? this.entered,
        averagePercent: averagePercent ?? this.averagePercent,
        authorMembershipId: authorMembershipId ?? this.authorMembershipId,
        currentTeacherId: currentTeacherId ?? this.currentTeacherId,
        currentTeacher: currentTeacher ?? this.currentTeacher,
        updatedAt: updatedAt ?? this.updatedAt,
        submittedAt: submittedAt ?? this.submittedAt,
        lockedAt: lockedAt ?? this.lockedAt,
        releasedAt: releasedAt ?? this.releasedAt,
        pendingSync: pendingSync ?? this.pendingSync,
        serverVersion: serverVersion ?? this.serverVersion,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'className': className,
        'subject': subject,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'term': term,
        'type': type.name,
        'maximumScore': maximumScore,
        'weight': weight,
        'state': state.name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'version': version,
        'totalStudents': totalStudents,
        'entered': entered,
        'averagePercent': averagePercent,
        'authorMembershipId': authorMembershipId,
        'currentTeacherId': currentTeacherId,
        'currentTeacher': currentTeacher,
        'updatedAt': updatedAt,
        'submittedAt': submittedAt,
        'lockedAt': lockedAt,
        'releasedAt': releasedAt,
      };

  /// The action-specific fields a definition-level mutation (create draft or
  /// publish) sends. Score entry, submit, lock, release, return and
  /// correction each send their own smaller payload built where they queue.
  Map<String, Object?> toDefinitionMutationJson({required String action}) => {
        'id': id,
        'action': action,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'type': type.name,
        'title': title,
        'maximumScore': maximumScore,
        'weight': weight,
      };

  factory TeacherAssessment.fromJson(Map<String, dynamic> json) {
    final type = TeacherAssessmentType.values.firstWhere(
      (item) => item.name == (json['type'] as String? ?? 'ca'),
      orElse: () => TeacherAssessmentType.ca,
    );
    final state = TeacherAssessmentState.values.firstWhere(
      (item) => item.name == (json['state'] as String? ?? 'draft'),
      orElse: () => TeacherAssessmentState.draft,
    );
    return TeacherAssessment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      className: json['className'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      classSubjectId: json['classSubjectId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      type: type,
      maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
      state: state,
      entries: (json['entries'] as List<dynamic>? ?? const [])
          .map((item) => TeacherAssessmentEntry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      version: (json['version'] as num?)?.toInt() ?? 1,
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      entered: (json['entered'] as num?)?.toInt() ?? 0,
      averagePercent: (json['averagePercent'] as num?)?.toDouble(),
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
      currentTeacherId: json['currentTeacherId'] as String? ?? '',
      currentTeacher: json['currentTeacher'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
      submittedAt: json['submittedAt'] as String?,
      lockedAt: json['lockedAt'] as String?,
      releasedAt: json['releasedAt'] as String?,
    );
  }
}

class TeacherAssessmentPermissions {
  const TeacherAssessmentPermissions({
    required this.canViewAssignedClassAssessments,
    required this.canCreateDraft,
    required this.canPublish,
    required this.canEnterScores,
    required this.canSubmitScores,
    required this.canCorrectScores,
    required this.canLockScores,
    required this.canReleaseResults,
    required this.canAiAlterMarks,
  });

  final bool canViewAssignedClassAssessments;
  final bool canCreateDraft;
  final bool canPublish;
  final bool canEnterScores;
  final bool canSubmitScores;
  final bool canCorrectScores;
  final bool canLockScores;
  final bool canReleaseResults;
  final bool canAiAlterMarks;
}

extension TeacherAssessmentEntryJson on TeacherAssessmentEntry {
  Map<String, Object?> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'admissionNumber': admissionNumber,
        'score': score,
        'percent': percent,
        'grade': grade,
      };
}

String teacherAssessmentTypeLabel(TeacherAssessmentType type) => switch (type) {
      TeacherAssessmentType.ca => 'Continuous Assessment',
      TeacherAssessmentType.quiz => 'Quiz',
      TeacherAssessmentType.test => 'Test',
      TeacherAssessmentType.exam => 'Exam',
      TeacherAssessmentType.practical => 'Practical',
      TeacherAssessmentType.project => 'Project',
    };

String teacherAssessmentStateLabel(TeacherAssessmentState state) => switch (state) {
      TeacherAssessmentState.draft => 'Draft',
      TeacherAssessmentState.published => 'Open for scoring',
      TeacherAssessmentState.submitted => 'Submitted for review',
      TeacherAssessmentState.locked => 'Locked · awaiting release',
      TeacherAssessmentState.released => 'Released',
    };

