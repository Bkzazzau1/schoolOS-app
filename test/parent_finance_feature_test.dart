import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_finance_repository.dart';
import 'package:schoolos_app/features/parent/domain/parent_finance_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const parent = SchoolMembership(id: 'm-parent', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.parent);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const accountant = SchoolMembership(id: 'm-accountant', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late ParentFinanceRepository finance;
  late FinanceLedgerRepository ledger;

  Future<void> setUpFamily([SchoolMembership who = parent]) async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([parent, teacher, accountant]);
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
    ledger = FinanceLedgerRepository(
      database: database,
      session: session,
      students: students,
      concessions: ConcessionRepository(localDatabase: database, schoolSession: session),
    );
    finance = ParentFinanceRepository(
      localDatabase: database,
      schoolSession: session,
      children: children,
      ledger: ledger,
    );
  }

  tearDown(() => db?.close());

  test('child accounts match the same real ledger Finance Office reads, never a disconnected number', () async {
    await setUpFamily();
    final view = await finance.load();
    final accounts = await ledger.accounts();
    expect(view.snapshot.children.map((c) => c.id).toList(), ['STU-001', 'PRI-003']);
    for (final child in view.snapshot.children) {
      final real = accounts.singleWhere((a) => a.student.id == child.id);
      expect(child.grossFees, real.gross);
      expect(child.paidAmount, real.paid);
      expect(child.balance, real.balance);
      expect(child.netFees, child.paidAmount + child.balance);
      // No real bank-account-number concept exists; the real system id stands in, honestly
      // unique per child, instead of an invented bank account number.
      expect(child.accountNumber, child.id);
      expect(child.bank, 'Not recorded yet');
    }
  });

  test('receipts and ledger entries are the real payments, with a reconciling running balance', () async {
    await setUpFamily();
    final view = await finance.load();
    final accounts = await ledger.accounts();
    for (final child in view.snapshot.children) {
      final real = accounts.singleWhere((a) => a.student.id == child.id);
      final realPaymentCount = real.payments.where((p) => !p.isVoided).length;
      final receipts = view.snapshot.receipts.where((r) => r.childId == child.id).toList();
      final entries = view.snapshot.ledger.where((e) => e.childId == child.id).toList();
      expect(receipts.length, realPaymentCount);
      expect(entries.length, realPaymentCount);
      for (final receipt in receipts) {
        expect(receipt.previousBalance - receipt.amount, receipt.newBalance);
        expect(receipt.admissionNumber, 'Not recorded yet');
      }
    }
  });

  test('reminders are scoped to the linked children and use the real reminder level label', () async {
    await setUpFamily();
    final view = await finance.load();
    final linkedIds = view.snapshot.children.map((c) => c.id).toSet();
    for (final reminder in view.snapshot.reminders) {
      expect(linkedIds, contains(reminder.childId));
      expect(reminder.status, isNot('Not recorded yet'));
    }
  });

  test('reminder history and store orders are honestly empty: no real source exists for either', () async {
    await setUpFamily();
    final view = await finance.load();
    expect(view.snapshot.reminderHistory, isEmpty);
    expect(view.snapshot.storeOrders, isEmpty);
  });

  test('a fresh family has no mandate set up, honestly disabled rather than a fabricated active one', () async {
    await setUpFamily();
    final view = await finance.load();
    expect(view.snapshot.mandate.enabled, isFalse);
    expect(view.mandateQueued, isFalse);
  });

  test('saving a mandate preference round-trips and queues for sync', () async {
    await setUpFamily();
    await finance.saveMandatePreference(const ParentPaymentMandatePreference(
      enabled: true,
      monthlyAmount: 20000,
      debitDay: '25th',
      collectionMethod: 'Bank direct debit',
    ));
    final view = await finance.load();
    expect(view.snapshot.mandate.enabled, isTrue);
    expect(view.snapshot.mandate.monthlyAmount, 20000);
    expect(view.mandateQueued, isTrue);
    expect(db!.pendingCount(tenantId: parent.schoolId), greaterThan(0));
  });

  test('a combined payment across both real children is queued and validated against real balances', () async {
    await setUpFamily();
    // In a fresh demo ledger Maryam's seeded payment happens to cover her fees in full, so give
    // her a real outstanding balance the same way a real accountant would: void that payment.
    await session.selectSchool(accountant);
    final accounts = await ledger.accounts();
    final maryamAccount = accounts.singleWhere((a) => a.student.id == 'STU-001');
    await ledger.voidPayment(maryamAccount.payments.single, 'Test setup: reopen a real balance');
    await session.selectSchool(parent);

    final view = await finance.load();
    final maryam = view.snapshot.children.firstWhere((c) => c.id == 'STU-001');
    final hafsa = view.snapshot.children.firstWhere((c) => c.id == 'PRI-003');
    expect(maryam.balance, greaterThan(0));
    expect(hafsa.balance, greaterThan(0));

    final request = await finance.queueCombinedPayment(allocations: [
      ParentCombinedPaymentAllocation(childId: maryam.id, childName: maryam.name, accountNumber: maryam.accountNumber, amount: 1000),
      ParentCombinedPaymentAllocation(childId: hafsa.id, childName: hafsa.name, accountNumber: hafsa.accountNumber, amount: 1000),
    ]);
    expect(request.total, 2000);
    final after = await finance.load();
    expect(after.pendingCombinedRequests, hasLength(1));
  });

  test('a combined payment above the real balance is rejected', () async {
    await setUpFamily();
    final view = await finance.load();
    final maryam = view.snapshot.children.firstWhere((c) => c.id == 'STU-001');
    final hafsa = view.snapshot.children.firstWhere((c) => c.id == 'PRI-003');
    expect(
      finance.queueCombinedPayment(allocations: [
        ParentCombinedPaymentAllocation(childId: maryam.id, childName: maryam.name, accountNumber: maryam.accountNumber, amount: maryam.balance + 999999),
        ParentCombinedPaymentAllocation(childId: hafsa.id, childName: hafsa.name, accountNumber: hafsa.accountNumber, amount: 1000),
      ]),
      throwsStateError,
    );
  });

  test('only a Parent membership can load family finance', () async {
    await setUpFamily(teacher);
    expect(finance.load(), throwsStateError);
  });
}
