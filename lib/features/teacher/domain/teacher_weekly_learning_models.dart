enum TeacherWeeklyPublicationState {
  draft,
  queuedForPublication,
  published,
}

enum TeacherWeeklyEventAction {
  savedDraft,
  queuedForPublication,
}

class TeacherWeeklyLearningOption {
  const TeacherWeeklyLearningOption({
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
        subject: json['subject'] as String? ?? '',
        planned: json['planned'] as String? ?? '',
        covered: json['covered'] as String? ?? '',
        next: json['next'] as String? ?? '',
        evidence: json['evidence'] as String? ?? '',
        support: json['support'] as String? ?? '',
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
    this.classSubjectId = '',
    this.termId = '',
    this.term = '',
    this.classId = '',
    this.subjectId = '',
    this.weekStart = '',
    this.weekEnd = '',
    this.authorMembershipId = '',
    this.currentTeacherId = '',
    this.currentTeacherAuthorized = true,
    this.pendingSync = false,
    this.approvedPlans = 0,
    this.deliveredLessons = 0,
    this.attendanceTotal = 0,
    this.attendancePresent = 0,
    this.attendanceLate = 0,
    this.attendanceAbsent = 0,
    this.attendanceExcused = 0,
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

  final String classSubjectId;
  final String termId;
  final String term;
  final String classId;
  final String subjectId;
  final String weekStart;
  final String weekEnd;
  final String authorMembershipId;
  final String currentTeacherId;
  final bool currentTeacherAuthorized;
  final bool pendingSync;
  final int approvedPlans;
  final int deliveredLessons;
  final int attendanceTotal;
  final int attendancePresent;
  final int attendanceLate;
  final int attendanceAbsent;
  final int attendanceExcused;

  int get completionPercent {
    if (subjects.isEmpty) return 0;
    final ready = subjects.where((item) => item.hasCoverage).length;
    return ((ready / subjects.length) * 100).round();
  }

  bool get canonical => classSubjectId.isNotEmpty && termId.isNotEmpty;
  bool get teacherEditable =>
      state == TeacherWeeklyPublicationState.draft && currentTeacherAuthorized;
  bool get serverPublished => state == TeacherWeeklyPublicationState.published;
  bool get queued => state == TeacherWeeklyPublicationState.queuedForPublication;

  TeacherWeeklySubjectUpdate? get subjectUpdate =>
      subjects.isEmpty ? null : subjects.first;

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
    String? classSubjectId,
    String? termId,
    String? term,
    String? classId,
    String? subjectId,
    String? weekStart,
    String? weekEnd,
    String? authorMembershipId,
    String? currentTeacherId,
    bool? currentTeacherAuthorized,
    bool? pendingSync,
    int? approvedPlans,
    int? deliveredLessons,
    int? attendanceTotal,
    int? attendancePresent,
    int? attendanceLate,
    int? attendanceAbsent,
    int? attendanceExcused,
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
        classSubjectId: classSubjectId ?? this.classSubjectId,
        termId: termId ?? this.termId,
        term: term ?? this.term,
        classId: classId ?? this.classId,
        subjectId: subjectId ?? this.subjectId,
        weekStart: weekStart ?? this.weekStart,
        weekEnd: weekEnd ?? this.weekEnd,
        authorMembershipId: authorMembershipId ?? this.authorMembershipId,
        currentTeacherId: currentTeacherId ?? this.currentTeacherId,
        currentTeacherAuthorized:
            currentTeacherAuthorized ?? this.currentTeacherAuthorized,
        pendingSync: pendingSync ?? this.pendingSync,
        approvedPlans: approvedPlans ?? this.approvedPlans,
        deliveredLessons: deliveredLessons ?? this.deliveredLessons,
        attendanceTotal: attendanceTotal ?? this.attendanceTotal,
        attendancePresent: attendancePresent ?? this.attendancePresent,
        attendanceLate: attendanceLate ?? this.attendanceLate,
        attendanceAbsent: attendanceAbsent ?? this.attendanceAbsent,
        attendanceExcused: attendanceExcused ?? this.attendanceExcused,
      );

  Map<String, Object?> toMutationJson({required String action}) {
    final subject = subjectUpdate;
    return {
      'id': id,
      'classSubjectId': classSubjectId,
      'termId': termId,
      'weekStart': weekStart,
      'action': action,
      'nextFocus': subject?.next ?? '',
      'supportNote': subject?.support ?? '',
      'parentNote': note,
    };
  }

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
        'classSubjectId': classSubjectId,
        'termId': termId,
        'term': term,
        'classId': classId,
        'subjectId': subjectId,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'authorMembershipId': authorMembershipId,
        'currentTeacherId': currentTeacherId,
        'currentTeacherAuthorized': currentTeacherAuthorized,
        'pendingSync': pendingSync,
        'approvedPlans': approvedPlans,
        'deliveredLessons': deliveredLessons,
        'attendanceTotal': attendanceTotal,
        'attendancePresent': attendancePresent,
        'attendanceLate': attendanceLate,
        'attendanceAbsent': attendanceAbsent,
        'attendanceExcused': attendanceExcused,
        'parentNote': note,
        'nextFocus': subjectUpdate?.next ?? '',
        'supportNote': subjectUpdate?.support ?? '',
        'planned': subjectUpdate?.planned ?? '',
        'covered': subjectUpdate?.covered ?? '',
        'evidence': subjectUpdate?.evidence ?? '',
      };

