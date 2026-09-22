import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/data/teacher_students_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_students_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const teacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherStudentsRepository students;

  Future<void> setUpSchool([SchoolMembership who = teacher]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher, newTeacher, owner]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    students = TeacherStudentsRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('the students list is the real students in the real assigned classes, deduplicated, nothing invented', () async {
    await setUpSchool();
    final snapshot = await students.load();
    final expectedIds = <String>{};
    for (final c in await roster.assignedClasses()) {
      for (final s in await roster.studentsIn(c.className)) {
        expectedIds.add(s.id);
      }
    }
    expect(snapshot.students.map((s) => s.id).toSet(), expectedIds);
    expect(snapshot.students.length, expectedIds.length, reason: 'no duplicates even though the teacher teaches two subjects to some of these classes');
    for (final s in snapshot.students) {
      expect(s.average, 0);
      expect(s.attendance, 0);
      expect(s.trend, 0);
      expect(s.risk, TeacherStudentRisk.stable, reason: 'nobody is given an alarming label from nothing');
      expect(s.attention, contains('No assessment or attendance history'));
    }
  });

  test('a teacher with no assigned classes gets an empty, honest list rather than a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await students.load();
    expect(snapshot.students, isEmpty);
    expect(snapshot.profiles, isEmpty);
  });

  test('the profile view uses the real name, class and status, with empty evidence rather than invented evidence', () async {
    await setUpSchool();
    final snapshot = await students.load();
    final first = snapshot.students.first;
    final profile = snapshot.profiles[first.id]!;
    expect(profile.name, first.name);
    expect(profile.className, first.className);
    expect(profile.status, 'Active');
    expect(profile.subjects, isEmpty);
    expect(profile.attendanceSummary, isEmpty);
    expect(profile.timeline, isEmpty);
  });

  test('a note can only be saved for a student really in the teacher\'s classes, and round-trips', () async {
    await setUpSchool();
    final real = (await students.load()).students.first;
    final refused = await students.saveNote(studentId: 'not-a-real-student', text: 'Hello');
    expect(refused.success, isFalse);
    expect(refused.message, contains('not in the teacher-assigned roster'));

    final saved = await students.saveNote(studentId: real.id, text: 'Doing well with fractions.');
    expect(saved.success, isTrue, reason: saved.message);
    final after = await students.load();
    expect(after.notes[real.id]!.text, 'Doing well with fractions.');
    expect(db.pendingCount(tenantId: teacher.schoolId), greaterThan(0));
  });
}
