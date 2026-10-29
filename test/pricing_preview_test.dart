import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/domain/subscription_summary.dart';

void main() {
  test('a null pricingPreview parses to null, not a crash', () {
    final summary = OrganizationSubscriptionSummary.fromJson(const {
      'organizationId': 'org-1',
      'status': 'active',
      'accessMode': 'full',
      'canManageBilling': true,
    });
    expect(summary.pricingPreview, isNull);
  });

  test('a single-school preview parses its bracket and has no discount', () {
    final preview = PricingPreview.fromJson(const {
      'totalMinor': 4000000,
      'grossMinor': 4000000,
      'discountMinor': 0,
      'currency': 'NGN',
      'lines': [
        {
          'schoolId': 'school-1',
          'billableStudentCount': 80,
          'fixedFeeMinor': 4000000,
          'pricingSource': 'bracket',
          'bracketMinStudents': 1,
          'bracketMaxStudents': 100,
        },
      ],
    });
    expect(preview.hasDiscount, isFalse);
    expect(preview.isMultiSchool, isFalse);
    expect(preview.lines.single.bracketMaxStudents, 100);
  });

  test('an annual discounted preview carries the gross total and term count', () {
    final preview = PricingPreview.fromJson(const {
      'totalMinor': 10800000,
      'grossMinor': 12000000,
      'discountMinor': 1200000,
      'currency': 'NGN',
      'lines': [
        {
          'schoolId': 'school-1',
          'billableStudentCount': 50,
          'fixedFeeMinor': 10800000,
          'pricingSource': 'bracket',
          'bracketMinStudents': 1,
          'bracketMaxStudents': 100,
          'termCount': 3,
        },
      ],
    });
    expect(preview.hasDiscount, isTrue);
    expect(preview.grossMinor, 12000000);
    expect(preview.lines.single.termCount, 3);
  });

  test('a multi-school preview sums every school into isMultiSchool', () {
    final preview = PricingPreview.fromJson(const {
      'totalMinor': 16000000,
      'grossMinor': 16000000,
      'discountMinor': 0,
      'currency': 'NGN',
      'lines': [
        {'schoolId': 's1', 'billableStudentCount': 80, 'fixedFeeMinor': 4000000, 'pricingSource': 'bracket'},
        {'schoolId': 's2', 'billableStudentCount': 450, 'fixedFeeMinor': 12000000, 'pricingSource': 'bracket'},
      ],
    });
    expect(preview.isMultiSchool, isTrue);
    expect(preview.lines, hasLength(2));
  });
}
