enum TeacherAssessmentSheetState { draft, submittedForReview, locked, released }

enum TeacherAssessmentEventAction { savedProgress, submittedForReview }

enum TeacherAssessmentRegisterState { complete, inProgress }

class TeacherAssessmentRegisterItem {
  const TeacherAssessmentRegisterItem({
    required this.id,
    required this.title,
    required this.className,
    required this.maximumScore,
    required this.entered,
    required this.total,
    required this.average,
    required this.state,
  });

  final String id;
  final String title;
  final String className;
  final int maximumScore;
  final int entered;
  final int total;
  final double average;
  final TeacherAssessmentRegisterState state;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'className': className,
        'maximumScore': maximumScore,
        'entered': entered,
        'total': total,
        'average': average,
        'state': state.name,
      };

  factory TeacherAssessmentRegisterItem.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentRegisterItem(
        id: json['id'] as String,
        title: json['title'] as String,
        className: json['className'] as String,
        maximumScore: json['maximumScore'] as int,
        entered: json['entered'] as int,
        total: json['total'] as int,
        average: (json['average'] as num).toDouble(),
        state: TeacherAssessmentRegisterState.values.byName(json['state'] as String),
      );
}

class TeacherAssessmentScoreEntry {
  const TeacherAssessmentScoreEntry({required this.studentId, required this.score});

  final String studentId;
  final int score;

  TeacherAssessmentScoreEntry copyWith({int? score}) =>
      TeacherAssessmentScoreEntry(studentId: studentId, score: score ?? this.score);

  Map<String, Object?> toJson() => {'studentId': studentId, 'score': score};

  factory TeacherAssessmentScoreEntry.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentScoreEntry(
        studentId: json['studentId'] as String,
        score: json['score'] as int,
      );
}

class TeacherAssessmentScoreSheet {
  const TeacherAssessmentScoreSheet({
    required this.id,
    required this.className,
    required this.assessmentLabel,
    required this.maximumScore,
    required this.entries,
    required this.state,
    this.version = 1,
    this.updatedAt,
    this.submittedAt,
    this.lockedAt,
    this.releasedAt,
  });

  final String id;
  final String className;
  final String assessmentLabel;
  final int maximumScore;
  final List<TeacherAssessmentScoreEntry> entries;
  final TeacherAssessmentSheetState state;
  final int version;
  final String? updatedAt;
  final String? submittedAt;
  final String? lockedAt;
  final String? releasedAt;

  bool get teacherEditable => state == TeacherAssessmentSheetState.draft;
  double get average => entries.isEmpty
      ? 0
      : entries.fold<int>(0, (sum, item) => sum + item.score) / entries.length;

  TeacherAssessmentScoreSheet copyWith({
    String? className,
    String? assessmentLabel,
    int? maximumScore,
    List<TeacherAssessmentScoreEntry>? entries,
    TeacherAssessmentSheetState? state,
    int? version,
    String? updatedAt,
    String? submittedAt,
    String? lockedAt,
    String? releasedAt,
  }) =>
      TeacherAssessmentScoreSheet(
        id: id,
        className: className ?? this.className,
        assessmentLabel: assessmentLabel ?? this.assessmentLabel,
        maximumScore: maximumScore ?? this.maximumScore,
        entries: entries ?? this.entries,
        state: state ?? this.state,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        submittedAt: submittedAt ?? this.submittedAt,
        lockedAt: lockedAt ?? this.lockedAt,
        releasedAt: releasedAt ?? this.releasedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'assessmentLabel': assessmentLabel,
        'maximumScore': maximumScore,
        'entries': entries.map((item) => item.toJson()).toList(),
        'state': state.name,
        'version': version,
        'updatedAt': updatedAt,
        'submittedAt': submittedAt,
        'lockedAt': lockedAt,
        'releasedAt': releasedAt,
      };

  factory TeacherAssessmentScoreSheet.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentScoreSheet(
        id: json['id'] as String,
        className: json['className'] as String,
        assessmentLabel: json['assessmentLabel'] as String,
        maximumScore: json['maximumScore'] as int,
        entries: (json['entries'] as List<dynamic>)
            .map((item) => TeacherAssessmentScoreEntry.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
        state: TeacherAssessmentSheetState.values.byName(json['state'] as String),
        version: json['version'] as int? ?? 1,
        updatedAt: json['updatedAt'] as String?,
        submittedAt: json['submittedAt'] as String?,
        lockedAt: json['lockedAt'] as String?,
        releasedAt: json['releasedAt'] as String?,
      );
}

class TeacherAssessmentEvent {
  const TeacherAssessmentEvent({
    required this.id,
    required this.sheetId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });

  final String id;
  final String sheetId;
  final TeacherAssessmentEventAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'sheetId': sheetId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };

  factory TeacherAssessmentEvent.fromJson(Map<String, dynamic> json) =>
      TeacherAssessmentEvent(
        id: json['id'] as String,
        sheetId: json['sheetId'] as String,
        action: TeacherAssessmentEventAction.values.byName(json['action'] as String),
        actorMembershipId: json['actorMembershipId'] as String,
        version: json['version'] as int,
        occurredAt: json['occurredAt'] as String,
      );
}

class TeacherAssessmentPermissions {
  const TeacherAssessmentPermissions({
    required this.canViewAssignedClassAssessments,
    required this.canEnterScores,
    required this.canSubmitScores,
    required this.canLockScores,
    required this.canReleaseResults,
    required this.canAiAlterMarks,
  });

  final bool canViewAssignedClassAssessments;
  final bool canEnterScores;
  final bool canSubmitScores;
  final bool canLockScores;
  final bool canReleaseResults;
  final bool canAiAlterMarks;
}

String teacherAssessmentSheetStateLabel(TeacherAssessmentSheetState state) => switch (state) {
      TeacherAssessmentSheetState.draft => 'Draft',
      TeacherAssessmentSheetState.submittedForReview => 'Submitted for review',
      TeacherAssessmentSheetState.locked => 'Locked',
      TeacherAssessmentSheetState.released => 'Released',
    };
