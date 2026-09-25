import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/appearance/school_appearance_controller.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_workspace_page.dart';
import 'package:schoolos_app/features/staff/presentation/staff_workspace_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const staffMember = SchoolMembership(
  id: 'membership-staff-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.staff,
);

// The same id shape LocalOwnerAccess.extraMembershipId uses for an
// owner-appointed "director" (an extra role on top of the Staff
// employment record) - a genuine second membership the person can switch
// to, landing on the real, unrestricted role workspace, not a cut-down copy.
const directorMembership = SchoolMembership(
  id: 'membership-staff-001#administrator',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.administrator,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([staffMember]);
    await session.selectSchool(staffMember);
  });

  tearDown(() => db.close());

  testWidgets('a Staff login sees its own real employment record, not a placeholder shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StaffWorkspacePage(
          membership: staffMember,
          localDatabase: db,
          schoolSession: session,
          schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mr. Peter James'), findsOneWidget);
    expect(find.text('House coordinator · Whole school'), findsOneWidget);
    expect(find.text('Bank account for salary'), findsOneWidget);
    expect(find.text('You have not entered your bank details yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to Students shows the real school directory', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StaffWorkspacePage(
          membership: staffMember,
          localDatabase: db,
          schoolSession: session,
          schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    expect(find.text('Student directory'), findsOneWidget);
    expect(find.textContaining('Maryam Abdullahi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an owner-appointed extra role can be reached from the switcher and opens its own real workspace', (tester) async {
    await session.setMemberships([staffMember, directorMembership]);
    await session.selectSchool(staffMember);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffWorkspacePage(
          membership: staffMember,
          localDatabase: db,
          schoolSession: session,
          schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('BrightGate · Administrator'), findsOneWidget);

    await tester.tap(find.text('BrightGate · Administrator'));
    await tester.pumpAndSettle();

    expect(find.byType(AdministratorWorkspacePage), findsOneWidget);
    expect(find.byType(StaffWorkspacePage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Staff renders on a phone viewport without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: StaffWorkspacePage(
          membership: staffMember,
          localDatabase: db,
          schoolSession: session,
          schoolAppearance: SchoolAppearanceController(localDatabase: db, schoolSession: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mr. Peter James'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
