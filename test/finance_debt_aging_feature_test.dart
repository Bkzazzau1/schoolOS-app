import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_debt_aging_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_debt_aging_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_debt_aging_page.dart';

void main() {
  test('outstanding aging preserves exact five website family rows', () {
    expect(financeFamilyReceivables, hasLength(5));
    expect(financeFamilyReceivables.map((row) => row.family).toList(), [
      'Abdullahi Yusuf Family',
      'Musa Bello Family',
      'Sani Ibrahim Family',
      'Kabir Ahmad Family',
      'Aliyu Umar Family',
    ]);
    expect(financeFamilyReceivables.first.balance, 180000);
    expect(financeFamilyReceivables[3].balance, 135000);
    expect(financeFamilyReceivables[3].status, FinanceReceivableStatus.action);
  });

  test('school-wide aging snapshot matches website totals', () {
    expect(financeAgingTotalOpenReceivables, 18700000);
    expect(financeAgingSummaries.map((item) => item.amount).toList(), [8200000, 5400000, 3100000, 2000000]);
    expect(financeAgingSummaries.fold<int>(0, (sum, item) => sum + item.amount), financeAgingTotalOpenReceivables);
    expect(financeAgingSummaries.map((item) => item.progressPercent).toList(), [100, 66, 38, 24]);
  });

  test('arrangement quality reconciles to total open receivables', () {
    expect(financeArrangementQuality.map((item) => item.amount).toList(), [6800000, 3400000, 1200000, 7300000]);
    expect(financeArrangementQuality.fold<int>(0, (sum, item) => sum + item.amount), financeAgingTotalOpenReceivables);
    expect(financeArrangementQuality.first.guidance, 'Do not classify as unarranged debt.');
    expect(financeArrangementQuality.last.label, 'No active arrangement');
  });

  test('sample family queue is not mistaken for school-wide receivable total', () {
    final sampleTotal = financeFamilyReceivables.fold<int>(0, (sum, row) => sum + row.balance);
    expect(sampleTotal, 500000);
    expect(sampleTotal, isNot(financeAgingTotalOpenReceivables));
  });

  test('aging filter follows exact website bucket behavior', () {
    expect(financeFilterReceivables(financeFamilyReceivables, 'All'), hasLength(5));
    expect(financeFilterReceivables(financeFamilyReceivables, '0–30 days'), hasLength(2));
    expect(financeFilterReceivables(financeFamilyReceivables, '31–60 days').single.family, 'Musa Bello Family');
    expect(financeFilterReceivables(financeFamilyReceivables, '61–90 days').single.plan, 'Financing active');
    expect(financeFilterReceivables(financeFamilyReceivables, '90+ days').single.status, FinanceReceivableStatus.action);
  });

  test('collection actions preserve exact website choices without inventing completion', () {
    expect(financeAgingActions, [
      'Send payment reminder',
      'Review mandate',
      'Offer payment plan',
      'Record promise to pay',
      'Review financing',
      'Escalate to proprietor',
    ]);
    expect(financeAgingPrototypeBoundary, contains('must not claim'));
    expect(financeAgingPrototypeBoundary, contains('governed workflow confirms it'));
  });

  test('aging and academic governance boundaries remain explicit', () {
    expect(financeAgingAccountingBoundary, contains('after approved scholarships and discounts'));
    expect(financeAgingAccountingBoundary, contains('age alone'));
    expect(financeAgingAcademicBoundary, contains('grades'));
    expect(financeAgingAcademicBoundary, contains('hidden student-risk scoring'));
    expect(financeAgingAcademicBoundary, contains('academic staff manage learning'));
  });

  test('family receivable serialization preserves arrangement evidence', () {
    final source = financeFamilyReceivables[2];
    final copy = FinanceFamilyReceivable.fromJson(source.toJson());
    expect(copy.family, source.family);
    expect(copy.balance, 100000);
    expect(copy.age, FinanceAgingBucket.sixtyOneTo90);
    expect(copy.plan, 'Financing active');
    expect(copy.status, FinanceReceivableStatus.structured);
  });

  test('aging money formatter matches Nigerian display', () {
    expect(financeAgingMoney(180000), '₦180,000');
    expect(financeAgingMoney(2000000), '₦2,000,000');
  });

  testWidgets('Outstanding Aging renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceDebtAgingPage())));
    await tester.pumpAndSettle();

    expect(find.text('Outstanding Fees & Aging'), findsOneWidget);
    expect(find.text('Export aging'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
