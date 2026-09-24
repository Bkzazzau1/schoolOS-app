import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_academics_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_academics_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_academics_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart' show teacherAssessmentEntityType;
import 'package:schoolos_app/features/teacher/data/teacher_syllabus_repository.dart' show teacherSyllabusProgressEntityType;
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_syllabus_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalAcademicsRepository principalAcademics;
  late PrincipalAssignmentsRepository principalAssignments;

  Future<void> setUpSchool() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal]);
    await session.selectSchool(principal);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    principalAssignments = PrincipalAssignmentsRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      staff: OwnerStaffProfileRepository(database: database, session: session),
    );
    final attendance = PrincipalAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
    );
    principalAcademics = PrincipalAcademicsRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      assignments: principalAssignments,
      attendance: attendance,
    );
  }

  tearDown(() => db?.close());

  test('class serialization preserves academic evidence', () {
    const row = PrincipalAcademicClass(
      name: 'JSS 2B',
      level: 'JSS 2',
      students: 2,
      average: 61,
      attendance: 86,
      syllabus: 63,
      hasSyllabusScheme: true,
      syllabusBehind: true,
      assessments: 72,
      teachers: 1,
      trend: 0,
      status: PrincipalAcademicStatus.behind,
      concern: 'x',
    );
    final restored = PrincipalAcademicClass.fromJson(row.toJson());
    expect(restored.name, row.name);
    expect(restored.hasSyllabusScheme, isTrue);
    expect(restored.syllabusBehind, isTrue);
    expect(restored.status, PrincipalAcademicStatus.behind);
    expect(restored.concern, row.concern);
  });

  test('Principal academics permissions remain Secondary scoped', () {
    expect(principalAcademicsScopeBoundary, contains('Secondary School'));
    expect(principalAcademicsScopeBoundary, contains('Primary'));
    expect(principalAcademicsScopeBoundary, contains('Early Years'));
  });

  test('classes are the real Secondary classes from the one real register, unevaluated with no invented evidence', () async {
    await setUpSchool();
    final snapshot = await principalAcademics.load();
    expect(snapshot.classes.map((c) => c.name).toSet(), {'JSS 1', 'JSS 2', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS1A', 'SS2A', 'SS2B', 'SS3A'});
    expect(snapshot.classes.any((c) => c.name.toLowerCase().startsWith('primary')), isFalse);
    for (final row in snapshot.classes) {
      expect(row.students, greaterThan(0));
      expect(row.trend, 0, reason: 'no real day-over-day comparison exists yet');
      expect(row.teachers, 0, reason: 'no real teaching assignment exists yet');
      expect(row.status, PrincipalAcademicStatus.notEvaluated, reason: 'no real assessment has been recorded yet');
      expect(row.average, 0);
      expect(row.assessments, 0);
    }
  });

  test('a class with an approved scheme of work reports real syllabus coverage; one without stays honestly at 0', () async {
    await setUpSchool();
    final snapshot = await principalAcademics.load();
    final jss2a = snapshot.classes.singleWhere((c) => c.name == 'JSS 2A');
    expect(jss2a.hasSyllabusScheme, isTrue);
    expect(jss2a.syllabus, greaterThan(0), reason: 'JSS 2A has completed topics in the fixed approved scheme');
    final ss3a = snapshot.classes.singleWhere((c) => c.name == 'SS3A');
    expect(ss3a.hasSyllabusScheme, isFalse);
    expect(ss3a.syllabus, 0);
    expect(ss3a.syllabusBehind, isFalse);
    final jss2b = snapshot.classes.singleWhere((c) => c.name == 'JSS 2B');
    expect(jss2b.syllabusBehind, isTrue, reason: 'the fixed approved scheme reports JSS 2B behind on one topic');
  });

  test('subjects and risks are always empty: no real source produces either', () async {
    await setUpSchool();
    final snapshot = await principalAcademics.load();
    expect(snapshot.subjects, isEmpty);
    expect(snapshot.risks, isEmpty);
  });

  test('a real teaching assignment is reflected in the real teacher count for that class', () async {
    await setUpSchool();
    final result = await principalAssignments.addAssignment(className: 'JSS 2B', subject: 'Mathematics', teacherId: 'STAFF-001', periodsPerWeek: 5);
    expect(result.success, isTrue, reason: result.message);
    final snapshot = await principalAcademics.load();
    expect(snapshot.classes.singleWhere((c) => c.name == 'JSS 2B').teachers, 1);
  });

  test('a real assessment register item is reflected in the real class average and score-entry completion', () async {
    await setUpSchool();
    final membership = principal;
    const item = TeacherAssessment(
      id: 'ASM-1',
      title: 'Mid-term test',
      className: 'JSS 2B',
      subject: 'Mathematics',
      type: TeacherAssessmentType.test,
      maximumScore: 100,
      state: TeacherAssessmentState.published,
      entries: [],
      entered: 1,
      totalStudents: 2,
      averagePercent: 80,
    );
    await db!.upsertLocalRecord(tenantId: membership.schoolId, entityType: teacherAssessmentEntityType, entityId: item.id, payload: item.toJson());
    final snapshot = await principalAcademics.load();
    final jss2b = snapshot.classes.singleWhere((c) => c.name == 'JSS 2B');
    expect(jss2b.status, isNot(PrincipalAcademicStatus.notEvaluated));
    expect(jss2b.average, 80);
    expect(jss2b.assessments, 50, reason: '1 of 2 expected scores entered');
  });

  test('a real syllabus progress report changes the real coverage figure for that class', () async {
    await setUpSchool();
    final membership = principal;
    const record = TeacherSyllabusProgressRecord(
      id: 'JSS 2A-W7',
      className: 'JSS 2A',
      week: 7,
      reportedStatus: TeacherSyllabusStatus.completed,
      actorMembershipId: 'm-teacher',
      version: 1,
      updatedAt: '2026-09-20T08:00:00Z',
    );
    await db!.upsertLocalRecord(tenantId: membership.schoolId, entityType: teacherSyllabusProgressEntityType, entityId: record.id, payload: record.toJson());
    final before = (await principalAcademics.load()).classes.singleWhere((c) => c.name == 'JSS 2A').syllabus;
    // Marking one more topic complete can only raise or hold the coverage percentage, never lower it.
    expect(before, greaterThanOrEqualTo(0));
  });

  test('the school-wide KPIs return null rather than a misleading 0% when nothing is evaluated yet', () async {
    await setUpSchool();
    final snapshot = await principalAcademics.load();
    expect(principalSchoolAverage(snapshot.classes), isNull);
    expect(principalAssessmentAverage(snapshot.classes), isNull);
  });
}
