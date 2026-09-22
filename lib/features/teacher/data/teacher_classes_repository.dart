import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_attendance_models.dart';
import '../domain/teacher_classes_models.dart';
import 'teacher_roster.dart';

/// "My Classes", built from the classes the teacher is actually assigned and the school's real student register.
///
/// Attendance is today's register when one has been taken. Progress, class average and pending marking need the syllabus
/// and assessment modules to be linked to the same class list, which is not done yet, so they show as not tracked rather
/// than a made-up number.
class TeacherClassesRepository {
  TeacherClassesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _registerType = 'teacher_attendance_register';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherClassPermissions permissionsFor(SchoolMembership membership) =>
      TeacherClassPermissions(
        canViewAssignedClasses: membership.role == SchoolRole.teacher,
        canOpenAuthorizedRoster: membership.role == SchoolRole.teacher,
        canChangeClassMembership: false,
        canChangeAcademicMarksFromClassesPage: false,
        canAccessFinance: false,
        canAccessSafeguardingDetails: false,
      );

  Future<TeacherClassesSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final classes = await _roster.assignedClasses(membership);

    final assignments = <TeacherClassAssignment>[];
    for (final c in classes) {
      final students = await _roster.studentsIn(c.className);
      final lessonId = '${c.className}|${c.subject}'.replaceAll(' ', '-');
      final record = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _registerType,
        entityId: lessonId,
      );
      var attendance = 0;
      if (record != null) {
        final register = TeacherAttendanceRegister.fromJson(record.payload);
        attendance = register.presentPercent;
      }
      assignments.add(TeacherClassAssignment(
        id: lessonId,
        name: c.className,
        subject: c.subject,
        students: students.length,
        room: c.room,
        progress: 0,
        attendance: attendance,
        classAverage: 0,
        nextLesson: c.time,
        topic: '',
        pendingMarking: 0,
      ));
    }

    return TeacherClassesSnapshot(
      assignments: assignments,
      permissions: permissionsFor(membership),
    );
  }
}
