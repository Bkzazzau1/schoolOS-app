import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/data/billing_repository.dart';
import 'package:schoolos_app/features/billing/presentation/school_entitlement_card.dart';

import 'fake_billing_api_client.dart';

Map<String, dynamic> _entitlementJson({
  String schoolId = 'school-1',
  String schoolName = 'BrightGate Academy',
  String? organizationId = 'org-1',
  String? viewerRole = 'proprietor',
  bool canManageBilling = false,
  bool premiumEnforcementEnabled = false,
  String paymentStatus = 'paid',
  Object? academicTerm,
  Object? enrollment,
  Object? billing,
  Map<String, dynamic>? entitlements,
}) {
  final defaultAvailable = paymentStatus == 'paid';
  return {
    'schoolId': schoolId,
    'schoolName': schoolName,
    'organizationId': organizationId,
    'viewerRole': viewerRole,
    'canManageBilling': canManageBilling,
    'premiumEnforcementEnabled': premiumEnforcementEnabled,
    'paymentStatus': paymentStatus,
    'academicTerm': academicTerm,
    'academicSession': null,
    'currentPeriod': null,
    'enrollment': enrollment,
    'entitlements': entitlements ??
        {
          'cbt_exam_publish': {
            'planEnabled': true,
            'schoolPaid': defaultAvailable,
            'available': defaultAvailable,
            'reason': defaultAvailable
                ? ''
                : "This feature needs this school's current term subscription to be paid.",
          },
          'report_card_generation': {
            'planEnabled': true,
            'schoolPaid': defaultAvailable,
            'available': defaultAvailable,
            'reason': defaultAvailable
                ? ''
                : "This feature needs this school's current term subscription to be paid.",
          },
        },
    'billing': billing,
  };
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('a paid school shows the Paid chip and available capabilities, never a lock', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond('schools/school-1/billing/entitlements/', _entitlementJson(paymentStatus: 'paid'));
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paid'), findsOneWidget);
    expect(find.textContaining('Publish CBT exams'), findsOneWidget);
    expect(find.textContaining('requires payment'), findsNothing);
  });

  testWidgets(
    'an unpaid school with enforcement on shows the Unpaid chip and locked capabilities',
    (tester) async {
      final api = FakeApiClient()
        ..respond(
          'schools/school-1/billing/entitlements/',
          _entitlementJson(paymentStatus: 'unpaid', premiumEnforcementEnabled: true),
        );
      final repository = BillingRepository(api: api);

      await tester.pumpWidget(
        _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unpaid'), findsOneWidget);
      expect(find.textContaining('requires payment'), findsWidgets);
    },
  );

  testWidgets('plan-disabled and payment-pending capabilities carry their own distinct reason', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(
          paymentStatus: 'unpaid',
          premiumEnforcementEnabled: true,
          entitlements: {
            'cbt_exam_publish': {
              'planEnabled': false,
              'schoolPaid': true,
              'available': false,
              'reason': 'Your current SkulGen plan does not include this feature.',
            },
            'report_card_generation': {
              'planEnabled': true,
              'schoolPaid': false,
              'available': false,
              'reason': "This feature needs this school's current term subscription to be paid.",
            },
          },
        ),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    final messages = tester
        .widgetList<Tooltip>(find.byType(Tooltip))
        .map((tooltip) => tooltip.message)
        .toList();
    expect(messages, contains('Your current SkulGen plan does not include this feature.'));
    expect(
      messages,
      contains("This feature needs this school's current term subscription to be paid."),
    );
  });

  testWidgets('premium enforcement disabled shows a future-facing note, never a lock', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(paymentStatus: 'unpaid', premiumEnforcementEnabled: false),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('payment will apply'), findsWidgets);
    expect(find.textContaining('requires payment'), findsNothing);
    // Never developer/rollout terminology shown to the person reading this page.
    expect(find.textContaining('enforcement'), findsNothing);
  });

  testWidgets('a missing academic term shows "Not configured" rather than inventing one', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond('schools/school-1/billing/entitlements/', _entitlementJson(academicTerm: null));
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not configured'), findsOneWidget);
  });

  testWidgets('a billing authority sees an honest "no invoice yet" message, not a fabricated one', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(paymentStatus: 'no_invoice_yet', canManageBilling: true, billing: null),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No invoice has been issued'), findsOneWidget);
  });

  testWidgets('without billing authority, payment controls and invoice detail stay hidden', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(paymentStatus: 'unpaid', canManageBilling: false, billing: null),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay with Paystack'), findsNothing);
    expect(find.textContaining('No invoice has been issued'), findsNothing);
  });

  testWidgets('a billing administrator with no school role still sees full billing detail', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(
          paymentStatus: 'unpaid',
          canManageBilling: true,
          viewerRole: null,
          billing: {
            'organizationId': 'org-1',
            'invoiceId': 'inv-1',
            'invoiceNumber': 'SOS-1',
            'status': 'open',
            'amountDueMinor': 4000000,
            'amountPaidMinor': 0,
            'currency': 'NGN',
            'issuedAt': '2026-01-01T00:00:00Z',
            'payable': true,
          },
        ),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('SOS-1'), findsOneWidget);
    expect(find.text('Pay with Paystack'), findsOneWidget);
  });

  testWidgets(
    'a pending payment attempt is recovered from the server, offering Refresh not a silent new charge',
    (tester) async {
      final api = FakeApiClient()
        ..respond(
          'schools/school-1/billing/entitlements/',
          _entitlementJson(
            paymentStatus: 'unpaid',
            canManageBilling: true,
            billing: {
              'organizationId': 'org-1',
              'invoiceId': 'inv-1',
              'invoiceNumber': 'SOS-1',
              'status': 'open',
              'amountDueMinor': 4000000,
              'amountPaidMinor': 0,
              'currency': 'NGN',
              'issuedAt': '2026-01-01T00:00:00Z',
              'payable': true,
              'latestPaymentAttempt': {
                'reference': 'ref-1',
                'status': 'pending',
                'createdAt': '2026-01-01T00:05:00Z',
                'checkoutUrl': 'https://checkout.paystack.com/ref-1',
              },
            },
          ),
        );
      final repository = BillingRepository(api: api);

      await tester.pumpWidget(
        _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refresh payment'), findsOneWidget);
      expect(find.text('Start a new payment'), findsOneWidget);
      expect(find.text('Pay with Paystack'), findsNothing);
      // Recovered straight from the first load - never a checkout call just to check.
      expect(api.callCount('organizations/org-1/billing/invoices/inv-1/checkout/'), 0);
    },
  );

  testWidgets('a failed verification explains plainly and leaves the card usable to retry', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(
          paymentStatus: 'unpaid',
          canManageBilling: true,
          billing: {
            'organizationId': 'org-1',
            'invoiceId': 'inv-1',
            'invoiceNumber': 'SOS-1',
            'status': 'open',
            'amountDueMinor': 4000000,
            'amountPaidMinor': 0,
            'currency': 'NGN',
            'issuedAt': '2026-01-01T00:00:00Z',
            'payable': true,
            'latestPaymentAttempt': {
              'reference': 'ref-1',
              'status': 'pending',
              'createdAt': '2026-01-01T00:05:00Z',
            },
          },
        ),
      )
      ..respond('organizations/org-1/billing/payments/ref-1/verify/', {
        'invoice': {
          'id': 'inv-1',
          'number': 'SOS-1',
          'organizationId': 'org-1',
          'status': 'open',
          'currency': 'NGN',
          'amountDueMinor': 4000000,
          'amountPaidMinor': 0,
          'issuedAt': '2026-01-01T00:00:00Z',
        },
        'payment': {
          'id': 'att-1',
          'provider': 'paystack',
          'reference': 'ref-1',
          'status': 'pending',
          'amountMinor': 4000000,
          'currency': 'NGN',
          'createdAt': '2026-01-01T00:05:00Z',
        },
      });
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refresh payment'));
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been confirmed yet'), findsOneWidget);
    // The card is still usable: the same pending attempt can be checked again.
    expect(find.text('Refresh payment'), findsOneWidget);
  });

  testWidgets(
    'a successful verification confirms via the entitlement API, not just the payment response',
    (tester) async {
      final api = FakeApiClient();
      var loadCount = 0;
      api.respondWith('schools/school-1/billing/entitlements/', (_) {
        loadCount++;
        final paid = loadCount > 1;
        return _entitlementJson(
          paymentStatus: paid ? 'paid' : 'unpaid',
          canManageBilling: true,
          billing: paid
              ? {
                  'organizationId': 'org-1',
                  'invoiceId': 'inv-1',
                  'invoiceNumber': 'SOS-1',
                  'status': 'paid',
                  'amountDueMinor': 4000000,
                  'amountPaidMinor': 4000000,
                  'currency': 'NGN',
                  'issuedAt': '2026-01-01T00:00:00Z',
                  'payable': false,
                }
              : {
                  'organizationId': 'org-1',
                  'invoiceId': 'inv-1',
                  'invoiceNumber': 'SOS-1',
                  'status': 'open',
                  'amountDueMinor': 4000000,
                  'amountPaidMinor': 0,
                  'currency': 'NGN',
                  'issuedAt': '2026-01-01T00:00:00Z',
                  'payable': true,
                  'latestPaymentAttempt': {
                    'reference': 'ref-1',
                    'status': 'pending',
                    'createdAt': '2026-01-01T00:05:00Z',
                  },
                },
        );
      });
      api.respond('organizations/org-1/billing/payments/ref-1/verify/', {
        'invoice': {
          'id': 'inv-1',
          'number': 'SOS-1',
          'organizationId': 'org-1',
          'status': 'paid',
          'currency': 'NGN',
          'amountDueMinor': 4000000,
          'amountPaidMinor': 4000000,
          'issuedAt': '2026-01-01T00:00:00Z',
        },
        'payment': {
          'id': 'att-1',
          'provider': 'paystack',
          'reference': 'ref-1',
          'status': 'succeeded',
          'amountMinor': 4000000,
          'currency': 'NGN',
          'createdAt': '2026-01-01T00:05:00Z',
          'succeededAt': '2026-01-01T00:06:00Z',
        },
      });
      final repository = BillingRepository(api: api);

      await tester.pumpWidget(
        _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refresh payment'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Premium capabilities are now available'), findsOneWidget);
      expect(find.text('Paid'), findsWidgets);
    },
  );

  testWidgets('different selected schools reload independently when the school id changes', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(schoolId: 'school-1', schoolName: 'Campus A', paymentStatus: 'paid'),
      )
      ..respond(
        'schools/school-2/billing/entitlements/',
        _entitlementJson(schoolId: 'school-2', schoolName: 'Campus B', paymentStatus: 'unpaid'),
      );
    final repository = BillingRepository(api: api);
    final key = GlobalKey();

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(key: key, schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Paid'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(key: key, schoolId: 'school-2', repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unpaid'), findsOneWidget);
    expect(api.callCount('schools/school-2/billing/entitlements/'), 1);
  });

  testWidgets(
    'a payment the webhook already settled before the person returns shows Paid directly',
    (tester) async {
      final api = FakeApiClient()
        ..respond(
          'schools/school-1/billing/entitlements/',
          _entitlementJson(
            paymentStatus: 'paid',
            canManageBilling: true,
            billing: {
              'organizationId': 'org-1',
              'invoiceId': 'inv-1',
              'invoiceNumber': 'SOS-1',
              'status': 'paid',
              'amountDueMinor': 4000000,
              'amountPaidMinor': 4000000,
              'currency': 'NGN',
              'issuedAt': '2026-01-01T00:00:00Z',
              'payable': false,
              'latestPaymentAttempt': {
                'reference': 'ref-1',
                'status': 'succeeded',
                'createdAt': '2026-01-01T00:05:00Z',
              },
            },
          ),
        );
      final repository = BillingRepository(api: api);

      await tester.pumpWidget(
        _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
      );
      await tester.pumpAndSettle();

      // No tap needed at all - the server already shows this as settled.
      expect(find.text('Paid'), findsWidgets);
      expect(find.text('Refresh payment'), findsNothing);
      expect(find.text('Pay with Paystack'), findsNothing);
      expect(api.callCount('organizations/org-1/billing/payments/ref-1/verify/'), 0);
    },
  );

  testWidgets('a failed or expired payment attempt offers a fresh payment, never "Refresh"', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(
          paymentStatus: 'unpaid',
          canManageBilling: true,
          billing: {
            'organizationId': 'org-1',
            'invoiceId': 'inv-1',
            'invoiceNumber': 'SOS-1',
            'status': 'open',
            'amountDueMinor': 4000000,
            'amountPaidMinor': 0,
            'currency': 'NGN',
            'issuedAt': '2026-01-01T00:00:00Z',
            'payable': true,
            'latestPaymentAttempt': {
              'reference': 'ref-old',
              'status': 'failed',
              'createdAt': '2026-01-01T00:05:00Z',
            },
          },
        ),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(SchoolEntitlementCard(schoolId: 'school-1', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay with Paystack'), findsOneWidget);
    expect(find.text('Refresh payment'), findsNothing);
    expect(find.text('Start a new payment'), findsNothing);
  });
}
