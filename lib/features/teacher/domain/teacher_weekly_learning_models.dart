enum TeacherWeeklyPublicationState {
  draft,
  queuedForPublication,
  published,
}

enum TeacherWeeklyEventAction {
  savedDraft,
  queuedForPublication,
}

class TeacherWeeklySubjectUpdate {
  const TeacherWeeklySubjectUpdate({
    required this.subject,
    required this.planned,
    required this.covered,
    required this.next,
    required this.evidence,
    required this.support,
    this.linkedPlanId,
  });

  final String subject;
  final String planned;
  final String covered;
  final String next;
  final String evidence;
  final String support;
  final String? linkedPlanId;

  bool get hasCoverage => covered.trim().isNotEmpty;

  TeacherWeeklySubjectUpdate copyWith({
    String? planned,
    String? covered,
    String? next,
    String? evidence,
    String? support,
  }) =>
      TeacherWeeklySubjectUpdate(
        subject: subject,
        planned: planned ?? this.planned,
        covered: covered ?? this.covered,
        next: next ?? this.next,
        evidence: evidence ?? this.evidence,
        support: support ?? this.support,
        linkedPlanId: linkedPlanId,
      );

  Map<String, Object?> toJson() => {
        'subject': subject,
        'planned': planned,
        'covered': covered,
        'next': next,
        'evidence': evidence,
        'support': support,
        'linkedPlanId': linkedPlanId,
      };

  factory TeacherWeeklySubjectUpdate.fromJson(Map<String, dynamic> json) =>
      TeacherWeeklySubjectUpdate(
        subject: json['subject'] as String,
        planned: json['planned'] as String,
        covered: json['covered'] as String,
        next: json['next'] as String,
        evidence: json['evidence'] as String,
        support: json['support'] as String,
        linkedPlanId: json['linkedPlanId'] as String?,
      );
}

class TeacherWeeklyLearningUpdate {
  const TeacherWeeklyLearningUpdate({
    required this.id,
    required this.className,
    required this.week,
    required this.subjects,
    required this.note,
    required this.state,
    this.version = 1,
    this.updatedAt,
    this.queuedAt,
    this.publishedAt,
  });

  final String id;
  final String className;
  final String week;
  final List<TeacherWeeklySubjectUpdate> subjects;
  final String note;
  final TeacherWeeklyPublicationState state;
  final int version;
  final String? updatedAt;
  final String? queuedAt;
  final String? publishedAt;

  int get completionPercent {
    if (subjects.isEmpty) return 0;
    final ready = subjects.where((item) => item.hasCoverage).length;
    return ((ready / subjects.length) * 100).round();
  }

  bool get teacherEditable => state == TeacherWeeklyPublicationState.draft;

  TeacherWeeklyLearningUpdate copyWith({
    String? className,
    String? week,
    List<TeacherWeeklySubjectUpdate>? subjects,
    String? note,
    TeacherWeeklyPublicationState? state,
    int? version,
    String? updatedAt,
    String? queuedAt,
    String? publishedAt,
  }) =>
      TeacherWeeklyLearningUpdate(
        id: id,
        className: className ?? this.className,
        week: week ?? this.week,
        subjects: subjects ?? this.subjects,
        note: note ?? this.note,
        state: state ?? this.state,
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        queuedAt: queuedAt ?? this.queuedAt,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'week': week,
        'subjects': subjects.map((item) => item.toJson()).toList(),
        'note': note,
        'state': state.name,
        'version': version,
        'updatedAt': updatedAt,
        'queuedAt': queuedAt,
        'publishedAt': publishedAt,
      };

  factory TeacherWeeklyLearningUpdate.fromJson(Map<String, dynamic> json) =>
      TeacherWeeklyLearningUpdate(
        id: json['id'] as String,
        className: json['className'] as String,
        week: json['week'] as String,
        subjects: (json['subjects'] as List<dynamic>)
            .map((item) => TeacherWeeklySubjectUpdate.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(growable: false),
        note: json['note'] as String,
        state: TeacherWeeklyPublicationState.values.byName(json['state'] as String),
        version: json['version'] as int? ?? 1,
        updatedAt: json['updatedAt'] as String?,
        queuedAt: json['queuedAt'] as String?,
        publishedAt: json['publishedAt'] as String?,
      );
}

class TeacherWeeklyLearningEvent {
  const TeacherWeeklyLearningEvent({
    required this.id,
    required this.updateId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });

  final String id;
  final String updateId;
  final TeacherWeeklyEventAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'updateId': updateId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };

  factory TeacherWeeklyLearningEvent.fromJson(Map<String, dynamic> json) =>
      TeacherWeeklyLearningEvent(
        id: json['id'] as String,
        updateId: json['updateId'] as String,
        action: TeacherWeeklyEventAction.values.byName(json['action'] as String),
        actorMembershipId: json['actorMembershipId'] as String,
        version: json['version'] as int,
        occurredAt: json['occurredAt'] as String,
      );
}

class TeacherWeeklyLearningPermissions {
  const TeacherWeeklyLearningPermissions({
    required this.canViewAssignedClassUpdates,
    required this.canEditDraft,
    required this.canQueuePublication,
    required this.canConfirmParentDelivery,
    required this.canIncludePrivateRecords,
  });

  final bool canViewAssignedClassUpdates;
  final bool canEditDraft;
  final bool canQueuePublication;
  final bool canConfirmParentDelivery;
  final bool canIncludePrivateRecords;
}

String teacherWeeklyPublicationLabel(TeacherWeeklyPublicationState state) =>
    switch (state) {
      TeacherWeeklyPublicationState.draft => 'Draft',
      TeacherWeeklyPublicationState.queuedForPublication => 'Queued for publication',
      TeacherWeeklyPublicationState.published => 'Published',
    };
