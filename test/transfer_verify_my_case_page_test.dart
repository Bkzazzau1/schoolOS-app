import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_network_api.dart';
import 'package:schoolos_app/features/transferverify/domain/dispute_models.dart';
import 'package:schoolos_app/features/transferverify/presentation/transfer_verify_my_case_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const guardian = SchoolMembership(id: 'guardian', schoolId: 'a', schoolName: 'A', role: SchoolRole.parent);

void main() {
  testWidgets('shows an honest message with no connected server', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyMyCasePage(api: null, membership: guardian))));
    await tester.pump();
    expect(find.textContaining('demo mode'), findsOneWidget);
  });

  testWidgets('shows a published case and sends a dispute', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var disputed = false;
    final server = FakeServer((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/my-case/')) {
        return jsonResponse({
          'cases': [
            {
              'transferAlertId': 'alert-1', 'studentName': 'Chidera Okafor', 'state': disputed ? 'disputed' : 'active',
              'status': 'bad_debt', 'reason': 'withdrew_without_clearance',
              'publishedAt': DateTime.now().toUtc().toIso8601String(),
              'hasOpenDispute': disputed, 'hasActiveClearance': false,
            },
          ],
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/disputes/')) {
        disputed = true;
        return jsonResponse({
          'dispute': {
            'id': 'dispute-1', 'transferAlertId': 'alert-1', 'reason': 'already_paid', 'explanation': 'Paid in cash.',
            'status': 'opened', 'openedAt': DateTime.now().toUtc().toIso8601String(),
          },
        }, 201);
      }
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyNetworkApi(api: apiFor(server));

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyMyCasePage(api: api, membership: guardian))));
    await tester.pumpAndSettle();

    expect(find.text('Chidera Okafor'), findsOneWidget);
    expect(find.text('Dispute this case'), findsOneWidget);

    await tester.tap(find.text('Dispute this case'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TransferDisputeReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The balance has already been paid').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Paid in cash.');
    await tester.tap(find.widgetWithText(FilledButton, 'Send dispute'));
    await tester.pumpAndSettle();

    expect(find.text('Your dispute is under review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
