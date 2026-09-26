import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/events/data/event_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_dashboard_repository.dart';
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
  late ParentDashboardRepository dashboard;
  late ParentChildrenRepository children;
  late ParentFinanceRepository finance;
  late ParentMessagesRepository messages;

  Future<void> setUpFamily() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher]);
    await session.selectSchool(parent);
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
    messages = ParentMessagesRepository(localDatabase: database, schoolSession: session, children: children);
    dashboard = ParentDashboardRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      learning: ParentLearningProgressRepository(localDatabase: database, schoolSession: session, children: children),
      finance: finance,
      messages: messages,
      events: EventRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  test('children are the real linked children, with real attendance and real balances, never fixed numbers', () async {
    await setUpFamily();
    final realChildren = (await children.load()).children;
    final realFinance = (await finance.load()).snapshot;
    final snapshot = await dashboard.load();

    expect(snapshot.children, hasLength(realChildren.length));
    for (final child in snapshot.children) {
      final real = realChildren.firstWhere((c) => c.id == child.id);
      final realAccount = realFinance.children.firstWhere((a) => a.id == child.id);
      expect(child.name, real.name);
      expect(child.className, real.className);
      expect(child.presentToday, real.presentToday);
      expect(child.attendancePercent, real.presentToday ? 100 : 0);
      expect(child.feeBalance, realAccount.balance);
    }
  });

  test('attention items only ever reflect a real absence or a real outstanding balance', () async {
    await setUpFamily();
    final snapshot = await dashboard.load();
    for (final item in snapshot.attentionItems) {
      final matchesChild = snapshot.children.any((c) => item.title.contains(c.name));
      expect(matchesChild, isTrue, reason: 'every attention item must name a real linked child');
      expect(['attendance', 'finance'], contains(item.destinationKey));
    }
    // Every child with a real outstanding balance must have a matching real attention item.
    for (final child in snapshot.children.where((c) => c.feeBalance > 0)) {
      expect(snapshot.attentionItems.any((item) => item.title.contains(child.name) && item.destinationKey == 'finance'), isTrue);
    }
  });

  test('finance roll-up reconciles exactly with the real Parent Finance screen', () async {
    await setUpFamily();
    final realFinance = (await finance.load()).snapshot;
    final snapshot = await dashboard.load();

    expect(snapshot.finance.totalBilled, realFinance.children.fold<int>(0, (sum, a) => sum + a.grossFees));
    expect(snapshot.finance.totalPaid, realFinance.children.fold<int>(0, (sum, a) => sum + a.paidAmount));
    expect(snapshot.totalCurrentBalance, realFinance.children.fold<int>(0, (sum, a) => sum + a.balance));
    // What each child owes; where the family pays is one account for the whole family, never one per child.
    for (final owed in snapshot.finance.balances) {
      final real = realFinance.children.firstWhere((a) => a.name == owed.childName);
      expect(owed.className, real.className);
      expect(owed.balance, real.balance);
    }
    // A fresh family has no mandate configured, so honestly no scheduled debit.
    expect(snapshot.finance.nextScheduledDebit, 0);
    expect(snapshot.finance.nextScheduledDebitLabel, 'Not recorded yet');
  });

  test('a real queued message appears on the dashboard, an empty channel does not', () async {
    await setUpFamily();
    final before = await dashboard.load();
    expect(before.messages, isEmpty, reason: 'a fresh family has no real messages yet');

    final realThreads = (await messages.load()).threads;
    await messages.queueReply(threadId: realThreads.first.id, body: 'When is the next PTA meeting?');

    final after = await dashboard.load();
    expect(after.messages, hasLength(1));
    expect(after.messages.single.message, 'When is the next PTA meeting?');
  });

  test('guardian name is an honest role label, never a fabricated person', () async {
    await setUpFamily();
    final snapshot = await dashboard.load();
    expect(snapshot.guardianName, 'Guardian');
    expect(snapshot.familyAccountId, parent.id);
  });

  test('only a Parent membership can load the family dashboard', () async {
    await setUpFamily();
    await session.selectSchool(teacher);
    expect(dashboard.load(), throwsStateError);
  });
}
