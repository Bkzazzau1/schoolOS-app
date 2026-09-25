enum TeacherCbtTestState { draft, published, closed }

enum TeacherCbtResultMode { scoreOnly, scoreAndAnswers }

/// A canonical class subject this Teacher currently teaches - a CBT test can
/// only be created for one of these, so a test always names one specific
/// subject in one specific class, never just a class.
class TeacherCbtOption {
  const TeacherCbtOption({
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

/// [correctIndex]/[explanation] are null whenever the server has redacted
/// them - always true for a Student before their own attempt is submitted,
/// and even then only revealed if the test's result mode allows it. A
/// Teacher authoring or reviewing their own test always receives both.
class TeacherCbtQuestion {
  const TeacherCbtQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.correctIndex,
    this.explanation = '',
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int? correctIndex;
  final String explanation;

  bool get isValid =>
      prompt.trim().isNotEmpty &&
      options.length >= 2 &&
      options.every((option) => option.trim().isNotEmpty) &&
      correctIndex != null &&
      correctIndex! >= 0 &&
      correctIndex! < options.length;

  TeacherCbtQuestion copyWith({
    String? prompt,
    List<String>? options,
    int? correctIndex,
    String? explanation,
  }) =>
      TeacherCbtQuestion(
        id: id,
        prompt: prompt ?? this.prompt,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        explanation: explanation ?? this.explanation,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'prompt': prompt,
        'options': options,
        if (correctIndex != null) 'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory TeacherCbtQuestion.fromJson(Map<String, dynamic> json) => TeacherCbtQuestion(
        id: json['id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        options: (json['options'] as List<dynamic>? ?? const [])
            .map((item) => item as String)
            .toList(growable: false),
        correctIndex: (json['correctIndex'] as num?)?.toInt(),
        explanation: json['explanation'] as String? ?? '',
      );
}

class TeacherCbtTest {
  const TeacherCbtTest({
    required this.id,
    required this.title,
    required this.className,
    required this.subject,
    required this.questions,
    required this.durationMinutes,
    required this.state,
    required this.resultMode,
    required this.instructions,
    this.classSubjectId = '',
    this.termId = '',
    this.term = '',
    this.version = 1,
    this.totalRecipients = 0,
    this.submittedCount = 0,
    this.averageScorePercent,
    this.authorMembershipId = '',
    this.currentTeacherId = '',
    this.currentTeacher = '',
    this.publishedAt,
    this.closedAt,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String title;
  final String className;
  final String subject;
  final List<TeacherCbtQuestion> questions;
  final int durationMinutes;
  final TeacherCbtTestState state;
  final TeacherCbtResultMode resultMode;
  final String instructions;
  final String classSubjectId;
  final String termId;
  final String term;
  final int version;

  /// Real evidence, always server-computed - never hand-set, never present
  /// before at least one recipient exists.
  final int totalRecipients;
  final int submittedCount;
  final double? averageScorePercent;

  final String authorMembershipId;
  final String currentTeacherId;
  final String currentTeacher;
  final String? publishedAt;
  final String? closedAt;
  final bool pendingSync;
  final int? serverVersion;

  int get questionCount => questions.length;
  bool get teacherEditable => state == TeacherCbtTestState.draft && !pendingSync;
  bool get canPublish => teacherEditable;
  bool get canClose => state == TeacherCbtTestState.published && !pendingSync;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $title $className $subject ${teacherCbtTestStateLabel(state)}'.toLowerCase().contains(q);
  }

  TeacherCbtTest copyWith({
    String? title,
    String? className,
    String? subject,
    List<TeacherCbtQuestion>? questions,
    int? durationMinutes,
    TeacherCbtTestState? state,
    TeacherCbtResultMode? resultMode,
    String? instructions,
    String? classSubjectId,
    String? termId,
    String? term,
    int? version,
    int? totalRecipients,
    int? submittedCount,
    double? averageScorePercent,
    String? authorMembershipId,
    String? currentTeacherId,
    String? currentTeacher,
    String? publishedAt,
    String? closedAt,
    bool? pendingSync,
    int? serverVersion,
  }) =>
      TeacherCbtTest(
        id: id,
        title: title ?? this.title,
        className: className ?? this.className,
        subject: subject ?? this.subject,
        questions: questions ?? this.questions,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        state: state ?? this.state,
        resultMode: resultMode ?? this.resultMode,
        instructions: instructions ?? this.instructions,
        classSubjectId: classSubjectId ?? this.classSubjectId,
        termId: termId ?? this.termId,
        term: term ?? this.term,
        version: version ?? this.version,
        totalRecipients: totalRecipients ?? this.totalRecipients,
        submittedCount: submittedCount ?? this.submittedCount,
        averageScorePercent: averageScorePercent ?? this.averageScorePercent,
        authorMembershipId: authorMembershipId ?? this.authorMembershipId,
        currentTeacherId: currentTeacherId ?? this.currentTeacherId,
        currentTeacher: currentTeacher ?? this.currentTeacher,
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
        'questions': questions.map((q) => q.toJson()).toList(),
        'durationMinutes': durationMinutes,
        'state': state.name,
        'resultMode': resultMode.name,
        'instructions': instructions,
        'version': version,
        'totalRecipients': totalRecipients,
        'submittedCount': submittedCount,
        'averageScorePercent': averageScorePercent,
        'authorMembershipId': authorMembershipId,
        'currentTeacherId': currentTeacherId,
        'currentTeacher': currentTeacher,
        'publishedAt': publishedAt,
        'closedAt': closedAt,
      };

  /// The action-specific fields a definition-level mutation (save draft,
  /// publish) sends. close sends only {id, action}.
  Map<String, Object?> toDefinitionMutationJson({required String action}) => {
        'id': id,
        'action': action,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'title': title,
        'durationMinutes': durationMinutes,
        'instructions': instructions,
        'resultMode': _resultModeWireValue(resultMode),
        'questions': [
          for (final q in questions)
            {
              'prompt': q.prompt,
              'options': q.options,
              'correctIndex': q.correctIndex,
              'explanation': q.explanation,
            },
        ],
      };

  factory TeacherCbtTest.fromJson(Map<String, dynamic> json) {
    final state = TeacherCbtTestState.values.firstWhere(
      (item) => item.name == (json['state'] as String? ?? 'draft'),
      orElse: () => TeacherCbtTestState.draft,
    );
    return TeacherCbtTest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      className: json['className'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      classSubjectId: json['classSubjectId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((item) => TeacherCbtQuestion.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 15,
      state: state,
      resultMode: _resultModeFromWire(json['resultMode'] as String?),
      instructions: json['instructions'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 1,
      totalRecipients: (json['totalRecipients'] as num?)?.toInt() ?? 0,
      submittedCount: (json['submittedCount'] as num?)?.toInt() ?? 0,
      averageScorePercent: (json['averageScorePercent'] as num?)?.toDouble(),
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
      currentTeacherId: json['currentTeacherId'] as String? ?? '',
      currentTeacher: json['currentTeacher'] as String? ?? '',
      publishedAt: json['publishedAt'] as String?,
      closedAt: json['closedAt'] as String?,
    );
  }
}

/// One recipient's own attempt at a published test - started, answered
/// question by question, then submitted. [score] is null until the server
/// has computed it at submission; never trusted from anywhere else.
class TeacherCbtAttempt {
  const TeacherCbtAttempt({
    required this.id,
    required this.testId,
    required this.testTitle,
    required this.className,
    required this.subject,
    required this.durationMinutes,
    required this.questionCount,
    required this.studentId,
    required this.studentName,
    this.startedAt,
    this.deadlineAt,
    this.answers = const [],
    this.submitted = false,
    this.submittedAt,
    this.score,
    this.version = 1,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String testId;
  final String testTitle;
  final String className;
  final String subject;
  final int durationMinutes;
  final int questionCount;
  final String studentId;
  final String studentName;
  final String? startedAt;
  final String? deadlineAt;
  final List<int?> answers;
  final bool submitted;
  final String? submittedAt;
  final int? score;
  final int version;
  final bool pendingSync;
  final int? serverVersion;

  bool get started => startedAt != null;

  DateTime? get deadline => deadlineAt == null ? null : DateTime.tryParse(deadlineAt!);

  TeacherCbtAttempt copyWith({
    String? startedAt,
    String? deadlineAt,
    List<int?>? answers,
    bool? submitted,
    String? submittedAt,
    int? score,
    int? version,
    bool? pendingSync,
    int? serverVersion,
  }) =>
      TeacherCbtAttempt(
        id: id,
        testId: testId,
        testTitle: testTitle,
        className: className,
        subject: subject,
        durationMinutes: durationMinutes,
        questionCount: questionCount,
        studentId: studentId,
        studentName: studentName,
        startedAt: startedAt ?? this.startedAt,
        deadlineAt: deadlineAt ?? this.deadlineAt,
        answers: answers ?? this.answers,
        submitted: submitted ?? this.submitted,
        submittedAt: submittedAt ?? this.submittedAt,
        score: score ?? this.score,
        version: version ?? this.version,
        pendingSync: pendingSync ?? this.pendingSync,
        serverVersion: serverVersion ?? this.serverVersion,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'testId': testId,
        'testTitle': testTitle,
        'className': className,
        'subject': subject,
        'durationMinutes': durationMinutes,
        'questionCount': questionCount,
        'studentId': studentId,
        'studentName': studentName,
        'startedAt': startedAt,
        'deadlineAt': deadlineAt,
        'answers': answers,
        'submitted': submitted,
        'submittedAt': submittedAt,
        'score': score,
        'version': version,
      };

  factory TeacherCbtAttempt.fromJson(Map<String, dynamic> json) => TeacherCbtAttempt(
        id: json['id'] as String? ?? '',
        testId: json['testId'] as String? ?? '',
        testTitle: json['testTitle'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
        studentId: json['studentId'] as String? ?? '',
        studentName: json['studentName'] as String? ?? '',
        startedAt: json['startedAt'] as String?,
        deadlineAt: json['deadlineAt'] as String?,
        answers: (json['answers'] as List<dynamic>? ?? const [])
            .map((item) => (item as num?)?.toInt())
            .toList(growable: false),
        submitted: json['submitted'] == true,
        submittedAt: json['submittedAt'] as String?,
        score: (json['score'] as num?)?.toInt(),
        version: (json['version'] as num?)?.toInt() ?? 1,
      );
}

class TeacherCbtPermissions {
  const TeacherCbtPermissions({
    required this.canViewAssignedClassTests,
    required this.canCreateDraft,
    required this.canPublish,
    required this.canClose,
    required this.canUsePracticeEvidence,
  });

  final bool canViewAssignedClassTests;
  final bool canCreateDraft;
  final bool canPublish;
  final bool canClose;
  final bool canUsePracticeEvidence;
}

String _resultModeWireValue(TeacherCbtResultMode mode) => switch (mode) {
      TeacherCbtResultMode.scoreOnly => 'score_only',
      TeacherCbtResultMode.scoreAndAnswers => 'score_and_answers',
    };

TeacherCbtResultMode _resultModeFromWire(String? value) => switch (value) {
      'score_and_answers' => TeacherCbtResultMode.scoreAndAnswers,
      _ => TeacherCbtResultMode.scoreOnly,
    };

String teacherCbtTestStateLabel(TeacherCbtTestState state) => switch (state) {
      TeacherCbtTestState.draft => 'Draft',
      TeacherCbtTestState.published => 'Published',
      TeacherCbtTestState.closed => 'Closed',
    };

String teacherCbtResultModeLabel(TeacherCbtResultMode mode) => switch (mode) {
      TeacherCbtResultMode.scoreOnly => 'Show score only',
      TeacherCbtResultMode.scoreAndAnswers => 'Show score and correct answers',
    };
