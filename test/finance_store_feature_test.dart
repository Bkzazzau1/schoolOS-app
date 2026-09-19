import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_store_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_store_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_store_page.dart';

void main() {
  test('school store preserves exact four website orders', () {
    expect(financeStoreOrders, hasLength(4));
    expect(financeStoreOrders.map((order) => order.id).toList(), [
      'ORD-2026-00481',
      'ORD-2026-00482',
      'ORD-2026-00483',
      'ORD-2026-00479',
    ]);
    expect(financeStoreOrders.first.student, 'Maryam Abdullahi');
    expect(financeStoreOrders.first.account, '2038457291');
    expect(financeStoreOrders[1].status, FinanceStoreOrderStatus.paidReady);
    expect(financeStoreOrders[2].status, FinanceStoreOrderStatus.awaitingPayment);
    expect(financeStoreOrders.last.status, FinanceStoreOrderStatus.completed);
  });

  test('website order math produces exact School Store KPIs', () {
    final totals = financeStoreTotals(financeStoreOrders);
    expect(totals.sales, 85000);
    expect(totals.openOrders, 3);
    expect(totals.paidNotFullyIssued, 2);
    expect(totals.awaitingPayment, 1);
    expect(totals.lowStockItems, 2);
  });

  test('store and tuition use separate collection rails', () {
    expect(financeStoreFeeRailRule, contains('Static student term account'));
    expect(financeStoreFeeRailRule, contains('tuition'));
    expect(financeStoreSundryRailRule, contains('Dynamic account created for one order'));
    expect(financeStoreSundryRailRule, contains('exact expected amount'));
    expect(financeStoreRailBoundary, contains('separate from tuition'));
    expect(financeStoreRailBoundary, contains('must not alter the student term-fee balance'));
  });

  test('inventory preserves exact website values and exposes source mismatch', () {
    expect(financeStoreStock, hasLength(6));
    final shirt = financeStoreStock.first;
    expect(shirt.item, 'School Shirt');
    expect(shirt.opening, 160);
    expect(shirt.issued, 86);
    expect(shirt.available, 124);
    expect(shirt.price, 7000);
    expect(shirt.reconciles, isFalse);
    expect(financeStoreStock.skip(1).every((item) => item.reconciles), isTrue);
  });

  test('store control exceptions preserve exact website evidence', () {
    expect(financeStoreControlExceptions, hasLength(4));
    expect(financeStoreControlExceptions[0].$1, '2 paid orders not fully issued');
    expect(financeStoreControlExceptions[1].$1, '1 order awaiting payment');
    expect(financeStoreControlExceptions[2].$1, 'Books revenue · ₦58,500');
    expect(financeStoreControlExceptions[3].$1, 'Uniform revenue · ₦39,000');
  });

  test('payment boundary blocks local fabrication of successful settlement', () {
    expect(financeStorePaymentBoundary, contains('authoritative bank/provider confirmation'));
    expect(financeStorePaymentBoundary, contains('not settlement'));
  });

  test('order serialization preserves payment and fulfillment evidence', () {
    final source = financeStoreOrders.first;
    final copy = FinanceStoreOrder.fromJson(source.toJson());
    expect(copy.id, source.id);
    expect(copy.account, source.account);
    expect(copy.amount, 34500);
    expect(copy.status, FinanceStoreOrderStatus.partiallyIssued);
    expect(copy.issued, 'Uniform issued · Book Pack pending');
  });

  test('finance store money formatter matches Nigerian display', () {
    expect(financeStoreMoney(85000), '₦85,000');
    expect(financeStoreMoney(12500), '₦12,500');
  });

  testWidgets('Confirm payment does not invent bank settlement', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceStorePage())));
    await tester.pumpAndSettle();

    expect(find.text('Partially issued'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm payment'));
    await tester.pumpAndSettle();

    expect(find.text('Partially issued'), findsWidgets);
    expect(
      find.textContaining('Authoritative bank/provider confirmation is required'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('School Store renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FinanceStorePage())));
    await tester.pumpAndSettle();

    expect(find.text('School Store & Collections'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
