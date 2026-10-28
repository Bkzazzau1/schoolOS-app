import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/server_confirm.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_campuses.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_campuses_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(
  id: '55555555-5555-5555-5555-555555555555',
  schoolId: '22222222-2222-2222-2222-222222222222',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late OwnerCampusesRepository repository;

  setUp(() async {
    LocalDatabase.blockDemoSeeds = true;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    final structure = ProprietorStructureRepository(
      localDatabase: db,
      schoolSession: session,
      confirm: ServerConfirm(database: db, syncNow: () async {}),
    );
    await structure.setUpStandardStructure();
    repository = OwnerCampusesRepository(
      structure: structure,
      profiles: OwnerStaffProfileRepository(database: db, session: session),
    );
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProprietorCampusesPage(schoolName: 'BrightGate', onActionRequested: (_) {}, repository: repository),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('adding a real campus shows it as its own card', (tester) async {
    await pump(tester);
    expect(find.textContaining('Kaduna Campus'), findsWidgets);
    expect(find.textContaining('Zaria Campus'), findsNothing);

    await tester.tap(find.text('Add campus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zaria Campus');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Zaria Campus'), findsWidgets);
    expect(find.text('Zaria Campus was added.'), findsOneWidget);
  });

  testWidgets('renaming a real campus updates its card, not a second one', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kaduna Main Campus');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kaduna Main Campus'), findsWidgets);
    expect(find.textContaining('Kaduna Campus'), findsNothing);
    expect(find.byType(Card).evaluate().where((e) => (e.widget as Card).key is ValueKey).length, 1);
  });

  testWidgets('assigning a section to a different real campus moves it there', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add campus'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zaria Campus');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // "Nursery / Early Years" sorts first in the assignment list; every seeded section starts on
    // the real "kaduna" campus.
    final before = (await repository.structure.load()).sections.singleWhere((s) => s.name == 'Nursery / Early Years');
    expect(before.campusId, 'kaduna');
    final zaria = (await repository.load()).campuses.singleWhere((c) => c.name == 'Zaria Campus');

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaria Campus').last);
    await tester.pumpAndSettle();

    final after = (await repository.structure.load()).sections.singleWhere((s) => s.name == 'Nursery / Early Years');
    expect(after.campusId, zaria.id);
  });
}
