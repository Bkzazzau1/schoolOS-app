import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/meals/data/meal_repository.dart';
import 'package:schoolos_app/features/meals/domain/meal_models.dart';
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
  late MealRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = MealRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty week, never a fabricated menu', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.meals, isEmpty);
  });

  group('permissionsFor mirrors apps.schoollife.specs.campus.MEALS exactly', () {
    test('the proprietor, principal and administrator can all edit the menu', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canEditMenu, isTrue, reason: role.name);
      }
    });

    test('nobody else can edit the menu', () async {
      for (final role in [SchoolRole.teacher, SchoolRole.parent, SchoolRole.student]) {
        await actAs(role);
        expect(repository.permissionsFor(session.requireActiveMembership()).canEditMenu, isFalse, reason: role.name);
      }
    });
  });

  group('updateMenuDay', () {
    const monday = SchoolMealDay(
      day: 'Monday',
      breakfast: 'Pap + akara',
      lunch: 'Jollof rice',
      snack: 'Fruit',
      servings: 50,
      status: MealServiceStatus.planned,
      note: 'Standard menu.',
    );

    test('a manager can really set a day that was never configured before', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.updateMenuDay(monday);
      expect(result.success, isTrue, reason: result.message);
      final saved = (await repository.load()).meals.single;
      expect(saved.day, 'Monday');
      expect(saved.isSet, isTrue);
    });

    test('a non-manager cannot set a day', () async {
      await actAs(SchoolRole.teacher);
      final result = await repository.updateMenuDay(monday);
      expect(result.success, isFalse);
    });

    test('breakfast, lunch and snack are all required', () async {
      await actAs(SchoolRole.proprietor);
      final result = await repository.updateMenuDay(monday.copyWith(breakfast: ''));
      expect(result.success, isFalse);
    });

    test('setting one day never fabricates the other four', () async {
      await actAs(SchoolRole.proprietor);
      await repository.updateMenuDay(monday);
      final snapshot = await repository.load();
      expect(snapshot.meals, hasLength(1));
    });
  });
}
