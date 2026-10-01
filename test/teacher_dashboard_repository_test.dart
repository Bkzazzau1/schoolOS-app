import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_dashboard_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

// Has JSS 2A and JSS 2B assigned in TeacherRoster's own demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-dashboard-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherDashboardRepository dashboard;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher]);
    await session.selectSchool(who);
    await seedClassicRoster(db, tenantId: who.schoolId);
    final roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    dashboard = TeacherDashboardRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('a teacher with no assigned class sees an honestly empty dashboard, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await dashboard.load();
    expect(snapshot.classes, isEmpty);
    expect(snapshot.todaySchedule, isEmpty);
    expect(snapshot.students, isEmpty);
    expect(snapshot.displayName, 'Teacher');
    for (final kpi in snapshot.kpis) {
      expect(kpi.value, anyOf('0', '0%'), reason: kpi.label);
    }
  });

  test('a teacher with real assigned classes sees a real class list and student count', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await dashboard.load();
    expect(snapshot.classes.map((c) => c.name).toSet(), {'JSS 2A', 'JSS 2B'});
    expect(snapshot.students, isNotEmpty);
    expect(snapshot.students.every((s) => s.className == 'JSS 2A' || s.className == 'JSS 2B'), isTrue);

    final classesKpi = snapshot.kpis.firstWhere((k) => k.label == 'Classes assigned');
    expect(classesKpi.value, '2');
  });
}
