import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_billing.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_ledger_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/concession_request.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

String sectionOfClassName(String c) => c.startsWith('Primary') ? 'Primary' : (c.startsWith('Nursery') ? 'Early Years' : 'Secondary');

ConcessionRequest concession(String id, String student, String className, int amount, ConcessionStatus status) => ConcessionRequest(
      id: id,
      student: student,
      className: className,
      type: ConcessionType.discount,
      grossFee: 145000,
      amount: amount,
      reason: 'Sibling',
      requestedBy: 'Finance',
      requestedByRole: 'Finance',
      requestedAt: '1 Sep',
      status: status,
    );

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late FinanceLedgerRepository ledger;

  Future<void> setUpSchool([SchoolMembership who = finance]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([finance, teacher]);
    await session.selectSchool(who);
    ledger = FinanceLedgerRepository(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
      concessions: ConcessionRepository(localDatabase: db, schoolSession: session),
    );
  }

  Future<StudentAccount> account(String id) async => (await ledger.accounts()).firstWhere((a) => a.student.id == id);

  tearDown(() => db.close());

  test('every student is billed their section fees, less approved concessions, less what they have paid', () async {
    await setUpSchool();
    final accounts = await ledger.accounts();
    expect(accounts.length, greaterThan(15));
    expect(accounts.firstWhere((a) => a.section == 'Primary').gross, 145000);
    expect(accounts.firstWhere((a) => a.section == 'Secondary').gross, 185000);
    expect(accounts.firstWhere((a) => a.section == 'Early Years').gross, 117500);
    for (final a in accounts) {
      expect(a.balance, a.net - a.paid);
      expect(a.balance, greaterThanOrEqualTo(0));
    }
    final t = totalsOf(accounts);
    expect(t.paid, greaterThan(0));
    expect(t.balance, greaterThan(0));
    expect(t.paid + t.balance, t.net);
  });

  test('an approved concession lowers the bill, a pending one does not', () async {
    await setUpSchool();
    final structs = await ledger.structures(financeCurrentTerm);
    final students = (await AdministratorStudentsRepository(localDatabase: db, schoolSession: session).load()).students;
    final target = students.firstWhere((s) => s.className.startsWith('Primary'));

    List<StudentAccount> bill(List<ConcessionRequest> concessions) => buildAccounts(
          students: [target],
          structures: structs,
          concessions: concessions,
          payments: const [],
          term: financeCurrentTerm,
          sectionOf: sectionOfClassName,
        );

    final base = bill(const []).first;
    final withConcession = bill([
      concession('C1', target.name, target.className, 10000, ConcessionStatus.approved),
      concession('C2', target.name, target.className, 50000, ConcessionStatus.pendingApproval),
    ]).first;
    expect(withConcession.concession, 10000);
    expect(withConcession.net, base.net - 10000);
  });

  test('the fee structure is changed, and a section is re-billed at once', () async {
    await setUpSchool();
    final before = (await ledger.accounts()).firstWhere((a) => a.section == 'Primary').gross;
    final saved = await ledger.saveStructure(
      term: financeCurrentTerm,
      section: 'Primary',
      items: const [FeeItem(name: 'Tuition', amount: 120000), FeeItem(name: 'Books', amount: 20000)],
    );
    expect(saved.success, isTrue, reason: saved.message);
    final after = (await ledger.accounts()).firstWhere((a) => a.section == 'Primary').gross;
    expect(before, 145000);
    expect(after, 140000);
    expect(db.pendingCount(tenantId: finance.schoolId), greaterThan(0));
  });

  test('a fee structure needs named, unique charges with amounts above zero', () async {
    await setUpSchool();
    Future<String> save(List<FeeItem> items) async =>
        (await ledger.saveStructure(term: financeCurrentTerm, section: 'Primary', items: items)).message;
    expect(await save(const []), contains('at least one'));
    expect(await save(const [FeeItem(name: ' ', amount: 5)]), contains('needs a name'));
    expect(await save(const [FeeItem(name: 'Tuition', amount: 0)]), contains('above zero'));
    expect(await save(const [FeeItem(name: 'Tuition', amount: 5), FeeItem(name: 'tuition', amount: 6)]), contains('same name'));
    final nowhere = await ledger.saveStructure(term: financeCurrentTerm, section: 'Nowhere', items: const [FeeItem(name: 'A', amount: 1)]);
    expect(nowhere.success, isFalse);
  });

  test('a payment gets the next receipt number, reduces the balance, and is refused when it is more than owed', () async {
    await setUpSchool();
    final unpaid = (await ledger.accounts()).firstWhere((a) => a.status == AccountStatus.unpaid);
    final before = unpaid.balance;

    final tooMuch = await ledger.recordPayment(student: unpaid.student, amount: before + 1, method: 'Cash');
    expect(tooMuch.success, isFalse);
    expect(tooMuch.message, contains('more than'));

    final part = await ledger.recordPayment(student: unpaid.student, amount: 50000, method: 'Cash');
    expect(part.success, isTrue, reason: part.message);
    expect(part.payment!.receiptNumber, matches(RegExp(r'^RCT-[0-9]{6}$')));
    final after = await account(unpaid.student.id);
    expect(after.balance, before - 50000);
    expect(after.status, AccountStatus.partPaid);

    final rest = await ledger.recordPayment(student: unpaid.student, amount: after.balance, method: 'Cash');
    expect(rest.success, isTrue);
    expect((await account(unpaid.student.id)).status, AccountStatus.paid);
    expect((await ledger.recordPayment(student: unpaid.student, amount: 1, method: 'Cash')).message, contains('nothing left'));
    expect(int.parse(rest.payment!.receiptNumber.substring(4)), greaterThan(int.parse(part.payment!.receiptNumber.substring(4))));
  });

  test('a transfer or POS payment needs its reference, and a reference cannot be used twice', () async {
    await setUpSchool();
    final unpaid = (await ledger.accounts()).where((a) => a.status == AccountStatus.unpaid).toList();
    final a = unpaid.first.student;
    final b = unpaid[1].student;
    expect((await ledger.recordPayment(student: a, amount: 1000, method: 'Bank transfer')).message, contains('reference'));
    expect((await ledger.recordPayment(student: a, amount: 1000, method: 'POS', reference: 'POS-77')).success, isTrue);
    expect((await ledger.recordPayment(student: b, amount: 1000, method: 'POS', reference: 'pos-77')).message, contains('already been recorded'));
    expect((await ledger.recordPayment(student: b, amount: 1000, method: 'Cheque')).success, isFalse);
    expect((await ledger.recordPayment(student: b, amount: 0, method: 'Cash')).success, isFalse);
  });

  test('a voided payment is kept with its reason and no longer counts as paid', () async {
    await setUpSchool();
    final unpaid = (await ledger.accounts()).firstWhere((a) => a.status == AccountStatus.unpaid);
    final paid = (await ledger.recordPayment(student: unpaid.student, amount: 40000, method: 'Cash')).payment!;
    expect((await account(unpaid.student.id)).paid, 40000);

    expect((await ledger.voidPayment(paid, '')).message, contains('Say why'));
    final voided = await ledger.voidPayment(paid, 'Entered against the wrong child');
    expect(voided.success, isTrue);
    final after = await account(unpaid.student.id);
    expect(after.paid, 0);
    expect(after.payments.single.isVoided, isTrue);
    expect(after.payments.single.voidedReason, 'Entered against the wrong child');
    expect((await ledger.voidPayment(voided.payment!, 'again')).message, contains('already voided'));
  });

  test('only the finance office or the owner can change fees and payments', () async {
    await setUpSchool(teacher);
    final any = (await ledger.accounts()).first;
    expect((await ledger.recordPayment(student: any.student, amount: 1000, method: 'Cash')).message, contains('finance office'));
    final save = await ledger.saveStructure(term: financeCurrentTerm, section: 'Primary', items: const [FeeItem(name: 'A', amount: 1)]);
    expect(save.success, isFalse);
  });

  test('another term starts from the default fees in the demo school', () async {
    await setUpSchool();
    final structs = await ledger.structures('2026/2027 · Term 2');
    expect(structs.length, 3);
    expect(structs.every((s) => s.total > 0), isTrue);
  });
}
