import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_attendance_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_attendance_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const teacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
const otherTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherAttendanceRepository attendance;

  Future<void> setUpSchool([SchoolMembership who = teacher]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher, otherTeacher, owner]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    attendance = TeacherAttendanceRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  /// Switches which membership is signed in, on the same school (so records already saved are kept).
  Future<void> signInAs(SchoolMembership who) async {
    await session.selectSchool(who);
  }

  tearDown(() => db.close());

  test('a demo teacher starts with their sample classes, and a teacher with none has an empty roster', () async {
    await setUpSchool();
    final classes = await roster.assignedClasses();
    expect(classes.map((c) => c.className), containsAll(['JSS 2A', 'JSS 2B', 'SS1A']));

    await setUpSchool(otherTeacher);
    expect((await roster.assignedClasses()).map((c) => c.className), containsAll(['Primary 3', 'Primary 4']));
  });

  test('students in a class come from the real register, and a student who left is not listed', () async {
    await setUpSchool();
    final students = await roster.studentsIn('JSS 2B');
    expect(students, isNotEmpty);
    expect(students.every((s) => s.className == 'JSS 2B'), isTrue);
    expect(students, everyElement(isNot(predicate<dynamic>((s) => s.status.toString().contains('transferredOut')))));
  });

  test('the owner can assign classes to a teacher; a teacher cannot assign their own', () async {
    await setUpSchool();
    final refused = await roster.assign(teacher, const [AssignedClass(className: 'Primary 5', subject: 'English')]);
    expect(refused, contains('owner'));

    await signInAs(owner);
    final ok = await roster.assign(teacher, const [AssignedClass(className: 'Primary 5', subject: 'English')]);
    expect(ok, isNull);
    await signInAs(teacher);
    expect((await roster.assignedClasses()).single.className, 'Primary 5');
    expect(db.pendingCount(tenantId: teacher.schoolId), greaterThan(0));
  });

  test('attendance has one register per assigned class, with the real students in it, all present at the start', () async {
    await setUpSchool();
    final snapshot = await attendance.load();
    expect(snapshot.registers.length, 3);
    final jss2b = snapshot.registers.firstWhere((r) => r.lesson.className == 'JSS 2B');
    final real = await roster.studentsIn('JSS 2B');
    expect(jss2b.entries.length, real.length);
    expect(jss2b.entries.every((e) => e.status == TeacherAttendanceStatus.present), isTrue);
    expect(jss2b.entries.map((e) => e.code), containsAll(real.map((s) => s.name)));
  });

  test('marking a student absent and submitting is saved and queued, and a submitted register is locked', () async {
    await setUpSchool();
    final lessonId = (await attendance.load()).registers.first.lesson.id;
    final entries = (await attendance.load()).registers.first.entries;
    final result = await attendance.setStatus(lessonId: lessonId, studentId: entries.first.studentId, status: TeacherAttendanceStatus.absent);
    expect(result.success, isTrue);

    final submitted = await attendance.submit(lessonId: lessonId);
    expect(submitted.success, isTrue);
    expect(submitted.register!.submissionState, TeacherAttendanceSubmissionState.submitted);
    expect(db.pendingCount(tenantId: teacher.schoolId), greaterThan(0));

    final locked = await attendance.setStatus(lessonId: lessonId, studentId: entries.first.studentId, status: TeacherAttendanceStatus.late);
    expect(locked.success, isFalse);
    expect(locked.message, contains('locked'));
  });

  test('a newly assigned class gets a fresh register without touching the others', () async {
    await setUpSchool();
    await signInAs(owner);
    await roster.assign(teacher, const [AssignedClass(className: 'JSS 2A', subject: 'Mathematics'), AssignedClass(className: 'Primary 5', subject: 'English')]);
    await signInAs(teacher);
    final lessonId = (await attendance.load()).registers.firstWhere((r) => r.lesson.className == 'JSS 2A').lesson.id;
    await attendance.setStatus(lessonId: lessonId, studentId: (await roster.studentsIn('JSS 2A')).first.id, status: TeacherAttendanceStatus.late);

    await signInAs(owner);
    await roster.assign(teacher, const [
      AssignedClass(className: 'JSS 2A', subject: 'Mathematics'),
      AssignedClass(className: 'Primary 5', subject: 'English'),
      AssignedClass(className: 'JSS 2B', subject: 'Mathematics'),
    ]);
    await signInAs(teacher);
    final snapshot = await attendance.load();
    expect(snapshot.registers.length, 3);
    final jss2a = snapshot.registers.firstWhere((r) => r.lesson.className == 'JSS 2A');
    expect(jss2a.entries.any((e) => e.status == TeacherAttendanceStatus.late), isTrue, reason: 'the existing register is kept');
  });
}
