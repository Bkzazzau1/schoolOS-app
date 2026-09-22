import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart' show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../teacher/data/teacher_assessment_repository.dart' show teacherAssessmentRegisterEntityType;
import '../../teacher/data/teacher_syllabus_demo_data.dart' show teacherSyllabusRows;
import '../../teacher/data/teacher_syllabus_repository.dart' show teacherSyllabusProgressEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';
import '../../teacher/domain/teacher_syllabus_models.dart';
import '../domain/principal_academics_models.dart';
import 'principal_assignments_repository.dart';
import 'principal_attendance_repository.dart';

class PrincipalAcademicsSnapshot {
  const PrincipalAcademicsSnapshot({
    required this.classes,
    required this.subjects,
    required this.risks,
    required this.permissions,
  });

  final List<PrincipalAcademicClass> classes;

  /// Always empty: no real assessment carries a subject label yet (a score sheet only records a class and a
  /// free-text title), so there is no real way to aggregate performance by subject school-wide.
  final List<PrincipalSubjectPerformance> subjects;

  /// Always empty: identifying a genuine academic "risk" needs human judgement over a pattern, which is not
  /// something any real source in the app produces automatically.
  final List<PrincipalAcademicRisk> risks;

  final PrincipalAcademicsPermissions permissions;
}

const _noConcernRecorded = 'No leadership note has been recorded for this class yet.';

/// The level bucket of a class name, e.g. "JSS 2A" -> "JSS 2", "SS1A" -> "SS 1".
String _levelOf(String className) {
  final match = RegExp(r'^([A-Za-z]+)\s*([0-9]+)').firstMatch(className);
  if (match == null) return className;
  return '${match.group(1)} ${match.group(2)}';
}

class PrincipalAcademicsRepository {
  PrincipalAcademicsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required AdministratorStudentsRepository students,
    required PrincipalAssignmentsRepository assignments,
    required PrincipalAttendanceRepository attendance,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _students = students,
        _assignments = assignments,
        _attendance = attendance;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final PrincipalAssignmentsRepository _assignments;
  final PrincipalAttendanceRepository _attendance;

  PrincipalAcademicsPermissions permissionsFor(SchoolMembership membership) => PrincipalAcademicsPermissions(
        canViewSecondaryAcademics: membership.role == SchoolRole.principal,
        canLeadSecondaryInterventions: membership.role == SchoolRole.principal,
        canManagePrimary: false,
        canManageEarlyYears: false,
      );

  Future<Map<String, List<AdministratorStudentRecord>>> _secondaryRegisterByClass() async {
    final register = (await _students.load()).students.where(
      (s) => s.status != AdministratorStudentStatus.transferredOut && sectionOfClass(s.className) == 'Secondary',
    );
    final byClass = <String, List<AdministratorStudentRecord>>{};
    for (final s in register) {
      byClass.putIfAbsent(s.className, () => []).add(s);
    }
    return byClass;
  }

  Future<Map<String, int>> _teachersPerClass() async {
    final assignments = (await _assignments.load()).assignments;
    final byClass = <String, Set<String>>{};
    for (final a in assignments) {
      byClass.putIfAbsent(a.className, () => {}).add(a.teacherId);
    }
    return {for (final entry in byClass.entries) entry.key: entry.value.length};
  }

  Future<Map<String, int>> _attendancePerClass() async {
    final rows = (await _attendance.load()).classes;
    return {for (final row in rows) row.className: row.rate};
  }

  Future<Map<String, List<TeacherAssessmentRegisterItem>>> _assessmentsPerClass(String schoolId) async {
    final records = await _localDatabase.getLocalRecords(tenantId: schoolId, entityType: teacherAssessmentRegisterEntityType);
    final byClass = <String, List<TeacherAssessmentRegisterItem>>{};
    for (final record in records) {
      final item = TeacherAssessmentRegisterItem.fromJson(record.payload);
      byClass.putIfAbsent(item.className, () => []).add(item);
    }
    return byClass;
  }

  Future<Map<String, TeacherSyllabusProgressRecord>> _syllabusProgressById(String schoolId) async {
    final records = await _localDatabase.getLocalRecords(tenantId: schoolId, entityType: teacherSyllabusProgressEntityType);
    return {
      for (final record in records) TeacherSyllabusProgressRecord.fromJson(record.payload).id: TeacherSyllabusProgressRecord.fromJson(record.payload),
    };
  }

  /// The share of [className]'s approved-scheme topics reported complete, as a whole percentage. `0` when the
  /// class has no approved scheme of work uploaded at all (see [PrincipalAcademicClass.hasSyllabusScheme]).
  int _syllabusCoverage(String className, Map<String, TeacherSyllabusProgressRecord> progressById) {
    final rows = teacherSyllabusRows.where((row) => row.className == className).toList();
    if (rows.isEmpty) return 0;
    final done = rows.where((row) => (progressById[row.id]?.reportedStatus ?? row.approvedStatus) == TeacherSyllabusStatus.completed).length;
    return (done * 100 / rows.length).round();
  }

  /// Whether any topic in [className]'s approved scheme is currently reported behind.
  bool _syllabusBehind(String className, Map<String, TeacherSyllabusProgressRecord> progressById) => teacherSyllabusRows
      .where((row) => row.className == className)
      .any((row) => (progressById[row.id]?.reportedStatus ?? row.approvedStatus) == TeacherSyllabusStatus.behind);

  Future<PrincipalAcademicsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();

    final registerByClass = await _secondaryRegisterByClass();
    final teachersByClass = await _teachersPerClass();
    final attendanceByClass = await _attendancePerClass();
    final assessmentsByClass = await _assessmentsPerClass(membership.schoolId);
    final syllabusProgressById = await _syllabusProgressById(membership.schoolId);

    final classNames = registerByClass.keys.toList()..sort();
    final classes = [
      for (final className in classNames)
        () {
          final items = assessmentsByClass[className] ?? const <TeacherAssessmentRegisterItem>[];
          final hasEvidence = items.isNotEmpty;
          final average = !hasEvidence
              ? 0
              : (items.fold<double>(0, (sum, item) => sum + (item.maximumScore == 0 ? 0 : item.average / item.maximumScore * 100)) / items.length).round();
          final totalEntered = items.fold<int>(0, (sum, item) => sum + item.entered);
          final totalExpected = items.fold<int>(0, (sum, item) => sum + item.total);
          final assessments = totalExpected == 0 ? 0 : (totalEntered * 100 / totalExpected).round();
          final hasScheme = teacherSyllabusRows.any((row) => row.className == className);
          final status = !hasEvidence
              ? PrincipalAcademicStatus.notEvaluated
              : (average >= 75
                  ? PrincipalAcademicStatus.strong
                  : (average >= 60 ? PrincipalAcademicStatus.onTrack : (average >= 45 ? PrincipalAcademicStatus.watch : PrincipalAcademicStatus.behind)));
          return PrincipalAcademicClass(
            name: className,
            level: _levelOf(className),
            students: registerByClass[className]!.length,
            average: average,
            attendance: attendanceByClass[className] ?? 0,
            syllabus: _syllabusCoverage(className, syllabusProgressById),
            hasSyllabusScheme: hasScheme,
            syllabusBehind: hasScheme && _syllabusBehind(className, syllabusProgressById),
            assessments: assessments,
            teachers: teachersByClass[className] ?? 0,
            trend: 0,
            status: status,
            concern: _noConcernRecorded,
          );
        }(),
    ];

    return PrincipalAcademicsSnapshot(
      classes: classes,
      subjects: const [],
      risks: const [],
      permissions: permissionsFor(membership),
    );
  }
}
