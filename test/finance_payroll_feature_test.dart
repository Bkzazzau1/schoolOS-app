import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_attendance_models.dart' show StaffAttendanceReviewStatus;
import 'package:schoolos_app/features/finance_office/data/finance_payroll_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_payroll_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_payroll_page.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  final mutations = <Map<Symbol, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values
              .where((r) =>
                  r.tenantId == a[#tenantId] && r.entityType == a[#entityType])
              .toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        mutations.add(a);
        return Future<String>.value('mutation-${mutations.length}');
    }
    return super.noSuchMethod(invocation);
  }
}

const _owner = SchoolMembership(
  id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);
const _finance = SchoolMembership(
  id: 'finance', schoolId: 'a', schoolName: 'A', role: SchoolRole.accountant);
const _principal = SchoolMembership(
  id: 'principal', schoolId: 'a', schoolName: 'A', role: SchoolRole.principal);
const _bursar = SchoolMembership(
  id: 'bursar', schoolId: 'a', schoolName: 'A', role: SchoolRole.accountant);

Future<SchoolSessionController> _session(SchoolMembership active) async {
  FlutterSecureStorage.setMockInitialValues({});
  final session = SchoolSessionController(store: SchoolSessionStore());
  await session.setMemberships([_owner, _finance, _principal, _bursar]);
  await session.selectSchool(active);
  return session;
}

