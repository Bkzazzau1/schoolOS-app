import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/familyfees/domain/family_fees_models.dart';
import 'package:schoolos_app/features/parent/domain/verified_payment_receipt_pdf.dart';

import 'family_fees_fixtures.dart';

void main() {
  test('a fully matched payment renders as a real, non-empty PDF', () async {
    final payment = FamilyVerifiedPayment.fromJson(verifiedPaymentJson());
    final bytes = await buildVerifiedPaymentReceiptPdf(payment: payment, schoolName: 'BrightGate Academy', familyName: 'Bello family');
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('a partially matched payment shows the unapplied amount without error', () async {
    final payment = FamilyVerifiedPayment.fromJson(verifiedPaymentJson(
      amountMinor: 15000000,
      allocatedMinor: 12000000,
      creditMinor: 0,
      unappliedMinor: 3000000,
    ));
    final bytes = await buildVerifiedPaymentReceiptPdf(payment: payment, schoolName: 'BrightGate Academy', familyName: 'Bello family');
    expect(bytes.length, greaterThan(500));
  });

  test('an overpayment held as credit renders without error', () async {
    final payment = FamilyVerifiedPayment.fromJson(verifiedPaymentJson(amountMinor: 15000000, allocatedMinor: 12000000, creditMinor: 3000000));
    final bytes = await buildVerifiedPaymentReceiptPdf(payment: payment, schoolName: 'BrightGate Academy', familyName: 'Bello family');
    expect(bytes.length, greaterThan(500));
  });

  test('several allocations across students all appear', () async {
    final payment = FamilyVerifiedPayment.fromJson(verifiedPaymentJson(
      amountMinor: 20000000,
      allocatedMinor: 20000000,
      allocations: [
        verifiedAllocationJson(studentId: 's1', studentName: 'Ahmad Bello', item: 'Tuition', amountMinor: 12000000),
        verifiedAllocationJson(studentId: 's2', studentName: 'Aisha Bello', item: 'Tuition', amountMinor: 8000000),
      ],
    ));
    final bytes = await buildVerifiedPaymentReceiptPdf(payment: payment, schoolName: 'BrightGate Academy', familyName: 'Bello family');
    expect(bytes.length, greaterThan(500));
  });
}
