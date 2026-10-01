import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/transport/data/transport_route_management_repository.dart';
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

SchoolMembership _member(SchoolRole role) =>
    SchoolMembership(id: role.name, schoolId: 'a', schoolName: 'A', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late TransportRouteManagementRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = TransportRouteManagementRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty route register, never fabricated routes', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.routes, isEmpty);
  });

  group('permissions mirror two different real backend ownership domains', () {
    test(
      'canManageRoutes mirrors apps.schoollife.specs.campus.TRANSPORT (proprietor, principal, administrator) - '
      'the same three roles this whole screen is scoped to, so every real viewer can manage routes',
      () async {
        for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
          await actAs(role);
          final snapshot = await repository.load();
          expect(snapshot.canManageRoutes, isTrue, reason: role.name);
        }
        await actAs(SchoolRole.teacher);
        expect(repository.load(), throwsStateError, reason: 'teacher cannot even view this screen');
      },
    );

    test(
      'canManageStops mirrors apps.transport.route_plan\'s own, narrower MANAGERS (principal excluded)',
      () async {
        await actAs(SchoolRole.principal);
        expect((await repository.load()).canManageStops, isFalse);
        for (final role in [SchoolRole.proprietor, SchoolRole.administrator]) {
          await actAs(role);
          expect((await repository.load()).canManageStops, isTrue, reason: role.name);
        }
      },
    );
  });

  group('createRoute', () {
    test('a principal can really create a route record, even though stops are off-limits', () async {
      await actAs(SchoolRole.principal);
      final result = await repository.createRoute(
        name: 'Zaria Road Route',
        vehicle: 'Toyota Coaster · BGA-01',
        assistant: 'Mrs. Esther John',
      );
      expect(result.success, isTrue, reason: result.message);
      final route = (await repository.load()).routes.single;
      expect(route.route.id, 'BUS-01');
      expect(route.route.name, 'Zaria Road Route');
      expect(route.activeStopCount, 0);

      expect(
        repository.addStop(
          routeId: 'BUS-01',
          name: 'Market Junction',
          morningTime: '07:00',
          afternoonTime: '15:30',
        ),
        throwsStateError,
        reason: 'principal is excluded from apps.transport.route_plan\'s own MANAGERS',
      );
    });

    test('a role outside route management cannot create a route', () async {
      await actAs(SchoolRole.teacher);
      expect(
        repository.createRoute(name: 'Ghost Route', vehicle: 'Bus', assistant: 'Someone'),
        throwsStateError,
      );
    });
  });

  group('addStop', () {
    test('an administrator (a real stop manager) can really add a stop to a real route', () async {
      await actAs(SchoolRole.administrator);
      await repository.createRoute(
        name: 'Barnawa / Kakuri Route',
        vehicle: 'Toyota Hiace · BGA-02',
        assistant: 'Not recorded yet',
      );
      final result = await repository.addStop(
        routeId: 'BUS-01',
        name: 'Market Junction',
        morningTime: '07:00',
        afternoonTime: '15:30',
      );
      expect(result.success, isTrue, reason: result.message);
      final entry = (await repository.load()).routes.single;
      expect(entry.activeStopCount, 1);
      expect(entry.plan.activeStops.single.name, 'Market Junction');
    });
  });

  test('loadPlanForRoute is honestly empty until a stop is really added', () async {
    await actAs(SchoolRole.proprietor);
    await repository.createRoute(
      name: 'Zaria Road Route',
      vehicle: 'Toyota Coaster · BGA-01',
      assistant: 'Mrs. Esther John',
    );
    final plan = await repository.loadPlanForRoute('BUS-01');
    expect(plan.stops, isEmpty);
    expect(plan.activeStops, isEmpty);
  });

  group('updateRoute', () {
    test('a principal can really update the route record itself', () async {
      await actAs(SchoolRole.principal);
      await repository.createRoute(
        name: 'Zaria Road Route',
        vehicle: 'Toyota Coaster · BGA-01',
        assistant: 'Mrs. Esther John',
      );
      final result = await repository.updateRoute(
        routeId: 'BUS-01',
        name: 'Zaria Road Route (Revised)',
        vehicle: 'Toyota Coaster · BGA-01',
        assistant: 'Mrs. Esther John',
        note: 'Timing adjusted for term 2.',
      );
      expect(result.success, isTrue, reason: result.message);
      expect((await repository.load()).routes.single.route.name, 'Zaria Road Route (Revised)');
    });
  });
}
