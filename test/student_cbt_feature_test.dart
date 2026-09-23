import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/student/data/student_cbt_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_cbt_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_cbt_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const student = SchoolMembership(id: 'membership-student-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.student);
const accountant = SchoolMembership(id: 'm-accountant', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late StudentCbtRepository studentCbt;
  late TeacherCbtRepository teacherCbt;
  late DateTime now;

  Future<void> setUpSchool() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([mathsTeacher, student, accountant]);
    await session.selectSchool(student);
    now = DateTime(2026, 9, 22, 9);
    studentCbt = StudentCbtRepository(localDatabase: database, schoolSession: session, now: () => now);
    final roster = TeacherRoster(
      database: database,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
    );
    teacherCbt = TeacherCbtRepository(localDatabase: database, schoolSession: session, roster: roster);
  }

  /// Publishes a brand-new real CBT with real questions for [className], acting as the real teacher.
  Future<TeacherCbtPracticeSet> publishRealSet({
    required String className,
    required List<TeacherCbtQuestion> questions,
    int durationMinutes = 10,
  }) async {
    await session.selectSchool(mathsTeacher);
    final created = await teacherCbt.createDraft(className: className, title: 'Test set');
    expect(created.success, isTrue, reason: created.message);
    final withQuestions = created.set!.copyWith(items: questions, durationMinutes: durationMinutes);
    final published = await teacherCbt.queuePublication(withQuestions);
    expect(published.success, isTrue, reason: published.message);
    // A real teacher's set only reaches students once the server confirms publication; simulate that
    // confirmation directly on the record the same way `_seedIfNeeded`'s own seed sets do
    // (`publishedAt: 'server-confirmed'`), since this test is about the student pipeline, not sync.
    final confirmed = published.set!.copyWith(state: TeacherCbtSetState.published, publishedAt: 'server-confirmed');
    await db!.upsertLocalRecord(
      tenantId: mathsTeacher.schoolId,
      entityType: teacherCbtPracticeSetEntityType,
      entityId: confirmed.id,
      payload: confirmed.toJson(),
    );
    await session.selectSchool(student);
    return confirmed;
  }

  const questions = [
    TeacherCbtQuestion(id: 'Q1', prompt: 'What is 2 + 2?', options: ['3', '4', '5'], correctIndex: 1),
    TeacherCbtQuestion(id: 'Q2', prompt: 'What is 5 - 2?', options: ['1', '2', '3'], correctIndex: 2),
  ];

  tearDown(() => db?.close());

  test('a student sees only real published sets for their real class', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);
    // A real JSS 2B set must never leak to a JSS 2A student.
    await publishRealSet(className: 'JSS 2B', questions: questions);

    final available = await studentCbt.loadAvailableSets();
    expect(available.map((a) => a.set.id).toList(), [published.id]);
    expect(available.single.set.items.map((q) => q.prompt).toList(), questions.map((q) => q.prompt).toList());
    expect(available.single.started, isFalse);
  });

  test('a draft or closed set never appears to a student, only published ones do', () async {
    await setUpSchool();
    await session.selectSchool(mathsTeacher);
    final draft = await teacherCbt.createDraft(className: 'JSS 2A', title: 'Still drafting');
    expect(draft.success, isTrue);
    await session.selectSchool(student);

    final available = await studentCbt.loadAvailableSets();
    expect(available, isEmpty, reason: 'the only real set for JSS 2A is still a draft, not published');
  });

  test('starting, answering and submitting a real CBT scores against the real correct answers', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);

    await studentCbt.startAttempt(published.id);
    await studentCbt.answer(published.id, 0, 1); // correct
    await studentCbt.answer(published.id, 1, 0); // wrong
    final score = await studentCbt.submit(published.id);
    expect(score, 1);

    final available = await studentCbt.loadAvailableSets();
    final attempted = available.singleWhere((a) => a.set.id == published.id);
    expect(attempted.submitted, isTrue);
    expect(attempted.score, 1);
  });

  test('a real submitted attempt makes the teacher\'s own CBT screen show real evidence', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);
    await studentCbt.startAttempt(published.id);
    await studentCbt.answer(published.id, 0, 1);
    await studentCbt.answer(published.id, 1, 2);
    await studentCbt.submit(published.id); // 2/2 correct

    await session.selectSchool(mathsTeacher);
    final snapshot = await teacherCbt.load();
    final real = snapshot.sets.singleWhere((s) => s.id == published.id);
    expect(real.attempts, 1);
    expect(real.averageAccuracy, 100);
  });

  test('answering after the real deadline has passed is rejected', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions, durationMinutes: 5);
    await studentCbt.startAttempt(published.id);
    await studentCbt.answer(published.id, 0, 1); // still within the window right after starting

    now = now.add(const Duration(minutes: 6));
    expect(studentCbt.answer(published.id, 1, 0), throwsStateError);
  });

  test('an attempt resumes with the same real deadline instead of restarting the clock', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions, durationMinutes: 10);
    await studentCbt.startAttempt(published.id);
    final deadline = (await studentCbt.loadAvailableSets()).single.deadline;

    now = now.add(const Duration(minutes: 2));
    await studentCbt.startAttempt(published.id); // resuming must not push the deadline further out
    expect((await studentCbt.loadAvailableSets()).single.deadline, deadline);
  });

  test('an expired, unsubmitted attempt can still be submitted for the answers already saved', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions, durationMinutes: 5);
    await studentCbt.startAttempt(published.id);
    await studentCbt.answer(published.id, 0, 1); // correct

    now = now.add(const Duration(minutes: 6));
    final score = await studentCbt.submit(published.id);
    expect(score, 1);
  });

  test('submitting twice is idempotent and keeps the first real score', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);
    await studentCbt.startAttempt(published.id);
    await studentCbt.answer(published.id, 0, 1);
    final first = await studentCbt.submit(published.id);
    final second = await studentCbt.submit(published.id);
    expect(second, first);
  });

  test('answering an out-of-range question or option is rejected', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);
    await studentCbt.startAttempt(published.id);
    expect(studentCbt.answer(published.id, 5, 0), throwsArgumentError);
    expect(studentCbt.answer(published.id, 0, 9), throwsArgumentError);
  });

  test('only a Student membership can take a CBT', () async {
    await setUpSchool();
    final published = await publishRealSet(className: 'JSS 2A', questions: questions);
    await session.selectSchool(accountant);
    expect(studentCbt.loadAvailableSets(), throwsStateError);
    expect(studentCbt.startAttempt(published.id), throwsStateError);
  });
}
