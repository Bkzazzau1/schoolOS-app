import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_attendance_desk.dart'
    show sectionOfClass;
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../teacher/data/teacher_assessment_repository.dart'
    show teacherAssessmentEntityType;
import '../../teacher/data/teacher_syllabus_repository.dart'
    show teacherSyllabusProgressEntityType;
import '../../teacher/domain/teacher_assessment_models.dart';
import '../../teacher/domain/teacher_syllabus_models.dart';
import '../domain/principal_academics_models.dart';
import 'principal_assignments_repository.dart';
import 'principal_attendance_repository.dart';

class PrincipalClassworkOversight {
  const PrincipalClassworkOversight({
    required this.id,
    required this.title,
    required this.className,
    required this.subject,
    required this.teacher,
    required this.state,
    required this.dueAt,
    required this.maximumScore,
    required this.totalStudents,
    required this.submissions,
    required this.marked,
    required this.lateSubmissions,
    required this.publicationRevision,
  });

  final String id;
  final String title;
  final String className;
  final String subject;
  final String teacher;
  final String state;
  final String dueAt;
  final int maximumScore;
  final int totalStudents;
  final int submissions;
  final int marked;
  final int lateSubmissions;
  final int publicationRevision;

  int get unsubmitted => totalStudents > submissions ? totalStudents - submissions : 0;
  int get unmarked => submissions > marked ? submissions - marked : 0;
}

class PrincipalAcademicsSnapshot {
  const PrincipalAcademicsSnapshot({
    required this.classes,
    required this.subjects,
    required this.risks,
    required this.classwork,
    required this.permissions,
  });

  final List<PrincipalAcademicClass> classes;

  /// Empty until assessment records carry a canonical subject id. A free-text
  /// assessment title is not sufficient authority for school-wide subject ranking.
  final List<PrincipalSubjectPerformance> subjects;

  /// Academic risk remains a human/AI interpretation layer, not an invented
  /// status inferred from incomplete operational records.
  final List<PrincipalAcademicRisk> risks;

  /// Read-only Teacher-issued work for the Principal's Secondary scope. Student
  /// draft responses are never included; counts come from canonical assignment
  /// publication/submission evidence maintained by the server.
  final List<PrincipalClassworkOversight> classwork;

  final PrincipalAcademicsPermissions permissions;
}

