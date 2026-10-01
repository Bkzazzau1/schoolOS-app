import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/assembly/data/assembly_repository.dart';
import 'package:schoolos_app/features/assembly/domain/assembly_models.dart';
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
  late AssemblyRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<AssemblyActionResult> createSession() => repository.create(
        title: 'Monday Assembly',
        type: AssemblySessionType.generalAssembly,
        audience: 'Whole school',
        day: 'Monday',
        time: '7:45 AM',
        venue: 'Main ground',
        lead: 'Leadership',
        participation: 'Whole school',
        note: 'Weekly announcements.',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = AssemblyRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty assembly calendar, never fabricated sessions', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.sessions, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.calendar.ASSEMBLY exactly', () {
    test('managers and teachers can create; only managers can manage all', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isTrue, reason: role.name);
        expect(p.canManageAll, isTrue, reason: role.name);
      }
      await actAs(SchoolRole.teacher);
      final teacher = repository.permissionsFor(session.requireActiveMembership());
      expect(teacher.canCreate, isTrue);
      expect(teacher.canManageAll, isFalse);
    });

    test('nobody else can create or manage sessions', () async {
      for (final role in [SchoolRole.parent, SchoolRole.student, SchoolRole.driver]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canCreate, isFalse, reason: role.name);
        expect(p.canManageAll, isFalse, reason: role.name);
      }
    });
  });

  group('create', () {
    test('a teacher (a real contributor) can really add a session', () async {
      await actAs(SchoolRole.teacher);
      final result = await createSession();
      expect(result.success, isTrue, reason: result.message);
      expect((await repository.load()).sessions.single.title, 'Monday Assembly');
    });

    test('a role outside manage/contribute cannot add a session', () async {
      await actAs(SchoolRole.parent);
      final result = await createSession();
      expect(result.success, isFalse);
    });

    test('an empty title is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.create(
        title: '   ',
        type: AssemblySessionType.generalAssembly,
        audience: '',
        day: '',
        time: '',
        venue: '',
        lead: '',
        participation: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });

  group('edit', () {
    test('a manager can really edit any session', () async {
      await actAs(SchoolRole.teacher);
      await createSession();
      final id = (await repository.load()).sessions.single.id;

      await actAs(SchoolRole.principal);
      final result = await repository.edit(
        id: id,
        title: 'Updated Assembly',
        type: AssemblySessionType.civic,
        audience: 'Secondary',
        day: 'Tuesday',
        time: '8:00 AM',
        venue: 'Hall',
        lead: 'Principal',
        participation: 'Secondary',
        note: 'Updated note.',
      );
      expect(result.success, isTrue, reason: result.message);
      final updated = (await repository.load()).sessions.single;
      expect(updated.title, 'Updated Assembly');
      expect(updated.type, AssemblySessionType.civic);
    });

    test('a teacher (a contributor, not a manager) cannot edit a session', () async {
      await actAs(SchoolRole.teacher);
      await createSession();
      final id = (await repository.load()).sessions.single.id;

      final result = await repository.edit(
        id: id,
        title: 'Hijacked title',
        type: AssemblySessionType.civic,
        audience: '',
        day: '',
        time: '',
        venue: '',
        lead: '',
        participation: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });
}
