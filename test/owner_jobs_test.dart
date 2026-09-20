import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/proprietor/data/job_assignment_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/owner_jobs_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  final mutations = <Map<Symbol, dynamic>>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId]).toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty],
        );
        return Future<void>.value();
      case #queueMutation:
        mutations.add(a);
        return Future<String>.value('mutation-${mutations.length}');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late JobAssignmentRepository repository;
  const owner = SchoolMembership(
    id: 'owner',
    schoolId: 'a',
    schoolName: 'A',
    role: SchoolRole.proprietor,
  );
  const other = SchoolMembership(
    id: 'owner-b',
    schoolId: 'b',
    schoolName: 'B',
    role: SchoolRole.proprietor,
  );
  const finance = SchoolMembership(
    id: 'finance',
    schoolId: 'a',
    schoolName: 'A',
    role: SchoolRole.accountant,
  );
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    await session.setMemberships([owner, other, finance]);
    await session.selectSchool(owner);
    repository = JobAssignmentRepository(database: database, session: session);
  });
  tearDown(() => session.dispose());
  Future<void> assign() => repository.assign(
    name: 'New person',
    email: ' NEW@example.com ',
    title: 'Bursar',
    duties: {'finance.fees', 'finance.payroll'},
  );

  test(
    'unregistered recipient remains pending; update and revocation persist',
    () async {
      await assign();
      await assign();
      final records = await repository.load();
      expect(records, hasLength(1));
      expect(records.single.payload['email'], 'new@example.com');
      expect(records.single.payload['status'], 'pendingActivation');
      expect(session.activeMembership, owner);
      expect(database.mutations.last[#membershipId], owner.id);
      await repository.revoke(records.single.entityId);
      expect((await repository.load()).single.payload['status'], 'revoked');
    },
  );
  test('owner assignments cannot be read or revoked across schools', () async {
    await assign();
    final id = (await repository.load()).single.entityId;
    await session.selectSchool(other);
    expect(await repository.load(), isEmpty);
    await expectLater(repository.revoke(id), throwsStateError);
  });
  test(
    'finance officer cannot assign jobs or read the owner directory',
    () async {
      await session.selectSchool(finance);
      await expectLater(assign(), throwsStateError);
      expect(() => repository.load(), throwsStateError);
      expect(database.records, isEmpty);
    },
  );
  test('invalid recipient and unsupported duties are rejected', () async {
    await expectLater(
      repository.assign(
        name: 'Someone',
        email: 'invalid',
        title: 'Bursar',
        duties: {'finance.fees'},
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.assign(
        name: 'Someone',
        email: 'a@example.com',
        title: 'Owner',
        duties: {'owner'},
      ),
      throwsArgumentError,
    );
    expect(database.records, isEmpty);
  });
  testWidgets('owner can prepare an assignment on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerJobsPage(repository: repository, onChanged: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New person');
    await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Bursar');
    await tester.scrollUntilVisible(find.text('All finance duties'), 250,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('All finance duties'));
    await tester.scrollUntilVisible(find.text('Save assignment'), 250,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save assignment'));
    await tester.pumpAndSettle();
    expect(
      (await repository.load()).single.payload['status'],
      'pendingActivation',
    );
    expect(tester.takeException(), isNull);
  });
}
