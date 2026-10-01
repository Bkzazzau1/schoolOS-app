import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/teaching_models/data/teaching_model_repository.dart';
import 'package:schoolos_app/features/teaching_models/domain/teaching_model_models.dart';
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
  late TeachingModelRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  Future<TeachingModelActionResult> createConfig() => repository.create(
        section: 'Primary',
        className: 'Primary 1',
        model: TeachingModelType.classTeacher,
        leadTeacher: 'Mrs. Ruth James',
        specialistCoverage: 'PE, Arabic, ICT',
        note: '',
      );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = TeachingModelRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty structure, never fabricated class configs', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.configurations, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.programmes.TEACHING_MODELS exactly', () {
    test('only the proprietor and principal (LEADERS) can configure', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canConfigureAllSections, isTrue, reason: role.name);
      }
    });

    test('administrator (not a LEADERS role here) and everyone else cannot configure', () async {
      for (final role in [SchoolRole.administrator, SchoolRole.teacher, SchoolRole.staff]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canConfigureAllSections, isFalse, reason: role.name);
      }
    });
  });

  group('create', () {
    test('a leader can really add a class configuration', () async {
      await actAs(SchoolRole.principal);
      final result = await createConfig();
      expect(result.success, isTrue, reason: result.message);
      final config = (await repository.load()).configurations.single;
      expect(config.className, 'Primary 1');
      expect(config.model, TeachingModelType.classTeacher);
    });

    test('administrator cannot add a class configuration', () async {
      await actAs(SchoolRole.administrator);
      final result = await createConfig();
      expect(result.success, isFalse);
    });

    test('an empty section or class name is refused', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.create(
        section: '   ',
        className: '',
        model: TeachingModelType.classTeacher,
        leadTeacher: '',
        specialistCoverage: '',
        note: '',
      );
      expect(result.success, isFalse);
    });
  });

  group('updateModel', () {
    test('a leader can really change a real class\'s model without touching lead/specialist data', () async {
      await actAs(SchoolRole.proprietor);
      await createConfig();
      final id = (await repository.load()).configurations.single.id;
      final result = await repository.updateModel(configurationId: id, model: TeachingModelType.hybrid);
      expect(result.success, isTrue, reason: result.message);
      final config = (await repository.load()).configurations.single;
      expect(config.model, TeachingModelType.hybrid);
      expect(config.leadTeacher, 'Mrs. Ruth James');
    });

    test('administrator cannot change a class model', () async {
      await actAs(SchoolRole.proprietor);
      await createConfig();
      final id = (await repository.load()).configurations.single.id;
      await actAs(SchoolRole.administrator);
      final result = await repository.updateModel(configurationId: id, model: TeachingModelType.hybrid);
      expect(result.success, isFalse);
    });
  });
}
