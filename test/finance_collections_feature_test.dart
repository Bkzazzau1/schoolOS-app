import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_collections_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_collections_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_collections_page.dart';

void main() {
  test('smart collections keeps four child ledgers but shares sibling family account', () {
    expect(financeTermAccounts, hasLength(4));
    expect(financeTermAccounts.map((item) => item.student).toList(), [
      'Maryam Abdullahi',
      'Hafsa Abdullahi',
      'Muhammad Kabir',
      'Zainab Aliyu',
    ]);
    expect(financeTermAccounts.first.account, '1047263815');
    expect(financeTermAccounts[1].account, financeTermAccounts.first.account);
    expect(financeTermAccounts[1].guardian, financeTermAccounts.first.guardian);
    expect(financeTermAccounts.last.status, FinanceTermAccountStatus.review);
  });

  test('collection KPIs count unique family accounts while preserving child-ledger money', () {
    final totals = financeCollectionsTotals(financeTermAccounts);
    expect(totals.gross, 610000);
    expect(totals.concessions, 65000);
    expect(totals.collected, 265000);
    expect(totals.outstanding, 280000);
    expect(totals.activeAccounts, 3);
  });

  test('individual child obligations remove concessions before debt', () {
    final maryam = financeTermAccounts[0];
    final hafsa = financeTermAccounts[1];
    final muhammad = financeTermAccounts[2];
    final zainab = financeTermAccounts[3];

    expect(maryam.outstanding, 125000);
    expect(hafsa.outstanding, 55000);
    expect(muhammad.outstanding, 50000);
    expect(zainab.outstanding, 50000);
    expect(hafsa.netCollectible, 135000);
    expect(muhammad.netCollectible, 125000);
  });

  test('live collections feed preserves references and sibling family account', () {
    expect(financeCollectionFeed, hasLength(4));
    expect(financeCollectionFeed.first.reference, 'TRX-260913-94821');
    expect(financeCollectionFeed.first.amount, 25000);
    expect(financeCollectionFeed.last.reference, 'TRX-260913-94790');
    expect(financeCollectionFeed.last.account, financeCollectionFeed.first.account);
    expect(
      financeCollectionFeed.every((item) => item.status == FinanceCollectionStatus.confirmed),
      isTrue,
    );
  });

  test('collection-limit options preserve website choices', () {
    expect(financeCollectionLimitReasons, [
      'Term fee + approved charges',
      'Transport + tuition',
      'Books + tuition',
      'Previous-term arrears',
      'Advance payment',
      'Other approved arrangement',
    ]);
    expect(financeCollectionValidityOptions, [
      'Until term closes',
      '24 hours',
      '72 hours',
      '7 days',
    ]);
  });

  test('collection status queue preserves website control items', () {
    expect(financeCollectionStatusItems, hasLength(4));
    expect(financeCollectionStatusItems[0].title, '7 failed mandate attempts');
    expect(financeCollectionStatusItems[1].title, '2 unmatched bank transactions');
    expect(financeCollectionStatusItems[2].title, '1 over-limit attempt');
    expect(financeCollectionStatusItems[3].title, '11 accounts nearly cleared');
  });

  test('smart collection boundaries enforce family account and child allocation semantics', () {
    expect(financeCollectionsFamilyAccountBoundary, contains('parent or guardian'));
    expect(financeCollectionsFamilyAccountBoundary, contains('Siblings'));
    expect(financeCollectionsAllocationBoundary, contains('allocated to the intended child ledger'));
    expect(financeCollectionsAllocationBoundary, contains('wrong child'));
    expect(financeCollectionsDepositBoundary, contains('not money stored in a wallet'));
    expect(financeCollectionsCeilingBoundary, contains('require a school-arranged limit change'));
    expect(financeCollectionsPrototypeBoundary, contains('UI prototype only'));
    expect(financeCollectionsPrototypeBoundary, contains('must not claim a bank-side ceiling changed'));
  });

  test('child ledger and collection event serialize without losing finance evidence', () {
    final account = FinanceTermAccount.fromJson(financeTermAccounts.first.toJson());
    expect(account.id, 'BGA/2023/SEC/001');
    expect(account.guardian, 'Alhaji Abdullahi Yusuf');
    expect(account.account, '1047263815');
    expect(account.limit, 125000);
    expect(account.lastPayment, '₦25,000 · 13 Sep');

    final event = FinanceCollectionEvent.fromJson(financeCollectionFeed.first.toJson());
    expect(event.reference, 'TRX-260913-94821');
    expect(event.account, '1047263815');
    expect(event.status, FinanceCollectionStatus.confirmed);
  });

  testWidgets('smart collections renders on a phone-sized viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FinanceCollectionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Collections Control Room'), findsOneWidget);
    expect(find.text('Export collections'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
