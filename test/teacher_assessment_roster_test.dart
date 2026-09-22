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

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data.
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

  tearDown(() => db.close());

  test('a new assessment for a real assigned class gets one score entry per real student, starting at zero', () async {
    await setUpSchool(mathsTeacher);
    final realStudents = await roster.studentsIn('JSS 2A');
    expect(realStudents, isNotEmpty, reason: 'the demo register must have JSS 2A students for this test to be meaningful');

    final result = await assessments.createAssessment(className: 'JSS 2A', title: 'CA 1', maximumScore: 20);
    expect(result.success, isTrue, reason: result.message);
    final sheet = result.sheet!;
    expect(sheet.entries.map((e) => e.studentId).toSet(), realStudents.map((s) => s.id).toSet());
    expect(sheet.entries.every((e) => e.score == 0), isTrue);
    expect(sheet.className, 'JSS 2A');
    expect(sheet.state, TeacherAssessmentSheetState.draft);
  });

  test('an assessment cannot be created for a class the teacher is not really assigned to', () async {
    await setUpSchool(mathsTeacher);
    final result = await assessments.createAssessment(className: 'JSS 3A', title: 'CA 1', maximumScore: 20);
    expect(result.success, isFalse);
    expect(result.message, contains('not assigned to this class'));
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), 0);
  });

  test('a blank title or a non-positive maximum score is refused', () async {
    await setUpSchool(mathsTeacher);
    final blank = await assessments.createAssessment(className: 'JSS 2A', title: '   ', maximumScore: 20);
    expect(blank.success, isFalse);
    final zero = await assessments.createAssessment(className: 'JSS 2A', title: 'CA 1', maximumScore: 0);
    expect(zero.success, isFalse);
  });

  test('the register and score sheets only ever show the teacher\'s real assigned classes', () async {
    await setUpSchool(mathsTeacher);
    await assessments.createAssessment(className: 'JSS 2A', title: 'CA 1', maximumScore: 20);
    await assessments.createAssessment(className: 'JSS 2B', title: 'CA 1', maximumScore: 20);
    final snapshot = await assessments.load();
    expect(snapshot.register.map((r) => r.className).toSet(), {'JSS 2A', 'JSS 2B'});
    expect(snapshot.classOptions, ['JSS 2A', 'JSS 2B', 'SS1A']);
    for (final item in snapshot.register) {
      expect(snapshot.sheets.containsKey(item.id), isTrue);
    }
  });

  test('a teacher with no assigned classes sees an honest empty register, not a crash', () async {
    await setUpSchool(primaryTeacher);
    final snapshot = await assessments.load();
    expect(snapshot.register, isEmpty);
    expect(snapshot.classOptions, ['Primary 3', 'Primary 4']);
  });

  test('saving progress records the real entered count and average, and queues sync', () async {
    await setUpSchool(mathsTeacher);
    final created = await assessments.createAssessment(className: 'JSS 2A', title: 'CA 1', maximumScore: 20);
    final sheet = created.sheet!;
    final entries = sheet.entries.toList();
    final scored = [
      entries[0].copyWith(score: 15),
      entries[1].copyWith(score: 10),
      for (var i = 2; i < entries.length; i++) entries[i],
    ];
    final draft = sheet.copyWith(entries: scored);

    final saved = await assessments.saveProgress(draft);
    expect(saved.success, isTrue, reason: saved.message);

    final snapshot = await assessments.load();
    final item = snapshot.register.singleWhere((r) => r.id == sheet.id);
    expect(item.entered, 2, reason: 'only the two non-zero scores count as entered');
    expect(item.total, entries.length);
    expect(item.average, saved.sheet!.average);
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });

  test('submitting scores locks the sheet from further teacher edits', () async {
    await setUpSchool(mathsTeacher);
    final created = await assessments.createAssessment(className: 'JSS 2A', title: 'CA 1', maximumScore: 20);
    final submitted = await assessments.submitScores(created.sheet!);
    expect(submitted.success, isTrue, reason: submitted.message);
    expect(submitted.sheet!.teacherEditable, isFalse);

    final reAttempt = await assessments.saveProgress(submitted.sheet!);
    expect(reAttempt.success, isFalse);
    expect(reAttempt.message, contains('cannot be silently rewritten'));
  });
}
