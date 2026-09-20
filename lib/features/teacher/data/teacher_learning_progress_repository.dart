import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_learning_progress_models.dart';
import 'teacher_learning_progress_demo_data.dart';

class TeacherLearningProgressSnapshot {
  const TeacherLearningProgressSnapshot({
    required this.students,
    required this.permissions,
  });

  final List<TeacherLearningStudentEvidence> students;
  final TeacherLearningProgressPermissions permissions;
}

class TeacherLearningProgressRepository {
  TeacherLearningProgressRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _studentEvidenceType = 'teacher_learning_progress_student';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

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
    await _seedIfNeeded(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _studentEvidenceType,
    );
    final parsed = records
        .map((record) => TeacherLearningStudentEvidence.fromJson(record.payload))
        .toList(growable: false);
    final order = {
      for (var i = 0; i < teacherLearningStudents.length; i++)
        teacherLearningStudents[i].id: i,
    };
    parsed.sort((a, b) =>
        (order[a.id] ?? 999).compareTo(order[b.id] ?? 999));

    return TeacherLearningProgressSnapshot(
      students: parsed,
      permissions: permissionsFor(membership),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _studentEvidenceType,
    );
    if (existing.isNotEmpty) return;

    for (final student in teacherLearningStudents) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _studentEvidenceType,
        entityId: student.id,
        payload: student.toJson(),
      );
    }
  }
}
