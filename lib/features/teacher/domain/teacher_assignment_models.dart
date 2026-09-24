enum TeacherAssignmentState {
  draft,
  queuedForPublication,
  published,
  open,
  closed,
}

enum TeacherAssignmentType { homework, classwork, project, revision }
enum TeacherAssignmentEventAction { savedDraft, queuedForPublication }
enum TeacherSubmissionState { draft, submitted, returned, graded }

class TeacherAssignmentOption {
  const TeacherAssignmentOption({
    required this.classSubjectId,
    required this.termId,
    required this.term,
    required this.className,
    required this.subject,
    this.topics = const [],
  });

  final String classSubjectId;
  final String termId;
  final String term;
  final String className;
  final String subject;
  final List<TeacherAssignmentTopic> topics;

  String get label => '$className · $subject';
}

class TeacherAssignmentTopic {
  const TeacherAssignmentTopic({required this.id, required this.title});

  final String id;
  final String title;
}

class TeacherAssignment {
  const TeacherAssignment({
    required this.id,
    required this.title,
    required this.className,
    required this.type,
    required this.instructions,
    required this.dueDate,
    required this.maximumScore,
    required this.submissions,
    required this.totalStudents,
    required this.marked,
    required this.lateSubmissions,
    required this.state,
    this.classSubjectId = '',
    this.termId = '',
    this.term = '',
    this.subject = '',
    this.topicId = '',
    this.topic = '',
    this.version = 1,
    this.publicationRevision = 0,
    this.authorMembershipId = '',
    this.currentTeacherId = '',
    this.updatedAt,
    this.queuedAt,
    this.publishedAt,
    this.closedAt,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String title;
  final String className;
  final TeacherAssignmentType type;
  final String instructions;
  final String dueDate;
  final int maximumScore;
  final int submissions;
  final int totalStudents;
  final int marked;
  final int lateSubmissions;
  final TeacherAssignmentState state;
  final String classSubjectId;
  final String termId;
  final String term;
  final String subject;
  final String topicId;
  final String topic;
  final int version;
  final int publicationRevision;
  final String authorMembershipId;
  final String currentTeacherId;
  final String? updatedAt;
  final String? queuedAt;
  final String? publishedAt;
  final String? closedAt;
  final bool pendingSync;
  final int? serverVersion;

  int get unmarked => submissions - marked;
  bool get serverPublished =>
      state == TeacherAssignmentState.published ||
      state == TeacherAssignmentState.open;
  bool get teacherEditable => state == TeacherAssignmentState.draft && !pendingSync;
  bool get canRevise => serverPublished && !pendingSync;
  bool get canClose => serverPublished && !pendingSync;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $title $className $subject ${teacherAssignmentStateLabel(state)}'
        .toLowerCase()
        .contains(q);
  }

  TeacherAssignment copyWith({
    String? title,
    String? className,
    TeacherAssignmentType? type,
    String? instructions,
    String? dueDate,
    int? maximumScore,
    int? submissions,
    int? totalStudents,
    int? marked,
    int? lateSubmissions,
    TeacherAssignmentState? state,
    String? classSubjectId,
    String? termId,
    String? term,
    String? subject,
    String? topicId,
    String? topic,
    int? version,
    int? publicationRevision,
    String? authorMembershipId,
    String? currentTeacherId,
    String? updatedAt,
    String? queuedAt,
    String? publishedAt,
    String? closedAt,
    bool? pendingSync,
    int? serverVersion,
  }) =>
      TeacherAssignment(
        id: id,
        title: title ?? this.title,
        className: className ?? this.className,
        type: type ?? this.type,
        instructions: instructions ?? this.instructions,
        dueDate: dueDate ?? this.dueDate,
        maximumScore: maximumScore ?? this.maximumScore,
        submissions: submissions ?? this.submissions,
        totalStudents: totalStudents ?? this.totalStudents,
        marked: marked ?? this.marked,
        lateSubmissions: lateSubmissions ?? this.lateSubmissions,
        state: state ?? this.state,
        classSubjectId: classSubjectId ?? this.classSubjectId,
        termId: termId ?? this.termId,
        term: term ?? this.term,
        subject: subject ?? this.subject,
        topicId: topicId ?? this.topicId,
        topic: topic ?? this.topic,
        version: version ?? this.version,
        publicationRevision: publicationRevision ?? this.publicationRevision,
        authorMembershipId: authorMembershipId ?? this.authorMembershipId,
        currentTeacherId: currentTeacherId ?? this.currentTeacherId,
        updatedAt: updatedAt ?? this.updatedAt,
        queuedAt: queuedAt ?? this.queuedAt,
        publishedAt: publishedAt ?? this.publishedAt,
        closedAt: closedAt ?? this.closedAt,
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
        'topicId': topicId,
        'topic': topic,
        'type': type.name,
        'instructions': instructions,
        'dueAt': dueDate,
        'dueDate': dueDate,
        'maximumScore': maximumScore,
        'submissions': submissions,
        'totalStudents': totalStudents,
        'marked': marked,
        'unmarked': unmarked,
        'lateSubmissions': lateSubmissions,
        'state': _stateWireValue(state),
        'version': version,
        'publicationRevision': publicationRevision,
        'authorMembershipId': authorMembershipId,
        'currentTeacherId': currentTeacherId,
        'updatedAt': updatedAt,
        'queuedAt': queuedAt,
        'publishedAt': publishedAt,
        'closedAt': closedAt,
      };

  Map<String, Object?> toMutationJson({required String action}) => {
        'id': id,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'topicId': topicId,
        'action': action,
        'type': type.name,
        'title': title,
        'instructions': instructions,
        'dueAt': dueDate,
        'maximumScore': maximumScore,
      };

  factory TeacherAssignment.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'] as String? ?? 'draft';
    final state = switch (rawState) {
      'published' => TeacherAssignmentState.published,
      'open' => TeacherAssignmentState.open,
      'closed' => TeacherAssignmentState.closed,
      'queuedForPublication' => TeacherAssignmentState.queuedForPublication,
      _ => TeacherAssignmentState.draft,
    };
    return TeacherAssignment(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      className: json['className'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      classSubjectId: json['classSubjectId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      type: TeacherAssignmentType.values.firstWhere(
        (item) => item.name == (json['type'] as String? ?? 'homework'),
        orElse: () => TeacherAssignmentType.homework,
      ),
      instructions: json['instructions'] as String? ?? '',
      dueDate: (json['dueAt'] ?? json['dueDate']) as String? ?? '',
      maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 0,
      submissions: (json['submissions'] as num?)?.toInt() ?? 0,
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      marked: (json['marked'] as num?)?.toInt() ?? 0,
      lateSubmissions: (json['lateSubmissions'] as num?)?.toInt() ?? 0,
      state: state,
      version: (json['version'] as num?)?.toInt() ?? 1,
      publicationRevision:
          (json['publicationRevision'] as num?)?.toInt() ?? 0,
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
      currentTeacherId: json['currentTeacherId'] as String? ?? '',
      updatedAt: json['updatedAt'] as String?,
      queuedAt: json['queuedAt'] as String?,
      publishedAt: json['publishedAt'] as String?,
      closedAt: json['closedAt'] as String?,
    );
  }
}

class TeacherAssignmentSubmission {
  const TeacherAssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.title,
    required this.className,
    required this.subject,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.state,
    required this.responseText,
    required this.maximumScore,
    this.attemptNumber = 0,
    this.submittedAt,
    this.isLate = false,
    this.score,
    this.feedback = '',
    this.gradedAt,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String assignmentId;
  final String title;
  final String className;
  final String subject;
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final TeacherSubmissionState state;
  final String responseText;
  final int maximumScore;
  final int attemptNumber;
  final String? submittedAt;
  final bool isLate;
  final double? score;
  final String feedback;
  final String? gradedAt;
  final bool pendingSync;
  final int? serverVersion;

