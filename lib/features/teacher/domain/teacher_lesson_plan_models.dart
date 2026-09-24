enum TeacherLessonPlanStatus {
  draft,
  queuedSubmission,
  submitted,
  approved,
  needsChanges,
}

enum TeacherLessonPlanEventAction { savedDraft, submitted }

enum TeacherLessonDeliveryState { draft, queued, delivered }

class TeacherLessonPlanTopicOption {
  const TeacherLessonPlanTopicOption({
    required this.id,
    required this.title,
    required this.sequence,
  });

  final String id;
  final String title;
  final int sequence;

  factory TeacherLessonPlanTopicOption.fromJson(Map<String, Object?> json) =>
      TeacherLessonPlanTopicOption(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        sequence: json['sequence'] as int? ?? 1,
      );
}

class TeacherLessonPlanOccurrenceOption {
  const TeacherLessonPlanOccurrenceOption({
    required this.timetableEntryId,
    required this.lessonDate,
    required this.classSubjectId,
    required this.termId,
    required this.className,
    required this.subject,
    required this.time,
    required this.room,
    required this.periodNumber,
    required this.topics,
  });

  final String timetableEntryId;
  final String lessonDate;
  final String classSubjectId;
  final String termId;
  final String className;
  final String subject;
  final String time;
  final String room;
  final int periodNumber;
  final List<TeacherLessonPlanTopicOption> topics;

