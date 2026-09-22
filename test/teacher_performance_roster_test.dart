import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_performance_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data (not JSS 3A).
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherPerformanceRepository performance;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, newTeacher]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    performance = TeacherPerformanceRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('class outcomes only show the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await performance.load();
    // The sample outcomes include JSS 3A, which this teacher is not assigned to.
    expect(snapshot.classPerformance.map((c) => c.name).toSet(), {'JSS 2A', 'JSS 2B', 'SS1A'});
  });

  test('a teacher with no assigned classes sees an honest empty list, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await performance.load();
    expect(snapshot.classPerformance, isEmpty);
  });

  test('a private reflection is written even once a real backend is configured (it is real data, not a seed)', () async {
    await setUpSchool(mathsTeacher);
    LocalDatabase.blockDemoSeeds = true;
    try {
      final result = await performance.addPrivateReflection('Focus more on JSS 2B pacing next week.');
      expect(result.success, isTrue, reason: result.message);
      final snapshot = await performance.load();
      expect(snapshot.reflections, hasLength(1), reason: 'a real, teacher-authored reflection must not be silently dropped by the demo-seed guard');
      expect(snapshot.reflections.first.body, 'Focus more on JSS 2B pacing next week.');
    } finally {
      LocalDatabase.blockDemoSeeds = false;
    }
  });
}
