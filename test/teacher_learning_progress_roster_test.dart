import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_learning_progress_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has no demo class assignment at all.
const newTeacher = SchoolMembership(id: 'm-new-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherLearningProgressRepository learningProgress;

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
    learningProgress = TeacherLearningProgressRepository(schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('students are the real, deduplicated roster across all assigned classes, with no invented evidence', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await learningProgress.load();
    final expectedIds = <String>{};
    for (final c in await roster.assignedClasses()) {
      for (final s in await roster.studentsIn(c.className)) {
        expectedIds.add(s.id);
      }
    }
    expect(snapshot.students.map((s) => s.id).toSet(), expectedIds);
    expect(snapshot.students.length, expectedIds.length, reason: 'no duplicates across subjects taught to the same class');
    expect(snapshot.classOptions, ['JSS 2A', 'JSS 2B', 'SS1A']);
    for (final student in snapshot.students) {
      expect(student.average, 0);
      expect(student.attendance, 0);
      expect(student.topics, isEmpty, reason: 'no module yet produces topic-tagged evidence to combine');
    }
  });

  test('a teacher with no assigned classes sees an honest empty list, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await learningProgress.load();
    expect(snapshot.students, isEmpty);
    expect(snapshot.classOptions, isEmpty);
  });

  test('the subject shown for each student comes from the teacher\'s real class assignment', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await learningProgress.load();
    for (final student in snapshot.students) {
      expect(student.subject, isNotEmpty);
    }
    final jss2a = snapshot.students.firstWhere((s) => s.className == 'JSS 2A');
    expect(jss2a.subject, 'Mathematics');
  });
}
