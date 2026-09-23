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

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has only Primary 3/4 assigned, so none of the sample JSS practice sets belong to them.
const primaryTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

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

  test('practice sets are filtered to the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await cbt.load();
    expect(snapshot.sets, isNotEmpty);
    expect(snapshot.sets.every((s) => s.className == 'JSS 2A' || s.className == 'JSS 2B'), isTrue);
    expect(snapshot.classOptions, ['JSS 2A', 'JSS 2B', 'SS1A']);
  });

  test('a teacher with no assigned classes sees an honest empty set list, not a crash', () async {
    await setUpSchool(primaryTeacher);
    final snapshot = await cbt.load();
    expect(snapshot.sets, isEmpty);
    expect(snapshot.classOptions, ['Primary 3', 'Primary 4']);
  });

  test('a new draft can only be created for a real assigned class, with no invented attempts', () async {
    await setUpSchool(mathsTeacher);
    final refused = await cbt.createDraft(className: 'JSS 3A', title: 'Week 9 Practice');
    expect(refused.success, isFalse);
    expect(refused.message, contains('not assigned to this class'));

    final result = await cbt.createDraft(className: 'SS1A', title: 'Week 9 Practice');
    expect(result.success, isTrue, reason: result.message);
    expect(result.set!.className, 'SS1A');
    expect(result.set!.attempts, 0);
    expect(result.set!.averageAccuracy, 0);
    expect(result.set!.state, TeacherCbtSetState.draft);

    final snapshot = await cbt.load();
    expect(snapshot.sets.any((s) => s.id == result.set!.id), isTrue);
  });

  test('a blank title is refused', () async {
    await setUpSchool(mathsTeacher);
    final result = await cbt.createDraft(className: 'JSS 2A', title: '   ');
    expect(result.success, isFalse);
  });

  test('saving a draft for a class the teacher is no longer assigned to is refused', () async {
    await setUpSchool(mathsTeacher);
    final created = await cbt.createDraft(className: 'JSS 2A', title: 'Week 9 Practice');
    final foreign = created.set!.copyWith(className: 'JSS 3A');
    final result = await cbt.saveDraft(foreign);
    expect(result.success, isFalse);
    expect(result.message, contains('not one of your assigned classes'));
  });

  test('publishing an empty draft is refused: a set needs real questions first', () async {
    await setUpSchool(mathsTeacher);
    final created = await cbt.createDraft(className: 'JSS 2A', title: 'Week 9 Practice');
    final refused = await cbt.queuePublication(created.set!);
    expect(refused.success, isFalse);
    expect(refused.message, contains('at least one real question'));
  });

  test('publishing a draft with real questions queues the set and queues a sync mutation', () async {
    await setUpSchool(mathsTeacher);
    final created = await cbt.createDraft(className: 'JSS 2A', title: 'Week 9 Practice');
    final withQuestion = created.set!.copyWith(items: const [
      TeacherCbtQuestion(id: 'Q1', prompt: 'What is 2 + 2?', options: ['3', '4', '5'], correctIndex: 1),
    ]);
    final published = await cbt.queuePublication(withQuestion);
    expect(published.success, isTrue, reason: published.message);
    expect(published.set!.state, TeacherCbtSetState.queuedForPublication);
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });
}
