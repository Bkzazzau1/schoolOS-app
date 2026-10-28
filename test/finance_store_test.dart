import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_store_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late FinanceStoreRepository store;

  Future<void> setUpSchool([SchoolMembership who = finance]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([finance, teacher]);
    await session.selectSchool(finance);
    await seedClassicRoster(db, tenantId: finance.schoolId);
    store = FinanceStoreRepository(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    await session.selectSchool(who);
  }

  tearDown(() => db.close());

  test('the owner or Finance Office can stock an item', () async {
    await setUpSchool();
    expect((await store.saveItem(name: 'Uniform (Small)', price: 8000, stock: 10)).success, isTrue);
    final items = await store.items();
    expect(items.single.name, 'Uniform (Small)');
    expect(items.single.stock, 10);
  });

  test('a teacher may not stock the store', () async {
    await setUpSchool(teacher);
    final result = await store.saveItem(name: 'Uniform', price: 8000, stock: 10);
    expect(result.success, isFalse);
    expect(result.message, contains('Finance Office'));
  });

  test('restocking an existing item updates it in place rather than duplicating it', () async {
    await setUpSchool();
    final first = await store.saveItem(name: 'Pencil', price: 200, stock: 50);
    expect(first.success, isTrue);
    final id = (await store.items()).single.id;
    await store.saveItem(id: id, name: 'Pencil', price: 200, stock: 80);
    final items = await store.items();
    expect(items.length, 1);
    expect(items.single.stock, 80);
  });

  test('a sale reduces stock and gets a numbered receipt', () async {
    await setUpSchool();
    await store.saveItem(id: 'ITEM-1', name: 'Uniform', price: 8000, stock: 10);
    final roster = await store.studentRegister();
    final result = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 2)], method: 'Cash',
    );
    expect(result.success, isTrue);
    expect(result.message, contains('STR-000001'));
    expect((await store.items()).single.stock, 8);
    expect((await store.sales()).single.amount, 16000);
  });

  test('a sale is refused when there is not enough stock', () async {
    await setUpSchool();
    await store.saveItem(id: 'ITEM-1', name: 'Uniform', price: 8000, stock: 1);
    final roster = await store.studentRegister();
    final result = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 2)], method: 'Cash',
    );
    expect(result.success, isFalse);
    expect(result.message, contains('left in stock'));
    expect((await store.items()).single.stock, 1);
  });

  test('a non-cash sale needs a reference, and the same reference cannot be used twice', () async {
    await setUpSchool();
    await store.saveItem(id: 'ITEM-1', name: 'Uniform', price: 8000, stock: 10);
    final roster = await store.studentRegister();
    final noRef = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 1)], method: 'POS',
    );
    expect(noRef.success, isFalse);

    final first = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 1)], method: 'POS', reference: 'REF-1',
    );
    expect(first.success, isTrue);
    final second = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 1)], method: 'POS', reference: 'REF-1',
    );
    expect(second.success, isFalse);
  });

  test('voiding a sale restores the stock it took', () async {
    await setUpSchool();
    await store.saveItem(id: 'ITEM-1', name: 'Uniform', price: 8000, stock: 10);
    final roster = await store.studentRegister();
    await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [(itemId: 'ITEM-1', quantity: 3)], method: 'Cash',
    );
    expect((await store.items()).single.stock, 7);
    final sale = (await store.sales()).single;
    final result = await store.voidSale(sale, 'Typed twice');
    expect(result.success, isTrue);
    expect((await store.items()).single.stock, 10);
    expect((await store.sales()).single.isVoided, isTrue);
  });

  test('a sale with no items is refused', () async {
    await setUpSchool();
    final roster = await store.studentRegister();
    final result = await store.recordSale(
      studentId: roster.first.id, studentName: roster.first.name, className: roster.first.className,
      lines: const [], method: 'Cash',
    );
    expect(result.success, isFalse);
  });
}
