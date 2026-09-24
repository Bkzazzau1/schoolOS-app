class PrincipalAssignmentTeacher {
  const PrincipalAssignmentTeacher({
    required this.id,
    required this.name,
    required this.department,
    required this.qualifiedSubjects,
    required this.weeklyPeriods,
    this.provisional = false,
    this.qualificationRecorded = false,
  });

  /// Real SchoolOS Teacher membership id. Teaching authority is attached to
  /// this identity, not to the HR/staff-directory record id.
  final String id;
  final String name;
  final String department;
  final List<String> qualifiedSubjects;
  final int weeklyPeriods;
  final bool provisional;
  final bool qualificationRecorded;

  /// Until a verified qualification-to-subject matrix exists, an empty list
  /// means "not formally classified", not "not allowed". The Principal remains
  /// responsible for the assignment decision.
  bool canTeach(String subject) =>
      qualifiedSubjects.isEmpty || qualifiedSubjects.contains(subject);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'department': department,
        'qualifiedSubjects': qualifiedSubjects,
        'weeklyPeriods': weeklyPeriods,
        'provisional': provisional,
        'qualificationRecorded': qualificationRecorded,
      };

  factory PrincipalAssignmentTeacher.fromJson(Map<String, Object?> json) =>
      PrincipalAssignmentTeacher(
        id: json['id']! as String,
        name: json['name']! as String,
        department: json['department']! as String,
        qualifiedSubjects:
            (json['qualifiedSubjects'] as List? ?? const []).cast<String>(),
        weeklyPeriods: json['weeklyPeriods'] as int? ?? 0,
        provisional: json['provisional'] as bool? ?? false,
        qualificationRecorded: json['qualificationRecorded'] as bool? ?? false,
      );
}

class PrincipalCurriculumRequirement {
  const PrincipalCurriculumRequirement({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subject,
    required this.requirement,
    required this.periodsPerWeek,
    required this.isActive,
  });

  final String id;
  final String sessionId;
  final String classId;
  final String className;
  final String subjectId;
  final String subject;
  final String requirement;
  final int periodsPerWeek;
  final bool isActive;

  bool get compulsory => requirement == 'compulsory';

  factory PrincipalCurriculumRequirement.fromJson(Map<String, Object?> json) =>
      PrincipalCurriculumRequirement(
        id: json['id'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        requirement: json['requirement'] as String? ?? 'compulsory',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 1,
        isActive: json['isActive'] as bool? ?? true,
      );
}

class PrincipalTeachingAssignment {
  const PrincipalTeachingAssignment({
    required this.id,
    required this.className,
    required this.subject,
    required this.teacherId,
    required this.periodsPerWeek,
    this.version = 1,
    this.sessionId = '',
    this.classSubjectId = '',
    this.subjectId = '',
    this.canonicalAssignmentId = '',
    this.handoverReason = '',
  });

  final String id;
  final String className;
  final String subject;
  final String teacherId;
  final int periodsPerWeek;
  final int version;
  final String sessionId;
  final String classSubjectId;
  final String subjectId;
  final String canonicalAssignmentId;
  final String handoverReason;

  PrincipalTeachingAssignment copyWith({
    String? teacherId,
    int? version,
    String? handoverReason,
  }) =>
      PrincipalTeachingAssignment(
        id: id,
        className: className,
        subject: subject,
        teacherId: teacherId ?? this.teacherId,
        periodsPerWeek: periodsPerWeek,
        version: version ?? this.version,
        sessionId: sessionId,
        classSubjectId: classSubjectId,
        subjectId: subjectId,
        canonicalAssignmentId: canonicalAssignmentId,
        handoverReason: handoverReason ?? this.handoverReason,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'subject': subject,
        'teacherId': teacherId,
        'periodsPerWeek': periodsPerWeek,
        'version': version,
        if (sessionId.isNotEmpty) 'sessionId': sessionId,
        if (classSubjectId.isNotEmpty) 'classSubjectId': classSubjectId,
        if (subjectId.isNotEmpty) 'subjectId': subjectId,
        if (canonicalAssignmentId.isNotEmpty)
          'canonicalAssignmentId': canonicalAssignmentId,
        if (handoverReason.isNotEmpty) 'handoverReason': handoverReason,
      };

