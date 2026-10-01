import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/lost_found/data/lost_found_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

class _Database implements LocalDatabase {
  final records = <String, LocalRecord>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final a = invocation.namedArguments;
    final key = '${a[#tenantId]}/${a[#entityType]}/${a[#entityId]}';
    switch (invocation.memberName) {
      case #getLocalRecord:
        return Future<LocalRecord?>.value(records[key]);
      case #getLocalRecords:
        return Future<List<LocalRecord>>.value(
          records.values.where((r) => r.tenantId == a[#tenantId] && r.entityType == a[#entityType]).toList(),
        );
      case #upsertLocalRecord:
        records[key] = LocalRecord(
          tenantId: a[#tenantId],
          entityType: a[#entityType],
          entityId: a[#entityId],
          payload: Map<String, Object?>.from(a[#payload]),
          updatedAt: DateTime.now(),
          isDirty: a[#isDirty] ?? false,
        );
        return Future<void>.value();
      case #queueMutation:
        return Future<String>.value('mutation');
    }
    return super.noSuchMethod(invocation);
  }
}

SchoolMembership _member(SchoolRole role) => SchoolMembership(id: role.name, schoolId: 'a', schoolName: 'A', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late LostFoundRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<LostFoundActionResult> report() => repository.report(
        item: 'Blue school sweater',
        category: 'Uniform',
        found: 'Primary playground',
        date: '13 Sep 2026',
        storage: 'Front Office Shelf A',
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = LostFoundRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty register, never fabricated items', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.items, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.campus.LOST_FOUND exactly', () {
    test('almost every role may report an item - anyone may report', () async {
      for (final role in [
        SchoolRole.proprietor,
        SchoolRole.principal,
        SchoolRole.administrator,
        SchoolRole.staff,
        SchoolRole.teacher,
        SchoolRole.parent,
        SchoolRole.student,
        SchoolRole.accountant,
        SchoolRole.driver,
      ]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canReport, isTrue, reason: role.name);
      }
    });

    test('alumni (not in manage or contribute) cannot report', () async {
      await actAs(SchoolRole.alumni);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReport, isFalse);
    });

    test('only staff who run the office (MANAGERS + staff) can manage claims', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator, SchoolRole.staff]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canManageClaims, isTrue, reason: role.name);
      }
      for (final role in [SchoolRole.teacher, SchoolRole.parent, SchoolRole.student]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canManageClaims, isFalse, reason: role.name);
      }
    });
  });

  group('report', () {
    test('a parent (a real contributor) can really report a found item, honestly unclaimed', () async {
      await actAs(SchoolRole.parent);
      final result = await report();
      expect(result.success, isTrue, reason: result.message);
      final item = (await repository.load()).items.single;
      expect(item.item, 'Blue school sweater');
      expect(item.claimant, isEmpty);
    });

    test('alumni cannot report an item', () async {
      await actAs(SchoolRole.alumni);
      final result = await report();
      expect(result.success, isFalse);
    });

    test('an empty item description is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.report(item: '   ', category: '', found: '', date: '', storage: '', note: '');
      expect(result.success, isFalse);
    });
  });

  group('claims office actions', () {
    test('only a manager can start a claim review or mark an item returned', () async {
      await actAs(SchoolRole.parent);
      await report();
      final id = (await repository.load()).items.single.id;

      final deniedReview = await repository.startClaimReview(id);
      expect(deniedReview.success, isFalse);

      await actAs(SchoolRole.staff);
      final allowedReview = await repository.startClaimReview(id);
      expect(allowedReview.success, isTrue, reason: allowedReview.message);

      final returned = await repository.markReturned(id);
      expect(returned.success, isTrue, reason: returned.message);
      expect((await repository.load()).items.single.isOpen, isFalse);
    });
  });
}