void _seedSalaries(_Database db) {
  const rows = [
    ('STAFF-001', 'Mrs. Amina Yusuf', 250000, 56000),
    ('STAFF-014', 'Mr. Ahmad Sani', 238000, 48000),
    ('STAFF-099', 'Mrs. Zainab Musa', 310000, 71000),
  ];
  for (final r in rows) {
    db.records['a/${OwnerPayrollRepository.profileType}/${r.$1}'] = LocalRecord(
      tenantId: 'a',
      entityType: OwnerPayrollRepository.profileType,
      entityId: r.$1,
      payload: {
        'staffId': r.$1, 'name': r.$2, 'role': 'Teacher',
        'gross': r.$3, 'deductions': r.$4, 'onPayroll': true, 'history': [],
      },
      updatedAt: DateTime.now(),
      isDirty: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payroll attendance context comes from the real staff attendance register, matched by real id', () async {
    final db = _Database();
    final session = await _session(_finance);
    addTearDown(session.dispose);
    final attendance = await AdministratorStaffAttendanceRepository(localDatabase: db, schoolSession: session).load();
    final amina = attendance.records.singleWhere((r) => r.id == 'STAFF-001');
    final ahmad = attendance.records.singleWhere((r) => r.id == 'STAFF-014');
    expect(amina.name, 'Mrs. Amina Yusuf');
    expect(amina.status, StaffAttendanceReviewStatus.ready);
    expect(ahmad.name, 'Mr. Ahmad Sani');
    expect(ahmad.status, StaffAttendanceReviewStatus.ready);
    // A staff id with no real attendance record on file is honestly held for review, not
    // silently defaulted to ready.
    expect(attendance.records.any((r) => r.id == 'STAFF-099'), isFalse);
  });

  test('payroll boundaries prevent automatic deduction payment and history rewrite', () {
    expect(financePayrollAttendanceRule, contains('device-level biometric details remain outside'));
    expect(financePayrollHumanReviewRule, contains('must not silently create a deduction'));
    expect(financePayrollAuthorityBoundary, contains('HR/leadership retains responsibility'));
    expect(financePayrollBatchBoundary, contains('must not mark salaries Paid'));
    expect(financePayrollBatchBoundary, contains('still held for attendance review'));
    expect(financePayrollSettlementBoundary, contains('not payment confirmation'));
    expect(financePayrollCorrectionBoundary, contains('Do not silently overwrite'));
  });

  test('payroll serialization preserves approved figures and review evidence', () {
    const source = FinancePayrollRow(
      staffId: 'STAFF-099',
      name: 'Mrs. Zainab Musa',
      expectedDays: 22,
      presentDays: 20,
      leaveDays: 1,
      unexplainedDays: 1,
      gross: 310000,
      deductions: 71000,
      net: 239000,
      status: FinancePayrollStatus.attendanceReview,
    );
    final copy = FinancePayrollRow.fromJson(source.toJson());
    expect(copy.staffId, 'STAFF-099');
    expect(copy.name, 'Mrs. Zainab Musa');
    expect(copy.gross, 310000);
    expect(copy.deductions, 71000);
    expect(copy.net, 239000);
    expect(copy.unexplainedDays, 1);
    expect(copy.status, FinancePayrollStatus.attendanceReview);
  });

  test('payroll money formatter matches Nigerian display', () {
    expect(financePayrollMoney(194000), '₦194,000');
    expect(financePayrollMoney(11900000), '₦11,900,000');
  });

  testWidgets('prepare batch remains preview only and holds review record', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _Database();
    _seedSalaries(db);
    final session = await _session(_owner);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancePayrollPage(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Prepare payment batch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ready records'), findsOneWidget);
    expect(find.textContaining('₦384,000'), findsWidgets);
    expect(find.textContaining('1 attendance-review record remains held'), findsOneWidget);
    expect(find.textContaining('No salary has been marked Paid'), findsOneWidget);
    // STAFF-099 has no real attendance record, so it is honestly held for review rather than
    // defaulted to ready — the same fact the "1 attendance-review record remains held" text above
    // already confirms from the real UI.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payroll Processing renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = _Database();
    _seedSalaries(db);
    final session = await _session(_owner);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancePayrollPage(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payroll Processing'), findsOneWidget);
    expect(find.text('Prepare payment batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance officer can see payroll and prepare but the approval step is waiting', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = _Database();
    _seedSalaries(db);
    final session = await _session(_finance);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancePayrollPage(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Payroll is restricted'), findsNothing);
    expect(find.text('Prepare payment batch'), findsOneWidget);
    expect(find.text('Mr. Ahmad Sani'), findsWidgets);
    expect(find.textContaining('No payroll batch has been prepared'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Prepare payment batch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Awaiting approval'), findsOneWidget);
    expect(find.text('Approve batch'), findsNothing);
    expect(find.text('Instruct disbursement'), findsNothing);
  });

  testWidgets('a principal with no payroll authority sees restricted payroll', (tester) async {
    final db = _Database();
    _seedSalaries(db);
    final session = await _session(_principal);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancePayrollPage(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Payroll is restricted'), findsOneWidget);
    expect(find.text('Prepare payment batch'), findsNothing);
    expect(find.textContaining('Mrs. Amina Yusuf'), findsNothing);
  });

  test('finance officers always view and prepare; approve and pay need an authorizer link', () {
    PayrollAuthorizer auth(String status, String? membershipId, Set<String> a) =>
        PayrollAuthorizer(
          id: 'x', name: 'X', authorities: a,
          status: status, membershipId: membershipId,
        );
    expect(payrollAuthoritiesFor(_owner, []), payrollAuthorityLabels.keys.toSet());
    expect(payrollAuthoritiesFor(_finance, []), {'view', 'prepare'});
    expect(payrollAuthoritiesFor(_finance, [auth('pendingActivation', 'finance', {'approve', 'pay'})]), {'view', 'prepare'});
    expect(payrollAuthoritiesFor(_finance, [auth('active', 'someone-else', {'approve'})]), {'view', 'prepare'});
    expect(payrollAuthoritiesFor(_finance, [auth('revoked', 'finance', {'pay'})]), {'view', 'prepare'});
    expect(payrollAuthoritiesFor(_finance, [auth('active', 'finance', {'approve'})]), {'view', 'prepare', 'approve'});
    expect(payrollAuthoritiesFor(_principal, []), isEmpty);
    expect(payrollAuthoritiesFor(_principal, [auth('active', 'principal', {'view'})]), {'view'});
  });

  FinancePayrollRow ready(String id, int gross, int deductions) => FinancePayrollRow(
    staffId: id, name: id, expectedDays: 22, presentDays: 22, leaveDays: 0,
    unexplainedDays: 0, gross: gross, deductions: deductions,
    net: gross - deductions, status: FinancePayrollStatus.ready,
  );

  test('payment cannot be released without approval, and approver differs from preparer', () async {
    final db = _Database();
    final period = PayrollBatchRepository.periodFor(DateTime.now());
    final rows = [ready('A', 100000, 10000), ready('B', 50000, 0)];

    final financeSession = await _session(_finance);
    addTearDown(financeSession.dispose);
    final finance = PayrollBatchRepository(database: db, session: financeSession);
    await finance.prepare(period, rows);
    var batch = (await finance.load(period))!;
    expect(batch.status, PayrollBatchStatus.prepared);
    expect(batch.total, 140000);
    expect(batch.preparedBy, 'finance');

    // Finance can neither approve nor release payment.
    expect(finance.approve(period), throwsStateError);
    expect(finance.instructDisbursement(period), throwsStateError);

    // Payment cannot be released before approval, even by the owner.
    final ownerSession = await _session(_owner);
    addTearDown(ownerSession.dispose);
    final owner = PayrollBatchRepository(database: db, session: ownerSession);
    expect(owner.instructDisbursement(period), throwsStateError);

    await owner.approve(period);
    batch = (await owner.load(period))!;
    expect(batch.status, PayrollBatchStatus.approved);
    expect(batch.approvedBy, 'owner');

    // An approved batch cannot be re-prepared or re-approved.
    expect(finance.prepare(period, rows), throwsStateError);
    expect(owner.approve(period), throwsStateError);
    expect(finance.instructDisbursement(period), throwsStateError);

    await owner.instructDisbursement(period);
    batch = (await owner.load(period))!;
    expect(batch.status, PayrollBatchStatus.disbursementInstructed);
    // Instructing is not payment: nothing is ever recorded as paid here.
    expect(db.records.values.any((r) => r.payload.toString().toLowerCase().contains('paid')), isFalse);
    expect(db.mutations.length, 3);
  });

  test('the person who prepared a batch cannot approve it, and reject reopens it', () async {
    final db = _Database();
    final period = PayrollBatchRepository.periodFor(DateTime.now());
    final ownerSession = await _session(_owner);
    addTearDown(ownerSession.dispose);
    final owner = PayrollBatchRepository(database: db, session: ownerSession);
    await owner.prepare(period, [ready('A', 100000, 0)]);
    expect(owner.approve(period), throwsStateError);

    final bursarSession = await _session(_bursar);
    addTearDown(bursarSession.dispose);
    // A finance officer who has been given approve authority through an active record.
    db.records['a/${OwnerPayrollRepository.authorizerType}/b'] = LocalRecord(
      tenantId: 'a',
      entityType: OwnerPayrollRepository.authorizerType,
      entityId: 'b',
      payload: {
        'name': 'Bursar', 'authorities': ['approve'],
        'status': 'active', 'membershipId': 'bursar',
      },
      updatedAt: DateTime.now(),
      isDirty: false,
    );
    final bursar = PayrollBatchRepository(database: db, session: bursarSession);
    await bursar.reject(period, 'Wrong total');
    var batch = (await bursar.load(period))!;
    expect(batch.status, PayrollBatchStatus.rejected);
    expect(batch.rejectionReason, 'Wrong total');
    expect(bursar.instructDisbursement(period), throwsStateError);
    // Rejected batches can be prepared again.
    await owner.prepare(period, [ready('A', 100000, 0), ready('B', 20000, 0)]);
    batch = (await owner.load(period))!;
    expect(batch.status, PayrollBatchStatus.prepared);
    expect(batch.total, 120000);
  });

  test('only attendance-cleared reconciled rows can be batched', () async {
    final db = _Database();
    final period = PayrollBatchRepository.periodFor(DateTime.now());
    final session = await _session(_finance);
    addTearDown(session.dispose);
    final repo = PayrollBatchRepository(database: db, session: session);
    expect(repo.prepare(period, []), throwsArgumentError);
    expect(
      repo.prepare(period, [
        FinancePayrollRow(
          staffId: 'H', name: 'Held', expectedDays: 22, presentDays: 20, leaveDays: 0,
          unexplainedDays: 2, gross: 100, deductions: 0, net: 100,
          status: FinancePayrollStatus.attendanceReview,
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      repo.prepare(period, [
        FinancePayrollRow(
          staffId: 'X', name: 'X', expectedDays: 22, presentDays: 22, leaveDays: 0,
          unexplainedDays: 0, gross: 100, deductions: 0, net: 90,
          status: FinancePayrollStatus.ready,
        ),
      ]),
      throwsArgumentError,
    );
  });

  test('owner salary saves keep history, queue sync and reject bad figures', () async {
    final db = _Database();
    final session = await _session(_owner);
    addTearDown(session.dispose);
    final repo = OwnerPayrollRepository(database: db, session: session);
    final person = (await repo.load()).staff.first;
    await repo.saveSalary(person: person, gross: 100000, deductions: 10000, onPayroll: true);
    await repo.saveSalary(person: person, gross: 120000, deductions: 10000, onPayroll: true);
    final snapshot = await repo.load();
    final profile = snapshot.profiles[person.id]!;
    expect(profile.net, 110000);
    expect(profile.history, hasLength(2));
    expect(db.mutations, hasLength(2));
    expect(
      () => repo.saveSalary(person: person, gross: 1000, deductions: 2000, onPayroll: true),
      throwsArgumentError,
    );
    expect(
      () => repo.saveAuthorizer(person: person, authorities: {}),
      throwsArgumentError,
    );
  });

  test('non-owner cannot manage payroll', () async {
    final session = await _session(_finance);
    addTearDown(session.dispose);
    final repo = OwnerPayrollRepository(database: _Database(), session: session);
    expect(repo.load(), throwsStateError);
  });
}
