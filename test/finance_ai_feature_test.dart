import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_os_app/features/finance_office/data/finance_ai_demo_data.dart';
import 'package:school_os_app/features/finance_office/data/finance_cashflow_demo_data.dart';
import 'package:school_os_app/features/finance_office/data/finance_debt_aging_demo_data.dart';
import 'package:school_os_app/features/finance_office/data/finance_reconciliation_demo_data.dart';
import 'package:school_os_app/features/finance_office/data/finance_reports_demo_data.dart';
import 'package:school_os_app/features/finance_office/domain/finance_ai_models.dart';
import 'package:school_os_app/features/finance_office/presentation/finance_ai_page.dart';

void main() {
  test('Finance AI preserves exact five website suggested questions', () {
    expect(financeAiPrompts, [
      'Why is Secondary collection below target?',
      'Show unmatched payments needing review',
      "Summarize this month's expenses",
      'Which accounts have the largest balances?',
      'What changed in collections this week?',
    ]);
  });

  test('default Secondary answer preserves website evidence and fairness boundary', () {
    final response = financeAiAnswerFor(financeAiPrompts.first);
    expect(response.answer, contains('86%'));
    expect(response.answer, contains('92% owner target'));
    expect(response.answer, contains('open balances'));
    expect(response.answer, contains('scheduled payment plans'));
    expect(response.answer, contains('cannot infer why individual families have not paid'));
    expect(response.answer, contains('should not rank or judge families'));
    expect(response.boundary, financeAiFairnessBoundary);
  });

  test('unmatched answer stays consistent with Reconciliation and cannot post', () {
    final response = financeAiAnswerFor(financeAiPrompts[1]);
    final unmatched = financeReconciliationKpis.firstWhere((item) => item.label == 'Unmatched');
    expect(response.answer, contains(unmatched.value));
    expect(response.answer, contains(unmatched.hint));
    expect(response.answer, contains('Sender name alone is not enough'));
    expect(response.answer, contains('must not post money or issue a receipt'));
    expect(response.boundary, financeAiActionBoundary);
  });

  test('expense answer stays consistent with Income & Expenses', () {
    final response = financeAiAnswerFor(financeAiPrompts[2]);
    final income = financeCashflowKpis.firstWhere((item) => item.label == 'Income this month');
    final expense = financeCashflowKpis.firstWhere((item) => item.label == 'Expenses this month');
    final net = financeCashflowKpis.firstWhere((item) => item.label == 'Net operating inflow');
    expect(response.answer, contains(income.value));
    expect(response.answer, contains(expense.value));
    expect(response.answer, contains(net.value));
    expect(response.answer, contains('Approved expense is not the same as bank settlement'));
  });

  test('largest-balance answer uses factual sample queue without family scoring', () {
    final response = financeAiAnswerFor(financeAiPrompts[3]);
    final sorted = [...financeFamilyReceivables]..sort((a, b) => b.balance.compareTo(a.balance));
    expect(sorted.first.family, 'Abdullahi Yusuf Family');
    expect(response.answer, contains('Abdullahi Yusuf Family: ₦180,000'));
    expect(response.answer, contains('Kabir Ahmad Family: ₦135,000'));
    expect(response.answer, contains('Sani Ibrahim Family: ₦100,000'));
    expect(response.answer, contains('not a school-wide family ranking'));
    expect(response.answer, contains('not a credit score'));
    expect(response.boundary, financeAiFairnessBoundary);
  });

  test('weekly collection answer preserves trend without conflating 94 and 94.1', () {
    final response = financeAiAnswerFor(financeAiPrompts[4]);
    expect(response.answer, contains('72% in W1'));
    expect(response.answer, contains('94% in W7'));
    expect(response.answer, contains('22 percentage points'));
    expect(response.answer, contains('94.1%'));
    expect(response.answer, contains('different displayed contexts'));
    expect(financeReportKpis.first.value, '94.1%');
  });

  test('unsupported question is bounded instead of fabricated', () {
    final response = financeAiAnswerFor('Predict which parent will default next term');
    expect(response.answer, contains('does not support a grounded answer'));
    expect(response.boundary, financeAiDataBoundary);
    expect(response.answer, isNot(contains('will default')));
  });

  test('Finance AI boundaries deny financial and academic authority', () {
    expect(financeAiActionBoundary, contains('cannot post payments'));
    expect(financeAiActionBoundary, contains('approve or pay payroll'));
    expect(financeAiActionBoundary, contains('write off debt'));
    expect(financeAiFairnessBoundary, contains('must not infer why a family has not paid'));
    expect(financeAiFairnessBoundary, contains('hidden family credit scores'));
    expect(financeAiFairnessBoundary, contains('academic treatment'));
    expect(financeAiDataBoundary, contains('Academic grades'));
    expect(financeAiDataBoundary, contains('safeguarding records'));
  });

  test('Finance AI response serializes evidence and boundary', () {
    final original = financeAiAnswerFor(financeAiPrompts[1]);
    final restored = FinanceAiResponse.fromJson(original.toJson());
    expect(restored.question, original.question);
    expect(restored.answer, original.answer);
    expect(restored.evidence, original.evidence);
    expect(restored.boundary, original.boundary);
  });

  testWidgets('suggested question updates grounded answer', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceAiPage())));
    expect(find.text('Why is Secondary collection below target?'), findsWidgets);

    await tester.tap(find.text('Show unmatched payments needing review').last);
    await tester.pump();

    expect(find.text('Show unmatched payments needing review'), findsWidgets);
    expect(find.textContaining('7 payment events remain unmatched'), findsOneWidget);
    expect(find.textContaining('₦386,000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('free-form unsupported question stays bounded', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceAiPage())));
    await tester.enterText(find.byType(TextField), 'Predict which parent will default next term');
    await tester.tap(find.widgetWithText(FilledButton, 'Ask AI'));
    await tester.pump();

    expect(find.textContaining('does not support a grounded answer'), findsOneWidget);
    expect(find.textContaining('Predict which parent will default next term'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Finance AI renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceAiPage())));
    expect(find.text('Finance AI'), findsOneWidget);
    expect(find.text('Finance Intelligence Assistant'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
