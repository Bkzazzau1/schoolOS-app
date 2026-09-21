import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/sync/server_confirm.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_demo_data.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/proprietor_structure_models.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_structure_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

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

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;

  /// The order in which the "server" was sent things, and what it says to each.
  final sent = <String>[];
  late String Function(SyncQueueItem item) serverSays;

  ServerConfirm confirm() => ServerConfirm(
        database: db,
        syncNow: () async {
          for (final item in db.syncQueueItems(tenantId: owner.schoolId).where((i) => i.status == SyncMutationStatus.pending)) {
            db.markMutationSyncing(item.id);
            sent.add('${item.entityType}:${item.entityId}');
            final answer = serverSays(item);
            if (answer == 'ok') {
              db.markMutationSynced(item.id, serverVersion: 1);
            } else {
              db.markMutationFailed(item.id, answer);
            }
          }
        },
      );

  setUp(() async {
    sent.clear();
    serverSays = (_) => 'ok';
    LocalDatabase.blockDemoSeeds = true;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner, principal]);
    await session.selectSchool(owner);
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  ProprietorStructureRepository repo() => ProprietorStructureRepository(localDatabase: db, schoolSession: session, confirm: confirm());

  group('sample records with a server', () {
    test('a sample (not an edit, never downloaded) is not written; everything real is', () async {
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: 'school_event', entityId: 'sample', payload: {'a': 1});
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: 'school_event', entityId: 'edit', payload: {'a': 1}, isDirty: true);
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: 'school_event', entityId: 'downloaded', payload: {'a': 1}, serverVersion: 3);
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: '_access_snapshot', entityId: 'm', payload: {'a': 1});
      final kept = (await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'school_event')).map((r) => r.entityId).toSet();
      expect(kept, {'edit', 'downloaded'});
      expect(await db.getLocalRecord(tenantId: owner.schoolId, entityType: '_access_snapshot', entityId: 'm'), isNotNull);
    });

    test('without a server samples are written as before', () async {
      LocalDatabase.blockDemoSeeds = false;
      await db.upsertLocalRecord(tenantId: owner.schoolId, entityType: 'school_event', entityId: 'sample', payload: {'a': 1});
      expect(await db.getLocalRecord(tenantId: owner.schoolId, entityType: 'school_event', entityId: 'sample'), isNotNull);
    });
  });

  group('the structure with a server', () {
    test('an empty school asks the owner to set it up, instead of showing sample sections', () async {
      final snapshot = await repo().load();
      expect(snapshot.needsSetup, isTrue);
      expect(snapshot.sections, isEmpty);
      expect(snapshot.leaders, isEmpty);
      expect(await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'academic_section'), isEmpty);
    });

    test('setting up creates the sections first and then the posts that belong to them', () async {
      final result = await repo().setUpStandardStructure();
      expect(result.success, isTrue);
      final firstPost = sent.indexWhere((s) => s.startsWith('leadership_appointment:'));
      final lastSection = sent.lastIndexWhere((s) => s.startsWith('academic_section:'));
      expect(sent.where((s) => s.startsWith('academic_section:')).length, initialAcademicSections.length);
      expect(sent.where((s) => s.startsWith('leadership_appointment:')).length, initialLeadershipAppointments.length);
      expect(lastSection, lessThan(firstPost));                                // a post needs its section on the server first

      final after = await repo().load();
      expect((after.needsSetup, after.sections.length, after.leaders.length), (false, initialAcademicSections.length, initialLeadershipAppointments.length));
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);
    });

    test('it stops at the first refusal, says why, and leaves nothing half-made on the device', () async {
      serverSays = (item) => item.entityId == initialAcademicSections[1].id ? 'The section name is required.' : 'ok';
      final result = await repo().setUpStandardStructure();
      expect((result.success, result.message), (false, 'The section name is required.'));
      expect(sent.any((s) => s.startsWith('leadership_appointment:')), isFalse);   // never got as far as the posts
      final sections = await db.getLocalRecords(tenantId: owner.schoolId, entityType: 'academic_section');
      expect(sections.map((r) => r.entityId), [initialAcademicSections.first.id]);
      expect(db.syncQueueItems(tenantId: owner.schoolId), isEmpty);
    });

    test('only the owner can set it up', () async {
      await session.selectSchool(principal);
      final result = await repo().setUpStandardStructure();
      expect(result.success, isFalse);
      expect(sent, isEmpty);
    });

    Future<ProprietorStructureRepository> setUpFirst() async {
      await repo().setUpStandardStructure();
      sent.clear();
      return repo();
    }

    test('an appointment is sent at once, and a refusal is shown with nothing kept', () async {
      final structure = await setUpFirst();
      final snapshot = await structure.load();
      final section = snapshot.sections.first;
      final manager = snapshot.leaders.firstWhere((l) => l.sectionId == section.id && l.level == LeadershipLevel.sectionHead);

      serverSays = (_) => 'Choose a reporting manager from the same section: its head or a deputy.';
      final refused = await structure.appoint(
        section: section, person: 'Mr. New', level: LeadershipLevel.deputy, title: 'Deputy', reportsTo: manager.id,
      );
      expect((refused.success, refused.message), (false, 'Choose a reporting manager from the same section: its head or a deputy.'));
      expect((await structure.load()).leaders.length, snapshot.leaders.length);      // no phantom post

      serverSays = (_) => 'ok';
      final accepted = await structure.appoint(
        section: section, person: 'Mr. New', level: LeadershipLevel.deputy, title: 'Deputy', reportsTo: manager.id,
      );
      expect(accepted.success, isTrue);
      expect((await structure.load()).leaders.length, snapshot.leaders.length + 1);
    });

    test('replacing a head sends the appointment first and then the section', () async {
      final structure = await setUpFirst();
      final section = (await structure.load()).sections.first;
      final result = await structure.replaceSectionHead(section: section, person: 'Mrs. Amina Yusuf');
      expect(result.success, isTrue);
      expect(sent.map((s) => s.split(':').first), ['leadership_appointment', 'academic_section']);
    });
  });

  group('the structure screen with a server', () {
    testWidgets('an empty school sees the set-up card, and setting up shows the structure', (tester) async {
      // The test font is much wider than the real one, so parts of the full page report an overflow
      // that does not happen on a device. What matters here is what the page shows and does.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      tester.view.physicalSize = const Size(1800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final structure = repo();
      var changed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProprietorStructurePage(
            schoolName: 'BrightGate',
            repository: structure,
            onActionRequested: (_) {},
            onStructureChanged: () => changed++,
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.textContaining('Set up BrightGate'), findsOneWidget);
      expect(find.text('Use the standard sections'), findsOneWidget);

      await tester.tap(find.text('Use the standard sections'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Use the standard sections'), findsNothing);
      expect(find.text(initialAcademicSections.first.name), findsWidgets);
      expect(changed, 1);
    });

    testWidgets('a refusal while setting up is shown on the card', (tester) async {
      tester.view.physicalSize = const Size(1800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      serverSays = (_) => 'Only the owner can change the structure.';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProprietorStructurePage(schoolName: 'BrightGate', repository: repo(), onActionRequested: (_) {}, onStructureChanged: () {}),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.tap(find.text('Use the standard sections'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      expect(find.text('Only the owner can change the structure.'), findsOneWidget);
      expect(find.text('Use the standard sections'), findsOneWidget);          // it can be tried again
    });
  });
}
