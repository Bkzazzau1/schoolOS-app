import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_learning_progress_models.dart';
import 'teacher_roster.dart';

class TeacherLearningProgressSnapshot {
  const TeacherLearningProgressSnapshot({
    required this.students,
    required this.classOptions,
    required this.permissions,
  });

  final List<TeacherLearningStudentEvidence> students;

  /// The teacher's real assigned classes.
  final List<String> classOptions;

  final TeacherLearningProgressPermissions permissions;
}

/// Combines evidence about a teacher's real assigned students. Each student is real, from the school's real
/// register; their per-topic evidence is empty for now because no module (classwork, assignments, assessments or
/// CBT) yet produces topic-tagged results to combine, and no evidence is invented in its place.
class TeacherLearningProgressRepository {
  TeacherLearningProgressRepository({
    required SchoolSessionController schoolSession,
    required TeacherRoster roster,
  })  : _schoolSession = schoolSession,
        _roster = roster;

  final SchoolSessionController _schoolSession;
  final TeacherRoster _roster;

  TeacherLearningProgressPermissions permissionsFor(SchoolMembership membership) {
    final teacher = membership.role == SchoolRole.teacher;
    return TeacherLearningProgressPermissions(
      canViewAssignedLearners: teacher,
      canViewMultiEvidence: teacher,
      canSuggestSupport: teacher,
      canPubliclyRankChildren: false,
      canDiagnoseCondition: false,
      canMakePromotionDecision: false,
      canMakePunishmentDecision: false,
    );
  }

  Future<TeacherLearningProgressSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final assignedClasses = await _roster.assignedClasses(membership);
    final classNames = {for (final c in assignedClasses) c.className}.toList()..sort();
    final subjectByClass = {for (final c in assignedClasses) c.className: c.subject};

    final seen = <String>{};
    final students = <TeacherLearningStudentEvidence>[];
    for (final className in classNames) {
      for (final student in await _roster.studentsIn(className)) {
        if (!seen.add(student.id)) continue;
        students.add(TeacherLearningStudentEvidence(
          id: student.id,
          name: student.name,
          className: student.className,
          subject: subjectByClass[className] ?? '',
          average: 0,
          attendance: 0,
          topics: const [],
        ));
      }
    }
    students.sort((a, b) => a.name.compareTo(b.name));

    return TeacherLearningProgressSnapshot(
      students: students,
      classOptions: classNames,
      permissions: permissionsFor(membership),
    );
  }
}
