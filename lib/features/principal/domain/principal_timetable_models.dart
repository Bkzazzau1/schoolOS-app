enum PrincipalTimetableStatus {
  scheduled('Scheduled'),
  substitution('Substitution'),
  uncovered('Uncovered'),
  clash('Clash');

  const PrincipalTimetableStatus(this.label);
  final String label;

  static PrincipalTimetableStatus fromLabel(String? value) => values.firstWhere(
        (item) => item.label == value,
        orElse: () => PrincipalTimetableStatus.scheduled,
      );
}

enum PrincipalTimetableExceptionAction {
  handled('Handled'),
  reopened('Reopened');

  const PrincipalTimetableExceptionAction(this.label);
  final String label;

  static PrincipalTimetableExceptionAction fromLabel(String? value) => values.firstWhere(
        (item) => item.label == value,
        orElse: () => PrincipalTimetableExceptionAction.handled,
      );
}

class PrincipalTimetableLesson {
  const PrincipalTimetableLesson({
    required this.id,
    required this.day,
    required this.time,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.room,
    required this.status,
  });

  final String id;
  final String day;
  final String time;
  final String className;
  final String subject;
  final String teacher;
  final String room;
  final PrincipalTimetableStatus status;

  bool get isException => status != PrincipalTimetableStatus.scheduled;

  Map<String, Object?> toJson() => {
        'id': id,
        'day': day,
        'time': time,
        'className': className,
        'subject': subject,
        'teacher': teacher,
        'room': room,
        'status': status.label,
      };

  factory PrincipalTimetableLesson.fromJson(Map<String, Object?> json) => PrincipalTimetableLesson(
        id: json['id'] as String? ?? '',
        day: json['day'] as String? ?? '',
        time: json['time'] as String? ?? '',
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        room: json['room'] as String? ?? '',
        status: PrincipalTimetableStatus.fromLabel(json['status'] as String?),
      );
}

class PrincipalTeacherLoad {
  const PrincipalTeacherLoad({
    required this.name,
    required this.lessons,
    required this.target,
    required this.status,
  });

  final String name;
  final int lessons;
  final int target;
  final String status;

  Map<String, Object?> toJson() => {
        'name': name,
        'lessons': lessons,
        'target': target,
        'status': status,
      };

  factory PrincipalTeacherLoad.fromJson(Map<String, Object?> json) => PrincipalTeacherLoad(
        name: json['name'] as String? ?? '',
        lessons: json['lessons'] as int? ?? 0,
        target: json['target'] as int? ?? 0,
        status: json['status'] as String? ?? '',
      );
}

class PrincipalRoomUtilization {
  const PrincipalRoomUtilization({
    required this.room,
    required this.lessons,
    required this.utilization,
  });

  final String room;
  final int lessons;
  final int utilization;

  Map<String, Object?> toJson() => {
        'room': room,
        'lessons': lessons,
        'utilization': utilization,
      };

  factory PrincipalRoomUtilization.fromJson(Map<String, Object?> json) => PrincipalRoomUtilization(
        room: json['room'] as String? ?? '',
        lessons: json['lessons'] as int? ?? 0,
        utilization: json['utilization'] as int? ?? 0,
      );
}

class PrincipalTimetableExceptionState {
  const PrincipalTimetableExceptionState({
    required this.lessonId,
    required this.handled,
    this.updatedByMembershipId,
    this.updatedAt,
  });

  final String lessonId;
  final bool handled;
  final String? updatedByMembershipId;
  final String? updatedAt;

  PrincipalTimetableExceptionState copyWith({
    bool? handled,
    String? updatedByMembershipId,
    String? updatedAt,
  }) =>
      PrincipalTimetableExceptionState(
        lessonId: lessonId,
        handled: handled ?? this.handled,
        updatedByMembershipId: updatedByMembershipId ?? this.updatedByMembershipId,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'lessonId': lessonId,
        'handled': handled,
        'updatedByMembershipId': updatedByMembershipId,
        'updatedAt': updatedAt,
      };

  factory PrincipalTimetableExceptionState.fromJson(Map<String, Object?> json) => PrincipalTimetableExceptionState(
        lessonId: json['lessonId'] as String? ?? '',
        handled: json['handled'] as bool? ?? false,
        updatedByMembershipId: json['updatedByMembershipId'] as String?,
        updatedAt: json['updatedAt'] as String?,
      );
}

class PrincipalTimetableExceptionEvent {
  const PrincipalTimetableExceptionEvent({
    required this.id,
    required this.lessonId,
    required this.action,
    required this.actorMembershipId,
    required this.occurredAt,
  });

  final String id;
  final String lessonId;
  final PrincipalTimetableExceptionAction action;
  final String actorMembershipId;
  final String occurredAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'lessonId': lessonId,
        'action': action.label,
        'actorMembershipId': actorMembershipId,
        'occurredAt': occurredAt,
      };

  factory PrincipalTimetableExceptionEvent.fromJson(Map<String, Object?> json) => PrincipalTimetableExceptionEvent(
        id: json['id'] as String? ?? '',
        lessonId: json['lessonId'] as String? ?? '',
        action: PrincipalTimetableExceptionAction.fromLabel(json['action'] as String?),
        actorMembershipId: json['actorMembershipId'] as String? ?? '',
        occurredAt: json['occurredAt'] as String? ?? '',
      );
}

class PrincipalTimetablePermissions {
  const PrincipalTimetablePermissions({
    required this.canViewSecondaryTimetable,
    required this.canHandleExceptions,
    required this.canEditScheduleDirectly,
    required this.canManagePrimary,
  });

  final bool canViewSecondaryTimetable;
  final bool canHandleExceptions;
  final bool canEditScheduleDirectly;
  final bool canManagePrimary;
}

const principalTimetablePermissions = PrincipalTimetablePermissions(
  canViewSecondaryTimetable: true,
  canHandleExceptions: true,
  canEditScheduleDirectly: false,
  canManagePrimary: false,
);

const principalTimetableAuthorityBoundary =
    'Principal timetable oversight is limited to Secondary School. Primary and Early Years scheduling remain outside this workspace.';

const principalTimetableExceptionBoundary =
    'Mark handled and Reopen record Principal exception-handling state only. They do not silently reassign a teacher, move a room, change a lesson time or publish a new timetable.';

const principalTimetableAuditBoundary =
    'Every handled/reopened exception keeps the actor membership, timestamp, lesson reference and append-only exception event for auditability.';

const principalTimetableAiBoundary =
    'Principal AI may highlight clashes, uncovered lessons and workload pressure, but it must not silently alter the timetable or assign staff.';
