import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_reconciliation_demo_data.dart';
import 'package:schoolos_app/features/finance_office/domain/finance_reconciliation_models.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_reconciliation_page.dart';

void main() {
  test('reconciliation queue preserves exact four website transactions', () {
    expect(financeReconciliationRows, hasLength(4));
    expect(financeReconciliationRows.map((row) => row.reference).toList(), [
      'BNK-260913-881',
      'BNK-260913-879',
      'MON-260913-412',
      'BNK-260913-865',
    ]);
    expect(financeReconciliationRows.map((row) => row.amount).toList(), [
      50000,
      80000,
      25000,
      20000,
    ]);
    expect(financeReconciliationRows[1].sender, 'Unknown sender');
    expect(financeReconciliationRows[1].status, FinanceReconciliationStatus.review);
  });

  test('website reconciliation KPI snapshot is preserved', () {
    expect(financeReconciliationKpis.map((item) => item.value).toList(), [
      '₦1.24m',
      '31',
      '7',
      '3',
      '81.6%',
    ]);
    expect(financeReconciliationKpis.first.hint, '38 payment events');
    expect(financeReconciliationKpis[2].hint, '₦386,000');
    expect(financeReconciliationKpis[3].hint, 'Awaiting evidence');
  });

  test('known matches link family account and child ledger separately', () {
    final maryam = financeReconciliationRows.first;
    final ibrahim = financeReconciliationRows.last;

    expect(maryam.familyAccountId, 'FAM-ABD-001');
    expect(maryam.familyAccountNumber, '1047263815');
    expect(maryam.childLedgerId, 'STU-001');
    expect(maryam.hasFamilyAllocation, isTrue);

    expect(ibrahim.familyAccountId, 'FAM-SAN-002');
    expect(ibrahim.familyAccountNumber, '1047263823');
    expect(ibrahim.childLedgerId, 'STU-002');
  });

  test('unmatched transfer has no fabricated family or child allocation', () {
    final row = financeReconciliationRows[1];
    expect(row.matchLabel, 'Unmatched');
    expect(row.needsReview, isTrue);
    expect(row.familyAccountId, isNull);
    expect(row.familyAccountNumber, isNull);
    expect(row.childLedgerId, isNull);
    expect(row.hasFamilyAllocation, isFalse);
  });

  test('matching signals retain evidence-strength ordering', () {
    expect(financeReconciliationSignals.map((item) => item.title).toList(), [
      'Dedicated family term account',
      'Payment reference',
      'Sender name alone',
    ]);
    expect(financeReconciliationSignals.last.detail, contains('human review'));
  });

  test('reconciliation boundaries block false match posting and history edits', () {
    expect(financeReconciliationFamilyBoundary, contains('correct child fee ledger'));
    expect(financeReconciliationFamilyBoundary, contains('must not silently change one child balance'));
    expect(financeReconciliationMatchBoundary, contains('must never be marked Matched solely from sender-name similarity'));
    expect(financeReconciliationPostingBoundary, contains('Ledger posting and receipt issuance remain downstream steps'));
    expect(financeReconciliationPostingBoundary, contains('must not fabricate a posted credit or a receipt'));
    expect(financeReconciliationReversalBoundary, contains('preserve the original transaction'));
    expect(financeReconciliationReversalBoundary, contains('Do not silently edit ledger history'));
    expect(financeReconciliationImportBoundary, contains('website prototype action'));
  });

  test('reconciliation row serialization preserves matching evidence', () {
    final source = financeReconciliationRows.first;
    final copy = FinanceReconciliationRow.fromJson(source.toJson());
    expect(copy.reference, source.reference);
    expect(copy.amount, source.amount);
    expect(copy.status, FinanceReconciliationStatus.matched);
    expect(copy.familyAccountId, 'FAM-ABD-001');
    expect(copy.familyAccountNumber, '1047263815');
    expect(copy.childLedgerId, 'STU-001');
  });

  test('reconciliation money formatter matches Nigerian display', () {
    expect(financeReconciliationMoney(80000), '₦80,000');
    expect(financeReconciliationMoney(50000), '₦50,000');
  });

  testWidgets('manual review proposal does not turn ambiguous transfer into matched payment', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceReconciliationPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Review & match'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Human review · BNK-260913-879'), findsOneWidget);
    expect(find.text('Still Review'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Alhaji Abdullahi Yusuf').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField).last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Maryam Abdullahi').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Record review proposal'));
    await tester.pumpAndSettle();

    expect(find.textContaining('transaction remains Review'), findsOneWidget);
    expect(find.textContaining('no child balance or receipt changed'), findsOneWidget);
    expect(financeReconciliationRows[1].status, FinanceReconciliationStatus.review);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payment Reconciliation renders on phone without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FinanceReconciliationPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Reconciliation'), findsOneWidget);
    expect(find.text('Import bank statement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
