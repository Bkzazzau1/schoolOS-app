import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_mandates_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_mandates_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_mandates_page.dart';

void main() {
  test('payment mandates preserve exact three website records', () {
    expect(financeMandates, hasLength(3));
    expect(financeMandates.map((item) => item.id).toList(), [
      'MDT-26041',
      'MDT-26042',
      'MDT-26043',
    ]);
    expect(financeMandates.first.guardian, 'Alhaji Abdullahi Yusuf');
    expect(financeMandates.first.children, 'Maryam + Hafsa');
    expect(financeMandates.first.provider, 'Remita / partner rail');
    expect(financeMandates[1].latestAttempt, FinanceMandateAttempt.failed);
    expect(financeMandates[2].status, FinanceMandateStatus.pendingConsent);
  });

  test('mandate website KPI snapshot is preserved', () {
    expect(financeMandateActiveCount, 412);
    expect(financeMandateExpectedNext30Days, '₦11.3M');
    expect(financeMandateSuccessfulThisMonth, 286);
    expect(financeMandateFailedAttempts, 7);
    expect(financeMandatePendingConsent, 19);
  });

  test('mandate workflow preserves exact authorization-to-receipt order', () {
    expect(financeMandateWorkflow.map((step) => step.title).toList(), [
      'Parent chooses plan',
      'Consent captured',
      'Provider attempts debit',
      'SchoolOS posts payment',
      'Receipt issued',
    ]);
    expect(financeMandateWorkflow[2].detail, 'Bank / salary rail');
    expect(financeMandateWorkflow[3].detail, 'Student fee ledger');
    expect(financeMandateWorkflow[4].detail, 'Parent portal');
  });

  test('mandate controls block consent, provider and settlement fabrication', () {
    expect(financeMandateConsentBoundary, contains('not active'));
    expect(financeMandateConsentBoundary, contains('must not trigger a debit'));
    expect(financeMandateProviderBoundary, contains('provider-side acknowledgement'));
    expect(financeMandateProviderBoundary, contains('must not claim'));
    expect(financeMandatePostingBoundary, contains('authoritative provider confirmation'));
    expect(financeMandateReceiptBoundary, contains('confirmed payment'));
  });

  test('mandate serialization preserves consent and attempt evidence', () {
    final source = financeMandates[1];
    final copy = FinanceMandate.fromJson(source.toJson());
    expect(copy.id, 'MDT-26042');
    expect(copy.method, 'Salary-linked');
    expect(copy.amount, 30000);
    expect(copy.status, FinanceMandateStatus.active);
    expect(copy.latestAttempt, FinanceMandateAttempt.failed);
    expect(copy.nextAttempt, '28 Sep 2026');
  });

  test('mandate money formatter matches Nigerian display', () {
    expect(financeMandateMoney(30000), '₦30,000');
    expect(financeMandateMoney(20000), '₦20,000');
  });

  testWidgets('retry action does not invent a provider debit result', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceMandatesPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Successful'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry collection'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No debit was attempted'), findsOneWidget);
    expect(find.textContaining('Successful remains unchanged'), findsOneWidget);
  });

  testWidgets('Payment Mandates renders on a phone viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceMandatesPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Mandates'), findsOneWidget);
    expect(find.text('Active mandates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
