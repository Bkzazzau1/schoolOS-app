import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_ai_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_ai_models.dart';
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
  late TeacherAiRepository ai;

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
    ai = TeacherAiRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('working contexts are limited to the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await ai.load();
    // JSS 3A Mathematics is not offered: this teacher isn't assigned JSS 3A.
    expect(snapshot.contextOptions, [
      TeacherAiContext.jss2aMathematics,
      TeacherAiContext.jss2bMathematics,
      TeacherAiContext.ss1aFurtherMathematics,
    ]);
  });

  test('a teacher with no assigned classes sees no working contexts, not a crash', () async {
    await setUpSchool(newTeacher);
    final snapshot = await ai.load();
    expect(snapshot.contextOptions, isEmpty);
  });

  test('asking with a context outside the real assignment is refused', () async {
    await setUpSchool(mathsTeacher);
    final result = await ai.ask(context: TeacherAiContext.jss3aMathematics, prompt: 'Plan a revision lesson');
    expect(result.success, isFalse);
    expect(result.response, contains('not one of your assigned classes'));
  });

  test('a real prompt is written even once a real backend is configured (it is real data, not a seed)', () async {
    await setUpSchool(mathsTeacher);
    // Prime the demo class assignment before a real backend is configured, exactly as load() already does
    // on first use; a real school would have this assigned by the owner/administrator instead.
    await roster.assignedClasses(mathsTeacher);
    LocalDatabase.blockDemoSeeds = true;
    try {
      final result = await ai.ask(context: TeacherAiContext.jss2aMathematics, prompt: 'Plan a revision lesson');
      expect(result.success, isTrue, reason: result.response);
      final snapshot = await ai.load();
      expect(snapshot.history.any((h) => h.prompt == 'Plan a revision lesson'), isTrue,
          reason: 'a real, teacher-authored prompt must not be silently dropped by the demo-seed guard');
    } finally {
      LocalDatabase.blockDemoSeeds = false;
    }
  });
}
