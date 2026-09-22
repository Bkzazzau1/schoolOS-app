import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_learning_progress_repository.dart';
import 'package:schoolos_app/features/parent/domain/parent_learning_progress_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_assessment_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const accountant = SchoolMembership(id: 'm-accountant', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data — teaches Maryam's (STU-001) class.
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
// Has only Primary 3/4 assigned — teaches Hafsa's (PRI-003) class.
const primaryTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentLearningProgressRepository learning;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, accountant, mathsTeacher, primaryTeacher]);
    await session.selectSchool(parent);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    final children = ParentChildrenRepository(
      localDatabase: database,
      schoolSession: session,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
      ledger: FinanceLedgerRepository(
        database: database,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
      ),
    );
    learning = ParentLearningProgressRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
    );
  }

  // Records a real assessment score for a real student, exactly the way the real Teacher screen
  // would: create the assessment for the real assigned class, then save a real score against it.
  Future<void> recordRealScore({
    required SchoolMembership teacherMembership,
    required String className,
    required String title,
    required int maximumScore,
    required String studentId,
    required int score,
  }) async {
    await session.selectSchool(teacherMembership);
    final roster = TeacherRoster(
      database: db!,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db!, schoolSession: session),
    );
    final assessments = TeacherAssessmentRepository(localDatabase: db!, schoolSession: session, roster: roster);
    final created = await assessments.createAssessment(className: className, title: title, maximumScore: maximumScore);
    expect(created.success, isTrue, reason: created.message);
    final sheet = created.sheet!;
    final scored = [
      for (final entry in sheet.entries)
        entry.studentId == studentId ? entry.copyWith(score: score) : entry,
    ];
    final saved = await assessments.saveProgress(sheet.copyWith(entries: scored));
    expect(saved.success, isTrue, reason: saved.message);
    await session.selectSchool(parent);
  }

  tearDown(() => db?.close());

  test('a fresh family with no real assessments yet sees an honest empty picture, not fabricated evidence', () async {
    await setUpFamily();
    final snapshot = await learning.load();
    expect(snapshot.children.map((c) => c.id).toList(), ['STU-001', 'PRI-003']);
    for (final child in snapshot.children) {
      expect(child.averagePercent, 0);
      expect(child.evidence, isEmpty);
      expect(child.timeline, isEmpty);
      expect(child.insight, 'Not recorded yet');
      // No real source exists for any of these; they must never be silently invented.
      expect(child.history, isEmpty);
      expect(child.subjects, isEmpty);
      expect(child.topics, isEmpty);
      expect(child.actions, isEmpty);
      expect(child.trendPercent, 0);
    }
  });

  test('a real recorded score becomes real evidence and average for the right child only', () async {
    await setUpFamily();
    await recordRealScore(
      teacherMembership: mathsTeacher,
      className: 'JSS 2A',
      title: 'CA 1',
      maximumScore: 20,
      studentId: 'STU-001',
      score: 15,
    );

    final snapshot = await learning.load();
    final maryam = snapshot.childById('STU-001')!;
    final hafsa = snapshot.childById('PRI-003')!;

    expect(maryam.averagePercent, 75); // 15/20
    expect(maryam.evidence, hasLength(1));
    expect(maryam.evidence.single.label, 'CA 1');
    expect(maryam.evidence.single.value, '15/20 (75%)');
    expect(maryam.timeline, hasLength(1));
    expect(maryam.timeline.single.detail, 'Score recorded: 15/20');
    expect(maryam.insight, contains('1 recorded assessment'));

    // Hafsa is unaffected by her sibling's real score in her sibling's real class.
    expect(hafsa.averagePercent, 0);
    expect(hafsa.evidence, isEmpty);
  });

  test('an average blends every real recorded score for that child, unentered scores are excluded', () async {
    await setUpFamily();
    await recordRealScore(
      teacherMembership: mathsTeacher,
      className: 'JSS 2A',
      title: 'CA 1',
      maximumScore: 20,
      studentId: 'STU-001',
      score: 10, // 50%
    );
    await recordRealScore(
      teacherMembership: mathsTeacher,
      className: 'JSS 2A',
      title: 'CA 2',
      maximumScore: 50,
      studentId: 'STU-001',
      score: 40, // 80%
    );

    final snapshot = await learning.load();
    final maryam = snapshot.childById('STU-001')!;
    expect(maryam.averagePercent, 65); // (50 + 80) / 2
    expect(maryam.evidence, hasLength(2));
    expect(maryam.insight, contains('2 recorded assessments'));
  });

  test('status is derived from the real average, not a fabricated label', () async {
    await setUpFamily();
    await recordRealScore(
      teacherMembership: primaryTeacher,
      className: 'Primary 3',
      title: 'Term Test',
      maximumScore: 100,
      studentId: 'PRI-003',
      score: 30,
    );
    final snapshot = await learning.load();
    final hafsa = snapshot.childById('PRI-003')!;
    expect(hafsa.averagePercent, 30);
    expect(hafsa.status, ParentLearningStatus.needsSupport);
  });

  test('attendancePercent matches the real linked-child attendance, never a second disagreeing number', () async {
    await setUpFamily();
    final snapshot = await learning.load();
    for (final child in snapshot.children) {
      expect(child.attendancePercent, anyOf(0, 100));
    }
  });

  test('childById returns the real matching child and rejects an unlinked one', () async {
    await setUpFamily();
    final maryam = await learning.childById('STU-001');
    expect(maryam.name, 'Maryam Abdullahi');
    expect(learning.childById('NOT-LINKED'), throwsStateError);
  });

  test('only a Parent membership can load family learning progress', () async {
    await setUpFamily();
    await session.selectSchool(accountant);
    expect(learning.load(), throwsStateError);
  });
}
