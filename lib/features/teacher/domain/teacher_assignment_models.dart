enum TeacherAssignmentState { draft, queuedForPublication, open, closed }
enum TeacherAssignmentType { homework, classwork, project, revision }
enum TeacherAssignmentEventAction { savedDraft, queuedForPublication }

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
    this.version = 1,
    this.updatedAt,
    this.queuedAt,
    this.publishedAt,
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
  final int version;
  final String? updatedAt;
  final String? queuedAt;
  final String? publishedAt;

  int get unmarked => submissions - marked;
  bool get teacherEditable => state == TeacherAssignmentState.draft;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id $title $className ${teacherAssignmentStateLabel(state)}'
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
    int? version,
    String? updatedAt,
    String? queuedAt,
    String? publishedAt,
  }) => TeacherAssignment(
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
        version: version ?? this.version,
        updatedAt: updatedAt ?? this.updatedAt,
        queuedAt: queuedAt ?? this.queuedAt,
        publishedAt: publishedAt ?? this.publishedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'className': className,
        'type': type.name,
        'instructions': instructions,
        'dueDate': dueDate,
        'maximumScore': maximumScore,
        'submissions': submissions,
        'totalStudents': totalStudents,
        'marked': marked,
        'lateSubmissions': lateSubmissions,
        'state': state.name,
        'version': version,
        'updatedAt': updatedAt,
        'queuedAt': queuedAt,
        'publishedAt': publishedAt,
      };

  factory TeacherAssignment.fromJson(Map<String, dynamic> json) => TeacherAssignment(
        id: json['id'] as String,
        title: json['title'] as String,
        className: json['className'] as String,
        type: TeacherAssignmentType.values.byName(json['type'] as String),
        instructions: json['instructions'] as String,
        dueDate: json['dueDate'] as String,
        maximumScore: json['maximumScore'] as int,
        submissions: json['submissions'] as int,
        totalStudents: json['totalStudents'] as int,
        marked: json['marked'] as int,
        lateSubmissions: json['lateSubmissions'] as int,
        state: TeacherAssignmentState.values.byName(json['state'] as String),
        version: json['version'] as int? ?? 1,
        updatedAt: json['updatedAt'] as String?,
        queuedAt: json['queuedAt'] as String?,
        publishedAt: json['publishedAt'] as String?,
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

String teacherAssignmentStateLabel(TeacherAssignmentState state) => switch (state) {
      TeacherAssignmentState.draft => 'Draft',
      TeacherAssignmentState.queuedForPublication => 'Queued',
      TeacherAssignmentState.open => 'Open',
      TeacherAssignmentState.closed => 'Closed',
    };

String teacherAssignmentTypeLabel(TeacherAssignmentType type) => switch (type) {
      TeacherAssignmentType.homework => 'Homework',
      TeacherAssignmentType.classwork => 'Classwork',
      TeacherAssignmentType.project => 'Project',
      TeacherAssignmentType.revision => 'Revision',
    };
