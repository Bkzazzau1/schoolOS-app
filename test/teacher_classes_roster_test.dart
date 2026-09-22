import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_attendance_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_classes_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_attendance_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const teacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherClassesRepository classes;
  late TeacherAttendanceRepository attendance;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher, owner]);
    await session.selectSchool(teacher);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    classes = TeacherClassesRepository(localDatabase: db, schoolSession: session, roster: roster);
    attendance = TeacherAttendanceRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('My Classes lists the assigned classes with the real student count', () async {
    await setUpSchool();
    final snapshot = await classes.load();
    expect(snapshot.assignments.map((a) => a.name), containsAll(['JSS 2A', 'JSS 2B', 'SS1A']));
    final jss2b = snapshot.assignments.firstWhere((a) => a.name == 'JSS 2B');
    expect(jss2b.students, (await roster.studentsIn('JSS 2B')).length);
    expect(jss2b.students, greaterThan(0));
    expect(snapshot.totalStudents, snapshot.assignments.fold<int>(0, (n, a) => n + a.students));
  });

  test('a class with no attendance taken yet shows 0%, and one with a register shows the real rate', () async {
    await setUpSchool();
    final before = (await classes.load()).assignments.firstWhere((a) => a.name == 'JSS 2A');
    expect(before.attendance, 0);

    final register = (await attendance.load()).registers.firstWhere((r) => r.lesson.className == 'JSS 2A');
    await attendance.setStatus(lessonId: register.lesson.id, studentId: register.entries.first.studentId, status: TeacherAttendanceStatus.absent);

    final after = (await classes.load()).assignments.firstWhere((a) => a.name == 'JSS 2A');
    final expected = (await attendance.load()).registers.firstWhere((r) => r.lesson.className == 'JSS 2A').presentPercent;
    expect(after.attendance, expected);
    expect(after.attendance, lessThan(100));
  });

  test('a class with no students on the register yet is still listed, with zero students', () async {
    await setUpSchool();
    await session.selectSchool(owner);
    await roster.assign(teacher, const [AssignedClass(className: 'No Such Class', subject: 'Civics')]);
    await session.selectSchool(teacher);
    final row = (await classes.load()).assignments.single;
    expect(row.name, 'No Such Class');
    expect(row.students, 0);
  });
}
