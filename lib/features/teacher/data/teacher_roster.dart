import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';

/// A canonical class-subject responsibility visible to one Teacher membership.
class AssignedClass {
  const AssignedClass({
    required this.className,
    required this.subject,
    this.classSubjectId = '',
    this.sessionId = '',
    this.classId = '',
    this.subjectId = '',
    this.periodsPerWeek = 0,
    this.room = '',
    this.time = '',
  });

  final String className;
  final String subject;
  final String classSubjectId;
  final String sessionId;
  final String classId;
  final String subjectId;
  final int periodsPerWeek;
  final String room;
  final String time;

  Map<String, Object?> toJson() => {
        'className': className,
        'subject': subject,
        'classSubjectId': classSubjectId,
        'sessionId': sessionId,
        'classId': classId,
        'subjectId': subjectId,
        'periodsPerWeek': periodsPerWeek,
        'room': room,
        'time': time,
      };

  factory AssignedClass.fromJson(Map<String, Object?> json) => AssignedClass(
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        classSubjectId: json['classSubjectId'] as String? ?? '',
        sessionId: json['sessionId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        subjectId: json['subjectId'] as String? ?? '',
        periodsPerWeek: json['periodsPerWeek'] as int? ?? 0,
        room: json['room'] as String? ?? '',
        time: json['time'] as String? ?? '',
      );
}

/// Demo-only teaching responsibilities. Real schools never seed these records.
const _demoAssignments = <String, List<AssignedClass>>{
  'membership-teacher-002': [
    AssignedClass(
      className: 'Primary 3',
      subject: 'Class teacher',
      room: 'P3',
      time: '8:00',
    ),
    AssignedClass(
      className: 'Primary 4',
      subject: 'English',
      room: 'P4',
      time: '9:20',
    ),
  ],
  'membership-teacher-003': [
    AssignedClass(
      className: 'JSS 2A',
      subject: 'Mathematics',
      periodsPerWeek: 5,
      room: 'B12',
      time: '8:00',
    ),
    AssignedClass(
      className: 'JSS 2B',
      subject: 'Mathematics',
      periodsPerWeek: 5,
      room: 'B14',
      time: '9:20',
    ),
    AssignedClass(
      className: 'SS1A',
      subject: 'Further Mathematics',
      periodsPerWeek: 4,
      room: 'D06',
      time: '11:00',
    ),
  ],
};

/// Teacher class access is derived from server-confirmed canonical teaching
/// assignments. A real Teacher device may read but never author this record.
class TeacherRoster {
  TeacherRoster({
    required this.database,
    required this.session,
    required this.students,
  });

  final LocalDatabase database;
  final SchoolSessionController session;
  final AdministratorStudentsRepository students;

  static const assignmentType = 'teacher_class_assignment';

  Future<List<AssignedClass>> assignedClasses([SchoolMembership? who]) async {
    final membership = who ?? session.requireActiveMembership();
    var record = await database.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: assignmentType,
      entityId: membership.id,
    );
    if (record == null) {
      // Backend-connected schools wait for the private server-generated link.
      // Never substitute a demo class for a real signed-in Teacher.
      if (LocalDatabase.blockDemoSeeds) return const [];
      final demo = _demoAssignments[membership.id];
      if (demo == null) return const [];
      await database.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentType,
        entityId: membership.id,
        payload: {'classes': [for (final value in demo) value.toJson()]},
      );
      record = await database.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: assignmentType,
        entityId: membership.id,
      );
    }
    return [
      for (final raw in (record?.payload['classes'] as List? ?? const []))
        AssignedClass.fromJson(Map<String, Object?>.from(raw as Map)),
    ];
  }

  /// Kept only for standalone demo behavior. In a real school the Principal's
  /// canonical Teaching Assignments workflow owns this relationship.
  Future<String?> assign(
    SchoolMembership teacher,
    List<AssignedClass> classes,
  ) async {
    final by = session.requireActiveMembership();
    if (LocalDatabase.blockDemoSeeds) {
      return 'Teaching responsibilities are managed by the Principal from canonical class-subject curriculum.';
    }
    if (by.role != SchoolRole.proprietor &&
        by.role != SchoolRole.administrator) {
      return 'Only the owner or the administrator can assign demo classes.';
    }
    final existing = await database.getLocalRecord(
      tenantId: by.schoolId,
      entityType: assignmentType,
      entityId: teacher.id,
    );
    final payload = {'classes': [for (final value in classes) value.toJson()]};
    await database.upsertLocalRecord(
      tenantId: by.schoolId,
      entityType: assignmentType,
      entityId: teacher.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: by.schoolId,
      membershipId: by.id,
      entityType: assignmentType,
      entityId: teacher.id,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
    return null;
  }

  /// Current pupils for a class. Completed transfer/graduation records do not
  /// survive this filter; a pending transfer remains visible until it completes.
  Future<List<AdministratorStudentRecord>> studentsIn(String className) async {
    final all = (await students.load()).students;
    final wanted = className.trim().toLowerCase();
    return [
      for (final student in all)
        if ((student.status == AdministratorStudentStatus.active ||
                student.status == AdministratorStudentStatus.transferPending) &&
            student.className.trim().toLowerCase() == wanted)
          student,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}
