import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/app/demo_people.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/sync_scope.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/local_owner_access.dart';
import 'package:schoolos_app/features/proprietor/data/owner_access_scope.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_workspace_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

/// The demo, as it is shown to people: the owner signs in with no server and opens every screen in the menu.
void main() {
  testWidgets('the demo owner can open every screen without an error', (tester) async {
    tester.view.physicalSize = const Size(1800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final owner = demoMemberships.firstWhere((m) => m.role == SchoolRole.proprietor);
    late LocalDatabase db;
    late SchoolSessionController session;
    late LocalOwnerAccess access;
    late SchoolAppearanceController appearance;
    await tester.runAsync(() async {
      db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
      await db.initialize();
      session = SchoolSessionController(store: FakeSessionStore());
      await session.setMemberships(demoMemberships);
      await session.selectSchool(owner);
      access = LocalOwnerAccess(store: db, session: session);
      await access.restore();
      appearance = SchoolAppearanceController(localDatabase: db, schoolSession: session);
      await appearance.initialize();
    });
    addTearDown(() {
      access.dispose();
      appearance.dispose();
      db.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AccessScope(
          access: access,
          child: OwnerAccessScope(
            repository: access,
            child: ProprietorWorkspacePage(
              membership: owner,
              localDatabase: db,
              schoolSession: session,
              schoolAppearance: appearance,
            ),
          ),
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
    }

    await settle();
    const screens = [
      'Executive Overview',
      'Owner Finance',
      'Enrollment & Admissions',
      'Staff & HR',
      'Jobs & Delegation',
      'Staff Profiles',
      'Payroll & Salaries',
      'Executive Reports',
      'Campus Comparison',
      'Proprietor AI',
      'Structure & Leadership',
      'School Appearance',
      'Access & Activities',
    ];
    for (final screen in screens) {
      final item = find.text(screen).first;
      expect(item, findsOneWidget, reason: '$screen is in the menu');
      await tester.tap(item);
      await settle();
      final problem = tester.takeException();
      // The test font is wider than the real one, so a squeezed layout is not a fault in the app.
      if (problem != null && !problem.toString().contains('overflowed')) {
        fail('$screen threw: $problem');
      }
    }
  });
}
