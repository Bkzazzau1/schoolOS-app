import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_network_api.dart';
import 'package:schoolos_app/features/transferverify/presentation/transfer_verify_requests_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.proprietor);
const administrator = SchoolMembership(id: 'admin', schoolId: 'a', schoolName: 'A', role: SchoolRole.administrator);

Map<String, Object?> _requestJson({String status = 'pending'}) => {
      'id': 'req-1',
      'transferAlertId': 'alert-1',
      'requestingSchoolName': 'A',
      'sourceSchoolName': 'Greenwood Academy',
      'status': status,
      'note': 'Considering admission.',
      'requestedAt': DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  testWidgets('shows an honest message with no connected server', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyRequestsPage(api: null, membership: owner))));
    await tester.pump();
    expect(find.textContaining('demo mode'), findsOneWidget);
  });

  testWidgets('an administrator sees only the sent side, never received', (tester) async {
    final server = FakeServer((request) async {
      if (request.url.path.endsWith('/requests/sent/')) return jsonResponse({'requests': [_requestJson()]});
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyNetworkApi(api: apiFor(server));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyRequestsPage(api: api, membership: administrator))));
    await tester.pumpAndSettle();

    expect(find.text('Sent by your school'), findsOneWidget);
    expect(find.text('Received by your school'), findsNothing);
    expect(server.to('/requests/received/'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the owner cancels a sent request and confirms a received one', (tester) async {
    var cancelled = false;
    var confirmed = false;
    final server = FakeServer((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/requests/sent/')) {
        return jsonResponse({'requests': [_requestJson(status: cancelled ? 'cancelled' : 'pending')]});
      }
      if (request.method == 'GET' && request.url.path.endsWith('/requests/received/')) {
        return jsonResponse({
          'requests': [
            {
              'id': 'req-2',
              'transferAlertId': 'alert-2',
              'requestingSchoolName': 'Riverside School',
              'sourceSchoolName': 'A',
              'status': confirmed ? 'confirmed' : 'pending',
              'note': '',
              'requestedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/req-1/cancel/')) {
        cancelled = true;
        return jsonResponse({'request': _requestJson(status: 'cancelled')});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/req-2/respond/')) {
        confirmed = true;
        return jsonResponse({
          'request': {
            'id': 'req-2', 'transferAlertId': 'alert-2', 'requestingSchoolName': 'Riverside School',
            'sourceSchoolName': 'A', 'status': 'confirmed', 'note': '',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyNetworkApi(api: apiFor(server));
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransferVerifyRequestsPage(api: api, membership: owner))));
    await tester.pumpAndSettle();

    expect(find.text('Greenwood Academy'), findsOneWidget);
    expect(find.text('Riverside School'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(find.text('Cancelled'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Confirm')));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
