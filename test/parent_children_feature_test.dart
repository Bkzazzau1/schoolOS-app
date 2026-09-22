import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
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
  late ParentChildrenRepository children;

  Future<void> setUpFamily([SchoolMembership who = parent]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(who);
    final students = AdministratorStudentsRepository(localDatabase: database, schoolSession: session);
    children = ParentChildrenRepository(
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
  }

  tearDown(() => db?.close());

  test('linked children are the real register entries, not a fabricated duplicate', () async {
    await setUpFamily();
    final snapshot = await children.load();
    expect(snapshot.children.map((c) => c.id).toList(), ['STU-001', 'PRI-003']);
    expect(snapshot.children.first.name, 'Maryam Abdullahi');
    expect(snapshot.children.first.className, 'JSS 2A');
    expect(snapshot.children.first.section, 'Secondary');
    expect(snapshot.children.last.name, 'Hafsa Abdullahi');
    expect(snapshot.children.last.className, 'Primary 3');
    expect(snapshot.children.last.section, 'Primary');
  });

  test('fields with no real source are honestly Not recorded yet, not invented', () async {
    await setUpFamily();
    final snapshot = await children.load();
    for (final child in snapshot.children) {
      expect(child.admissionNumber, 'Not recorded yet');
      expect(child.classTeacher, 'Not recorded yet');
      expect(child.learningLabel, 'Not recorded yet');
      expect(child.house, 'Not recorded yet');
      expect(child.transport, 'Not recorded yet');
      expect(child.paymentAccount, 'Not recorded yet');
      expect(child.paymentPlan, 'Not recorded yet');
      expect(child.activities, 'Not recorded yet');
      expect(child.subjects, isEmpty);
      expect(child.timeline, isEmpty);
    }
    expect(snapshot.academicPeriod, 'Not recorded yet');
  });

  test('attendance status is real (today\'s real gate-scan record), never a fixed percentage', () async {
    await setUpFamily();
    final snapshot = await children.load();
    const validLabels = {'Present today', 'Not recorded yet', 'Late', 'Checked out', 'Offline synced', 'Excused'};
    for (final child in snapshot.children) {
      expect(validLabels, contains(child.attendanceLabel));
      expect(child.presentToday, child.attendanceLabel == 'Present today');
    }
  });

  test('financial balance is real, from the same ledger Finance Office uses', () async {
    await setUpFamily();
    final snapshot = await children.load();
    final ledger = FinanceLedgerRepository(
      database: db!,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db!, schoolSession: session),
      concessions: ConcessionRepository(localDatabase: db!, schoolSession: session),
    );
    final accounts = await ledger.accounts();
    for (final child in snapshot.children) {
      final account = accounts.where((a) => a.student.id == child.id).firstOrNull;
      expect(child.currentBalance, account?.balance ?? 0);
    }
  });

  test('childById returns the real linked child and refuses an unlinked one', () async {
    await setUpFamily();
    final maryam = await children.childById('STU-001');
    expect(maryam.name, 'Maryam Abdullahi');
    expect(() => children.childById('STU-099'), throwsStateError);
  });

  test('replaceLinkedChildren rejects a duplicate or blank id', () async {
    await setUpFamily();
    expect(() => children.replaceLinkedChildren(childIds: ['STU-001', 'STU-001']), throwsStateError);
    expect(() => children.replaceLinkedChildren(childIds: ['']), throwsStateError);
  });

  test('only a Parent membership can load linked family records', () async {
    await setUpFamily(teacher);
    expect(children.load(), throwsStateError);
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