  factory PrincipalTeachingAssignment.fromJson(Map<String, Object?> json) =>
      PrincipalTeachingAssignment(
        id: json['id']! as String,
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        teacherId: json['teacherId'] as String? ?? '',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 1,
        version: json['version'] as int? ?? 1,
        sessionId: json['sessionId'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        canonicalAssignmentId:
            json['canonicalAssignmentId'] as String? ?? '',
        handoverReason: json['handoverReason'] as String? ?? '',
      );
}

class PrincipalUnassignedSubject {
  const PrincipalUnassignedSubject({
    required this.className,
    required this.subject,
    required this.periods,
    this.classSubjectId = '',
  });
  final String className;
  final String subject;
  final int periods;
  final String classSubjectId;
}

class PrincipalAssignmentTransfer {
  const PrincipalAssignmentTransfer({
    required this.id,
    required this.assignmentId,
    required this.className,
    required this.subject,
    required this.fromTeacherId,
    required this.toTeacherId,
    required this.reason,
    required this.transferredByMembershipId,
    required this.transferredAt,
    required this.recordScope,
    required this.previousAssignmentVersion,
    required this.newAssignmentVersion,
  });

  final String id;
  final String assignmentId;
  final String className;
  final String subject;
  final String fromTeacherId;
  final String toTeacherId;
  final String reason;
  final String transferredByMembershipId;
  final String transferredAt;
  final List<String> recordScope;
  final int previousAssignmentVersion;
  final int newAssignmentVersion;

  Map<String, Object?> toJson() => {
        'id': id,
        'assignmentId': assignmentId,
        'className': className,
        'subject': subject,
        'fromTeacherId': fromTeacherId,
        'toTeacherId': toTeacherId,
        'reason': reason,
        'transferredByMembershipId': transferredByMembershipId,
        'transferredAt': transferredAt,
        'recordScope': recordScope,
        'previousAssignmentVersion': previousAssignmentVersion,
        'newAssignmentVersion': newAssignmentVersion,
      };

  factory PrincipalAssignmentTransfer.fromJson(Map<String, Object?> json) =>
      PrincipalAssignmentTransfer(
        id: json['id']! as String,
        assignmentId: json['assignmentId']! as String,
        className: json['className']! as String,
        subject: json['subject']! as String,
        fromTeacherId: json['fromTeacherId']! as String,
        toTeacherId: json['toTeacherId']! as String,
        reason: json['reason']! as String,
        transferredByMembershipId:
            json['transferredByMembershipId']! as String,
        transferredAt: json['transferredAt']! as String,
        recordScope: (json['recordScope']! as List).cast<String>(),
        previousAssignmentVersion: json['previousAssignmentVersion']! as int,
        newAssignmentVersion: json['newAssignmentVersion']! as int,
      );
}

class PrincipalTeachingRecordAccess {
  const PrincipalTeachingRecordAccess({
    required this.id,
    required this.assignmentId,
    required this.teacherId,
    required this.className,
    required this.subject,
    required this.recordScope,
    required this.grantedByMembershipId,
    required this.grantedAt,
    required this.provisionalTarget,
  });

  final String id;
  final String assignmentId;
  final String teacherId;
  final String className;
  final String subject;
  final List<String> recordScope;
  final String grantedByMembershipId;
  final String grantedAt;
  final bool provisionalTarget;

  Map<String, Object?> toJson() => {
        'id': id,
        'assignmentId': assignmentId,
        'teacherId': teacherId,
        'className': className,
        'subject': subject,
        'recordScope': recordScope,
        'grantedByMembershipId': grantedByMembershipId,
        'grantedAt': grantedAt,
        'provisionalTarget': provisionalTarget,
      };

  factory PrincipalTeachingRecordAccess.fromJson(Map<String, Object?> json) =>
      PrincipalTeachingRecordAccess(
        id: json['id']! as String,
        assignmentId: json['assignmentId']! as String,
        teacherId: json['teacherId']! as String,
        className: json['className']! as String,
        subject: json['subject']! as String,
        recordScope: (json['recordScope']! as List).cast<String>(),
        grantedByMembershipId: json['grantedByMembershipId']! as String,
        grantedAt: json['grantedAt']! as String,
        provisionalTarget: json['provisionalTarget'] as bool? ?? false,
      );
}

class PrincipalAssignmentPermissions {
  const PrincipalAssignmentPermissions({
    required this.canManageSecondaryAssignments,
    required this.canCreateProvisionalTargets,
    required this.canTransferWork,
    required this.canManagePrimary,
  });
  final bool canManageSecondaryAssignments;
  final bool canCreateProvisionalTargets;
  final bool canTransferWork;
  final bool canManagePrimary;
}
