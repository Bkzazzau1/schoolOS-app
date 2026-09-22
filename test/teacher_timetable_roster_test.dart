import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/data/teacher_timetable_repository.dart';
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
  late TeacherTimetableRepository timetable;

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
    timetable = TeacherTimetableRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('the timetable only shows lessons for the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await timetable.load();
    // The sample schedule includes JSS 3A lessons, which this teacher is not assigned to.
    expect(snapshot.lessons.any((l) => l.className == 'JSS 3A'), isFalse);
    expect(snapshot.lessons.map((l) => l.className).toSet(), {'JSS 2A', 'JSS 2B', 'SS1A'});
  });

  test('a teacher with no assigned classes sees an honest empty timetable, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await timetable.load();
    expect(snapshot.lessons, isEmpty);
    expect(snapshot.lessonsForDay('Monday'), isEmpty);
  });

  test('requesting a timetable change queues a real, syncable intent', () async {
    await setUpSchool(mathsTeacher);
    final result = await timetable.requestChange();
    expect(result.success, isTrue, reason: result.message);
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
    final snapshot = await timetable.load();
    expect(snapshot.intents, hasLength(1));
  });
}
