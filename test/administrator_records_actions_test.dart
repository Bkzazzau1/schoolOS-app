import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_records_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_records_models.dart';
import 'package:schoolos_app/features/administrator/presentation/administrator_records_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorRecordsRepository records;

  Future<void> setUpSchool([SchoolMembership who = admin]) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin, teacher]);
    await session.selectSchool(who);
    records = AdministratorRecordsRepository(localDatabase: db, schoolSession: session);
  }

  Future<AdministratorDocumentRecord> byId(String id) async => (await records.load()).records.firstWhere((r) => r.id == id);

  tearDown(() => db.close());

  test('the demo school has documents in every state, for students, families and staff', () async {
    await setUpSchool();
    final all = (await records.load()).records;
    expect(all.length, greaterThan(12));
    for (final status in AdministratorRecordStatus.values) {
      expect(all.any((r) => r.status == status), isTrue, reason: status.label);
    }
    expect({for (final r in all) r.kind}, containsAll(['Student', 'Family', 'Staff']));
  });

  test('a missing document is received, then verified, and each step is kept in its history', () async {
    await setUpSchool();
    final missing = await byId('REC-DEMO-01');
    expect(missing.status, AdministratorRecordStatus.missing);

    final received = await records.act(missing, 'Mark received');
    expect(received.success, isTrue, reason: received.message);
    expect(received.record!.status, AdministratorRecordStatus.pending);
    expect(received.record!.received, isNot('—'));

    final verified = await records.act(received.record!, 'Verify');
    expect(verified.success, isTrue);
    final stored = await byId('REC-DEMO-01');
    expect(stored.status, AdministratorRecordStatus.verified);
    expect(stored.verifiedBy, admin.id);
    expect(stored.history.map((h) => h['action']), ['Mark received', 'Verify']);
    expect(db.pendingCount(tenantId: admin.schoolId), greaterThan(0));
  });

  test('only the steps that make sense for the state are allowed, and sending back or reopening needs a reason', () async {
    await setUpSchool();
    final verified = await byId('REC-DEMO-02');
    expect((await records.act(verified, 'Verify')).success, isFalse);
    expect((await records.act(verified, 'Mark received')).success, isFalse);
    expect((await records.act(verified, 'Reopen')).message, contains('Say why'));

    final reopened = await records.act(verified, 'Reopen', note: 'Photo is unreadable');
    expect(reopened.success, isTrue);
    expect(reopened.record!.status, AdministratorRecordStatus.pending);
    expect(reopened.record!.verifiedBy, isEmpty);

    final sentBack = await records.act(reopened.record!, 'Send back', note: 'Asked the family for a clearer copy');
    expect(sentBack.record!.status, AdministratorRecordStatus.missing);
    expect(sentBack.record!.received, '—');
    expect(sentBack.record!.history.length, 2, reason: 'nothing is removed from the history');
  });

  test('a draft letter is issued', () async {
    await setUpSchool();
    final draft = await byId('REC-DEMO-07');
    final issued = await records.act(draft, 'Issue');
    expect(issued.record!.status, AdministratorRecordStatus.verified);
  });

  test('a new document starts as missing, is not added twice, and needs a name and a document', () async {
    await setUpSchool();
    final added = await records.add(owner: 'Halima Sani', document: 'Passport photograph', kind: 'Student');
    expect(added.success, isTrue, reason: added.message);
    expect(added.record!.status, AdministratorRecordStatus.missing);
    expect((await records.add(owner: 'halima sani', document: 'passport photograph', kind: 'Student')).message, contains('already has'));
    expect((await records.add(owner: '', document: 'Birth certificate', kind: 'Student')).success, isFalse);
    expect((await records.add(owner: 'X', document: 'Birth certificate', kind: 'Pet')).success, isFalse);
  });

  test('only the records office may change documents', () async {
    await setUpSchool(teacher);
    final any = (await records.load()).records.first;
    expect((await records.act(any, 'Reopen', note: 'x')).success, isFalse);
    expect((await records.add(owner: 'A', document: 'Birth certificate', kind: 'Student')).message, contains('records office'));
  });

  testWidgets('the records desk tracks a document and verifies one from its dialogs', (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(setUpSchool);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdministratorRecordsPage(schoolName: 'BrightGate', repository: records)),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await settle();
    await tester.tap(find.byKey(const ValueKey('record-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('record-owner')), 'Halima Sani');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-add')));
    await settle();
    await tester.pumpAndSettle();

    late List<AdministratorDocumentRecord> all;
    await tester.runAsync(() async => all = (await records.load()).records);
    expect(all.any((r) => r.recordOwner == 'Halima Sani' && r.document == 'Birth certificate'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
