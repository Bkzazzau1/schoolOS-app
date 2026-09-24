import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_attendance_models.dart';
import '../domain/teacher_classes_models.dart';
import 'teacher_roster.dart';

/// "My Classes" is built only from the classes published to the current
/// Teacher membership by the server-owned teacher_class_assignment record.
/// Student counts are read from the current school register; curriculum
/// identity, periods and term topics come from the canonical assignment link.
class TeacherClassesRepository {
  TeacherClassesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _roster = roster;

  static const _registerType = 'teacher_attendance_register';
  static const _academicSessionType = 'academic_session';

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
    for (final assigned in classes) {
      final students = await _roster.studentsIn(assigned.className);
      final legacyLessonId =
          '${assigned.className}|${assigned.subject}'.replaceAll(' ', '-');
      final assignmentViewId = assigned.classSubjectId.isNotEmpty
          ? assigned.classSubjectId
          : legacyLessonId;

      final registerRecord = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: _registerType,
        entityId: legacyLessonId,
      );
      var attendance = 0;
      if (registerRecord != null) {
        final register =
            TeacherAttendanceRegister.fromJson(registerRecord.payload);
        attendance = register.presentPercent;
      }

      var sessionName = '';
      if (assigned.sessionId.isNotEmpty) {
        final sessionRecord = await _localDatabase.getLocalRecord(
          tenantId: membership.schoolId,
          entityType: _academicSessionType,
          entityId: assigned.sessionId,
        );
        sessionName = sessionRecord?.payload['name'] as String? ?? '';
      }

      final curriculumTopics = [
        for (final topic in assigned.topics)
          TeacherClassCurriculumTopic(
            id: topic.id,
            sequence: topic.sequence,
            title: topic.title,
            description: topic.description,
          ),
      ];

      assignments.add(
        TeacherClassAssignment(
          id: assignmentViewId,
          name: assigned.className,
          subject: assigned.subject,
          students: students.length,
          room: assigned.room,
          progress: 0,
          attendance: attendance,
          classAverage: 0,
          nextLesson: assigned.time,
          topic: curriculumTopics.isEmpty ? '' : curriculumTopics.first.title,
          pendingMarking: 0,
          sessionId: assigned.sessionId,
          sessionName: sessionName,
          classId: assigned.classId,
          subjectId: assigned.subjectId,
          classSubjectId: assigned.classSubjectId,
          teachingAssignmentId: assigned.teachingAssignmentId,
          periodsPerWeek: assigned.periodsPerWeek,
          currentTermId: assigned.currentTermId,
          currentTerm: assigned.currentTerm,
          curriculumTopics: curriculumTopics,
        ),
      );
    }

    return TeacherClassesSnapshot(
      assignments: assignments,
      permissions: permissionsFor(membership),
    );
  }
}
