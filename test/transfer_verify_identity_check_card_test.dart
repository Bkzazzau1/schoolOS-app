import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_network_api.dart';
import 'package:schoolos_app/features/transferverify/presentation/transfer_verify_identity_check_card.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(id: 'owner', schoolId: 'a', schoolName: 'A', role: SchoolRole.administrator);

void main() {
  testWidgets('shows an honest message with no connected server', (tester) async {
    final controller = TextEditingController(text: '08031234567');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferVerifyIdentityCheckCard(membership: owner, api: null, guardianPhoneController: controller),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('demo mode'), findsOneWidget);
  });

  testWidgets('checks a phone, shows a candidate, and asks the source school to verify', (tester) async {
    final controller = TextEditingController(text: '08031234567');
    addTearDown(controller.dispose);

    var requested = false;
    final server = FakeServer((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/network/match/')) {
        return jsonResponse({
          'candidates': [
            {
              'transferAlertId': 'alert-1',
              'confidence': 'candidate_match',
              'matchedOn': 'guardian_phone',
              'sourceSchoolName': 'Greenwood Academy',
              'status': 'bad_debt',
              'reason': 'withdrew_without_clearance',
              'publishedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ],
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/network/requests/')) {
        requested = true;
        return jsonResponse({
          'request': {
            'id': 'req-1',
            'transferAlertId': 'alert-1',
            'requestingSchoolName': 'A',
            'sourceSchoolName': 'Greenwood Academy',
            'status': 'pending',
            'note': '',
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
          },
        }, 201);
      }
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyNetworkApi(api: apiFor(server));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransferVerifyIdentityCheckCard(membership: owner, api: api, guardianPhoneController: controller),
        ),
      ),
    );
    await tester.tap(find.text('Check TransferVerify'));
    await tester.pumpAndSettle();

    expect(find.text('Greenwood Academy'), findsOneWidget);
    expect(find.textContaining('Candidate match'), findsOneWidget);

    await tester.tap(find.text('Ask Greenwood Academy to verify'));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(find.textContaining('waiting for the source school'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
