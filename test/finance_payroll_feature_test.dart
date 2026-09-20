import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_demo_data.dart';
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

Future<SchoolSessionController> _session(SchoolMembership active) async {
  FlutterSecureStorage.setMockInitialValues({});
  final session = SchoolSessionController(store: SchoolSessionStore());
  await session.setMemberships([_owner, _finance]);
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

  test('payroll handoff preserves exact three website staff rows', () {
    expect(financePayrollRows, hasLength(3));
    expect(financePayrollRows.map((row) => row.staffId).toList(), [
      'TCH-2048',
      'TCH-2031',
      'TCH-2016',
    ]);
    expect(financePayrollRows.map((row) => row.name).toList(), [
      'Mrs. Amina Yusuf',
      'Mr. Ahmad Sani',
      'Mrs. Zainab Musa',
    ]);
    expect(financePayrollRows.map((row) => row.net).toList(), [194000, 190000, 239000]);
  });

  test('website payroll KPI snapshot is preserved exactly', () {
    expect(financePayrollKpis.map((item) => item.value).toList(), [
      '₦14.8m',
      '₦2.9m',
      '₦11.9m',
      '62 / 64',
      '2',
    ]);
    expect(financePayrollKpis[1].hint, 'Approved payroll deductions only');
    expect(financePayrollKpis[3].hint, '2 records held for review');
  });

  test('sample payroll arithmetic reconciles and review state stays separate', () {
    expect(financePayrollRows.every((row) => row.arithmeticReconciles), isTrue);
    expect(financePayrollRows.where((row) => row.isReady), hasLength(2));
    expect(financePayrollRows.where((row) => row.needsAttendanceReview), hasLength(1));
    expect(financePayrollRows.last.unexplainedDays, 1);
    expect(financePayrollRows.last.status, FinancePayrollStatus.attendanceReview);
  });

  test('shared attendance records agree with administrator reviewed handoff', () {
    for (final payroll in financePayrollRows.take(2)) {
      final attendance = administratorStaffAttendanceWebsiteSeed.firstWhere(
        (record) => record.name == payroll.name,
      );
      expect(payroll.expectedDays, attendance.expected);
      expect(payroll.presentDays, attendance.present);
      expect(payroll.leaveDays, attendance.leave);
      expect(payroll.unexplainedDays, attendance.unexplained);
    }
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
    final source = financePayrollRows.last;
    final copy = FinancePayrollRow.fromJson(source.toJson());
    expect(copy.staffId, 'TCH-2016');
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
    expect(find.textContaining('₦384,000'), findsOneWidget);
    expect(find.textContaining('1 attendance-review record remains held'), findsOneWidget);
    expect(find.textContaining('No salary has been marked Paid'), findsOneWidget);
    expect(financePayrollRows.last.status, FinancePayrollStatus.attendanceReview);
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

  testWidgets('finance officer without owner authority sees restricted payroll', (tester) async {
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
    expect(find.textContaining('Payroll is restricted'), findsOneWidget);
    expect(find.text('Prepare payment batch'), findsNothing);
    expect(find.textContaining('Mrs. Amina Yusuf'), findsNothing);
  });

  test('authority requires an active record linked to the membership', () {
    PayrollAuthorizer auth(String status, String? membershipId) =>
        PayrollAuthorizer(
          id: 'x', name: 'X', authorities: {'view', 'prepare'},
          status: status, membershipId: membershipId,
        );
    expect(payrollAuthoritiesFor(_owner, []), payrollAuthorityLabels.keys.toSet());
    expect(payrollAuthoritiesFor(_finance, [auth('pendingActivation', 'finance')]), isEmpty);
    expect(payrollAuthoritiesFor(_finance, [auth('active', 'someone-else')]), isEmpty);
    expect(payrollAuthoritiesFor(_finance, [auth('revoked', 'finance')]), isEmpty);
    expect(payrollAuthoritiesFor(_finance, [auth('active', 'finance')]), {'view', 'prepare'});
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
