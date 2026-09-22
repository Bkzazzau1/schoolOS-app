import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_weekly_learning_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_weekly_learning_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const accountant = SchoolMembership(id: 'm-accountant', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentWeeklyLearningRepository weekly;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, accountant, teacher]);
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
    weekly = ParentWeeklyLearningRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
    );
  }

  tearDown(() => db?.close());

  test('a fresh family sees no updates yet: the real teacher record is still an unpublished draft', () async {
    await setUpFamily();
    final snapshot = await weekly.load();
    expect(snapshot.updates, isEmpty);
    expect(snapshot.children, isEmpty);
  });

  test('queuing a real weekly update for a real class reaches only the real children in that class', () async {
    await setUpFamily();

    await session.selectSchool(teacher);
    final teacherWeekly = TeacherWeeklyLearningRepository(localDatabase: db!, schoolSession: session);
    final draft = (await teacherWeekly.load()).update; // seeded for JSS 2A, Maryam's real class
    final queued = await teacherWeekly.queuePublication(draft);
    expect(queued.success, isTrue, reason: queued.message);
    await session.selectSchool(parent);

    final snapshot = await weekly.load();
    // Only Maryam (STU-001) is really in JSS 2A; Hafsa (PRI-003) is really in Primary 3 and gets nothing.
    expect(snapshot.updates, hasLength(1));
    final update = snapshot.updates.single;
    expect(update.childId, 'STU-001');
    expect(update.className, 'JSS 2A');
    expect(update.weekLabel, draft.week);
    expect(update.teacher, 'Not recorded yet');
    expect(update.teacherNote, draft.note);
    expect(update.subjects.length, draft.subjects.length);
    for (var i = 0; i < update.subjects.length; i++) {
      expect(update.subjects[i].subject, draft.subjects[i].subject);
      expect(update.subjects[i].thisWeek, draft.subjects[i].covered);
      expect(update.subjects[i].learningEvidence, draft.subjects[i].evidence);
      expect(update.subjects[i].nextTopic, draft.subjects[i].next);
      expect(update.subjects[i].practiceNote, draft.subjects[i].support);
    }

    final hafsaUpdates = snapshot.updatesForChild('PRI-003');
    expect(hafsaUpdates, isEmpty);
  });

  test('a blank support note honestly reads "Not recorded yet" instead of an empty string', () async {
    await setUpFamily();

    await session.selectSchool(teacher);
    final teacherWeekly = TeacherWeeklyLearningRepository(localDatabase: db!, schoolSession: session);
    final draft = (await teacherWeekly.load()).update;
    final blanked = draft.copyWith(
      subjects: [
        for (final subject in draft.subjects) subject.copyWith(support: ''),
      ],
    );
    final queued = await teacherWeekly.queuePublication(blanked);
    expect(queued.success, isTrue, reason: queued.message);
    await session.selectSchool(parent);

    final snapshot = await weekly.load();
    for (final subject in snapshot.updates.single.subjects) {
      expect(subject.practiceNote, 'Not recorded yet');
    }
  });

  test('only a Parent membership can load family weekly learning', () async {
    await setUpFamily();
    await session.selectSchool(accountant);
    expect(weekly.load(), throwsStateError);
  });
}
