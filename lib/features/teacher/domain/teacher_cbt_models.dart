enum TeacherCbtSetState { draft, queuedForPublication, published, closed }

enum TeacherCbtEventAction { savedDraft, queuedForPublication }

class TeacherCbtQuestion {
  const TeacherCbtQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  bool get isValid =>
      prompt.trim().isNotEmpty &&
      options.length >= 2 &&
      options.every((option) => option.trim().isNotEmpty) &&
      correctIndex >= 0 &&
      correctIndex < options.length;

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
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory TeacherCbtQuestion.fromJson(Map<String, dynamic> json) => TeacherCbtQuestion(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        options: (json['options'] as List<dynamic>).map((item) => item as String).toList(growable: false),
        correctIndex: json['correctIndex'] as int,
        explanation: json['explanation'] as String? ?? '',
      );
}

class TeacherCbtPracticeSet {
  const TeacherCbtPracticeSet({
    required this.id,
    required this.title,
    required this.className,
    required this.items,
    required this.durationMinutes,
    required this.state,
    required this.attempts,
    required this.averageAccuracy,
    required this.resultMode,
    required this.instructions,
    this.version = 1,
    this.queuedAt,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String className;

  /// The real questions a teacher has actually written for this set. `questionCount` (not a
  /// separately-settable number) is what a student attempting this set really answers.
  final List<TeacherCbtQuestion> items;

  final int durationMinutes;
  final TeacherCbtSetState state;

  /// Read-only, real evidence: how many real students have really submitted an attempt, and their
  /// real average accuracy. Always recomputed by `TeacherCbtRepository.load()` from real attempt
  /// records, never hand-set — see `TeacherCbtRepository`'s own doc comment.
  final int attempts;
  final int averageAccuracy;

  final String resultMode;
  final String instructions;
  final int version;
  final String? queuedAt;
  final String? publishedAt;

  int get questionCount => items.length;

  bool get teacherEditable => state == TeacherCbtSetState.draft;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $title $className ${teacherCbtSetStateLabel(state)}'
        .toLowerCase()
        .contains(q);
  }

  TeacherCbtPracticeSet copyWith({
    String? title,
    String? className,
    List<TeacherCbtQuestion>? items,
    int? durationMinutes,
    TeacherCbtSetState? state,
    int? attempts,
    int? averageAccuracy,
    String? resultMode,
    String? instructions,
    int? version,
    String? queuedAt,
    String? publishedAt,
  }) =>
      TeacherCbtPracticeSet(
        id: id,
        title: title ?? this.title,
        className: className ?? this.className,
        items: items ?? this.items,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        state: state ?? this.state,
        attempts: attempts ?? this.attempts,
        averageAccuracy: averageAccuracy ?? this.averageAccuracy,
        resultMode: resultMode ?? this.resultMode,
        instructions: instructions ?? this.instructions,
        version: version ?? this.version,
        queuedAt: queuedAt ?? this.queuedAt,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'className': className,
        'items': items.map((item) => item.toJson()).toList(),
        'durationMinutes': durationMinutes,
        'state': state.name,
        'attempts': attempts,
        'averageAccuracy': averageAccuracy,
        'resultMode': resultMode,
        'instructions': instructions,
        'version': version,
        'queuedAt': queuedAt,
        'publishedAt': publishedAt,
      };

  factory TeacherCbtPracticeSet.fromJson(Map<String, dynamic> json) =>
      TeacherCbtPracticeSet(
        id: json['id'] as String,
        title: json['title'] as String,
        className: json['className'] as String,
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => TeacherCbtQuestion.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        durationMinutes: json['durationMinutes'] as int,
        state: TeacherCbtSetState.values.byName(json['state'] as String),
        attempts: json['attempts'] as int,
        averageAccuracy: json['averageAccuracy'] as int,
        resultMode: json['resultMode'] as String,
        instructions: json['instructions'] as String,
        version: json['version'] as int? ?? 1,
        queuedAt: json['queuedAt'] as String?,
        publishedAt: json['publishedAt'] as String?,
      );
}

class TeacherCbtEvent {
  const TeacherCbtEvent({
    required this.id,
    required this.setId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });
  final String id;
  final String setId;
  final TeacherCbtEventAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'setId': setId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };
}

/// One real student's real completed attempt at a real published [TeacherCbtPracticeSet]. Written by
/// the student side (`StudentCbtRepository`) and read back by `TeacherCbtRepository.load()` to compute
/// a set's real `attempts`/`averageAccuracy` — the two numbers this whole model used to fabricate.
class TeacherCbtAttempt {
  const TeacherCbtAttempt({
    required this.id,
    required this.setId,
    required this.studentMembershipId,
    required this.score,
    required this.totalQuestions,
    required this.submittedAt,
  });

  final String id;
  final String setId;
  final String studentMembershipId;
  final int score;
  final int totalQuestions;
  final String submittedAt;

  int get accuracyPercent => totalQuestions == 0 ? 0 : ((score / totalQuestions) * 100).round();

  Map<String, Object?> toJson() => {
        'id': id,
        'setId': setId,
        'studentMembershipId': studentMembershipId,
        'score': score,
        'totalQuestions': totalQuestions,
        'submittedAt': submittedAt,
      };

  factory TeacherCbtAttempt.fromJson(Map<String, dynamic> json) => TeacherCbtAttempt(
        id: json['id'] as String,
        setId: json['setId'] as String,
        studentMembershipId: json['studentMembershipId'] as String,
        score: json['score'] as int,
        totalQuestions: json['totalQuestions'] as int,
        submittedAt: json['submittedAt'] as String,
      );
}

class TeacherCbtPermissions {
  const TeacherCbtPermissions({
    required this.canViewAssignedPractice,
    required this.canEditDrafts,
    required this.canQueuePublication,
    required this.canConfirmPublication,
    required this.canUsePracticeEvidence,
    required this.canMakeHighStakesDecision,
  });
  final bool canViewAssignedPractice;
  final bool canEditDrafts;
  final bool canQueuePublication;
  final bool canConfirmPublication;
  final bool canUsePracticeEvidence;
  final bool canMakeHighStakesDecision;
}

String teacherCbtSetStateLabel(TeacherCbtSetState state) => switch (state) {
      TeacherCbtSetState.draft => 'Draft',
      TeacherCbtSetState.queuedForPublication => 'Queued',
      TeacherCbtSetState.published => 'Published',
      TeacherCbtSetState.closed => 'Closed',
    };
