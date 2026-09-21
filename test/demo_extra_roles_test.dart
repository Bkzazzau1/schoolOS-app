import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/demo_people.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/local_owner_access.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_controller.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_access_person_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

void main() {
  testWidgets('the owner gives a teacher the parent role from their page, and can take it away', (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final owner = demoMemberships.firstWhere((m) => m.role == SchoolRole.proprietor);
    final session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships(demoMemberships);
    final access = LocalOwnerAccess(store: MemorySyncStore(), session: session);
    await access.restore();
    final controller = OwnerAccessController(repository: access, owner: owner);
    await controller.load();
    addTearDown(access.dispose);

    await tester.pumpWidget(MaterialApp(
      home: OwnerAccessPersonPage(controller: controller, membershipId: 'membership-teacher-002'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Teacher (main)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parent').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('extra-role-parent')), findsOneWidget);
    expect(session.memberships.any((m) => m.id == 'membership-teacher-002#parent'), isTrue);

    await tester.tap(find.descendant(of: find.byKey(const ValueKey('extra-role-parent')), matching: find.byIcon(Icons.clear)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take away').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('extra-role-parent')), findsNothing);
  });
}
