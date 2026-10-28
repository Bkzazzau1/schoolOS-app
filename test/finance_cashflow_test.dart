import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/finance_office/data/finance_cashflow_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_cashflow_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late FinanceCashflowRepository cashbook;

  Future<void> setUpSchool([SchoolMembership who = finance]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, finance, teacher]);
    await session.selectSchool(owner);
    cashbook = FinanceCashflowRepository(database: db, session: session);
    await session.selectSchool(who);
  }

  tearDown(() => db.close());

  test('income posts immediately with no approval needed', () async {
    await setUpSchool();
    final result = await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'PTA donation', type: CashflowType.income,
      category: 'Donation', amount: 50000,
    );
    expect(result.success, isTrue);
    expect((await cashbook.entries()).single.status, CashflowStatus.posted);
  });

  test('an expense starts pending approval', () async {
    await setUpSchool();
    await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Generator fuel', type: CashflowType.expense,
      category: 'Utilities', amount: 25000,
    );
    expect((await cashbook.entries()).single.status, CashflowStatus.pendingApproval);
  });

  test('a teacher may not record an entry', () async {
    await setUpSchool(teacher);
    final result = await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 1000,
    );
    expect(result.success, isFalse);
    expect(result.message, contains('Finance Office'));
  });

  test('the owner may approve an expense and the decision sticks', () async {
    await setUpSchool();
    await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 25000,
    );
    await session.selectSchool(owner);
    final entry = (await cashbook.entries()).single;
    final result = await cashbook.decide(entry, approve: true);
    expect(result.success, isTrue);
    expect((await cashbook.entries()).single.status, CashflowStatus.approved);
  });

  test('accountant alone may not approve, even their own expense', () async {
    await setUpSchool();
    await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 25000,
    );
    final entry = (await cashbook.entries()).single;
    final result = await cashbook.decide(entry, approve: true);
    expect(result.success, isFalse);
    expect(result.message, contains('billing authority'));
  });

  test('declining needs a reason', () async {
    await setUpSchool();
    await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 25000,
    );
    await session.selectSchool(owner);
    final entry = (await cashbook.entries()).single;
    final noReason = await cashbook.decide(entry, approve: false);
    expect(noReason.success, isFalse);
    final withReason = await cashbook.decide(entry, approve: false, note: 'Not budgeted this term');
    expect(withReason.success, isTrue);
    expect((await cashbook.entries()).single.status, CashflowStatus.declined);
  });

  test('a decision is final', () async {
    await setUpSchool();
    await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 25000,
    );
    await session.selectSchool(owner);
    final entry = (await cashbook.entries()).single;
    await cashbook.decide(entry, approve: true);
    final decided = (await cashbook.entries()).single;
    final result = await cashbook.decide(decided, approve: false, note: 'Too late');
    expect(result.success, isFalse);
    expect(result.message, contains('already'));
  });

  test('an unknown category or a zero amount is refused', () async {
    await setUpSchool();
    final badCategory = await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Bribes', amount: 1000,
    );
    expect(badCategory.success, isFalse);
    final zero = await cashbook.recordEntry(
      date: DateTime(2026, 9, 15), description: 'Fuel', type: CashflowType.expense, category: 'Utilities', amount: 0,
    );
    expect(zero.success, isFalse);
  });
}
