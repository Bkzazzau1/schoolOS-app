import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/domain/school_entitlement_summary.dart';

Map<String, dynamic> _payload({
  String paymentStatus = 'paid',
  bool canManageBilling = false,
  bool premiumEnforcementEnabled = false,
  Map<String, dynamic>? entitlements,
  Map<String, dynamic>? enrollment,
  Map<String, dynamic>? billing,
  Map<String, dynamic>? academicTerm,
  Map<String, dynamic>? currentPeriod,
  String? organizationId = 'org-1',
}) {
  return {
    'schoolId': 'school-1',
    'schoolName': 'BrightGate Academy',
    'organizationId': organizationId,
    'viewerRole': 'teacher',
    'canManageBilling': canManageBilling,
    'premiumEnforcementEnabled': premiumEnforcementEnabled,
    'paymentStatus': paymentStatus,
    'academicTerm': academicTerm,
    'academicSession': null,
    'currentPeriod': currentPeriod,
    'enrollment': enrollment,
    'entitlements': entitlements ??
        {
          'cbt_exam_publish': {'available': true, 'reason': ''},
          'report_card_generation': {'available': true, 'reason': ''},
        },
    'billing': billing,
  };
}

void main() {
  test('fromJson parses a fully-paid school with both capabilities available', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload());
    expect(summary.schoolId, 'school-1');
    expect(summary.isPaid, isTrue);
    expect(summary.subscriptionApplies, isTrue);
    expect(summary.capability('cbt_exam_publish').available, isTrue);
    expect(summary.capability('report_card_generation').available, isTrue);
  });

  test('capability() returns a safe unavailable default for an unknown code, never a crash', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload());
    final unknown = summary.capability('something_invented');
    expect(unknown.available, isFalse);
    expect(unknown.reason, isEmpty);
  });

  test('an unpaid schools capabilities are unavailable with a server-given reason', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      paymentStatus: 'unpaid',
      entitlements: {
        'cbt_exam_publish': {
          'planEnabled': true,
          'schoolPaid': false,
          'available': false,
          'reason': "This feature needs this school's current term subscription to be paid.",
        },
      },
    ));
    expect(summary.isPaid, isFalse);
    final capability = summary.capability('cbt_exam_publish');
    expect(capability.available, isFalse);
    expect(capability.reason, isNotEmpty);
  });

  test('plan entitlement and school payment parse as separate signals, never one boolean', () {
    final planDisabled = SchoolEntitlementSummary.fromJson(_payload(
      entitlements: {
        'cbt_exam_publish': {
          'planEnabled': false,
          'schoolPaid': true,
          'available': false,
          'reason': 'Your current SkulGen plan does not include this feature.',
        },
      },
    )).capability('cbt_exam_publish');
    expect(planDisabled.planEnabled, isFalse);
    expect(planDisabled.schoolPaid, isTrue);
    expect(planDisabled.available, isFalse);

    final unpaidSchool = SchoolEntitlementSummary.fromJson(_payload(
      entitlements: {
        'cbt_exam_publish': {
          'planEnabled': true,
          'schoolPaid': false,
          'available': false,
          'reason': "This feature needs this school's current term subscription to be paid.",
        },
      },
    )).capability('cbt_exam_publish');
    expect(unpaidSchool.planEnabled, isTrue);
    expect(unpaidSchool.schoolPaid, isFalse);
  });

  test('a legacy school with no organization reports not_applicable and never shows billing', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      paymentStatus: 'not_applicable',
      organizationId: null,
      canManageBilling: false,
    ));
    expect(summary.subscriptionApplies, isFalse);
    expect(summary.organizationId, isNull);
    expect(summary.billing, isNull);
    expect(summary.paymentStatusLabel, 'Not applicable');
  });

  test('billing detail is null when the server did not include it, never an invented one', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(canManageBilling: true, billing: null));
    expect(summary.canManageBilling, isTrue);
    expect(summary.billing, isNull);
  });

  test('billing detail parses amounts, outstanding balance and payable state from a real invoice', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      canManageBilling: true,
      billing: {
        'organizationId': 'org-1',
        'invoiceId': 'inv-1',
        'invoiceNumber': 'SOS-20260101-ABC',
        'status': 'open',
        'amountDueMinor': 4000000,
        'amountPaidMinor': 1000000,
        'currency': 'NGN',
        'issuedAt': '2026-01-01T00:00:00Z',
        'dueAt': '2026-01-08T00:00:00Z',
        'payable': true,
      },
    ));
    final billing = summary.billing!;
    expect(billing.outstandingMinor, 3000000);
    expect(billing.paid, isFalse);
    expect(billing.payable, isTrue);
  });

  test('billing outstandingMinor never goes negative or throws on a bad server value', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      canManageBilling: true,
      billing: {
        'organizationId': 'org-1',
        'invoiceId': 'inv-1',
        'invoiceNumber': 'SOS-20260101-ABC',
        'status': 'paid',
        'amountDueMinor': -500,
        'amountPaidMinor': 0,
        'currency': 'NGN',
        'issuedAt': '2026-01-01T00:00:00Z',
        'payable': false,
      },
    ));
    expect(() => summary.billing!.outstandingMinor, returnsNormally);
    expect(summary.billing!.outstandingMinor, 0);
    expect(summary.billing!.paid, isTrue);
  });

  test('enrollment reports a bracket label when the price is known', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      enrollment: {
        'billableStudentCount': 20,
        'measuredAt': '2026-01-01T00:00:00Z',
        'bracketMinStudents': 1,
        'bracketMaxStudents': 100,
        'pricingSource': 'bracket',
        'undefinedReason': null,
      },
    ));
    final enrollment = summary.enrollment!;
    expect(enrollment.isPriceKnown, isTrue);
    expect(enrollment.isEnterprise, isFalse);
    expect(enrollment.pricingLabel, '1–100 students');
  });

  test('enrollment never invents a price for zero enrollment - it carries a reason instead', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      enrollment: {
        'billableStudentCount': 0,
        'measuredAt': '2026-01-01T00:00:00Z',
        'bracketMinStudents': null,
        'bracketMaxStudents': null,
        'pricingSource': null,
        'undefinedReason': 'This school has zero billable students.',
      },
    ));
    final enrollment = summary.enrollment!;
    expect(enrollment.isPriceKnown, isFalse);
    expect(enrollment.undefinedReason, isNotNull);
  });

  test('an enterprise agreement labels itself as an agreement, never a bracket range', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      enrollment: {
        'billableStudentCount': 5000,
        'bracketMinStudents': null,
        'bracketMaxStudents': null,
        'pricingSource': 'enterprise',
      },
    ));
    final enrollment = summary.enrollment!;
    expect(enrollment.isEnterprise, isTrue);
    expect(enrollment.pricingLabel, 'Enterprise agreement');
  });

  test('academic term and current period parse from real nested payloads', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload(
      academicTerm: {
        'id': 'term-1',
        'code': 't1',
        'name': 'Term 1',
        'startsOn': '2026-01-10',
        'endsOn': '2026-04-10',
      },
      currentPeriod: {'start': '2026-01-10T00:00:00Z', 'end': '2026-04-11T00:00:00Z'},
    ));
    expect(summary.academicTerm?.name, 'Term 1');
    expect(summary.currentPeriodStart, isNotNull);
    expect(summary.currentPeriodEnd, isNotNull);
  });

  test('a missing academic term or enrollment parses as null, never a guessed value', () {
    final summary = SchoolEntitlementSummary.fromJson(_payload());
    expect(summary.academicTerm, isNull);
    expect(summary.academicSession, isNull);
    expect(summary.enrollment, isNull);
    expect(summary.currentPeriodStart, isNull);
  });

  test('paymentStatusLabel covers every real server status', () {
    for (final entry in {
      'paid': 'Paid',
      'unpaid': 'Unpaid',
      'no_invoice_yet': 'No invoice yet',
      'not_applicable': 'Not applicable',
    }.entries) {
      final summary = SchoolEntitlementSummary.fromJson(_payload(paymentStatus: entry.key));
      expect(summary.paymentStatusLabel, entry.value);
    }
  });
}
