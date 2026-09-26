import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/familyfees/data/family_fees_api.dart';
import 'package:schoolos_app/features/finance_office/data/finance_ledger_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_children_repository.dart';
import 'package:schoolos_app/features/parent/data/parent_finance_repository.dart';
import 'package:schoolos_app/features/parent/domain/parent_finance_models.dart';
import 'package:schoolos_app/features/parent/presentation/parent_finance_page.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'family_fees_fixtures.dart';

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
    }
  });

  test('a child has no account number: where a family pays belongs to the family, never to a child', () async {
    await setUpFamily();
    final view = await finance.load();
    // Nothing that describes a child carries an account number, so a child's internal id can never be shown as one.
    expect(jsonEncode(view.snapshot.toJson()), isNot(contains('accountNumber')));
    expect(view.snapshot.children, hasLength(2));
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

  test('only a Parent membership can load family finance', () async {
    await setUpFamily(teacher);
    expect(finance.load(), throwsStateError);
  });

  testWidgets(
    'the page renders for a fresh family with no mandate configured, without crashing the mandate picker',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await setUpFamily();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParentFinancePage(repository: finance, onQueueChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A fresh family's real mandate honestly has no collection method configured
      // ("Not recorded yet"), which is not one of the picker's own selectable options; the page must
      // still render the picker with a real default instead of crashing on that mismatch.
      expect(find.text('Automatic payment mandate'), findsOneWidget);
      expect(find.text('Bank direct debit · prototype'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('where the family pays', () {
    Future<void> pumpPage(WidgetTester tester, {Future<http.Response> Function(http.Request)? server}) async {
      tester.view.physicalSize = const Size(1600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await setUpFamily();
      Widget page = MaterialApp(home: Scaffold(body: ParentFinancePage(repository: finance, onQueueChanged: () {})));
      if (server != null) page = FamilyFeesScope(api: FamilyFeesApi(api: apiFor(FakeServer(server))), child: page);
      await tester.pumpWidget(page);
      await tester.pumpAndSettle();
    }

    Future<http.Response> families(List<Map<String, Object?>> accounts) async => jsonResponse(myFamiliesJson([myFamilyJson(accounts: accounts)]));

    testWidgets('with no school server it says no account can be shown and makes none up', (tester) async {
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('family-account-no-server')), findsOneWidget);
      expect(find.text('Your family\'s payment account'), findsOneWidget);
      // A child's internal id is never offered as somewhere to pay.
      for (final id in ['STU-001', 'PRI-003']) {
        expect(find.text(id), findsNothing);
      }
      expect(find.text('Student term accounts'), findsNothing);
    });

    testWidgets('the family account is shown once for all the children, under the bank\'s own word for the number', (tester) async {
      await pumpPage(tester, server: (_) => families([payAccountJson()]));
      expect(find.text('0123456789'), findsOneWidget);
      expect(find.text('Account number'), findsOneWidget);
      expect(find.text('GTBank'), findsOneWidget);
      expect(find.text('Account name: BRIGHTGATE / BELLO'), findsOneWidget);
      // One account for the family, not one per child: two children, one number.
      expect(find.byKey(const ValueKey('family-account-acc-1')), findsOneWidget);
    });

    testWidgets('a bank whose account is not a plain number shows what that bank gives, and its extra facts to quote', (tester) async {
      await pumpPage(
        tester,
        server: (_) => families([
          payAccountJson(
            id: 'acc-2', provider: 'moniepoint', bankName: 'Moniepoint', accountNumber: 'MP-4471-2209', numberLabel: 'Payment code',
            details: [
              {'label': 'Payment reference', 'value': 'BG-0042'},
              {'label': 'Sort code', 'value': '090405'},
            ],
            note: 'Pay from any bank app.',
          ),
        ]),
      );
      expect(find.text('Payment code'), findsOneWidget);
      expect(find.text('MP-4471-2209'), findsOneWidget);
      expect(find.text('Payment reference: BG-0042'), findsOneWidget);
      expect(find.text('Sort code: 090405'), findsOneWidget);
      expect(find.text('Pay from any bank app.'), findsOneWidget);
      expect(find.text('Account number'), findsNothing);
    });

    testWidgets('a family may hold accounts with several banks, each shown', (tester) async {
      await pumpPage(
        tester,
        server: (_) => families([
          payAccountJson(),
          payAccountJson(id: 'acc-2', provider: 'uba', bankName: 'UBA', accountNumber: '1000000001'),
        ]),
      );
      expect(find.text('0123456789'), findsOneWidget);
      expect(find.text('1000000001'), findsOneWidget);
      expect(find.text('GTBank'), findsOneWidget);
      expect(find.text('UBA'), findsOneWidget);
    });

    testWidgets('an account still being set up, or paused by the school, shows no number to pay into', (tester) async {
      await pumpPage(
        tester,
        server: (_) => families([
          payAccountJson(id: 'acc-1', status: 'provisioning'),
          payAccountJson(id: 'acc-2', provider: 'uba', bankName: 'UBA', accountNumber: '1000000001', status: 'suspended'),
        ]),
      );
      expect(find.textContaining('still setting this account up'), findsOneWidget);
      expect(find.textContaining('paused this account'), findsOneWidget);
      expect(find.text('0123456789'), findsNothing);
      expect(find.text('1000000001'), findsNothing);
    });

    testWidgets('a test account is labelled as one', (tester) async {
      await pumpPage(tester, server: (_) => families([payAccountJson(provider: 'sandbox', bankName: 'SchoolOS Test Bank', isTest: true)]));
      expect(find.text('Test account'), findsOneWidget);
    });

    testWidgets('a family with no account yet is told so, and nothing else is offered', (tester) async {
      await pumpPage(tester, server: (_) => families(const []));
      expect(find.byKey(const ValueKey('family-account-none')), findsOneWidget);
      expect(find.textContaining('has not set up a payment account for your family yet'), findsOneWidget);
    });

    testWidgets('when the server cannot be reached it says so and can be asked again', (tester) async {
      var calls = 0;
      await pumpPage(tester, server: (_) async {
        calls++;
        return calls == 1 ? jsonResponse({'message': 'The school server is having trouble.'}, 500) : families([payAccountJson()]);
      });
      expect(find.byKey(const ValueKey('family-account-error')), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('0123456789'), findsOneWidget);
    });

    testWidgets('it asks the school\'s server for this parent\'s families and nothing else', (tester) async {
      final server = FakeServer((_) => families([payAccountJson()]));
      tester.view.physicalSize = const Size(1600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await setUpFamily();
      await tester.pumpWidget(
        FamilyFeesScope(
          api: FamilyFeesApi(api: apiFor(server)),
          child: MaterialApp(home: Scaffold(body: ParentFinancePage(repository: finance, onQueueChanged: () {}))),
        ),
      );
      await tester.pumpAndSettle();
      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/schools/school-1/receivables/me/families/');
      expect(request.url.queryParameters, {'membership': 'm-parent'});
    });

    testWidgets('paying for several children at once gives one total to transfer, and no payment request is queued', (tester) async {
      await pumpPage(tester, server: (_) => families([payAccountJson()]));
      expect(find.text('Pay for several children at once'), findsOneWidget);
      expect(find.text('Total to transfer'), findsOneWidget);
      expect(find.text('Copy total'), findsOneWidget);
      expect(find.textContaining('queued'), findsNothing);
      expect(find.textContaining('SchoolOS does not receive or hold your payment'), findsWidgets);
    });
  });
}
