enum TeacherLessonPlanStatus { draft, submitted, approved, needsChanges }

enum TeacherLessonPlanEventAction { savedDraft, submitted }

class TeacherLessonPlan {
  const TeacherLessonPlan({
    required this.id,
    required this.className,
    required this.week,
    required this.topic,
    required this.status,
    required this.updatedLabel,
    this.objectives = '',
    this.starter = '',
    this.activities = '',
    this.assessment = '',
    this.resources = '',
    this.version = 1,
  });

  final String id;
  final String className;
  final String week;
  final String topic;
  final TeacherLessonPlanStatus status;
  final String updatedLabel;
  final String objectives;
  final String starter;
  final String activities;
  final String assessment;
  final String resources;
  final int version;

  bool get teacherEditable =>
      status == TeacherLessonPlanStatus.draft ||
      status == TeacherLessonPlanStatus.needsChanges;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $className $week $topic ${teacherLessonPlanStatusLabel(status)}'
        .toLowerCase()
        .contains(q);
  }

  TeacherLessonPlan copyWith({
    String? className,
    String? week,
    String? topic,
    TeacherLessonPlanStatus? status,
    String? updatedLabel,
    String? objectives,
    String? starter,
    String? activities,
    String? assessment,
    String? resources,
    int? version,
  }) =>
      TeacherLessonPlan(
        id: id,
        className: className ?? this.className,
        week: week ?? this.week,
        topic: topic ?? this.topic,
        status: status ?? this.status,
        updatedLabel: updatedLabel ?? this.updatedLabel,
        objectives: objectives ?? this.objectives,
        starter: starter ?? this.starter,
        activities: activities ?? this.activities,
        assessment: assessment ?? this.assessment,
        resources: resources ?? this.resources,
        version: version ?? this.version,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'week': week,
        'topic': topic,
        'status': status.name,
        'updatedLabel': updatedLabel,
        'objectives': objectives,
        'starter': starter,
        'activities': activities,
        'assessment': assessment,
        'resources': resources,
        'version': version,
      };

  factory TeacherLessonPlan.fromJson(Map<String, dynamic> json) =>
      TeacherLessonPlan(
        id: json['id'] as String,
        className: json['className'] as String,
        week: json['week'] as String,
        topic: json['topic'] as String,
        status: TeacherLessonPlanStatus.values.byName(json['status'] as String),
        updatedLabel: json['updatedLabel'] as String,
        objectives: json['objectives'] as String? ?? '',
        starter: json['starter'] as String? ?? '',
        activities: json['activities'] as String? ?? '',
        assessment: json['assessment'] as String? ?? '',
        resources: json['resources'] as String? ?? '',
        version: json['version'] as int? ?? 1,
      );
}

class TeacherLessonPlanEvent {
  const TeacherLessonPlanEvent({
    required this.id,
    required this.planId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });

  final String id;
  final String planId;
  final TeacherLessonPlanEventAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'planId': planId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };

  factory TeacherLessonPlanEvent.fromJson(Map<String, dynamic> json) =>
      TeacherLessonPlanEvent(
        id: json['id'] as String,
        planId: json['planId'] as String,
        action: TeacherLessonPlanEventAction.values.byName(json['action'] as String),
        actorMembershipId: json['actorMembershipId'] as String,
        version: json['version'] as int,
        occurredAt: json['occurredAt'] as String,
      );
}

class TeacherLessonPlanPermissions {
  const TeacherLessonPlanPermissions({
    required this.canViewAssignedPlans,
    required this.canEditDrafts,
    required this.canSubmitForApproval,
    required this.canApprovePlans,
    required this.canOverrideReviewerStatus,
  });

  final bool canViewAssignedPlans;
  final bool canEditDrafts;
  final bool canSubmitForApproval;
  final bool canApprovePlans;
  final bool canOverrideReviewerStatus;
}

String teacherLessonPlanStatusLabel(TeacherLessonPlanStatus status) => switch (status) {
      TeacherLessonPlanStatus.draft => 'Draft',
      TeacherLessonPlanStatus.submitted => 'Submitted',
      TeacherLessonPlanStatus.approved => 'Approved',
      TeacherLessonPlanStatus.needsChanges => 'Needs changes',
    };
