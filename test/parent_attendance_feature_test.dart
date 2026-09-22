import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_attendance_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentAttendanceRepository attendance;

  Future<void> setUpFamily([SchoolMembership who = parent]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(who);
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
    attendance = ParentAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  test('child summaries are the real linked children, real class, honest single-day window', () async {
    await setUpFamily();
    final snapshot = await attendance.load();
    expect(snapshot.children.map((c) => c.childId).toList(), ['STU-001', 'PRI-003']);
    for (final child in snapshot.children) {
      // The real source only keeps today's record: presentDays/totalSchoolDays describe a
      // single day, never a fabricated running total.
      expect(child.totalSchoolDays, 1);
      expect(child.presentDays, anyOf(0, 1));
      expect(child.attendancePercent, child.presentDays == 1 ? 100 : 0);
      expect(child.checkedInToday, child.presentDays == 1);
    }
  });

  test('today\'s event list only contains real linked children, consistent with the summaries', () async {
    await setUpFamily();
    final snapshot = await attendance.load();
    final linkedIds = snapshot.children.map((c) => c.childId).toSet();
    for (final event in snapshot.events) {
      expect(linkedIds, contains(event.childId));
      expect(event.dateLabel, 'Today');
    }
    // Every checked-in child has a matching event; every event corresponds to a checked-in child.
    final checkedInIds = snapshot.children.where((c) => c.checkedInToday).map((c) => c.childId).toSet();
    expect(snapshot.events.map((e) => e.childId).toSet(), checkedInIds);
  });

  test('there is no real push-notification source for attendance check-ins', () async {
    await setUpFamily();
    final snapshot = await attendance.load();
    expect(snapshot.notifications, isEmpty);
  });

  test('only a Parent membership can load family attendance', () async {
    await setUpFamily(teacher);
    expect(attendance.load(), throwsStateError);
  });
}
