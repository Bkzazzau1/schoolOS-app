enum TeacherCbtSetState { draft, queuedForPublication, published, closed }

enum TeacherCbtEventAction { savedDraft, queuedForPublication }

class TeacherCbtPracticeSet {
  const TeacherCbtPracticeSet({
    required this.id,
    required this.title,
    required this.className,
    required this.questions,
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
  final int questions;
  final int durationMinutes;
  final TeacherCbtSetState state;
  final int attempts;
  final int averageAccuracy;
  final String resultMode;
  final String instructions;
  final int version;
  final String? queuedAt;
  final String? publishedAt;

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
    int? questions,
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
        questions: questions ?? this.questions,
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
        'questions': questions,
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
        questions: json['questions'] as int,
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

class TeacherCbtResult {
  const TeacherCbtResult({
    required this.student,
    required this.className,
    required this.score,
    required this.accuracy,
    required this.time,
    required this.focus,
  });
  final String student;
  final String className;
  final String score;
  final String accuracy;
  final String time;
  final String focus;
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
