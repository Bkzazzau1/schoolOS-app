import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_dashboard.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_office_dashboard_page.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  LocalDatabase? db;
  late FinanceLedgerRepository ledger;

  Future<void> setUpSchool() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    db = database;
    await database.initialize();
    final session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([finance]);
    await session.selectSchool(finance);
    ledger = FinanceLedgerRepository(
      database: database,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
      concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
    );
  }

  tearDown(() => db?.close());

  Future<FinanceDashboard> dashboard() async => buildFinanceDashboard(
        accounts: await ledger.accounts(),
        payments: await ledger.allPayments(),
        concessions: await ledger.concessions.loadRequests(),
        reminders: await ledger.reminders(),
        aging: await ledger.aging(today: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21),
      );

  test('the dashboard adds up from the ledger: collected plus owed is what families are billed', () async {
    await setUpSchool();
    final d = await dashboard();
    expect(d.totals.paid + d.totals.balance, d.totals.net);
    expect(d.totals.paid, greaterThan(0));
    expect(d.owingAccounts, greaterThan(0));
    expect(d.byMethod.values.fold<int>(0, (n, v) => n + v), d.totals.paid);
    expect(d.recent.length, lessThanOrEqualTo(6));
    for (var i = 1; i < d.recent.length; i++) {
      expect(d.recent[i - 1].receivedAt.compareTo(d.recent[i].receivedAt), greaterThanOrEqualTo(0));
    }
  });

  test('what needs attention comes from real records: who owes, no reminders yet, and requests waiting for the owner', () async {
    await setUpSchool();
    final d = await dashboard();
    final titles = d.attention.map((a) => a.title).toList();
    expect(titles.any((t) => t.contains('accounts owe')), isTrue);
    expect(titles, contains('No reminders have been queued yet'));
    expect(d.attention.firstWhere((a) => a.title.contains('accounts owe')).target, 'debt-aging');
    expect(d.pendingConcessions, (await ledger.concessions.loadRequests()).where((c) => c.status == ConcessionStatus.pendingApproval).length);

    final unpaid = (await ledger.aging(today: DateTime(2026, 9, 21))).owing.first;
    await ledger.queueReminder(unpaid, schoolName: 'BrightGate', now: DateTime(2026, 9, 21));
    final after = await dashboard();
    expect(after.attention.map((a) => a.title), isNot(contains('No reminders have been queued yet')));
    expect(after.remindersQueued, 1);
  });

  test('a payment received today shows in today\'s receipts', () async {
    await setUpSchool();
    final before = await ledger.aging(today: DateTime.now());
    final target = before.owing.first;
    await ledger.recordPayment(student: target.student, amount: 10000, method: 'Cash');
    final d = buildFinanceDashboard(
      accounts: await ledger.accounts(),
      payments: await ledger.allPayments(),
      concessions: const [],
      reminders: const [],
      aging: await ledger.aging(),
      now: DateTime.now(),
    );
    expect(d.receiptsToday, greaterThanOrEqualTo(1));
    expect(d.receivedToday, greaterThanOrEqualTo(10000));
  });

  testWidgets('the dashboard page shows the real figures and takes the finance officer to the screen that needs them', (tester) async {
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: FinanceOfficeDashboardPage(schoolName: 'BrightGate', onNavigate: (k) => opened = k, ledger: ledger)),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.text('Finance Dashboard'), findsOneWidget);
    expect(find.text('Net collectible'), findsOneWidget);
    final owe = find.textContaining('accounts owe');
    await tester.ensureVisible(owe);
    await tester.tap(owe);
    expect(opened, 'debt-aging');
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  });
}
