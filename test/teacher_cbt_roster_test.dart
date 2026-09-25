import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_cbt_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A and JSS 2B assigned (both Mathematics) in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has only Primary 3/4 assigned, so no JSS test belongs to them.
const primaryTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

const _question = TeacherCbtQuestion(id: 'Q1', prompt: 'What is 2 + 2?', options: ['3', '4', '5'], correctIndex: 1);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherCbtRepository cbt;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, primaryTeacher]);
    await session.selectSchool(who);
    roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    cbt = TeacherCbtRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('a fresh session starts with an empty draft for the teacher\'s real assigned classes, not a fabricated test', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    expect(snapshot.tests, isEmpty);
    expect(snapshot.options.map((o) => '${o.className} · ${o.subject}'), ['JSS 2A · Mathematics', 'JSS 2B · Mathematics']);
    expect(snapshot.draft.className, 'JSS 2A');
    expect(snapshot.draft.state, TeacherCbtTestState.draft);
  });

  test('a teacher with no JSS classes sees honestly empty options, not a crash', () async {
    await setUpSchool(primaryTeacher);
    final snapshot = await cbt.load();
    expect(snapshot.tests, isEmpty);
    expect(snapshot.options.map((o) => o.className), ['Primary 3', 'Primary 4']);
  });

  test('a blank title is refused', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    final result = await cbt.saveDraft(snapshot.draft);
    expect(result.success, isFalse);
    expect(result.message, contains('Enter a title'));
  });

  test('saving a valid draft adds it to the library and queues a sync mutation', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    final result = await cbt.saveDraft(snapshot.draft.copyWith(title: 'Week 9 Practice'));
    expect(result.success, isTrue, reason: result.message);
    expect(result.test!.state, TeacherCbtTestState.draft);

    final reloaded = await cbt.load();
    expect(reloaded.draft.id, result.test!.id);
    expect(reloaded.draft.title, 'Week 9 Practice');
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });

  test('publishing an empty draft is refused: a test needs at least one real question first', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    final refused = await cbt.publish(snapshot.draft.copyWith(title: 'Week 9 Practice'));
    expect(refused.success, isFalse);
    expect(refused.message, contains('Every question needs'));
  });

  test('publishing a draft with a real question births one attempt per real, active roster student', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    final draft = snapshot.draft.copyWith(title: 'Week 9 Practice', questions: const [_question]);
    final published = await cbt.publish(draft);
    expect(published.success, isTrue, reason: published.message);
    expect(published.test!.state, TeacherCbtTestState.published);

    final classRoster = await roster.studentsIn('JSS 2A');
    expect(classRoster, isNotEmpty);
    expect(published.test!.totalRecipients, classRoster.length);
  });

  test('a draft cannot be closed, only a published test can', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    final draft = snapshot.draft.copyWith(title: 'Week 9 Practice', questions: const [_question]);
    final refused = await cbt.close(draft);
    expect(refused.success, isFalse);

    final published = await cbt.publish(draft);
    final closed = await cbt.close(published.test!);
    expect(closed.success, isTrue, reason: closed.message);
    expect(closed.test!.state, TeacherCbtTestState.closed);
  });
}