  factory TeacherWeeklyLearningUpdate.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'] as String? ?? 'draft';
    final state = switch (rawState) {
      'queuedForPublication' => TeacherWeeklyPublicationState.queuedForPublication,
      'published' => TeacherWeeklyPublicationState.published,
      _ => TeacherWeeklyPublicationState.draft,
    };

    final rawSubjects = json['subjects'];
    final subjects = <TeacherWeeklySubjectUpdate>[];
    if (rawSubjects is List) {
      for (final item in rawSubjects) {
        if (item is Map) {
          subjects.add(
            TeacherWeeklySubjectUpdate.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    } else {
      final subject = json['subject'] as String? ?? '';
      if (subject.isNotEmpty) {
        subjects.add(
          TeacherWeeklySubjectUpdate(
            subject: subject,
            planned: json['planned'] as String? ?? '',
            covered: json['covered'] as String? ?? '',
            next: json['nextFocus'] as String? ?? '',
            evidence: json['evidence'] as String? ?? '',
            support: json['supportNote'] as String? ?? '',
          ),
        );
      }
    }

    final evidenceDetails = json['evidenceDetails'];
    final evidenceMap = evidenceDetails is Map
        ? Map<String, dynamic>.from(evidenceDetails)
        : const <String, dynamic>{};
    final attendanceRaw = evidenceMap['attendance'];
    final attendance = attendanceRaw is Map
        ? Map<String, dynamic>.from(attendanceRaw)
        : const <String, dynamic>{};

    return TeacherWeeklyLearningUpdate(
      id: json['id'] as String? ?? '',
      className: json['className'] as String? ?? '',
      week: json['weekLabel'] as String? ??
          json['week'] as String? ??
          json['weekStart'] as String? ??
          '',
      subjects: subjects,
      note: json['parentNote'] as String? ?? json['note'] as String? ?? '',
      state: state,
      version: json['version'] as int? ?? 1,
      updatedAt: json['updatedAt'] as String?,
      queuedAt: json['queuedAt'] as String?,
      publishedAt: json['publishedAt'] as String?,
      classSubjectId: json['classSubjectId'] as String? ?? '',
      termId: json['termId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      weekStart: json['weekStart'] as String? ?? '',
      weekEnd: json['weekEnd'] as String? ?? '',
      authorMembershipId: json['authorMembershipId'] as String? ?? '',
      currentTeacherId: json['currentTeacherId'] as String? ?? '',
      currentTeacherAuthorized:
          json['currentTeacherAuthorized'] as bool? ?? true,
      pendingSync: json['pendingSync'] as bool? ?? false,
      approvedPlans: evidenceMap['approvedPlans'] as int? ??
          json['approvedPlans'] as int? ??
          0,
      deliveredLessons: evidenceMap['deliveredLessons'] as int? ??
          json['deliveredLessons'] as int? ??
          0,
      attendanceTotal: attendance['total'] as int? ??
          json['attendanceTotal'] as int? ??
          0,
      attendancePresent: attendance['present'] as int? ??
          json['attendancePresent'] as int? ??
          0,
      attendanceLate: attendance['late'] as int? ??
          json['attendanceLate'] as int? ??
          0,
      attendanceAbsent: attendance['absent'] as int? ??
          json['attendanceAbsent'] as int? ??
          0,
      attendanceExcused: attendance['excused'] as int? ??
          json['attendanceExcused'] as int? ??
          0,
    );
  }
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
        id: json['id'] as String? ?? '',
        updateId: json['updateId'] as String? ?? '',
        action: TeacherWeeklyEventAction.values.firstWhere(
          (item) => item.name == (json['action'] as String? ?? ''),
          orElse: () => TeacherWeeklyEventAction.savedDraft,
        ),
        actorMembershipId: json['actorMembershipId'] as String? ?? '',
        version: json['version'] as int? ?? 1,
        occurredAt: json['occurredAt'] as String? ?? '',
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
