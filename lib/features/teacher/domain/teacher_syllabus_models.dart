enum TeacherSyllabusStatus { completed, inProgress, current, upcoming, behind }

enum TeacherSyllabusProgressAction { markedComplete, markedInProgress }

class TeacherSyllabusRow {
  const TeacherSyllabusRow({
    required this.className,
    required this.week,
    required this.topic,
    required this.approvedStatus,
    required this.plannedLessons,
    this.canonicalTopicId = '',
  });

  final String className;
  final int week;
  final String topic;
  final TeacherSyllabusStatus approvedStatus;
  final int plannedLessons;

  /// Server-backed rows use the canonical CurriculumTopic UUID. Demo rows keep
  /// the historic class/week identifier so standalone demo behaviour remains.
  final String canonicalTopicId;

  String get id => canonicalTopicId.isNotEmpty
      ? canonicalTopicId
      : '$className-W$week';

  bool matches(String query, {TeacherSyllabusStatus? reportedStatus}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$week $topic ${teacherSyllabusStatusLabel(reportedStatus ?? approvedStatus)}'
        .toLowerCase()
        .contains(q);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'canonicalTopicId': canonicalTopicId,
        'className': className,
        'week': week,
        'topic': topic,
        'approvedStatus': approvedStatus.name,
        'plannedLessons': plannedLessons,
      };

  factory TeacherSyllabusRow.fromJson(Map<String, dynamic> json) =>
      TeacherSyllabusRow(
        className: json['className'] as String,
        week: json['week'] as int,
        topic: json['topic'] as String,
        approvedStatus: TeacherSyllabusStatus.values.byName(
          json['approvedStatus'] as String,
        ),
        plannedLessons: json['plannedLessons'] as int,
        canonicalTopicId: json['canonicalTopicId'] as String? ??
            json['id'] as String? ??
            '',
      );
}

class TeacherSyllabusProgressRecord {
  const TeacherSyllabusProgressRecord({
    required this.id,
    required this.className,
    required this.week,
    required this.reportedStatus,
    required this.actorMembershipId,
    required this.version,
    required this.updatedAt,
  });

  final String id;
  final String className;
  final int week;
  final TeacherSyllabusStatus reportedStatus;
  final String actorMembershipId;
  final int version;
  final String updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'week': week,
        'reportedStatus': reportedStatus.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'updatedAt': updatedAt,
      };

  factory TeacherSyllabusProgressRecord.fromJson(Map<String, dynamic> json) =>
      TeacherSyllabusProgressRecord(
        id: json['id'] as String,
        className: json['className'] as String,
        week: json['week'] as int,
        reportedStatus: TeacherSyllabusStatus.values.byName(
          json['reportedStatus'] as String,
        ),
        actorMembershipId: json['actorMembershipId'] as String,
        version: json['version'] as int,
        updatedAt: json['updatedAt'] as String,
      );
}

class TeacherSyllabusProgressEvent {
  const TeacherSyllabusProgressEvent({
    required this.id,
    required this.recordId,
    required this.action,
    required this.actorMembershipId,
    required this.version,
    required this.occurredAt,
  });

  final String id;
  final String recordId;
  final TeacherSyllabusProgressAction action;
  final String actorMembershipId;
  final int version;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'recordId': recordId,
        'action': action.name,
        'actorMembershipId': actorMembershipId,
        'version': version,
        'occurredAt': occurredAt,
      };

  factory TeacherSyllabusProgressEvent.fromJson(Map<String, dynamic> json) =>
      TeacherSyllabusProgressEvent(
        id: json['id'] as String,
        recordId: json['recordId'] as String,
        action: TeacherSyllabusProgressAction.values.byName(
          json['action'] as String,
        ),
        actorMembershipId: json['actorMembershipId'] as String,
        version: json['version'] as int,
        occurredAt: json['occurredAt'] as String,
      );
}

class TeacherSyllabusPermissions {
  const TeacherSyllabusPermissions({
    required this.canViewAssignedScheme,
    required this.canReportCoverage,
    required this.canEditApprovedScheme,
    required this.canReorderTopics,
    required this.canConfirmLeadershipApproval,
  });

  final bool canViewAssignedScheme;
  final bool canReportCoverage;
  final bool canEditApprovedScheme;
  final bool canReorderTopics;
  final bool canConfirmLeadershipApproval;
}

String teacherSyllabusStatusLabel(TeacherSyllabusStatus status) => switch (status) {
      TeacherSyllabusStatus.completed => 'Completed',
      TeacherSyllabusStatus.inProgress => 'In progress',
      TeacherSyllabusStatus.current => 'Current',
      TeacherSyllabusStatus.upcoming => 'Upcoming',
      TeacherSyllabusStatus.behind => 'Behind',
    };
