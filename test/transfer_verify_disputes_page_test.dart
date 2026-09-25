import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_network_api.dart';
import 'package:schoolos_app/features/transferverify/presentation/transfer_verify_disputes_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);

void main() {
  testWidgets('shows an honest message with no connected server', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyDisputesPage(api: null, membership: owner))));
    await tester.pump();
    expect(find.textContaining('demo mode'), findsOneWidget);
  });

  testWidgets('accepts a dispute and revokes an issued clearance', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var disputeStatus = 'opened';
    var clearanceStatus = 'active';
    final server = FakeServer((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/disputes/received/')) {
        return jsonResponse({
          'disputes': [
            {
              'id': 'dispute-1', 'transferAlertId': 'alert-1', 'reason': 'already_paid',
              'explanation': 'Paid in cash.', 'status': disputeStatus,
              'openedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/clearances/list/')) {
        return jsonResponse({
          'clearances': [
            {
              'id': 'clr-1', 'issuingSchoolName': 'A', 'verificationToken': 'tok-123',
              'status': clearanceStatus, 'issuedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/dispute-1/review/')) {
        disputeStatus = 'accepted';
        return jsonResponse({
          'dispute': {
            'id': 'dispute-1', 'transferAlertId': 'alert-1', 'reason': 'already_paid',
            'explanation': 'Paid in cash.', 'status': 'accepted',
            'openedAt': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/clr-1/revoke/')) {
        clearanceStatus = 'revoked';
        return jsonResponse({
          'clearance': {
            'id': 'clr-1', 'issuingSchoolName': 'A', 'verificationToken': 'tok-123',
            'status': 'revoked', 'issuedAt': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyNetworkApi(api: apiFor(server));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyDisputesPage(api: api, membership: owner))));
    await tester.pumpAndSettle();

    expect(find.text('already paid'), findsOneWidget);
    expect(find.text('Token: tok-123'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Accept')));
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);

    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('Revoked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
