import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/service/data/service_repository.dart';
import 'package:schoolos_app/features/service/domain/service_models.dart';
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
  late ServiceRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<ServiceActionResult> createProject() => repository.create(
        title: 'School Environment Clean-Up',
        type: 'Service',
        audience: 'JSS 2 + JSS 3',
        coordinator: 'Environmental Club',
        date: '19 Sep 2026',
        status: ServiceProjectStatus.planned,
        beneficiary: 'School community',
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = ServiceRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty project register, never fabricated projects', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.projects, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.programmes.SERVICE exactly', () {
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

    test('only the proprietor and principal (LEADERS) can verify records, not administrator', () async {
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canVerifyRecords, isFalse);
      for (final role in [SchoolRole.proprietor, SchoolRole.principal]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canVerifyRecords, isTrue, reason: role.name);
      }
    });
  });

  group('create', () {
    test('a teacher (a real contributor) can really add a project, starting at honest zeros', () async {
      await actAs(SchoolRole.teacher);
      final result = await createProject();
      expect(result.success, isTrue, reason: result.message);
      final project = (await repository.load()).projects.single;
      expect(project.title, 'School Environment Clean-Up');
      expect(project.participants, 0);
      expect(project.hours, 0);
      expect(project.verified, isFalse);
    });

    test('a role outside manage/contribute cannot add a project', () async {
      await actAs(SchoolRole.parent);
      final result = await createProject();
      expect(result.success, isFalse);
    });
  });

  group('edit', () {
    test('a manager can really update participants and hours by hand', () async {
      await actAs(SchoolRole.proprietor);
      await createProject();
      final id = (await repository.load()).projects.single.id;
      final result = await repository.edit(
        id: id,
        type: 'Service',
        audience: 'JSS 2 + JSS 3',
        coordinator: 'Environmental Club',
        date: '19 Sep 2026',
        participants: 74,
        hours: 148,
        status: ServiceProjectStatus.completed,
        beneficiary: 'School community',
        note: 'Updated.',
      );
      expect(result.success, isTrue, reason: result.message);
      final project = (await repository.load()).projects.single;
      expect(project.participants, 74);
      expect(project.status, ServiceProjectStatus.completed);
    });

    test('a teacher (a contributor, not a manager) cannot edit a project', () async {
      await actAs(SchoolRole.teacher);
      await createProject();
      final id = (await repository.load()).projects.single.id;
      final result = await repository.edit(
        id: id,
        type: '',
        audience: '',
        coordinator: '',
        date: '',
        participants: 1,
        hours: 1,
        status: ServiceProjectStatus.active,
        beneficiary: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });

  group('toggleVerification', () {
    test('a leader can really verify a real project; administrator cannot', () async {
      await actAs(SchoolRole.proprietor);
      await createProject();
      final id = (await repository.load()).projects.single.id;

      await actAs(SchoolRole.administrator);
      final denied = await repository.toggleVerification(id);
      expect(denied.success, isFalse);

      await actAs(SchoolRole.principal);
      final allowed = await repository.toggleVerification(id);
      expect(allowed.success, isTrue, reason: allowed.message);
      expect((await repository.load()).projects.single.verified, isTrue);
    });
  });
}
