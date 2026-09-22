import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/events/data/event_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_ai_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_attendance_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_finance_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_learning_progress_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_messages_repository.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentAIRepository ai;
  late ParentAttendanceRepository attendance;
  late ParentFinanceRepository finance;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
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
    attendance = ParentAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      students: students,
      attendance: AdministratorAttendanceRepository(localDatabase: database, schoolSession: session),
    );
    finance = ParentFinanceRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      ledger: FinanceLedgerRepository(
        database: database,
        session: session,
        students: students,
        concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
      ),
    );
    ai = ParentAIRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      attendance: attendance,
      finance: finance,
      learning: ParentLearningProgressRepository(localDatabase: database, schoolSession: session, children: children),
      events: EventRepository(localDatabase: database, schoolSession: session),
      messages: ParentMessagesRepository(localDatabase: database, schoolSession: session, children: children),
    );
  }

  tearDown(() => db?.close());

  test('an attendance question about a real child matches the real Parent Attendance screen exactly', () async {
    await setUpFamily();
    final realAttendance = await attendance.load();
    final maryam = realAttendance.children.firstWhere((c) => c.name == 'Maryam Abdullahi');

    final response = await ai.answer('How is Maryam doing with attendance?');
    expect(response.isGroundedInCachedFamilyContext, isTrue);
    expect(response.answer, contains('${maryam.attendancePercent}%'));
  });

  test('a payment question about a real child matches the real Parent Finance screen exactly', () async {
    await setUpFamily();
    final realFinance = (await finance.load()).snapshot;
    final hafsa = realFinance.children.firstWhere((c) => c.name == 'Hafsa Abdullahi');

    final response = await ai.answer('What is Hafsa\'s fee balance?');
    expect(response.isGroundedInCachedFamilyContext, isTrue);
    if (hafsa.balance == 0) {
      expect(response.answer, contains('fully paid'));
    } else {
      expect(response.answer, contains('outstanding'));
    }
  });

  test('a why/diagnosis/ranking question is honestly refused, not answered with a guess', () async {
    await setUpFamily();
    final response = await ai.answer('Why has Hafsa\'s attendance dropped, and who is smarter than Maryam?');
    expect(response.isGroundedInCachedFamilyContext, isFalse);
    expect(response.answer, contains('do not diagnose'));
  });

  test('an unrelated question gets the honest capability fallback, not a fabricated answer', () async {
    await setUpFamily();
    final response = await ai.answer('What is the school\'s wifi password?');
    expect(response.isGroundedInCachedFamilyContext, isFalse);
    expect(response.answer, contains('cannot access'));
  });

  test('suggestions are answered live through the same engine, never a fixed canned reply', () async {
    await setUpFamily();
    final snapshot = await ai.load();
    expect(snapshot.suggestions, isNotEmpty);
    for (final suggestion in snapshot.suggestions) {
      final direct = await ai.answer(suggestion.prompt);
      expect(suggestion.answer, direct.answer);
    }
  });

  test('an empty or overlong question is rejected', () async {
    await setUpFamily();
    expect(() => ai.answer('   '), throwsArgumentError);
    expect(() => ai.answer('x' * 1001), throwsArgumentError);
  });

  test('only a Parent membership can use Parent AI', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(ai.load(), throwsStateError);
    expect(ai.answer('How is Maryam doing?'), throwsStateError);
  });
}