  bool get markable =>
      state == TeacherSubmissionState.submitted ||
      state == TeacherSubmissionState.graded;

  factory TeacherAssignmentSubmission.fromJson(Map<String, dynamic> json) =>
      TeacherAssignmentSubmission(
        id: json['id'] as String? ?? '',
        assignmentId: json['assignmentId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        admissionNumber: json['admissionNumber'] as String? ?? '',
        state: TeacherSubmissionState.values.firstWhere(
          (item) => item.name == (json['state'] as String? ?? 'draft'),
          orElse: () => TeacherSubmissionState.draft,
        ),
        responseText: json['responseText'] as String? ?? '',
        maximumScore: (json['maximumScore'] as num?)?.toInt() ?? 0,
        attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 0,
        submittedAt: json['submittedAt'] as String?,
        isLate: json['isLate'] == true,
        score: (json['score'] as num?)?.toDouble(),
        feedback: json['feedback'] as String? ?? '',
        gradedAt: json['gradedAt'] as String?,
      );
}

class TeacherAssignmentEvent {
  const TeacherAssignmentEvent({
    required this.id,
    required this.assignmentId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });

  final String id;
  final String assignmentId;
  final TeacherAssignmentEventAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'assignmentId': assignmentId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };
}

class TeacherAssignmentPermissions {
  const TeacherAssignmentPermissions({
    required this.canViewAssignedClassAssignments,
    required this.canCreateDraft,
    required this.canQueuePublication,
    required this.canConfirmPublication,
    required this.canConfirmScores,
    required this.canAutoGrade,
  });

  final bool canViewAssignedClassAssignments;
  final bool canCreateDraft;
  final bool canQueuePublication;
  final bool canConfirmPublication;
  final bool canConfirmScores;
  final bool canAutoGrade;
}

String _stateWireValue(TeacherAssignmentState state) => switch (state) {
      TeacherAssignmentState.published || TeacherAssignmentState.open => 'published',
      TeacherAssignmentState.closed => 'closed',
      TeacherAssignmentState.queuedForPublication => 'queuedForPublication',
      _ => 'draft',
    };

String teacherAssignmentStateLabel(TeacherAssignmentState state) => switch (state) {
      TeacherAssignmentState.draft => 'Draft',
      TeacherAssignmentState.queuedForPublication => 'Queued · not server-acknowledged',
      TeacherAssignmentState.published || TeacherAssignmentState.open => 'Published',
      TeacherAssignmentState.closed => 'Closed',
    };

String teacherAssignmentTypeLabel(TeacherAssignmentType type) => switch (type) {
      TeacherAssignmentType.homework => 'Homework',
      TeacherAssignmentType.classwork => 'Classwork',
      TeacherAssignmentType.project => 'Project',
      TeacherAssignmentType.revision => 'Revision',
    };

String teacherSubmissionStateLabel(TeacherSubmissionState state) => switch (state) {
      TeacherSubmissionState.draft => 'Draft',
      TeacherSubmissionState.submitted => 'Submitted',
      TeacherSubmissionState.returned => 'Returned',
      TeacherSubmissionState.graded => 'Graded',
    };
