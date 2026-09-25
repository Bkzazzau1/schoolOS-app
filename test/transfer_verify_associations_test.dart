import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/features/transferverify/data/transfer_verify_associations_api.dart';
import 'package:schoolos_app/features/transferverify/presentation/transfer_verify_associations_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const association = {
  'id': '11111111-1111-1111-1111-111111111111',
  'name': 'Kaduna Private Schools Association',
  'registrationReference': 'KDPSA-001',
  'geographicScope': 'Kaduna State',
  'description': '',
  'status': 'active',
  'isOpenForMembership': true,
};

void main() {
  testWidgets('shows an honest message when there is no connected server', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TransferVerifyAssociationsPage(api: null, membership: owner))),
    );
    await tester.pump();
    expect(find.textContaining('demo mode'), findsOneWidget);
  });

  testWidgets('browses the catalog and joins an association when connected', (tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var joined = false;
    final server = FakeServer((request) async {
      if (request.method == 'GET' && request.url.path.contains('/schools/')) {
        return jsonResponse({
          'memberships': joined
              ? [
                  {
                    'id': 'm1',
                    'associationId': association['id'],
                    'associationName': association['name'],
                    'schoolId': owner.schoolId,
                    'status': 'pending',
                    'requestedByMembershipId': owner.id,
                    'requestedAt': DateTime.now().toUtc().toIso8601String(),
                    'decisionNote': '',
                  },
                ]
              : [],
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/transferverify/associations/')) {
        return jsonResponse({'associations': [association]});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/join/')) {
        joined = true;
        return jsonResponse({
          'membership': {
            'id': 'm1',
            'associationId': association['id'],
            'associationName': association['name'],
            'schoolId': owner.schoolId,
            'status': 'pending',
            'requestedByMembershipId': owner.id,
            'requestedAt': DateTime.now().toUtc().toIso8601String(),
            'decisionNote': '',
          },
        }, 201);
      }
      return jsonResponse({}, 404);
    });
    final api = TransferVerifyAssociationsApi(api: apiFor(server));

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TransferVerifyAssociationsPage(api: api, membership: owner))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kaduna Private Schools Association'), findsOneWidget);
    expect(find.text('Not a member of any association yet.'), findsOneWidget);

    await tester.tap(find.text('Request to join'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Request sent to Kaduna'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final joinRequest = server.to('/join/').single;
    expect(jsonDecode(joinRequest.body)['membership'], owner.id);
  });
}
