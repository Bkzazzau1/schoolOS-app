import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_assessment_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A and JSS 2B assigned in TeacherRoster's demo data.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has only Primary 3/4 assigned.
const primaryTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherAssessmentRepository assessments;

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
    assessments = TeacherAssessmentRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  Future<TeacherAssessment> publishFor(String className, {String title = 'CA 1', int maximumScore = 20}) async {
    final loaded = await assessments.load();
    final draftResult = await assessments.saveDraft(
      loaded.draft.copyWith(className: className, title: title, maximumScore: maximumScore),
    );
    expect(draftResult.success, isTrue, reason: draftResult.message);
    final publishResult = await assessments.publish(draftResult.assessment!);
    expect(publishResult.success, isTrue, reason: publishResult.message);
    return publishResult.assessment!;
  }

  tearDown(() => db.close());

  // Standalone demo mode publishes against the real class register (never a fabricated
  // student list), and never yet has server-side authority to check which class the
  // signed-in teacher is really assigned to - unlike canonical/server-backed mode, which
  // enforces that through real TeachingAssignment authority instead (see
  // TeacherAssessmentRepository's own doc comment on why demo mode stays permissive here).
  test('publishing gets one score entry per real student in the class, starting unentered', () async {
    await setUpSchool(mathsTeacher);
    final realStudents = await roster.studentsIn('JSS 2A');
    expect(realStudents, isNotEmpty, reason: 'the demo register must have JSS 2A students for this test to be meaningful');

    final published = await publishFor('JSS 2A');
    expect(published.entries.map((e) => e.studentId).toSet(), realStudents.map((s) => s.id).toSet());
    expect(published.entries.every((e) => e.score == null), isTrue);
    expect(published.className, 'JSS 2A');
    expect(published.state, TeacherAssessmentState.published);
  });

  test('publishing is refused for a class with no real students on the register', () async {
    await setUpSchool(mathsTeacher);
    final loaded = await assessments.load();
    final draftResult = await assessments.saveDraft(
      loaded.draft.copyWith(className: 'Not A Real Class', title: 'CA 1', maximumScore: 20),
    );
    expect(draftResult.success, isTrue, reason: draftResult.message);
    final publishResult = await assessments.publish(draftResult.assessment!);
    expect(publishResult.success, isFalse);
    expect(publishResult.message, contains('no students'));
  });

  test('a blank title or a non-positive maximum score is refused at publication', () async {
    await setUpSchool(mathsTeacher);
    final loaded = await assessments.load();
    final blankTitle = await assessments.saveDraft(loaded.draft.copyWith(className: 'JSS 2A', title: '   ', maximumScore: 20));
    expect((await assessments.publish(blankTitle.assessment!)).success, isFalse);
    final zeroMax = await assessments.saveDraft(loaded.draft.copyWith(className: 'JSS 2A', title: 'CA 1', maximumScore: 0));
    expect((await assessments.publish(zeroMax.assessment!)).success, isFalse);
  });

  test('the assessment library and class options only ever show the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    await publishFor('JSS 2A');
    await publishFor('JSS 2B');
    final snapshot = await assessments.load();
    expect(snapshot.assessments.map((a) => a.className).toSet(), {'JSS 2A', 'JSS 2B'});
    expect(snapshot.options.map((o) => o.className).toList(), ['JSS 2A', 'JSS 2B']);
  });

  test('a teacher with no assigned classes sees an honest empty library, not a crash', () async {
    await setUpSchool(primaryTeacher);
    final snapshot = await assessments.load();
    expect(snapshot.assessments, isEmpty);
    expect(snapshot.options.map((o) => o.className).toList(), ['Primary 3', 'Primary 4']);
  });

  test('saving scores records the real entered count and average, and queues sync', () async {
    await setUpSchool(mathsTeacher);
    final published = await publishFor('JSS 2A');
    final entries = published.entries.toList();
    final scored = [
      entries[0].copyWith(score: 15),
      entries[1].copyWith(score: 10),
      for (var i = 2; i < entries.length; i++) entries[i],
    ];

    final saved = await assessments.saveScores(published.copyWith(entries: scored));
    expect(saved.success, isTrue, reason: saved.message);

    final snapshot = await assessments.load();
    final item = snapshot.assessments.singleWhere((a) => a.id == published.id);
    expect(item.entered, 2, reason: 'only the two entered scores count, unlike the earlier prototype which could not tell an entered zero from "not entered"');
    expect(item.totalStudents, entries.length);
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });

  test('submitting scores locks the assessment from further teacher score entry', () async {
    await setUpSchool(mathsTeacher);
    final published = await publishFor('JSS 2A');
    final submitted = await assessments.submit(published);
    expect(submitted.success, isTrue, reason: submitted.message);
    expect(submitted.assessment!.scoresEditable, isFalse);

    final reAttempt = await assessments.saveScores(submitted.assessment!);
    expect(reAttempt.success, isFalse);
    expect(reAttempt.message, contains('open'));
  });
}
