import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/finance_office/data/finance_facts.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_reconciliation.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_ledger_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_ai_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_reconciliation_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_reports_page.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

Payment payment(String id, int amount, String method, String reference, {String voided = ''}) => Payment(
      id: id,
      receiptNumber: 'RCT-$id',
      studentId: 'S$id',
      studentName: 'Student $id',
      className: 'Primary 3',
      term: financeCurrentTerm,
      amount: amount,
      method: method,
      receivedAt: '2026-09-10T09:00:00Z',
      reference: reference,
      voidedReason: voided,
    );

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

  test('reconciliation matches by reference and amount, and separates what needs a look', () {
    final report = reconcile(
      lines: const [
        BankLine(id: 'L1', date: '2026-09-10', amount: 50000, reference: 'REF1'),
        BankLine(id: 'L2', date: '2026-09-10', amount: 30500, reference: 'ref2'),
        BankLine(id: 'L3', date: '2026-09-11', amount: 20000, reference: 'NOBODY'),
      ],
      payments: [
        payment('1', 50000, 'Bank transfer', 'REF1'),
        payment('2', 30000, 'POS', 'REF2'),
        payment('3', 15000, 'Bank transfer', 'REF3'),
        payment('4', 10000, 'Cash', ''),
        payment('5', 12000, 'POS', 'REF5', voided: 'Wrong child'),
      ],
    );
    expect(report.matched.single.payment.id, '1');
    expect(report.amountMismatches.single.payment.id, '2');
    expect(report.unmatchedLines.single.reference, 'NOBODY');
    expect(report.unmatchedPayments.map((p) => p.id), ['3'], reason: 'cash and voided receipts are not expected on a statement');
    expect(report.clear, isFalse);
    expect(reconcile(lines: const [], payments: const []).clear, isTrue);
  });

  test('the demo statement has matches, a disagreement and unrecorded money, and recording it from the statement clears the line', () async {
    await setUpSchool();
    final before = await ledger.reconciliation();
    expect(before.matched, isNotEmpty);
    expect(before.amountMismatches.length, 1);
    expect(before.unmatchedLines.length, 2);
    expect(before.unmatchedPayments, isNotEmpty);

    final line = before.unmatchedLines.first;
    final student = (await ledger.aging(today: DateTime(2026, 9, 21))).owing.firstWhere((a) => a.balance >= line.amount).student;
    final done = await ledger.recordFromStatement(line, student);
    expect(done.success, isTrue, reason: done.message);
    final after = await ledger.reconciliation();
    expect(after.unmatchedLines.length, 1);
    expect(after.matched.length, before.matched.length + 1);
  });

  test('a statement line needs an amount and a reference, and the same reference cannot be added twice', () async {
    await setUpSchool();
    expect((await ledger.addBankLine(date: DateTime(2026, 9, 21), amount: 0, reference: 'X1')).message, contains('above zero'));
    expect((await ledger.addBankLine(date: DateTime(2026, 9, 21), amount: 5000, reference: ' ')).message, contains('reference'));
    expect((await ledger.addBankLine(date: DateTime(2026, 9, 21), amount: 5000, reference: 'X1')).success, isTrue);
    expect((await ledger.addBankLine(date: DateTime(2026, 9, 21), amount: 5000, reference: 'x1')).message, contains('already on the statement'));
  });

  test('only the finance office or the owner can add statement lines', () async {
    await setUpSchool(teacher);
    expect((await ledger.addBankLine(date: DateTime(2026, 9, 21), amount: 5000, reference: 'X1')).success, isFalse);
  });

  test('the reports come from the ledger and say which areas are not recorded', () async {
    await setUpSchool();
    final facts = await loadFinanceFacts(ledger, now: DateTime(2026, 9, 21));
    final docs = buildFinanceReports(facts);
    expect(docs.where((d) => d.available).map((d) => d.title), [
      'Collection summary',
      'Outstanding fees',
      'Receipts register',
      'Scholarships & discounts',
      'Bank reconciliation',
    ]);
    expect(docs.where((d) => !d.available).map((d) => d.title), ['School store', 'Expenses & income', 'Payment mandates']);
    final summary = renderFinanceReport(docs.first);
    expect(summary, contains('Collected:'));
    final pack = renderFinancePack(schoolName: 'BrightGate', docs: docs, date: DateTime(2026, 9, 21));
    expect(pack, contains('Generated: 2026-09-21'));
    expect(pack, contains('NOT AVAILABLE YET'));
    expect(pack, contains('School store: The school store is not recorded yet.'));
  });

  test('the assistant answers from the ledger and refuses what is not recorded', () async {
    await setUpSchool();
    final service = FinanceAiService(await loadFinanceFacts(ledger, now: DateTime(2026, 9, 21)));
    final facts = service.facts;

    final owes = service.answer('Who owes the most?');
    expect(owes.answer, contains('accounts owe'));
    expect(owes.evidence.first, contains(facts.aging.owing.first.student.name));

    final collected = service.answer('How much have we collected this term?');
    expect(collected.answer, contains('${facts.totals.collectedPercent}%'));

    expect(service.answer('Compare collection by section').evidence.length, 3);
    expect(service.answer('How overdue are fees?').answer, contains('days overdue'));
    expect(service.answer('How did families pay?').evidence, isNotEmpty);
    expect(service.answer('Is the bank statement reconciled?').answer, contains('not fully reconciled'));
    for (final q in ['What is our profit?', 'Forecast next term income', 'How is the school store doing?']) {
      final a = service.answer(q);
      expect(a.answer, contains('not recorded'), reason: q);
      expect(a.evidence.join(' '), isNot(contains('₦')), reason: q);
    }
    expect(service.answer('What can the finance office not report yet?').evidence.length, 3);
    for (final prompt in financeAiPrompts) {
      expect(service.answer(prompt).answer, isNotEmpty, reason: prompt);
    }
    expect(owes.boundary, contains('does not contact families'));
  });

  testWidgets('the reconciliation, reports and assistant pages show the ledger', (tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceReconciliationPage(ledger: ledger))));
    await settle();
    expect(find.text('Bank money nobody recorded'), findsOneWidget);
    expect(find.byKey(const ValueKey('recon-add')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceReportsPage(ledger: ledger, schoolName: 'BrightGate'))));
    await settle();
    expect(find.byKey(const ValueKey('report-Collection summary')), findsOneWidget);
    expect(find.textContaining('Not available yet · The school store is not recorded yet.'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceAiPage(ledger: ledger))));
    await settle();
    expect(find.byKey(const ValueKey('finance-ai-answer')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('finance-ai-input')), 'What is our profit?');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('not recorded yet'), findsWidgets);
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  });
}
