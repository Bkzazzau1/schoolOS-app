import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';

/// A class a teacher teaches, and what they teach it.
class AssignedClass {
  const AssignedClass({required this.className, required this.subject, this.room = '', this.time = ''});

  final String className;
  final String subject;
  final String room;
  final String time;

  Map<String, Object?> toJson() => {'className': className, 'subject': subject, 'room': room, 'time': time};

  factory AssignedClass.fromJson(Map<String, Object?> json) => AssignedClass(
        className: json['className'] as String? ?? '',
        subject: json['subject'] as String? ?? '',
        room: json['room'] as String? ?? '',
        time: json['time'] as String? ?? '',
      );
}

/// Which classes each demo teacher teaches. Real schools assign classes themselves.
const _demoAssignments = <String, List<AssignedClass>>{
  'membership-teacher-002': [
    AssignedClass(className: 'Primary 3', subject: 'Class teacher', room: 'P3', time: '8:00'),
    AssignedClass(className: 'Primary 4', subject: 'English', room: 'P4', time: '9:20'),
  ],
  'membership-teacher-003': [
    AssignedClass(className: 'JSS 2A', subject: 'Mathematics', room: 'B12', time: '8:00'),
    AssignedClass(className: 'JSS 2B', subject: 'Mathematics', room: 'B14', time: '9:20'),
    AssignedClass(className: 'SS1A', subject: 'Further Mathematics', room: 'D06', time: '11:00'),
  ],
};

/// The classes a teacher teaches and the students in them, from the school's real student register.
class TeacherRoster {
  TeacherRoster({required this.database, required this.session, required this.students});

  final LocalDatabase database;
  final SchoolSessionController session;
  final AdministratorStudentsRepository students;

  static const assignmentType = 'teacher_class_assignment';

  /// The classes this membership teaches. The demo teachers start with some; the owner or administrator can assign more.
  Future<List<AssignedClass>> assignedClasses([SchoolMembership? who]) async {
    final m = who ?? session.requireActiveMembership();
    var record = await database.getLocalRecord(tenantId: m.schoolId, entityType: assignmentType, entityId: m.id);
    if (record == null) {
      final demo = _demoAssignments[m.id];
      if (demo == null) return const [];
      // The demo school (a school server blocks this: it assigns its own classes).
      await database.upsertLocalRecord(
        tenantId: m.schoolId,
        entityType: assignmentType,
        entityId: m.id,
        payload: {'classes': [for (final c in demo) c.toJson()]},
      );
      record = await database.getLocalRecord(tenantId: m.schoolId, entityType: assignmentType, entityId: m.id);
    }
    return [
      for (final c in (record?.payload['classes'] as List? ?? const [])) AssignedClass.fromJson(Map<String, Object?>.from(c as Map)),
    ];
  }

  /// Sets the classes a teacher teaches (owner or administrator only).
  Future<String?> assign(SchoolMembership teacher, List<AssignedClass> classes) async {
    final by = session.requireActiveMembership();
    if (by.role != SchoolRole.proprietor && by.role != SchoolRole.administrator) {
      return 'Only the owner or the administrator can assign classes.';
    }
    final existing = await database.getLocalRecord(tenantId: by.schoolId, entityType: assignmentType, entityId: teacher.id);
    final payload = {'classes': [for (final c in classes) c.toJson()]};
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

  /// The students in a class today (a student who has left the school is not listed), by name.
  Future<List<AdministratorStudentRecord>> studentsIn(String className) async {
    final all = (await students.load()).students;
    final wanted = className.trim().toLowerCase();
    return [
      for (final s in all)
        if (s.status != AdministratorStudentStatus.transferredOut && s.className.trim().toLowerCase() == wanted) s,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}
