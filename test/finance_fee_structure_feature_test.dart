import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/finance_office/data/finance_fee_structure_demo_data.dart';
import 'package:schoolos_app/features/finance_office/presentation/finance_fee_structure_page.dart';

void main() {
  test('fee structure preserves exact section charges from website', () {
    expect(financeFeeSections.length, 3);
    expect(financeFeeSections[0].section, 'Nursery / Early Years');
    expect(financeFeeSections[0].students, 84);
    expect(financeFeeSections[0].tuition, 95000);
    expect(financeFeeSections[0].total, 117500);
    expect(financeFeeSections[1].section, 'Primary School');
    expect(financeFeeSections[1].students, 286);
    expect(financeFeeSections[1].total, 145000);
    expect(financeFeeSections[2].section, 'Secondary School');
    expect(financeFeeSections[2].students, 278);
    expect(financeFeeSections[2].total, 185000);
  });

  test('fee structure preserves optional charge policy', () {
    expect(financeOptionalCharges.length, 5);
    expect(financeOptionalCharges.first.charge, 'Transport');
    expect(financeOptionalCharges.first.amount, 'Route-based');
    expect(financeOptionalCharges[1].amount, '₦35,000');
    expect(financeOptionalCharges[3].mode, 'Optional / required by policy');
    expect(financeOptionalCharges.last.rule, 'Not merged into tuition silently');
  });

  test('fee structure preserves billing sequence and accounting distinction', () {
    expect(financeBillingSequence.length, 5);
    expect(financeBillingSequence.map((step) => step.title).toList(), [
      'Section fee structure',
      'Optional services',
      'Scholarships & discounts',
      'Net collectible',
      'Collections',
    ]);
    expect(financeFeeBillingPopulation, 648);
    expect(financeFeeAccountingDistinction, contains('reduce what the parent owes'));
    expect(financeFeeAccountingDistinction, contains('after those concessions are applied'));
  });

  test('fee structure preserves exact term options and money formatting', () {
    expect(financeFeeTerms, [
      '2026/2027 · Term 1',
      '2026/2027 · Term 2',
      '2026/2027 · Term 3',
    ]);
    expect(financeMoney(117500), '₦117,500');
    expect(financeMoney(145000), '₦145,000');
    expect(financeMoney(185000), '₦185,000');
  });

  testWidgets('fee structure save draft preserves local prototype behavior', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FinanceFeeStructurePage()),
      ),
    );

    expect(find.text('Fee Structure'), findsOneWidget);
    expect(find.text('Draft fee structure saved locally in this UI prototype.'), findsNothing);

    await tester.tap(find.text('Save draft'));
    await tester.pump();

    expect(
      find.text('Draft fee structure saved locally in this UI prototype.'),
      findsOneWidget,
    );
  });
}
