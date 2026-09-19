import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_attendance_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_payroll_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_payroll_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_payroll_page.dart';

void main() {
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

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinancePayrollPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Prepare payment batch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ready sample records'), findsOneWidget);
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

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinancePayrollPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payroll Processing'), findsOneWidget);
    expect(find.text('Prepare payment batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
