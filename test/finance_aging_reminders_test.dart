import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_aging.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_ledger_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_debt_aging_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_reminders_page.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late FinanceLedgerRepository ledger;

  Future<void> setUpSchool([SchoolMembership who = finance]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    db = database;
    await database.initialize();
    final session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([finance, teacher]);
    await session.selectSchool(who);
    ledger = FinanceLedgerRepository(
      database: database,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
      concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  final due = DateTime(2026, 8, 25);

  test('overdue days fall into the right band', () {
    expect(bandOf(due, DateTime(2026, 8, 25)), AgingBand.notDue);
    expect(bandOf(due, DateTime(2026, 8, 20)), AgingBand.notDue);
    expect(bandOf(due, DateTime(2026, 8, 26)), AgingBand.current);
    expect(bandOf(due, DateTime(2026, 9, 24)), AgingBand.current);
    expect(bandOf(due, DateTime(2026, 9, 25)), AgingBand.followUp);
    expect(bandOf(due, DateTime(2026, 10, 25)), AgingBand.review);
    expect(bandOf(due, DateTime(2026, 11, 30)), AgingBand.priority);
    expect(daysOverdue(due, DateTime(2026, 9, 21, 15, 30)), 27);
  });

  test('the aging report lists everyone who owes, largest first, and the total matches the ledger', () async {
    await setUpSchool();
    final report = await ledger.aging(today: DateTime(2026, 9, 21));
    expect(report.overdue, isTrue);
    expect(report.band, AgingBand.current);
    expect(report.owing, isNotEmpty);
    for (var i = 1; i < report.owing.length; i++) {
      expect(report.owing[i - 1].balance, greaterThanOrEqualTo(report.owing[i].balance));
    }
    final totals = totalsOf(await ledger.accounts());
    expect(report.outstanding, totals.balance);
    expect(report.bands.firstWhere((b) => b.band == AgingBand.current).amount, report.outstanding);
    expect(report.bands.firstWhere((b) => b.band == AgingBand.priority).amount, 0);
  });

  test('moving the due date to the future makes nothing overdue, and nobody can be reminded', () async {
    await setUpSchool();
    expect((await ledger.setDueDate(financeCurrentTerm, DateTime(2027, 1, 1))).success, isTrue);
    final report = await ledger.aging(today: DateTime(2026, 9, 21));
    expect(report.overdue, isFalse);
    expect(report.band, AgingBand.notDue);
    final account = report.owing.first;
    final refused = await ledger.queueReminder(account, schoolName: 'BrightGate', now: DateTime(2026, 9, 21));
    expect(refused.success, isFalse);
    expect(refused.message, contains('not overdue yet'));
  });

  test('reminders get firmer each time, are spaced apart, and stop at the final notice', () async {
    await setUpSchool();
    final account = (await ledger.aging(today: DateTime(2026, 9, 21))).owing.first;
    final day1 = DateTime(2026, 9, 21, 9);

    final first = await ledger.queueReminder(account, schoolName: 'BrightGate', now: day1);
    expect(first.success, isTrue, reason: first.message);
    expect((await ledger.reminders()).single.level, 1);

    final tooSoon = await ledger.queueReminder(account, schoolName: 'BrightGate', now: day1.add(const Duration(days: 1)));
    expect(tooSoon.success, isFalse);
    expect(tooSoon.message, contains('Wait 3 days'));

    expect((await ledger.queueReminder(account, schoolName: 'BrightGate', now: day1.add(const Duration(days: 4)))).success, isTrue);
    expect((await ledger.queueReminder(account, schoolName: 'BrightGate', now: day1.add(const Duration(days: 8)))).success, isTrue);
    final levels = (await ledger.reminders()).map((r) => r.level).toList()..sort();
    expect(levels, [1, 2, 3]);
    expect((await ledger.queueReminder(account, schoolName: 'BrightGate', now: day1.add(const Duration(days: 12)))).success, isTrue);
    expect((await ledger.reminders()).where((r) => r.level == 3).length, 2, reason: 'the final notice is repeated, not made firmer');
  });

  test('a reminder states the amount and term, is addressed to the guardian, and never guesses why fees are unpaid', () async {
    await setUpSchool();
    final account = (await ledger.aging(today: DateTime(2026, 9, 21))).owing.first;
    await ledger.queueReminder(account, schoolName: 'BrightGate Academy', now: DateTime(2026, 9, 21));
    final message = (await ledger.reminders()).single.message;
    expect(message, contains(account.student.primaryGuardian));
    expect(message, contains(account.student.name));
    expect(message, contains('BrightGate Academy'));
    expect(message, contains('₦'));
    expect(message, contains(financeCurrentTerm));
    expect(message.toLowerCase(), isNot(contains('because')));
  });

  test('someone who owes nothing is not reminded, and "remind everyone" reminds each family once', () async {
    await setUpSchool();
    final paid = (await ledger.accounts()).firstWhere((a) => a.status == AccountStatus.paid);
    expect((await ledger.queueReminder(paid, schoolName: 'BrightGate', now: DateTime(2026, 9, 21))).message, contains('owes nothing'));

    final owingCount = (await ledger.aging(today: DateTime(2026, 9, 21))).owing.length;
    final queued = await ledger.queueAllReminders(schoolName: 'BrightGate', now: DateTime(2026, 9, 21));
    expect(queued, owingCount);
    expect(await ledger.queueAllReminders(schoolName: 'BrightGate', now: DateTime(2026, 9, 21)), 0, reason: 'nobody twice in a day');
  });

  test('only the finance office or the owner can set the due date or queue reminders', () async {
    await setUpSchool(teacher);
    expect((await ledger.setDueDate(financeCurrentTerm, DateTime(2026, 10, 1))).success, isFalse);
    final account = (await ledger.accounts()).first;
    expect((await ledger.queueReminder(account, schoolName: 'BrightGate')).message, contains('finance office'));
  });

  testWidgets('the aging page shows the bands and who owes, and the reminders page queues a reminder after a preview', (tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    late StudentAccount target;
    await tester.runAsync(() async => target = (await ledger.aging()).owing.first);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceDebtAgingPage(ledger: ledger))));
    await settle();
    expect(find.byKey(const ValueKey('band-current')), findsOneWidget);
    expect(find.byKey(ValueKey('owing-${target.student.id}')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceRemindersPage(ledger: ledger, schoolName: 'BrightGate'))));
    await settle();
    await tester.ensureVisible(find.byKey(ValueKey('remind-button-${target.student.id}')));
    await tester.tap(find.byKey(ValueKey('remind-button-${target.student.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('friendly reminder'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-confirm')));
    await settle();

    late List<FeeReminder> reminders;
    await tester.runAsync(() async => reminders = await ledger.reminders());
    expect(reminders.single.studentId, target.student.id);
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  });
}
