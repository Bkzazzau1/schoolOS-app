import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/domain/billing_invoice.dart';

BillingInvoice _invoice({
  required int amountDueMinor,
  required int amountPaidMinor,
  int? grossAmountMinor,
  int discountMinor = 0,
  List<BillingInvoiceLine> lines = const [],
}) {
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
    grossAmountMinor: grossAmountMinor ?? amountDueMinor,
    discountMinor: discountMinor,
    issuedAt: DateTime(2026, 1, 1),
    lines: lines,
  );
}

BillingInvoiceLine _line({
  String schoolId = 'school-1',
  String schoolName = 'BrightGate Academy',
  int billableStudentCount = 80,
  int fixedFeeMinor = 4000000,
  String pricingSource = 'bracket',
  int? bracketMinStudents = 1,
  int? bracketMaxStudents = 100,
}) {
  return BillingInvoiceLine(
    id: 'line-1',
    schoolId: schoolId,
    schoolName: schoolName,
    billableStudentCount: billableStudentCount,
    currency: 'NGN',
    fixedFeeMinor: fixedFeeMinor,
    pricingSource: pricingSource,
    bracketMinStudents: bracketMinStudents,
    bracketMaxStudents: bracketMaxStudents,
    grossFeeMinor: fixedFeeMinor,
    discountMinor: 0,
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

  test('hasDiscount and isMultiSchool read the real server fields, not a guess', () {
    final noDiscount = _invoice(amountDueMinor: 4000000, amountPaidMinor: 0);
    expect(noDiscount.hasDiscount, isFalse);
    expect(noDiscount.isMultiSchool, isFalse);

    final discounted = _invoice(
      amountDueMinor: 10800000,
      amountPaidMinor: 0,
      grossAmountMinor: 12000000,
      discountMinor: 1200000,
    );
    expect(discounted.hasDiscount, isTrue);

    final multiSchool = _invoice(
      amountDueMinor: 16000000,
      amountPaidMinor: 0,
      lines: [_line(), _line(schoolId: 'school-2', schoolName: 'Second Campus')],
    );
    expect(multiSchool.isMultiSchool, isTrue);
  });

  test('a bracket line labels itself by its range, never a per-student figure', () {
    expect(_line(bracketMinStudents: 1, bracketMaxStudents: 100).pricingLabel, '1–100 students');
    expect(_line(bracketMinStudents: 1001, bracketMaxStudents: null).pricingLabel, '1001+ students');
  });

  test('an enterprise line labels itself as an agreement, never a bracket range', () {
    final line = _line(pricingSource: 'enterprise', bracketMinStudents: null, bracketMaxStudents: null);
    expect(line.isEnterprise, isTrue);
    expect(line.pricingLabel, 'Enterprise agreement');
  });

  test('fromJson parses lines, gross and discount from a real invoice payload', () {
    final invoice = BillingInvoice.fromJson({
      'id': 'inv-2',
      'number': 'SOS-20260101-ABC',
      'organizationId': 'org-1',
      'status': 'open',
      'currency': 'NGN',
      'amountDueMinor': 16000000,
      'amountPaidMinor': 0,
      'grossAmountMinor': 16000000,
      'discountMinor': 0,
      'pricingMode': 'fixed_bracket',
      'issuedAt': '2026-01-01T00:00:00Z',
      'lines': [
        {
          'id': 'line-1',
          'schoolId': 'school-1',
          'schoolName': 'BrightGate Academy',
          'billableStudentCount': 80,
          'currency': 'NGN',
          'fixedFeeMinor': 4000000,
          'pricingSource': 'bracket',
          'bracketMinStudents': 1,
          'bracketMaxStudents': 100,
          'grossFeeMinor': 4000000,
          'discountMinor': 0,
        },
      ],
    });

    expect(invoice.isFixedBracketPriced, isTrue);
    expect(invoice.lines, hasLength(1));
    expect(invoice.lines.first.schoolName, 'BrightGate Academy');
    expect(invoice.lines.first.pricingLabel, '1–100 students');
  });

  test('fromJson falls back gross to amountDueMinor for an invoice issued before this field existed', () {
    final invoice = BillingInvoice.fromJson({
      'id': 'inv-3',
      'amountDueMinor': 500000,
      'amountPaidMinor': 0,
      'issuedAt': '2026-01-01T00:00:00Z',
    });
    expect(invoice.grossAmountMinor, 500000);
    expect(invoice.discountMinor, 0);
    expect(invoice.lines, isEmpty);
  });
}
