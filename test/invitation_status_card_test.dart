import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:schoolos_app/core/network/api_exceptions.dart';
import 'package:schoolos_app/features/proprietor/data/staff_server_api.dart';
import 'package:schoolos_app/features/proprietor/presentation/invitation_status_card.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

const principal = SchoolMembership(
  id: '88888888-8888-8888-8888-888888888888',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.principal,
);

Map<String, Object?> status(String state, {bool linked = false, String? sentAt = '2026-09-20T09:00:00Z', String event = 'sent'}) => {
      'status': state,
      'linked': linked,
      'email': 'musa@school.ng',
      'sentAt': sentAt,
      'expiresAt': '2026-10-04T09:00:00Z',
      'acceptedAt': state == 'accepted' ? '2026-09-22T10:00:00Z' : null,
      'lastEvent': {'event': event, 'at': '2026-09-20T09:00:01Z', 'detail': {}},
    };

void main() {
  late FakeServer server;
  late Map<String, Object?> current;
  http.Response? refuse;
  var changed = 0;

  Future<void> open(WidgetTester tester, Map<String, Object?> data, {SchoolMembership member = owner}) async {
    current = data;
    refuse = null;
    changed = 0;
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = FakeServer((r) async {
      if (r.method == 'GET') return jsonResponse(current);
      final answer = refuse;
      if (answer != null) {
        refuse = null;
        return answer;
      }
      return r.method == 'DELETE' ? http.Response('', 204) : jsonResponse(current);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: InvitationStatusCard(
            key: UniqueKey(),
            api: StaffServerApi(api: apiFor(server)),
            membership: member,
            staffId: 'STAFF-1',
            onChanged: () => changed++,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<http.Request> sent() => server.requests.where((r) => r.method != 'GET').toList();

  testWidgets('a pending invitation says who it went to and until when', (tester) async {
    await open(tester, status('pending'));
    expect(find.textContaining('Sent to musa@school.ng on 20 Sep 2026'), findsOneWidget);
    expect(find.textContaining('works until 4 Oct 2026'), findsOneWidget);
    expect(find.text('Send again'), findsOneWidget);
    expect(find.text('Cancel invitation'), findsOneWidget);
    expect(find.text('Remove login'), findsNothing);
  });

  testWidgets('one that never arrived, or expired, tells them to send it again', (tester) async {
    await open(tester, status('pending', sentAt: null, event: 'failed'));
    expect(find.textContaining('could not be delivered'), findsOneWidget);
    await open(tester, status('expired'));
    expect(find.textContaining('expired on 4 Oct 2026'), findsOneWidget);
  });

  testWidgets('accepted, cancelled and not-yet-sent are worded plainly', (tester) async {
    await open(tester, status('accepted', linked: true));
    expect(find.text('Accepted on 22 Sep 2026.'), findsOneWidget);
    expect(find.text('This staff member has a login.'), findsOneWidget);
    expect(find.text('Send again'), findsNothing);                 // they already joined
    await open(tester, status('revoked'));
    expect(find.textContaining('cancelled or replaced'), findsOneWidget);
    await open(tester, {'status': 'none', 'linked': false});
    expect(find.text('No invitation has been sent.'), findsOneWidget);
    expect(find.text('Send invitation'), findsOneWidget);
  });

  testWidgets('sending again offers the email to correct, and sends it', (tester) async {
    await open(tester, status('pending'));
    await tester.tap(find.text('Send again'));
    await tester.pumpAndSettle();
    expect(find.text('The link they were sent before stops working. Correct the email address if it was wrong.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'musa.fixed@school.ng');
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final request = sent().single;
    expect(request.method, 'POST');
    expect(request.url.path, endsWith('/owner/schools/${owner.schoolId}/staff/STAFF-1/invitation/'));
    expect(body(request), {'email': 'musa.fixed@school.ng'});
    expect(find.text('Invitation sent.'), findsOneWidget);
    expect(changed, 1);
  });

  testWidgets('cancelling the dialog sends nothing', (tester) async {
    await open(tester, status('pending'));
    await tester.tap(find.text('Send again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sent(), isEmpty);
  });

  testWidgets('cancelling an invitation asks first', (tester) async {
    await open(tester, status('pending'));
    await tester.tap(find.text('Cancel invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this invitation?'), findsOneWidget);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(sent(), isEmpty);

    await tester.tap(find.text('Cancel invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel invitation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sent().single.method, 'DELETE');
    expect(find.text('Invitation cancelled.'), findsOneWidget);
  });

  testWidgets('removing a login explains what it does, and only the owner can', (tester) async {
    await open(tester, status('accepted', linked: true));
    await tester.tap(find.text('Remove login'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Their account is not deleted'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final request = sent().single;
    expect((request.method, request.url.path.endsWith('/staff/STAFF-1/unlink/')), ('POST', true));
    expect(find.text('Login removed.'), findsOneWidget);

    await open(tester, status('accepted', linked: true), member: principal);
    expect(find.text('Remove login'), findsNothing);
  });

  testWidgets('the principal can send again but not cancel', (tester) async {
    await open(tester, status('pending'), member: principal);
    expect(find.text('Send again'), findsOneWidget);
    expect(find.text('Cancel invitation'), findsNothing);
    expect(server.requests.first.url.queryParameters['membership'], principal.id);
  });

  testWidgets('a refusal is shown in the server\'s words and the card stays usable', (tester) async {
    await open(tester, status('pending'));
    refuse = jsonResponse({'code': 'invalid_email', 'message': 'Enter a valid email address.'}, 400);
    await tester.tap(find.text('Send again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(changed, 0);
    expect(find.text('Send again'), findsOneWidget);
  });

  testWidgets('offline it says so and can try again', (tester) async {
    current = status('pending');
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var online = false;
    server = FakeServer((r) async {
      if (!online) throw const ApiOfflineException();
      return jsonResponse(current);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: InvitationStatusCard(api: StaffServerApi(api: apiFor(server)), membership: owner, staffId: 'STAFF-1')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('need a connection'), findsOneWidget);
    online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sent to musa@school.ng'), findsOneWidget);
  });
}
