import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_cashflow_repository.dart';
import 'package:schoolos_app/features/finance_office/data/finance_store_repository.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_cashflow_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_cashflow_page.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_store_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late FinanceStoreRepository store;
  late FinanceCashflowRepository cashbook;

  Future<void> setUpSchool() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, finance]);
    await session.selectSchool(finance);
    await seedClassicRoster(db, tenantId: finance.schoolId);
    store = FinanceStoreRepository(
      database: db, session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    cashbook = FinanceCashflowRepository(database: db, session: session);
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
    final problem = tester.takeException();
    expect(problem == null || problem.toString().contains('overflowed'), isTrue, reason: '$problem');
  }

  tearDown(() => db.close());

  testWidgets('adding an item and recording a sale reduces stock on the School Store page', (tester) async {
    bigScreen(tester);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceStorePage(repository: store))));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('store-add-item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('store-item-name')), 'Uniform (Small)');
    await tester.enterText(find.byKey(const ValueKey('store-item-price')), '8000');
    await tester.enterText(find.byKey(const ValueKey('store-item-stock')), '10');
    await tester.tap(find.byKey(const ValueKey('store-item-save')));
    await settle(tester);
    expect(find.text('Uniform (Small)'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('store-record-sale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store-sale-student')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yusuf Bello · JSS 2B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store-sale-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uniform (Small) (10 left)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('store-sale-quantity')), '2');
    await tester.tap(find.byKey(const ValueKey('store-sale-add-line')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('store-sale-submit')));
    await settle(tester);

    late int stock;
    await tester.runAsync(() async => stock = (await store.items()).single.stock);
    expect(stock, 8);
    expectNoRealError(tester);
  });

  testWidgets('recording an expense and approving it on the Expenses & Income page', (tester) async {
    bigScreen(tester);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceCashflowPage(key: const ValueKey('cashbook-as-finance'), repository: cashbook))));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('cashbook-add-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cashbook-description')), 'Generator fuel');
    await tester.enterText(find.byKey(const ValueKey('cashbook-amount')), '25000');
    await tester.tap(find.byKey(const ValueKey('cashbook-submit')));
    await settle(tester);

    late CashflowEntry pending;
    await tester.runAsync(() async => pending = (await cashbook.entries()).single);
    expect(pending.status, CashflowStatus.pendingApproval);

    // Not a billing authority yet: no approve/decline buttons on their own pending entry.
    expect(find.byKey(ValueKey('cashbook-approve-${pending.id}')), findsNothing);

    await tester.runAsync(() => session.selectSchool(owner));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FinanceCashflowPage(key: const ValueKey('cashbook-as-owner'), repository: cashbook))));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('cashbook-approve-${pending.id}')));
    await settle(tester);

    late CashflowEntry decided;
    await tester.runAsync(() async => decided = (await cashbook.entries()).single);
    expect(decided.status, CashflowStatus.approved);
    expectNoRealError(tester);
  });
}