  String get id => '$timetableEntryId|$lessonDate';
  String get label => '$lessonDate · $time · $className · $subject';
}

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
    this.timetableEntryId = '',
    this.lessonDate = '',
    this.classSubjectId = '',
    this.termId = '',
    this.subject = '',
    this.time = '',
    this.room = '',
    this.topicId = '',
    this.effectiveTeacherId = '',
    this.authorMembershipId = '',
    this.submittedByMembershipId,
    this.submittedAt,
    this.reviewedAt,
    this.reviewComment = '',
    this.pendingSync = false,
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

  final String timetableEntryId;
  final String lessonDate;
  final String classSubjectId;
  final String termId;
  final String subject;
  final String time;
  final String room;
  final String topicId;
  final String effectiveTeacherId;
  final String authorMembershipId;
  final String? submittedByMembershipId;
  final String? submittedAt;
  final String? reviewedAt;
  final String reviewComment;
  final bool pendingSync;

  bool get teacherEditable =>
      status == TeacherLessonPlanStatus.draft ||
      status == TeacherLessonPlanStatus.needsChanges;
  bool get waitingForServer => status == TeacherLessonPlanStatus.queuedSubmission;
  bool get canonicalApproved => status == TeacherLessonPlanStatus.approved;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $className $lessonDate $week $subject $topic ${teacherLessonPlanStatusLabel(status)}'
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
    String? timetableEntryId,
    String? lessonDate,
    String? classSubjectId,
    String? termId,
    String? subject,
    String? time,
    String? room,
    String? topicId,
    String? effectiveTeacherId,
    String? authorMembershipId,
    String? submittedByMembershipId,
    String? submittedAt,
    String? reviewedAt,
    String? reviewComment,
    bool? pendingSync,
    bool clearReview = false,
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
        timetableEntryId: timetableEntryId ?? this.timetableEntryId,
        lessonDate: lessonDate ?? this.lessonDate,
        classSubjectId: classSubjectId ?? this.classSubjectId,
        termId: termId ?? this.termId,
        subject: subject ?? this.subject,
        time: time ?? this.time,
        room: room ?? this.room,
        topicId: topicId ?? this.topicId,
        effectiveTeacherId: effectiveTeacherId ?? this.effectiveTeacherId,
        authorMembershipId: authorMembershipId ?? this.authorMembershipId,
        submittedByMembershipId:
            submittedByMembershipId ?? this.submittedByMembershipId,
        submittedAt: submittedAt ?? this.submittedAt,
        reviewedAt: clearReview ? null : (reviewedAt ?? this.reviewedAt),
        reviewComment: clearReview ? '' : (reviewComment ?? this.reviewComment),
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, Object?> toMutationJson({required String action}) => {
        'id': id,
        'timetableEntryId': timetableEntryId,
        'lessonDate': lessonDate,
        'topicId': topicId,
        'action': action,
        'objectives': objectives,
        'starter': starter,
        'activities': activities,
        'assessment': assessment,
        'resources': resources,
      };

  Map<String, Object?> toLocalJson() => {
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
        'timetableEntryId': timetableEntryId,
        'lessonDate': lessonDate,
        'classSubjectId': classSubjectId,
        'termId': termId,
        'subject': subject,
        'time': time,
        'room': room,
        'topicId': topicId,
        'effectiveTeacherId': effectiveTeacherId,
        'authorMembershipId': authorMembershipId,
        'submittedByMembershipId': submittedByMembershipId,
        'submittedAt': submittedAt,
        'reviewedAt': reviewedAt,
        'reviewComment': reviewComment,
      };

  Map<String, Object?> toJson() => toLocalJson();

  factory TeacherLessonPlan.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'] as String? ?? json['status'] as String? ?? 'draft';
    final status = switch (rawState) {
      'queuedSubmission' => TeacherLessonPlanStatus.queuedSubmission,
      'submitted' => TeacherLessonPlanStatus.submitted,
      'approved' => TeacherLessonPlanStatus.approved,
      'needsChanges' || 'needs_changes' => TeacherLessonPlanStatus.needsChanges,
      _ => TeacherLessonPlanStatus.draft,
    };
    final lessonDate = json['lessonDate'] as String? ?? '';
    return TeacherLessonPlan(
      id: json['id'] as String? ?? '',
      className: json['className'] as String? ?? '',
      week: json['week'] as String? ?? (lessonDate.isEmpty ? '' : lessonDate),
      topic: json['topic'] as String? ?? '',
      status: status,
      updatedLabel: json['updatedLabel'] as String? ??
          json['updatedAt'] as String? ??
          '',
      objectives: json['objectives'] as String? ?? '',
      starter: json['starter'] as String? ?? '',
      activities: json['activities'] as String? ?? '',
      assessment: json['assessment'] as String? ?? '',
      resources: json['resources'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      timetableEntryId: json['timetableEntryId'] as String? ?? '',
      lessonDate: lessonDate,
      classSubjectId: json['classSubjectId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      time: json['time'] as String? ?? '',
      room: json['room'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      effectiveTeacherId: json['effectiveTeacherId'] as String? ?? '',
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
      submittedByMembershipId: json['submittedByMembershipId'] as String?,
      submittedAt: json['submittedAt'] as String?,
      reviewedAt: json['reviewedAt'] as String?,
      reviewComment: json['reviewComment'] as String? ?? '',
    );
  }
}

class TeacherLessonDelivery {
  const TeacherLessonDelivery({
    required this.id,
    required this.planId,
    required this.timetableEntryId,
    required this.lessonDate,
    required this.topicId,
    required this.state,
    this.reflection = '',
    this.homework = '',
    this.topicCompleted = false,
    this.deliveredAt,
    this.attendanceState,
    this.attendanceTotal = 0,
    this.attendancePresent = 0,
    this.attendanceAbsent = 0,
    this.attendanceLate = 0,
    this.pendingSync = false,
  });

  final String id;
  final String planId;
  final String timetableEntryId;
  final String lessonDate;
  final String topicId;
  final TeacherLessonDeliveryState state;
  final String reflection;
  final String homework;
  final bool topicCompleted;
  final String? deliveredAt;
  final String? attendanceState;
  final int attendanceTotal;
  final int attendancePresent;
  final int attendanceAbsent;
  final int attendanceLate;
  final bool pendingSync;

  bool get locked => state != TeacherLessonDeliveryState.draft;

  TeacherLessonDelivery copyWith({
    TeacherLessonDeliveryState? state,
    String? reflection,
    String? homework,
    bool? topicCompleted,
    String? deliveredAt,
    String? attendanceState,
    int? attendanceTotal,
    int? attendancePresent,
    int? attendanceAbsent,
    int? attendanceLate,
    bool? pendingSync,
  }) =>
      TeacherLessonDelivery(
        id: id,
        planId: planId,
        timetableEntryId: timetableEntryId,
        lessonDate: lessonDate,
        topicId: topicId,
        state: state ?? this.state,
        reflection: reflection ?? this.reflection,
        homework: homework ?? this.homework,
        topicCompleted: topicCompleted ?? this.topicCompleted,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        attendanceState: attendanceState ?? this.attendanceState,
        attendanceTotal: attendanceTotal ?? this.attendanceTotal,
        attendancePresent: attendancePresent ?? this.attendancePresent,
        attendanceAbsent: attendanceAbsent ?? this.attendanceAbsent,
        attendanceLate: attendanceLate ?? this.attendanceLate,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  Map<String, Object?> toMutationJson({required String action}) => {
        'id': id,
        'timetableEntryId': timetableEntryId,
        'lessonDate': lessonDate,
        'planId': planId,
        'action': action,
        'reflection': reflection,
        'homework': homework,
        'topicCompleted': topicCompleted,
      };

  Map<String, Object?> toLocalJson() => {
        'id': id,
        'planId': planId,
        'timetableEntryId': timetableEntryId,
        'lessonDate': lessonDate,
        'topicId': topicId,
        'state': state.name,
        'reflection': reflection,
        'homework': homework,
        'topicCompleted': topicCompleted,
        'deliveredAt': deliveredAt,
        'attendanceState': attendanceState,
        'attendanceTotal': attendanceTotal,
        'attendancePresent': attendancePresent,
        'attendanceAbsent': attendanceAbsent,
        'attendanceLate': attendanceLate,
      };

  factory TeacherLessonDelivery.fromJson(Map<String, dynamic> json) {
    final raw = json['state'] as String? ?? 'draft';
    final state = switch (raw) {
      'queued' => TeacherLessonDeliveryState.queued,
      'delivered' => TeacherLessonDeliveryState.delivered,
      _ => TeacherLessonDeliveryState.draft,
    };
    return TeacherLessonDelivery(
      id: json['id'] as String? ?? '',
      planId: json['planId'] as String? ?? '',
      timetableEntryId: json['timetableEntryId'] as String? ?? '',
      lessonDate: json['lessonDate'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      state: state,
      reflection: json['reflection'] as String? ?? '',
      homework: json['homework'] as String? ?? '',
      topicCompleted: json['topicCompleted'] as bool? ?? false,
      deliveredAt: json['deliveredAt'] as String?,
      attendanceState: json['attendanceState'] as String?,
      attendanceTotal: json['attendanceTotal'] as int? ?? 0,
      attendancePresent: json['attendancePresent'] as int? ?? 0,
      attendanceAbsent: json['attendanceAbsent'] as int? ?? 0,
      attendanceLate: json['attendanceLate'] as int? ?? 0,
    );
  }
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
        id: json['id'] as String? ?? '',
        planId: json['planId'] as String? ?? '',
        action: TeacherLessonPlanEventAction.values.firstWhere(
          (item) => item.name == (json['action'] as String? ?? ''),
          orElse: () => TeacherLessonPlanEventAction.savedDraft,
        ),
        actorMembershipId: json['actorMembershipId'] as String? ?? '',
        version: json['version'] as int? ?? 1,
        occurredAt: json['occurredAt'] as String? ?? '',
      );
}

class TeacherLessonPlanPermissions {
  const TeacherLessonPlanPermissions({
    required this.canViewAssignedPlans,
    required this.canEditDrafts,
    required this.canSubmitForApproval,
    required this.canApprovePlans,
    required this.canOverrideReviewerStatus,
    this.canRecordDelivery = false,
  });

  final bool canViewAssignedPlans;
  final bool canEditDrafts;
  final bool canSubmitForApproval;
  final bool canApprovePlans;
  final bool canOverrideReviewerStatus;
  final bool canRecordDelivery;
}

String teacherLessonPlanStatusLabel(TeacherLessonPlanStatus status) => switch (status) {
      TeacherLessonPlanStatus.draft => 'Draft',
      TeacherLessonPlanStatus.queuedSubmission => 'Submission queued',
      TeacherLessonPlanStatus.submitted => 'Submitted',
      TeacherLessonPlanStatus.approved => 'Approved',
      TeacherLessonPlanStatus.needsChanges => 'Needs changes',
    };

String teacherLessonDeliveryStateLabel(TeacherLessonDeliveryState state) => switch (state) {
      TeacherLessonDeliveryState.draft => 'Delivery draft',
      TeacherLessonDeliveryState.queued => 'Delivery queued',
      TeacherLessonDeliveryState.delivered => 'Delivered',
    };
