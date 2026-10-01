import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/houses/data/house_repository.dart';
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
  late HouseRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = HouseRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty house list, never fabricated houses', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.houses, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.framework.MANAGERS exactly', () {
    test('the proprietor, principal and administrator can all manage houses', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canManageAll, isTrue, reason: role.name);
      }
    });

    test('nobody else can manage houses', () async {
      for (final role in [SchoolRole.teacher, SchoolRole.parent, SchoolRole.student, SchoolRole.driver]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canManageAll, isFalse, reason: role.name);
      }
    });
  });

  group('create', () {
    test('a manager can really add a house with an honest zero starting point', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.create(name: 'Blue House', captain: 'Amina Bello', coordinator: 'Mrs. Bello');
      expect(result.success, isTrue, reason: result.message);
      final house = (await repository.load()).houses.single;
      expect(house.name, 'Blue House');
      expect(house.points, 0);
      expect(house.members, 0);
      expect(house.status, 'Active');
    });

    test('a non-manager cannot add a house', () async {
      await actAs(SchoolRole.teacher);
      final result = await repository.create(name: 'Blue House', captain: '', coordinator: '');
      expect(result.success, isFalse);
    });

    test('an empty name is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.create(name: '   ', captain: '', coordinator: '');
      expect(result.success, isFalse);
    });
  });

  group('edit', () {
    test('a manager can really update a house\'s own points by hand', () async {
      await actAs(SchoolRole.principal);
      await repository.create(name: 'Blue House', captain: 'Amina Bello', coordinator: 'Mrs. Bello');
      final id = (await repository.load()).houses.single.id;
      final result = await repository.edit(
        id: id,
        name: 'Blue House',
        captain: 'Amina Bello',
        coordinator: 'Mrs. Bello',
        members: 40,
        points: 85,
        sports: 50,
        academicCompetitions: 20,
        service: 15,
        status: 'Leading',
      );
      expect(result.success, isTrue, reason: result.message);
      final house = (await repository.load()).houses.single;
      expect(house.points, 85);
      expect(house.members, 40);
      expect(house.status, 'Leading');
    });

    test('a non-manager cannot edit a house', () async {
      await actAs(SchoolRole.proprietor);
      await repository.create(name: 'Blue House', captain: '', coordinator: '');
      final id = (await repository.load()).houses.single.id;
      await actAs(SchoolRole.teacher);
      final result = await repository.edit(
        id: id,
        name: 'Blue House',
        captain: '',
        coordinator: '',
        members: 1,
        points: 1,
        sports: 1,
        academicCompetitions: 1,
        service: 1,
        status: 'Active',
      );
      expect(result.success, isFalse);
    });
  });
}