const _noConcernRecorded =
    'No leadership note has been recorded for this class yet.';

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

  static const _sessionType = 'academic_session';
  static const _termType = 'academic_term';
  static const _topicType = 'academic_curriculum_topic';
  static const _classworkType = 'academic_assignment';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final AdministratorStudentsRepository _students;
  final PrincipalAssignmentsRepository _assignments;
  final PrincipalAttendanceRepository _attendance;

  PrincipalAcademicsPermissions permissionsFor(SchoolMembership membership) =>
      PrincipalAcademicsPermissions(
        canViewSecondaryAcademics: membership.role == SchoolRole.principal,
        canLeadSecondaryInterventions: membership.role == SchoolRole.principal,
        canManagePrimary: false,
        canManageEarlyYears: false,
      );

  Future<Map<String, List<AdministratorStudentRecord>>>
      _secondaryRegisterByClass() async {
    final register = (await _students.load()).students.where(
      (student) =>
          student.status == AdministratorStudentStatus.active &&
          sectionOfClass(student.className) == 'Secondary',
    );
    final byClass = <String, List<AdministratorStudentRecord>>{};
    for (final student in register) {
      byClass.putIfAbsent(student.className, () => []).add(student);
    }
    return byClass;
  }

  Future<Map<String, int>> _attendancePerClass() async {
    final rows = (await _attendance.load()).classes;
    return {for (final row in rows) row.className: row.rate};
  }

  /// Only assessments that have actually gone past drafting (published or
  /// further along) count as class evidence - a Teacher's in-progress draft
  /// is not yet real class-wide assessment activity.
  Future<Map<String, List<TeacherAssessment>>> _assessmentsPerClass(
    String schoolId,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: teacherAssessmentEntityType,
    );
    final byClass = <String, List<TeacherAssessment>>{};
    for (final record in records) {
      final item = TeacherAssessment.fromJson(record.payload);
      if (item.state == TeacherAssessmentState.draft) continue;
      byClass.putIfAbsent(item.className, () => []).add(item);
    }
    return byClass;
  }

  Future<String> _activeSessionId(String schoolId) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: _sessionType,
    );
    for (final record in records) {
      if (record.payload['status'] == 'active') {
        return record.payload['id'] as String? ?? record.entityId;
      }
    }
    return '';
  }

  Future<String> _activeTermId(String schoolId, String sessionId) async {
    if (sessionId.isEmpty) return '';
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: _termType,
    );
    for (final record in records) {
      final payload = record.payload;
      if (payload['sessionId'] == sessionId && payload['status'] == 'active') {
        return payload['id'] as String? ?? record.entityId;
      }
    }
    return '';
  }

  Future<Map<String, TeacherSyllabusProgressRecord>> _progressByTopic(
    String schoolId,
  ) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: teacherSyllabusProgressEntityType,
    );
    final result = <String, TeacherSyllabusProgressRecord>{};
    for (final record in records) {
      final item = TeacherSyllabusProgressRecord.fromJson(record.payload);
      result[item.id] = item;
    }
    return result;
  }

  Future<Map<String, List<String>>> _topicIdsByClass({
    required String schoolId,
    required String termId,
    required PrincipalAssignmentsSnapshot assignmentSnapshot,
  }) async {
    if (termId.isEmpty) return const {};
    final classByRequirement = {
      for (final item in assignmentSnapshot.curriculumRequirements)
        if (item.isActive) item.id: item.className,
    };
    if (classByRequirement.isEmpty) return const {};

    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: _topicType,
    );
    final byClass = <String, List<String>>{};
    for (final record in records) {
      final payload = record.payload;
      if (payload['termId'] != termId) continue;
      final classSubjectId = payload['classSubjectId'] as String? ?? '';
      final className = classByRequirement[classSubjectId];
      if (className == null) continue;
      final id = payload['id'] as String? ?? record.entityId;
      byClass.putIfAbsent(className, () => []).add(id);
    }
    return byClass;
  }

  Future<List<PrincipalClassworkOversight>> _classworkForTerm({
    required String schoolId,
    required String termId,
  }) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: schoolId,
      entityType: _classworkType,
    );
    final result = <PrincipalClassworkOversight>[];
    for (final record in records) {
      final payload = record.payload;
      if ((payload['section'] as String? ?? '').trim().toLowerCase() !=
          'secondary') {
        continue;
      }
      if (termId.isNotEmpty && payload['termId'] != termId) continue;
      result.add(
        PrincipalClassworkOversight(
          id: payload['id'] as String? ?? record.entityId,
          title: payload['title'] as String? ?? '',
          className: payload['className'] as String? ?? '',
          subject: payload['subject'] as String? ?? '',
          teacher: payload['currentTeacher'] as String? ??
              payload['author'] as String? ??
              'Teacher',
          state: payload['state'] as String? ?? 'draft',
          dueAt: payload['dueAt'] as String? ?? '',
          maximumScore: (payload['maximumScore'] as num?)?.toInt() ?? 0,
          totalStudents: (payload['totalStudents'] as num?)?.toInt() ?? 0,
          submissions: (payload['submissions'] as num?)?.toInt() ?? 0,
          marked: (payload['marked'] as num?)?.toInt() ?? 0,
          lateSubmissions: (payload['lateSubmissions'] as num?)?.toInt() ?? 0,
          publicationRevision:
              (payload['publicationRevision'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    result.sort((a, b) {
      final byDue = a.dueAt.compareTo(b.dueAt);
      if (byDue != 0) return byDue;
      final byClass = a.className.compareTo(b.className);
      return byClass != 0 ? byClass : a.subject.compareTo(b.subject);
    });
    return result;
  }

  Future<PrincipalAcademicsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final schoolId = membership.schoolId;

    final registerByClass = await _secondaryRegisterByClass();
    final attendanceByClass = await _attendancePerClass();
    final assessmentsByClass = await _assessmentsPerClass(schoolId);
    final assignmentSnapshot = await _assignments.load();
    final teachersByClass = <String, Set<String>>{};
    for (final assignment in assignmentSnapshot.assignments) {
      teachersByClass
          .putIfAbsent(assignment.className, () => <String>{})
          .add(assignment.teacherId);
    }

    final activeSessionId = await _activeSessionId(schoolId);
    final activeTermId = await _activeTermId(schoolId, activeSessionId);
    final topicsByClass = await _topicIdsByClass(
      schoolId: schoolId,
      termId: activeTermId,
      assignmentSnapshot: assignmentSnapshot,
    );
    final progressByTopic = await _progressByTopic(schoolId);
    final classwork = await _classworkForTerm(
      schoolId: schoolId,
      termId: activeTermId,
    );

    final classNames = <String>{
      ...registerByClass.keys,
      ...assignmentSnapshot.classOptions,
    }.toList()
      ..sort();

    final classes = [
      for (final className in classNames)
        () {
          final assessmentItems =
              assessmentsByClass[className] ?? const <TeacherAssessment>[];
          final hasEvidence = assessmentItems.isNotEmpty;
          final scoredItems =
              assessmentItems.where((item) => item.averagePercent != null).toList();
          final average = scoredItems.isEmpty
              ? 0
              : (scoredItems.fold<double>(0, (sum, item) => sum + item.averagePercent!) /
                      scoredItems.length)
                  .round();
          final totalEntered = assessmentItems.fold<int>(
            0,
            (sum, item) => sum + item.entered,
          );
          final totalExpected = assessmentItems.fold<int>(
            0,
            (sum, item) => sum + item.totalStudents,
          );
          final assessments = totalExpected == 0
              ? 0
              : (totalEntered * 100 / totalExpected).round();

          final topicIds = topicsByClass[className] ?? const <String>[];
          final completed = topicIds
              .where(
                (id) =>
                    progressByTopic[id]?.reportedStatus ==
                    TeacherSyllabusStatus.completed,
              )
              .length;
          final syllabus = topicIds.isEmpty
              ? 0
              : (completed * 100 / topicIds.length).round();
          final hasScheme = topicIds.isNotEmpty;

          final status = !hasEvidence
              ? PrincipalAcademicStatus.notEvaluated
              : (average >= 75
                  ? PrincipalAcademicStatus.strong
                  : (average >= 60
                      ? PrincipalAcademicStatus.onTrack
                      : (average >= 45
                          ? PrincipalAcademicStatus.watch
                          : PrincipalAcademicStatus.behind)));

          return PrincipalAcademicClass(
            name: className,
            level: _levelOf(className),
            students: registerByClass[className]?.length ?? 0,
            average: average,
            attendance: attendanceByClass[className] ?? 0,
            syllabus: syllabus,
            hasSyllabusScheme: hasScheme,
            syllabusBehind: false,
            assessments: assessments,
            teachers: teachersByClass[className]?.length ?? 0,
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
      classwork: classwork,
      permissions: permissionsFor(membership),
    );
  }
}
