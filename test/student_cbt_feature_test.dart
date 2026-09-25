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

// Has JSS 2A and JSS 2B assigned (both Mathematics) in TeacherRoster's demo data.
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
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    studentCbt = StudentCbtRepository(localDatabase: database, schoolSession: session, students: students, now: () => now);
    final roster = TeacherRoster(database: database, session: session, students: students);
    teacherCbt = TeacherCbtRepository(localDatabase: database, schoolSession: session, roster: roster);
  }

  /// Publishes a brand-new real CBT test with real questions for [className], acting as the real
  /// teacher - births one real attempt per real active student on that class register, exactly as
  /// the canonical backend does at publish time.
  Future<TeacherCbtTest> publishRealTest({
    required String className,
    required List<TeacherCbtQuestion> questions,
    int durationMinutes = 10,
  }) async {
    await session.selectSchool(mathsTeacher);
    final snapshot = await teacherCbt.load();
    final option = snapshot.options.firstWhere((o) => o.className == className);
    final saved = await teacherCbt.saveDraft(
      snapshot.draft.copyWith(
        classSubjectId: option.classSubjectId,
        termId: option.termId,
        term: option.term,
        className: option.className,
        subject: option.subject,
        title: 'Test set',
        questions: questions,
        durationMinutes: durationMinutes,
      ),
    );
    expect(saved.success, isTrue, reason: saved.message);
    final published = await teacherCbt.publish(saved.test!);
    expect(published.success, isTrue, reason: published.message);
    await session.selectSchool(student);
    return published.test!;
  }

  const questions = [
    TeacherCbtQuestion(id: 'Q1', prompt: 'What is 2 + 2?', options: ['3', '4', '5'], correctIndex: 1),
    TeacherCbtQuestion(id: 'Q2', prompt: 'What is 5 - 2?', options: ['1', '2', '3'], correctIndex: 2),
  ];

  tearDown(() => db?.close());

  test('a student sees only their own real attempt at a real published test for their real class', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);
    // A real JSS 2B test must never leak to a JSS 2A student.
    await publishRealTest(className: 'JSS 2B', questions: questions);

    final available = await studentCbt.loadAvailable();
    expect(available.map((a) => a.test.id).toList(), [published.id]);
    expect(available.single.test.questions.map((q) => q.prompt).toList(), questions.map((q) => q.prompt).toList());
    expect(available.single.started, isFalse);
  });

  test('a draft test never appears to a student, only a published one does', () async {
    await setUpSchool();
    await session.selectSchool(mathsTeacher);
    final snapshot = await teacherCbt.load();
    final option = snapshot.options.firstWhere((o) => o.className == 'JSS 2A');
    final saved = await teacherCbt.saveDraft(
      snapshot.draft.copyWith(
        classSubjectId: option.classSubjectId,
        termId: option.termId,
        term: option.term,
        className: option.className,
        subject: option.subject,
        title: 'Still drafting',
      ),
    );
    expect(saved.success, isTrue, reason: saved.message);
    await session.selectSchool(student);

    final available = await studentCbt.loadAvailable();
    expect(available, isEmpty, reason: 'the only real test for JSS 2A is still a draft, not published');
  });

  test('starting, answering and submitting a real CBT scores against the real correct answers', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);

    await studentCbt.start(published.id);
    await studentCbt.answer(published.id, 0, 1); // correct
    await studentCbt.answer(published.id, 1, 0); // wrong
    final result = await studentCbt.submit(published.id);
    expect(result.success, isTrue, reason: result.message);

    final available = await studentCbt.loadAvailable();
    final attempted = available.singleWhere((a) => a.test.id == published.id);
    expect(attempted.submitted, isTrue);
    expect(attempted.score, 1);
  });

  test('a real submitted attempt makes the teacher\'s own CBT screen show real evidence', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);
    await studentCbt.start(published.id);
    await studentCbt.answer(published.id, 0, 1);
    await studentCbt.answer(published.id, 1, 2);
    await studentCbt.submit(published.id); // 2/2 correct

    await session.selectSchool(mathsTeacher);
    final snapshot = await teacherCbt.load();
    final real = snapshot.tests.singleWhere((t) => t.id == published.id);
    expect(real.submittedCount, 1);
    expect(real.averageScorePercent, 100);
  });

  test('answering after the real deadline has passed is refused', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions, durationMinutes: 5);
    await studentCbt.start(published.id);
    await studentCbt.answer(published.id, 0, 1); // still within the window right after starting

    now = now.add(const Duration(minutes: 6));
    final refused = await studentCbt.answer(published.id, 1, 0);
    expect(refused.success, isFalse);
  });

  test('an attempt resumes with the same real deadline instead of restarting the clock', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions, durationMinutes: 10);
    await studentCbt.start(published.id);
    final deadline = (await studentCbt.loadAvailable()).single.deadline;

    now = now.add(const Duration(minutes: 2));
    await studentCbt.start(published.id); // resuming must not push the deadline further out
    expect((await studentCbt.loadAvailable()).single.deadline, deadline);
  });

  test('an expired, unsubmitted attempt can still be submitted for the answers already saved', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions, durationMinutes: 5);
    await studentCbt.start(published.id);
    await studentCbt.answer(published.id, 0, 1); // correct

    now = now.add(const Duration(minutes: 6));
    final result = await studentCbt.submit(published.id);
    expect(result.success, isTrue, reason: result.message);
    expect((await studentCbt.loadAvailable()).single.score, 1);
  });

  test('submitting twice is idempotent and keeps the first real score', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);
    await studentCbt.start(published.id);
    await studentCbt.answer(published.id, 0, 1);
    await studentCbt.submit(published.id);
    final first = (await studentCbt.loadAvailable()).single.score;
    await studentCbt.submit(published.id);
    final second = (await studentCbt.loadAvailable()).single.score;
    expect(second, first);
  });

  test('answering an out-of-range question or option is refused', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);
    await studentCbt.start(published.id);
    expect((await studentCbt.answer(published.id, 5, 0)).success, isFalse);
    expect((await studentCbt.answer(published.id, 0, 9)).success, isFalse);
  });

  test('only a Student membership can take a CBT', () async {
    await setUpSchool();
    final published = await publishRealTest(className: 'JSS 2A', questions: questions);
    await session.selectSchool(accountant);
    expect(studentCbt.loadAvailable(), throwsStateError);
    expect(studentCbt.start(published.id), throwsStateError);
  });
}
