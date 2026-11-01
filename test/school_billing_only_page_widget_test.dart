import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/account/presentation/school_billing_only_page.dart';
import 'package:schoolos_app/features/billing/data/billing_repository.dart';

import 'fake_billing_api_client.dart';

/// [SchoolBillingOnlyPage] (Phase D Stage 1.5, Task 5) is the read-only destination for an
/// organization-level billing administrator who holds no school-level membership - it must
/// show the school's own subscription status and never anything resembling an academic or
/// operational workspace.
void main() {
  testWidgets('shows the school name, its entitlement card, and no workspace chrome', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond('schools/school-1/billing/entitlements/', {
        'schoolId': 'school-1',
        'schoolName': 'BrightGate Academy',
        'organizationId': 'org-1',
        'viewerRole': null,
        'canManageBilling': true,
        'premiumEnforcementEnabled': false,
        'paymentStatus': 'unpaid',
        'academicTerm': null,
        'academicSession': null,
        'currentPeriod': null,
        'enrollment': null,
        'entitlements': {
          'cbt_exam_publish': {
            'planEnabled': true,
            'schoolPaid': false,
            'available': false,
            'reason': '',
          },
          'report_card_generation': {
            'planEnabled': true,
            'schoolPaid': false,
            'available': false,
            'reason': '',
          },
        },
        'billing': null,
      });
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolBillingOnlyPage(
          schoolId: 'school-1',
          schoolName: 'BrightGate Academy',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BrightGate Academy · Billing'), findsOneWidget);
    expect(find.textContaining("This school's subscription"), findsOneWidget);
    expect(find.textContaining('do not have a role at this school'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
