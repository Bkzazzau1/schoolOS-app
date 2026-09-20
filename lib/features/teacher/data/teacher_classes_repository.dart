import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/teacher_classes_models.dart';
import 'teacher_classes_demo_data.dart';

class TeacherClassesRepository {
  TeacherClassesRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _assignmentType = 'teacher_class_assignment';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

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
    await _seedIfNeeded(membership);

    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );

    final assignments = records
        .map((record) => TeacherClassAssignment.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => _order(a.id).compareTo(_order(b.id)));

    return TeacherClassesSnapshot(
      assignments: assignments,
      permissions: permissionsFor(membership),
    );
  }

  Future<void> _seedIfNeeded(SchoolMembership membership) async {
    final existing = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _assignmentType,
    );
    if (existing.isNotEmpty) return;

    for (final assignment in teacherClassAssignments) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _assignmentType,
        entityId: assignment.id,
        payload: assignment.toJson(),
      );
    }
  }

  int _order(String id) {
    final index = teacherClassAssignments.indexWhere((item) => item.id == id);
    return index < 0 ? teacherClassAssignments.length : index;
  }
}
