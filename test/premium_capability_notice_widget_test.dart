import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/billing/data/billing_repository.dart';
import 'package:schoolos_app/features/billing/presentation/billing_scope.dart';
import 'package:schoolos_app/features/billing/presentation/premium_capability_notice.dart';

import 'fake_billing_api_client.dart';

Map<String, dynamic> _entitlementJson({
  String code = 'cbt_exam_publish',
  bool available = true,
  bool premiumEnforcementEnabled = false,
  String reason = '',
}) {
  return {
    'schoolId': 'school-1',
    'schoolName': 'BrightGate Academy',
    'organizationId': 'org-1',
    'viewerRole': 'teacher',
    'canManageBilling': false,
    'premiumEnforcementEnabled': premiumEnforcementEnabled,
    'paymentStatus': available ? 'paid' : 'unpaid',
    'academicTerm': null,
    'academicSession': null,
    'currentPeriod': null,
    'enrollment': null,
    'entitlements': {
      code: {'planEnabled': true, 'schoolPaid': available, 'available': available, 'reason': reason},
    },
    'billing': null,
  };
}

Widget _wrap(BillingRepository repository, Widget child) =>
    MaterialApp(home: Scaffold(body: BillingScope(repository: repository, child: child)));

void main() {
  testWidgets('shows nothing while the capability is available', (tester) async {
    final api = FakeApiClient()
      ..respond('schools/school-1/billing/entitlements/', _entitlementJson(available: true));
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Container), findsNothing);
    expect(find.textContaining('Publishing a new exam'), findsNothing);
  });

  testWidgets('shows nothing when unavailable but enforcement is off - never a misleading lock', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(available: false, premiumEnforcementEnabled: false),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('needs this school'), findsNothing);
    expect(find.textContaining('enforcement'), findsNothing);
  });

  testWidgets('shows the servers own reason when unavailable and enforcement is on', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(
          available: false,
          premiumEnforcementEnabled: true,
          reason: "This feature needs this school's current term subscription to be paid.",
        ),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining("This feature needs this school's current term subscription to be paid."),
      findsOneWidget,
    );
  });

  testWidgets('reports status via onStatus so a host screen can gate its own button', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..respond(
        'schools/school-1/billing/entitlements/',
        _entitlementJson(available: false, premiumEnforcementEnabled: true),
      );
    final repository = BillingRepository(api: api);
    bool? reportedEnforced;
    bool? reportedAvailable;

    await tester.pumpWidget(
      _wrap(
        repository,
        PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
          onStatus: (enforced, available) {
            reportedEnforced = enforced;
            reportedAvailable = available;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(reportedEnforced, isTrue);
    expect(reportedAvailable, isFalse);
  });

  testWidgets('refetches when the selected school changes', (tester) async {
    final api = FakeApiClient()
      ..respond('schools/school-1/billing/entitlements/', _entitlementJson(available: true))
      ..respond(
        'schools/school-2/billing/entitlements/',
        _entitlementJson(available: false, premiumEnforcementEnabled: true, reason: 'School 2 needs payment.'),
      );
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('School 2 needs payment.'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-2',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('School 2 needs payment.'), findsOneWidget);
    expect(api.callCount('schools/school-2/billing/entitlements/'), 1);
  });

  testWidgets('refetches when the repository reports an entitlement-affecting change', (
    tester,
  ) async {
    final api = FakeApiClient();
    var callCount = 0;
    api.respondWith('schools/school-1/billing/entitlements/', (_) {
      callCount++;
      final nowAvailable = callCount > 1;
      return _entitlementJson(
        available: nowAvailable,
        premiumEnforcementEnabled: true,
        reason: nowAvailable ? '' : 'Needs payment.',
      );
    });
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Needs payment.'), findsOneWidget);

    // Simulates a successful payment verification elsewhere notifying every listener.
    repository.notifyEntitlementsChanged();
    await tester.pumpAndSettle();

    expect(find.textContaining('Needs payment.'), findsNothing);
    expect(api.callCount('schools/school-1/billing/entitlements/'), 2);
  });

  testWidgets('fails open and shows nothing when the entitlement read errors out', (
    tester,
  ) async {
    final api = FakeApiClient()
      ..fail('schools/school-1/billing/entitlements/', StateError('offline'));
    final repository = BillingRepository(api: api);

    await tester.pumpWidget(
      _wrap(
        repository,
        const PremiumCapabilityNotice(
          schoolId: 'school-1',
          code: 'cbt_exam_publish',
          featureLabel: 'Publishing a new exam',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Container), findsNothing);
  });

  testWidgets(
    'a response for a school no longer on screen is discarded, not shown (Stage 2, Task 2)',
    (tester) async {
      final api = FakeApiClient();
      final firstLoad = api.respondLater('schools/school-1/billing/entitlements/');
      api.respond(
        'schools/school-2/billing/entitlements/',
        _entitlementJson(available: true, premiumEnforcementEnabled: true),
      );
      final repository = BillingRepository(api: api);
      final key = GlobalKey();

      await tester.pumpWidget(
        _wrap(
          repository,
          PremiumCapabilityNotice(
            key: key,
            schoolId: 'school-1',
            code: 'cbt_exam_publish',
            featureLabel: 'Publishing a new exam',
          ),
        ),
      );
      await tester.pump();

      // Switch to school 2 before school 1's own entitlement response ever arrives.
      await tester.pumpWidget(
        _wrap(
          repository,
          PremiumCapabilityNotice(
            key: key,
            schoolId: 'school-2',
            code: 'cbt_exam_publish',
            featureLabel: 'Publishing a new exam',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Publishing a new exam'), findsNothing); // school 2 is available

      // School 1's stale, locked response now arrives - it must never be shown for school 2.
      firstLoad.complete(
        _entitlementJson(
          available: false,
          premiumEnforcementEnabled: true,
          reason: 'School 1 needs payment.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('School 1 needs payment.'), findsNothing);
      expect(find.textContaining('Publishing a new exam'), findsNothing);
    },
  );
}
