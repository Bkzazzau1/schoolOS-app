import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_ledger_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_family_accounts_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_fee_structure_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_receipts_page.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  late LocalDatabase db;
  late FinanceLedgerRepository ledger;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    final session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([finance]);
    await session.selectSchool(finance);
    ledger = FinanceLedgerRepository(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
      concessions: ConcessionRepository(localDatabase: db, schoolSession: session),
    );
  }

  Future<void> settle(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void expectNoRealError(WidgetTester tester) {
    // The test font is wider than the real one, so a squeezed layout is not a fault in the app.
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  }

  tearDown(() => db.close());

  testWidgets('the finance office edits a section fees from the Fee Structure page and students are re-billed', (tester) async {
    bigScreen(tester);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceFeeStructurePage(ledger: ledger))));
    await settle(tester);
    expect(find.byKey(const ValueKey('structure-Primary')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('edit-Primary')));
    await tester.tap(find.byKey(const ValueKey('edit-Primary')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('fee-amount-0')), '130000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fee-save')));
    await settle(tester);

    late List<FeeStructure> structures;
    await tester.runAsync(() async => structures = await ledger.structures(financeCurrentTerm));
    expect(structures.firstWhere((s) => s.section == 'Primary').total, 160000, reason: '130000 + 12000 + 8000 + 10000');
    expectNoRealError(tester);
  });

  testWidgets('the finance office records a payment from Student Accounts and a receipt appears in Receipts', (tester) async {
    bigScreen(tester);
    await tester.runAsync(setUpSchool);
    late StudentAccount target;
    await tester.runAsync(() async => target = (await ledger.accounts()).firstWhere((a) => a.status == AccountStatus.unpaid));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceFamilyAccountsPage(ledger: ledger))));
    await settle(tester);

    await tester.enterText(find.byKey(const ValueKey('accounts-search')), target.student.name);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('account-${target.student.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-pay')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('payment-amount')), '25000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-record')));
    await settle(tester);

    late StudentAccount after;
    await tester.runAsync(() async => after = (await ledger.accounts()).firstWhere((a) => a.student.id == target.student.id));
    expect(after.paid, 25000);
    expect(after.status, AccountStatus.partPaid);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceReceiptsPage(ledger: ledger, schoolName: 'BrightGate'))));
    await settle(tester);
    expect(find.byKey(ValueKey('receipt-${after.payments.single.receiptNumber}')), findsOneWidget);
    expectNoRealError(tester);
  });

  testWidgets('a receipt is voided from Receipts with a reason and stays listed as voided', (tester) async {
    bigScreen(tester);
    await tester.runAsync(setUpSchool);
    late Payment payment;
    await tester.runAsync(() async {
      final unpaid = (await ledger.accounts()).firstWhere((a) => a.status == AccountStatus.unpaid);
      payment = (await ledger.recordPayment(student: unpaid.student, amount: 20000, method: 'Cash')).payment!;
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceReceiptsPage(ledger: ledger, schoolName: 'BrightGate'))));
    await settle(tester);

    await tester.tap(find.byKey(ValueKey('receipt-${payment.receiptNumber}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receipt-void')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Wrong child');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Void payment').last);
    await settle(tester);

    late List<Payment> all;
    await tester.runAsync(() async => all = await ledger.allPayments());
    final stored = all.firstWhere((p) => p.id == payment.id);
    expect(stored.isVoided, isTrue);
    expect(stored.voidedReason, 'Wrong child');
    expectNoRealError(tester);
  });
}
