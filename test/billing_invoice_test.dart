import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/domain/billing_invoice.dart';

BillingInvoice _invoice({required int amountDueMinor, required int amountPaidMinor}) {
  return BillingInvoice(
    id: 'inv-1',
    number: 'INV-0001',
    organizationId: 'org-1',
    status: 'open',
    currency: 'NGN',
    baseAmountMinor: 0,
    studentUnitAmountMinor: 0,
    billableStudentCount: 0,
    amountDueMinor: amountDueMinor,
    amountPaidMinor: amountPaidMinor,
    issuedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('outstandingMinor is the due amount minus what has been paid', () {
    expect(_invoice(amountDueMinor: 10000, amountPaidMinor: 4000).outstandingMinor, 6000);
  });

  test('outstandingMinor never goes negative when overpaid', () {
    expect(_invoice(amountDueMinor: 10000, amountPaidMinor: 15000).outstandingMinor, 0);
  });

  // amountDueMinor is trusted server data with no non-negative guarantee (a
  // credit-note invoice, a refund adjustment, or a bad backend value). Before
  // the fix, clamp(0, amountDueMinor) threw here because Dart's clamp requires
  // lower <= upper, which crashed every screen that reads outstandingMinor.
  test('outstandingMinor does not throw when the server sends a negative amount due', () {
    expect(() => _invoice(amountDueMinor: -500, amountPaidMinor: 0).outstandingMinor, returnsNormally);
    expect(_invoice(amountDueMinor: -500, amountPaidMinor: 0).outstandingMinor, 0);
  });
}
