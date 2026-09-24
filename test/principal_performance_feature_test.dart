import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_academics_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_incidents_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_performance_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_incidents_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart' show teacherAssessmentEntityType;
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalPerformanceRepository performance;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    final assignments = PrincipalAssignmentsRepository(
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
    final academics = PrincipalAcademicsRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      assignments: assignments,
      attendance: attendance,
    );
    final incidents = PrincipalIncidentsRepository(localDatabase: database, schoolSession: session);
    performance = PrincipalPerformanceRepository(
      localDatabase: database,
      schoolSession: session,
      academics: academics,
      attendance: attendance,
      incidents: incidents,
      staff: OwnerStaffProfileRepository(database: database, session: session),
    );
  }

  tearDown(() => db?.close());

  test('a fresh demo school only shows evidence for indicators with an always-real source', () async {
    await setUpSchool();
    final snapshot = await performance.load();
    // Student/teacher attendance and syllabus coverage are already backed by real deterministic
    // demo data (today's gate scans, a default staff attendance record, the fixed approved
    // scheme's baked-in progress) the same way other Principal screens already treat as real.
    // Academic average, assessment completion and resolved incidents have no evidence until a
    // teacher or the principal actually records something, so they stay honestly unevaluated.
    const alwaysReal = {'Student attendance', 'Teacher attendance', 'Syllabus coverage'};
    expect(snapshot.overallHealth, isNotNull);
    expect(snapshot.evaluatedIndicators, alwaysReal.length);
    expect(snapshot.priorities, isEmpty, reason: 'flagging a real priority needs human judgement nothing in the app produces automatically');
    for (final metric in snapshot.metrics) {
      expect(metric.hasEvidence, alwaysReal.contains(metric.label), reason: metric.label);
    }
  });

  test('class health lists every real Secondary class with no invented score', () async {
    await setUpSchool();
    final snapshot = await performance.load();
    expect(snapshot.classHealth.map((c) => c.className).toSet(), {'JSS 1', 'JSS 2', 'JSS 2A', 'JSS 2B', 'JSS 3A', 'SS1A', 'SS2A', 'SS2B', 'SS3A'});
    for (final row in snapshot.classHealth) {
      expect(row.average, isNull);
      expect(row.attendance, inInclusiveRange(0, 100));
    }
  });

  test('a real assessment record raises the real academic-average metric and its class row', () async {
    await setUpSchool();
    const item = TeacherAssessment(
      id: 'ASM-1',
      title: 'Mid-term test',
      className: 'JSS 2B',
      subject: 'Mathematics',
      type: TeacherAssessmentType.test,
      maximumScore: 100,
      state: TeacherAssessmentState.published,
      entries: [],
      entered: 2,
      totalStudents: 2,
      averagePercent: 80,
    );
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: teacherAssessmentEntityType, entityId: item.id, payload: item.toJson());
    final snapshot = await performance.load();
    final metric = snapshot.metrics.firstWhere((m) => m.label == 'Academic average');
    expect(metric.hasEvidence, isTrue);
    expect(metric.current, 80);
    expect(snapshot.classHealth.firstWhere((c) => c.className == 'JSS 2B').average, 80);
  });

  test('real recorded incidents raise the real resolved-incidents metric', () async {
    await setUpSchool();
    Future<void> record(String id, PrincipalIncidentStatus status) => db!.upsertLocalRecord(
          tenantId: principal.schoolId,
          entityType: 'principal_recorded_incident_case',
          entityId: id,
          payload: PrincipalIncident(
            id: id,
            title: 'Recorded concern',
            category: PrincipalIncidentCategory.property,
            severity: PrincipalIncidentSeverity.low,
            status: status,
            person: 'Reported by staff',
            context: 'JSS 2A',
            reportedBy: principal.id,
            owner: principal.id,
            reportedAt: '2026-09-22',
            location: 'Classroom',
            guardianContact: PrincipalGuardianContact.notRequired,
            evidenceCount: 0,
            summary: 'A staff-entered report.',
            nextAction: 'Review evidence',
          ).toJson(),
        );
    await record('case-1', PrincipalIncidentStatus.resolved);
    await record('case-2', PrincipalIncidentStatus.open);
    final snapshot = await performance.load();
    final metric = snapshot.metrics.firstWhere((m) => m.label == 'Resolved incidents');
    expect(metric.hasEvidence, isTrue);
    expect(metric.current, 50);
  });

  test('a non-principal membership sees a fully empty scorecard', () async {
    await setUpSchool(teacher);
    final snapshot = await performance.load();
    expect(snapshot.metrics, isEmpty);
    expect(snapshot.classHealth, isEmpty);
    expect(snapshot.priorities, isEmpty);
  });
}
