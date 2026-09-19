import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_cashflow_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_cashflow_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_cashflow_page.dart';

void main() {
  test('cashflow ledger preserves exact five website rows', () {
    expect(financeCashflowEntries, hasLength(5));
    expect(financeCashflowEntries.map((e) => e.description).toList(), [
      'Fuel & transport operations',
      'School fees collections',
      'Laboratory supplies',
      'After-school activity fees',
      'Utilities',
    ]);
    expect(financeCashflowEntries.map((e) => e.amount).toList(), [
      186000,
      1240000,
      72500,
      215000,
      128400,
    ]);
  });

  test('website cashflow KPI snapshot is preserved', () {
    expect(financeCashflowKpis.map((e) => e.value).toList(), [
      '₦18.6m',
      '₦6.4m',
      '₦12.2m',
      '9',
      '+3.8%',
    ]);
    expect(financeCashflowKpis[3].hint, '₦742,000');
    expect(financeCashflowKpis.last.hint, 'Against monthly plan');
  });

  test('website rows keep posted income distinct from approved expenses', () {
    final incomes = financeCashflowEntries.where((e) => e.isIncome).toList();
    final expenses = financeCashflowEntries.where((e) => e.isExpense).toList();

    expect(incomes, hasLength(2));
    expect(expenses, hasLength(3));
    expect(incomes.every((e) => e.isPostedIncome), isTrue);
    expect(expenses.every((e) => e.isApprovedExpense), isTrue);
  });

  test('sample recent row totals remain internally consistent', () {
    final income = financeCashflowEntries
        .where((e) => e.isIncome)
        .fold<int>(0, (sum, e) => sum + e.amount);
    final expenses = financeCashflowEntries
        .where((e) => e.isExpense)
        .fold<int>(0, (sum, e) => sum + e.amount);

    expect(income, 1455000);
    expect(expenses, 386900);
    expect(income - expenses, 1068100);
  });

  test('all four website expense controls are preserved', () {
    expect(financeExpenseControls.map((e) => e.title).toList(), [
      'Supporting evidence',
      'Approval separation',
      'Immutable posting trail',
      'Budget context',
    ]);
  });

  test('cashflow boundaries prevent fabricated posting and destructive edits', () {
    expect(financeIncomeEntryBoundary, contains('must not increase posted cash'));
    expect(financeExpenseRequestBoundary, contains('not an approved expense'));
    expect(financeExpenseRequestBoundary, contains('separate downstream event'));
    expect(financeExpenseEvidenceBoundary, contains('supporting evidence'));
    expect(financeCashflowCorrectionBoundary, contains('reversal or adjustment entries'));
    expect(financeCashflowCorrectionBoundary, contains('do not delete'));
    expect(financeCashflowPrototypeBoundary, contains('does not fabricate approval'));
  });

  test('cashflow entry serialization preserves accounting state', () {
    final source = financeCashflowEntries.first;
    final copy = FinanceCashflowEntry.fromJson(source.toJson());
    expect(copy.date, source.date);
    expect(copy.description, source.description);
    expect(copy.type, FinanceCashflowType.expense);
    expect(copy.status, FinanceCashflowStatus.approved);
    expect(copy.amount, 186000);
  });

  test('cashflow money formatter matches Nigerian display', () {
    expect(financeCashflowMoney(1240000), '₦1,240,000');
    expect(financeCashflowMoney(72500), '₦72,500');
  });

  testWidgets('entry actions remain controlled drafts rather than posting money', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceCashflowPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'New income entry'));
    await tester.pumpAndSettle();
    expect(find.text(financeIncomeEntryBoundary), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'New expense request'));
    await tester.pumpAndSettle();
    expect(find.text(financeExpenseRequestBoundary), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Income & Expenses renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceCashflowPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Income & Expenses'), findsOneWidget);
    expect(find.text('New expense request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
