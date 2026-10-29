import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/features/bankconnect/data/bank_connect_api.dart';
import 'package:schoolos_app/features/finance_office/presentation/smart_collection_summary_card.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'bank_connect_fixtures.dart';
import 'core/backend_test_support.dart';

const finance = SchoolMembership(id: 'm-fin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.accountant);

void main() {
  Future<void> pumpCard(WidgetTester tester, {Future<http.Response> Function(http.Request)? server, VoidCallback? onOpen}) async {
    Widget card = MaterialApp(home: Scaffold(body: SmartCollectionSummaryCard(membership: finance, onOpenCollections: onOpen ?? () {})));
    if (server != null) card = BankConnectScope(api: BankConnectApi(api: apiFor(FakeServer(server))), child: card);
    await tester.pumpWidget(card);
    await tester.pumpAndSettle();
  }

  testWidgets('with no server it says Smart Money Collection is not connected, and makes nothing up', (tester) async {
    await pumpCard(tester);
    expect(find.text('Smart Money Collection is not connected on this device.'), findsOneWidget);
  });

  testWidgets('with a server it shows the real today/week/term totals, never recomputed', (tester) async {
    await pumpCard(tester, server: (_) async => jsonResponse(summaryJson(today: 5000000)));
    expect(find.text('Smart Money Collection'), findsOneWidget);
    expect(find.textContaining('₦50,000'), findsOneWidget);
    expect(find.textContaining('₦150,000'), findsOneWidget);
    expect(find.textContaining('₦450,000'), findsOneWidget);
    // Clearly a separate card from the manual ledger's Kpi row, never summed into it.
    expect(find.textContaining('never added together'), findsOneWidget);
  });

  testWidgets('payments waiting for review and a connection needing attention are both surfaced', (tester) async {
    await pumpCard(tester, server: (_) async => jsonResponse(summaryJson(
      pending: 3,
      needAttention: 1,
      connections: [connectionHealthJson(status: 'error', lastErrorCode: 'provider_unavailable', webhookConfirmedAt: null, lastVerifiedAt: null)],
    )));
    expect(find.textContaining('3 payment(s) waiting'), findsOneWidget);
    expect(find.textContaining('Needs attention'), findsOneWidget);
    expect(find.textContaining('provider_unavailable'), findsOneWidget);
    expect(find.textContaining('Webhook not yet confirmed'), findsOneWidget);
  });

  testWidgets('a healthy connection shows when its webhook was confirmed and when it was last verified', (tester) async {
    await pumpCard(tester, server: (_) async => jsonResponse(summaryJson(connections: [
      connectionHealthJson(webhookConfirmedAt: '2026-09-20T09:00:00+01:00', lastVerifiedAt: '2026-09-25T08:00:00+01:00'),
    ])));
    expect(find.textContaining('Webhook confirmed 2026-09-20'), findsOneWidget);
    expect(find.textContaining('Last verified 2026-09-25'), findsOneWidget);
    expect(find.textContaining('· Active'), findsOneWidget);
    expect(find.textContaining('Needs attention'), findsNothing);
  });

  testWidgets('no provider connected yet says so honestly, not zeros', (tester) async {
    await pumpCard(tester, server: (_) async => jsonResponse(summaryJson(available: false)));
    expect(find.textContaining('No collection provider is connected yet'), findsOneWidget);
  });

  testWidgets('"Open Collections" routes to the real Collections screen', (tester) async {
    String? opened;
    await pumpCard(tester, server: (_) async => jsonResponse(summaryJson()), onOpen: () => opened = 'collections');
    await tester.tap(find.text('Open Collections'));
    expect(opened, 'collections');
  });
}
