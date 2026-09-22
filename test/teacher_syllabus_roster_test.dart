import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/data/teacher_syllabus_repository.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_syllabus_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// Has JSS 2A, JSS 2B and SS1A assigned in TeacherRoster's demo data (not JSS 3A).
const mathsTeacher = SchoolMembership(id: 'membership-teacher-003', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

// Has only Primary 3/4 assigned, none of which has an uploaded scheme of work.
const primaryTeacher = SchoolMembership(id: 'membership-teacher-002', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherRoster roster;
  late TeacherSyllabusRepository syllabus;

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
    syllabus = TeacherSyllabusRepository(localDatabase: db, schoolSession: session, roster: roster);
  }

  tearDown(() => db.close());

  test('only the real assigned classes that have an uploaded scheme are offered, not the whole demo scheme', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await syllabus.load();
    // The teacher is assigned JSS 2A, JSS 2B and SS1A, but not JSS 3A, so JSS 3A must not appear
    // even though it exists in the uploaded scheme of work.
    expect(snapshot.classes, ['JSS 2A', 'JSS 2B', 'SS1A']);
    expect(snapshot.rows.map((r) => r.className).toSet(), {'JSS 2A', 'JSS 2B', 'SS1A'});
    expect(snapshot.rows.any((r) => r.className == 'JSS 3A'), isFalse);
  });

  test('the SS1A scheme is matched by exact class name, not lost to a naming mismatch', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await syllabus.load();
    expect(snapshot.classes, contains('SS1A'));
    expect(snapshot.rows.where((r) => r.className == 'SS1A'), hasLength(8));
  });

  test('a teacher whose assigned classes have no uploaded scheme sees an honest empty list, not a crash', () async {
    await setUpSchool(primaryTeacher);
    final snapshot = await syllabus.load();
    expect(snapshot.classes, isEmpty);
    expect(snapshot.rows, isEmpty);
  });

  test('coverage and pacing are computed from the real rows, not read from a fixed table', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await syllabus.load();
    // 4 of 8 approved weeks are completed for both classes in the fixed demo scheme.
    expect(snapshot.coverageOf('JSS 2A'), 50);
    expect(snapshot.coverageOf('JSS 2B'), 50);
    expect(snapshot.isBehind('JSS 2A'), isFalse);
    expect(snapshot.isBehind('JSS 2B'), isTrue, reason: 'JSS 2B week 6 is explicitly behind in the demo scheme');
  });

  test('marking coverage for a class outside the teacher\'s assigned scheme is refused, even if the row exists', () async {
    await setUpSchool(mathsTeacher);
    final foreignRow = TeacherSyllabusRow(
      className: 'JSS 3A',
      week: 1,
      topic: 'Algebra Review',
      approvedStatus: TeacherSyllabusStatus.completed,
      plannedLessons: 3,
    );
    final result = await syllabus.markStatus(row: foreignRow, status: TeacherSyllabusStatus.completed);
    expect(result.success, isFalse);
    expect(result.message, contains('not in your assigned scheme'));
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), 0);
  });

  test('marking coverage for a really-assigned class records it locally and queues it for sync', () async {
    await setUpSchool(mathsTeacher);
    final snapshot = await syllabus.load();
    final row = snapshot.rows.firstWhere((r) => r.className == 'JSS 2A' && r.week == 6);
    final result = await syllabus.markStatus(row: row, status: TeacherSyllabusStatus.completed);
    expect(result.success, isTrue, reason: result.message);
    final after = await syllabus.load();
    expect(after.progress[row.id]?.reportedStatus, TeacherSyllabusStatus.completed);
    expect(after.coverageOf('JSS 2A'), 63, reason: '5 of 8 weeks now reported complete');
    expect(db.pendingCount(tenantId: mathsTeacher.schoolId), greaterThan(0));
  });
}
