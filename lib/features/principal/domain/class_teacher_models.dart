/// The canonical, server-syncable entity type for who is the class/form
/// teacher of one whole class in one academic session. Write authority
/// mirrors Principal Teaching Assignment exactly (Principal, Secondary only,
/// or Proprietor school-wide) - not Administrator, since this is a staffing
/// decision, not a release/oversight one.
const classTeacherAssignmentEntityType = 'class_teacher_assignment';

/// A Teacher-readable roster of the classes they are currently the class
/// teacher for. Server-derived; never written directly by a device.
const classTeacherLinkEntityType = 'class_teacher_link';

class ClassTeacherAssignment {
  const ClassTeacherAssignment({
    required this.id,
    required this.classId,
    required this.className,
    required this.section,
    required this.sessionId,
    required this.session,
    required this.teacherId,
    required this.teacherName,
    this.version = 1,
    this.startedAt,
    this.endedAt,
    this.pendingSync = false,
    this.serverVersion,
  });

  final String id;
  final String classId;
  final String className;
  final String section;
  final String sessionId;
  final String session;
  final String teacherId;
  final String teacherName;
  final int version;
  final String? startedAt;
  final String? endedAt;
  final bool pendingSync;
  final int? serverVersion;

  bool get isActive => endedAt == null;

  Map<String, Object?> toJson() => {
        'id': id,
        'classId': classId,
        'className': className,
        'section': section,
        'sessionId': sessionId,
        'session': session,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'version': version,
        'startedAt': startedAt,
        'endedAt': endedAt,
      };

  Map<String, Object?> toMutationJson({String handoverReason = ''}) => {
        'id': id,
        'classId': classId,
        'sessionId': sessionId,
        'teacherId': teacherId,
        'handoverReason': handoverReason,
      };

  factory ClassTeacherAssignment.fromJson(Map<String, dynamic> json) => ClassTeacherAssignment(
        id: json['id'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        section: json['section'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        session: json['session'] as String? ?? '',
        teacherId: json['teacherId'] as String? ?? '',
        teacherName: json['teacherName'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        startedAt: json['startedAt'] as String?,
        endedAt: json['endedAt'] as String?,
      );
}

/// One class this Teacher currently holds as class/form teacher, from
/// [classTeacherLinkEntityType].
class MyClassTeacherLink {
  const MyClassTeacherLink({
    required this.classId,
    required this.className,
    required this.section,
    required this.sessionId,
    required this.session,
  });

  final String classId;
  final String className;
  final String section;
  final String sessionId;
  final String session;

  factory MyClassTeacherLink.fromJson(Map<String, dynamic> json) => MyClassTeacherLink(
        classId: json['classId'] as String? ?? '',
        className: json['className'] as String? ?? '',
        section: json['section'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        session: json['session'] as String? ?? '',
      );
}
