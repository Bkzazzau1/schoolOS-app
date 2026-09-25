import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/billing/data/billing_repository.dart';
import 'package:schoolos_app/features/billing/presentation/billing_scope.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_workspace_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
  organizationId: '33333333-3333-3333-3333-333333333333',
);

final subscriptionJson = {
  'organizationId': owner.organizationId,
  'status': 'active',
  'accessMode': 'full',
  'canManageBilling': true,
  'entitlements': <String, Object?>{},
  'usage': {'activeSchools': 1, 'billableStudents': 648},
  'plan': {
    'code': 'standard',
    'name': 'Standard',
    'description': 'The standard SchoolOS plan.',
    'currency': 'NGN',
    'baseAmountMinor': 0,
    'studentUnitAmountMinor': 50000,
    'billingInterval': 'monthly',
  },
};

void main() {
  Future<void> openMenu(WidgetTester tester, {required bool backend}) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = _Database();
    final session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    Widget home = ProprietorWorkspacePage(
      membership: owner,
      localDatabase: db,
      schoolSession: session,
      schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
    );
    if (backend) {
      final server = FakeServer((request) async {
        if (request.url.path.endsWith('/subscription/')) return jsonResponse(subscriptionJson);
        if (request.url.path.endsWith('/invoices/')) return jsonResponse({'invoices': []});
        return jsonResponse({}, 404);
      });
      home = BillingScope(repository: BillingRepository(api: apiFor(server)), child: home);
    }
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
    await tester.tap(find.byTooltip('Owner workspace'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers Subscriptions when there is a server', (tester) async {
    await openMenu(tester, backend: true);
    expect(find.text('Subscriptions'), findsWidgets);
  });

  testWidgets('does not offer it on demo data, where there is no account to bill', (tester) async {
    await openMenu(tester, backend: false);
    expect(find.text('School Life'), findsWidgets);
    expect(find.text('Subscriptions'), findsNothing);
  });

  testWidgets('opening it shows the real plan and status from the server', (tester) async {
    await openMenu(tester, backend: true);
    await tester.tap(find.text('Subscriptions').first);
    await tester.pumpAndSettle();

    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('648'), findsWidgets);
  });
}

class _Database implements LocalDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getLocalRecord) return Future<LocalRecord?>.value(null);
    if (invocation.memberName == #getLocalRecords) return Future<List<LocalRecord>>.value([]);
    if (invocation.memberName == #pendingCount) return 0;
    return super.noSuchMethod(invocation);
  }
}
