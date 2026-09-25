import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_scope.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_source.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_workspace_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

void main() {
  Future<void> openMenu(WidgetTester tester) async {
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
    home = OwnerAccessScope(repository: _NoopOwnerAccess(), child: home);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pump();
    await tester.tap(find.byTooltip('Owner workspace'));
    await tester.pumpAndSettle();
  }

  testWidgets('TransferVerify is in the owner nav, between Alumni and Subscriptions', (tester) async {
    await openMenu(tester);
    expect(find.text('TransferVerify'), findsWidgets);

    final alumniY = tester.getTopLeft(find.text('Alumni').first).dy;
    final transferVerifyY = tester.getTopLeft(find.text('TransferVerify').first).dy;
    final subscriptionsY = tester.getTopLeft(find.text('Subscriptions').first).dy;
    expect(transferVerifyY, greaterThan(alumniY));
    expect(subscriptionsY, greaterThan(transferVerifyY));
  });

  testWidgets('opening TransferVerify shows the Bad Debt Classification workspace, no server required', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('TransferVerify').first);
    await tester.pumpAndSettle();

    expect(find.text('Bad Debt Classification'), findsOneWidget);
    expect(find.text('Classify a bad debt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NoopOwnerAccess implements OwnerAccessSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
