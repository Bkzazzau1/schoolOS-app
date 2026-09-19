class PrincipalAssignmentTeacher {
  const PrincipalAssignmentTeacher({
    required this.id,
    required this.name,
    required this.department,
    required this.qualifiedSubjects,
    required this.weeklyPeriods,
    this.provisional = false,
  });

  final String id;
  final String name;
  final String department;
  final List<String> qualifiedSubjects;
  final int weeklyPeriods;
  final bool provisional;

  bool canTeach(String subject) => qualifiedSubjects.contains(subject);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'department': department,
        'qualifiedSubjects': qualifiedSubjects,
        'weeklyPeriods': weeklyPeriods,
        'provisional': provisional,
      };

  factory PrincipalAssignmentTeacher.fromJson(Map<String, Object?> json) => PrincipalAssignmentTeacher(
        id: json['id']! as String,
        name: json['name']! as String,
        department: json['department']! as String,
        qualifiedSubjects: (json['qualifiedSubjects']! as List).cast<String>(),
        weeklyPeriods: json['weeklyPeriods']! as int,
        provisional: json['provisional'] as bool? ?? false,
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
  });

  final String id;
  final String className;
  final String subject;
  final String teacherId;
  final int periodsPerWeek;
  final int version;

  PrincipalTeachingAssignment copyWith({String? teacherId, int? version}) => PrincipalTeachingAssignment(
        id: id,
        className: className,
        subject: subject,
        teacherId: teacherId ?? this.teacherId,
        periodsPerWeek: periodsPerWeek,
        version: version ?? this.version,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'className': className,
        'subject': subject,
        'teacherId': teacherId,
        'periodsPerWeek': periodsPerWeek,
        'version': version,
      };

  factory PrincipalTeachingAssignment.fromJson(Map<String, Object?> json) => PrincipalTeachingAssignment(
        id: json['id']! as String,
        className: json['className']! as String,
        subject: json['subject']! as String,
        teacherId: json['teacherId']! as String,
        periodsPerWeek: json['periodsPerWeek']! as int,
        version: json['version'] as int? ?? 1,
      );
}

class PrincipalUnassignedSubject {
  const PrincipalUnassignedSubject({required this.className, required this.subject, required this.periods});
  final String className;
  final String subject;
  final int periods;
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

  factory PrincipalAssignmentTransfer.fromJson(Map<String, Object?> json) => PrincipalAssignmentTransfer(
        id: json['id']! as String,
        assignmentId: json['assignmentId']! as String,
        className: json['className']! as String,
        subject: json['subject']! as String,
        fromTeacherId: json['fromTeacherId']! as String,
        toTeacherId: json['toTeacherId']! as String,
        reason: json['reason']! as String,
        transferredByMembershipId: json['transferredByMembershipId']! as String,
        transferredAt: json['transferredAt']! as String,
        recordScope: (json['recordScope']! as List).cast<String>(),
        previousAssignmentVersion: json['previousAssignmentVersion']! as int,
        newAssignmentVersion: json['newAssignmentVersion']! as int,
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
