import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_collections_demo_data.dart';
import 'package:schoolos_app/features/finance_office/data/finance_receipts_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_collections_models.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_receipts_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_receipts_page.dart';

void main() {
  test('receipts register preserves three confirmed receipt records', () {
    expect(financeReceipts, hasLength(3));
    expect(financeReceipts.map((receipt) => receipt.number).toList(), [
      'BGA/RCPT/2026/004819',
      'BGA/RCPT/2026/004818',
      'BGA/RCPT/2026/004817',
    ]);
    expect(financeReceipts.map((receipt) => receipt.student).toList(), [
      'Maryam Abdullahi',
      'Muhammad Kabir',
      'Zainab Aliyu',
    ]);
    expect(financeReceipts.map((receipt) => receipt.amount).toList(), [
      25000,
      50000,
      15000,
    ]);
  });

  test('all receipts are confirmed family-account credits allocated to child ledgers', () {
    expect(
      financeReceipts.every(
        (receipt) =>
            receipt.status == FinanceReceiptStatus.confirmed &&
            receipt.method == 'Family Term Account' &&
            receipt.date == '13 Sep 2026',
      ),
      isTrue,
    );
  });

  test('every receipt balance reconciles exactly', () {
    expect(financeReceipts.every((receipt) => receipt.balancesReconcile), isTrue);
    expect(financeReceipts.first.previousBalance, 150000);
    expect(financeReceipts.first.newBalance, 125000);
    expect(financeReceipts[1].previousBalance, 100000);
    expect(financeReceipts[1].newBalance, 50000);
    expect(financeReceipts.last.previousBalance, 65000);
    expect(financeReceipts.last.newBalance, 50000);
  });

  test('receipt references match confirmed Smart Collections child allocations', () {
    for (final receipt in financeReceipts) {
      final event = financeCollectionFeed.firstWhere(
        (item) => item.reference == receipt.transactionReference,
      );
      expect(event.status, FinanceCollectionStatus.confirmed);
      expect(event.student, receipt.student);
      expect(event.amount, receipt.amount);
    }
  });

  test('receipt serialization preserves ledger evidence', () {
    final source = financeReceipts.first;
    final copy = FinanceReceipt.fromJson(source.toJson());
    expect(copy.number, source.number);
    expect(copy.student, source.student);
    expect(copy.admissionNumber, source.admissionNumber);
    expect(copy.transactionReference, source.transactionReference);
    expect(copy.previousBalance, source.previousBalance);
    expect(copy.newBalance, source.newBalance);
    expect(copy.status, FinanceReceiptStatus.confirmed);
  });

  test('receipt boundaries prevent duplicate, unallocated or premature claims', () {
    expect(financeReceiptIssuanceBoundary, contains('family-account collection event'));
    expect(financeReceiptIssuanceBoundary, contains('allocated to the intended child'));
    expect(financeReceiptIssuanceBoundary, contains('posted to that child fee ledger'));
    expect(financeReceiptIssuanceBoundary, contains('unallocated'));
    expect(financeReceiptIssuanceBoundary, contains('must not create a confirmed receipt'));
    expect(financeReceiptMutationBoundary, contains('must never post another payment'));
    expect(financeReceiptMutationBoundary, contains('duplicate receipt'));
    expect(financeReceiptPrototypeBoundary, contains('browser print'));
    expect(financeReceiptPrototypeBoundary, contains('non-financial'));
  });

  test('receipt money formatter matches Nigerian display', () {
    expect(financeReceiptMoney(25000), '₦25,000');
    expect(financeReceiptMoney(150000), '₦150,000');
    expect(financeReceiptMoney(50000), '₦50,000');
  });

  testWidgets('selecting a receipt updates the preview evidence', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceReceiptsPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRX-260913-94821'), findsOneWidget);
    await tester.tap(find.text('Muhammad Kabir').first);
    await tester.pumpAndSettle();
    expect(find.text('TRX-260913-94817'), findsOneWidget);
    expect(find.text('BGA/RCPT/2026/004818'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('print selected remains a non-financial document action', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceReceiptsPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Print selected'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('non-financial prototype document action'),
      findsOneWidget,
    );
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('Receipts Register renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceReceiptsPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receipts Register'), findsOneWidget);
    expect(find.text('Recent receipts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
