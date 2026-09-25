import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_academics_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_approvals_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_assignments_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_attendance_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_dashboard_demo_data.dart';
import 'package:schoolos_app/features/principal/data/principal_dashboard_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_incidents_repository.dart';
import 'package:schoolos_app/features/principal/data/principal_teachers_repository.dart';
import 'package:schoolos_app/features/principal/domain/principal_approvals_models.dart' show PrincipalApprovalStatus;
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_lesson_plan_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const principal = SchoolMembership(id: 'm-principal', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.principal);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late PrincipalDashboardRepository dashboard;
  late PrincipalApprovalsRepository approvals;

  Future<void> setUpSchool([SchoolMembership who = principal]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([principal, teacher]);
    await session.selectSchool(who);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    final staff = OwnerStaffProfileRepository(database: database, session: session);
    final assignments = PrincipalAssignmentsRepository(localDatabase: database, schoolSession: session, students: students, staff: staff);
    final attendance = PrincipalAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
    );
    final academics = PrincipalAcademicsRepository(localDatabase: database, schoolSession: session, students: students, assignments: assignments, attendance: attendance);
    final teachers = PrincipalTeachersRepository(localDatabase: database, schoolSession: session, staff: staff);
    approvals = PrincipalApprovalsRepository(localDatabase: database, schoolSession: session);
    final incidents = PrincipalIncidentsRepository(localDatabase: database, schoolSession: session);
    dashboard = PrincipalDashboardRepository(
      localDatabase: database,
      schoolSession: session,
      academics: academics,
      attendance: attendance,
      teachers: teachers,
      approvals: approvals,
      incidents: incidents,
      staff: staff,
    );
  }

  tearDown(() => db?.close());

  test('principal workspace preserves every real website destination', () {
    expect(principalNavigation.length, 20);
    expect(principalNavigation.map((item) => item.label).toList(), [
      'Dashboard',
      'Teachers',
      'Staff Profiles',
      'Teaching Assignments',
      'Class Teachers',
      'Academics',
      'Students',
      'Attendance',
      'Approvals',
      'Results & Reports',
      'Timetable',
      'Excursions',
      'Media Gallery',
      'Alumni Management',
      'Communication',
      'Incidents',
      'Principal AI',
      'School Performance',
      'Profile',
      'Community',
    ]);
  });

  test('a fresh demo school has honest KPIs: real attendance, everything else at zero, no invented totals', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.kpis.map((k) => k.label), [
      'Secondary students present',
      'Secondary teachers present',
      'Pending approvals',
      'Classes on track',
      'Open incidents',
    ]);
    final teacherPresence = snapshot.kpis.firstWhere((k) => k.label == 'Secondary teachers present');
    // A default staff attendance record already exists in the demo (see Performance's own
    // fresh-school test), so this is real and non-null from the start.
    expect(teacherPresence.value, isNot('Not recorded'));
    final pending = snapshot.kpis.firstWhere((k) => k.label == 'Pending approvals');
    expect(pending.value, '0');
    final incidents = snapshot.kpis.firstWhere((k) => k.label == 'Open incidents');
    expect(incidents.value, '0');
  });

  test('approval queue, alerts and activity are honestly empty in a fresh demo school', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.approvals, isEmpty);
    expect(snapshot.alerts, isEmpty, reason: 'flagging a real alert needs human judgement nothing in the app infers automatically');
    expect(snapshot.activity, isEmpty);
  });

  test('teacher and class indicators are the real Secondary register, honestly zeroed', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.teachers.map((t) => t.name).toSet(), {'Mrs. Amina Yusuf', 'Mr. Ahmad Sani'});
    for (final t in snapshot.teachers) {
      expect(t.compliance, 0);
      expect(t.status, 'Not evaluated');
    }
    expect(snapshot.classes, isNotEmpty);
    expect(snapshot.classes.any((c) => c.name.toLowerCase().startsWith('primary')), isFalse);
  });

  test('a real teacher submission appears in the real approval queue and real activity feed', () async {
    await setUpSchool();
    final plan = TeacherLessonPlan(id: 'PLAN-1', className: 'JSS 2A', week: 'Week 1', topic: 'Fractions', status: TeacherLessonPlanStatus.submitted, updatedLabel: 'Just now');
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan', entityId: plan.id, payload: plan.toJson());
    final event = TeacherLessonPlanEvent(id: 'EVT-1', planId: plan.id, action: TeacherLessonPlanEventAction.submitted, actorMembershipId: 'm-teacher', version: 1, occurredAt: '2020-01-01T00:00:00Z');
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan_event', entityId: event.id, payload: event.toJson());

    final snapshot = await dashboard.load();
    expect(snapshot.approvals.single.type, 'Lesson Plan');
    expect(snapshot.approvals.single.title, contains('Fractions'));
    expect(snapshot.kpis.firstWhere((k) => k.label == 'Pending approvals').value, '1');
    expect(snapshot.activity, isNotEmpty);
    expect(snapshot.activity.first.action, contains('submitted'));
  });

  test('a real approval decision appears in real activity too', () async {
    await setUpSchool();
    final plan = TeacherLessonPlan(id: 'PLAN-1', className: 'JSS 2A', week: 'Week 1', topic: 'Fractions', status: TeacherLessonPlanStatus.submitted, updatedLabel: 'Just now');
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan', entityId: plan.id, payload: plan.toJson());
    final event = TeacherLessonPlanEvent(id: 'EVT-1', planId: plan.id, action: TeacherLessonPlanEventAction.submitted, actorMembershipId: 'm-teacher', version: 1, occurredAt: '2020-01-01T00:00:00Z');
    await db!.upsertLocalRecord(tenantId: principal.schoolId, entityType: 'teacher_lesson_plan_event', entityId: event.id, payload: event.toJson());
    final decision = await approvals.decide(approvalId: 'teacher_lesson_plan:PLAN-1:v1', status: PrincipalApprovalStatus.approved, comment: 'Looks good.');
    expect(decision.success, isTrue, reason: decision.message);

    final snapshot = await dashboard.load();
    expect(snapshot.approvals, isEmpty, reason: 'the submission is no longer pending');
    expect(snapshot.activity.any((a) => a.action.contains('Approved')), isTrue);
  });

  test('principal authority is Secondary-scoped rather than whole-school governance', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.permissions.canLeadSecondary, isTrue);
    expect(snapshot.permissions.canApproveAcademicWork, isTrue);
    expect(snapshot.permissions.canGovernWholeSchool, isFalse);
    expect(snapshot.permissions.canLeadPrimary, isFalse);
    expect(principalScopeBoundary, contains('Secondary School'));
    expect(principalScopeBoundary, contains('Proprietor-wide'));
  });

  test('a non-principal membership sees a fully empty dashboard', () async {
    await setUpSchool(teacher);
    final snapshot = await dashboard.load();
    expect(snapshot.kpis, isEmpty);
    expect(snapshot.teachers, isEmpty);
    expect(snapshot.classes, isEmpty);
  });

  test('principal remains a serializable first-class membership role', () {
    const membership = SchoolMembership(
      id: 'membership-principal-001',
      schoolId: 'school-brightgate',
      schoolName: 'BrightGate Academy',
      role: SchoolRole.principal,
    );
    final restored = SchoolMembership.fromJson(membership.toJson());
    expect(restored.role, SchoolRole.principal);
    expect(restored.roleLabel, 'Principal');
  });
}
