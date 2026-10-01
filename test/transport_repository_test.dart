import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/sync/sync_mutation.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/core/tenancy/school_session_store.dart';
import 'package:schoolos_app/features/driver/domain/driver_morning_run_models.dart';
import 'package:schoolos_app/features/transport/data/transport_repository.dart';
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

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Database database;
  late SchoolSessionController session;
  late TransportRepository repository;

  Future<void> actAs(SchoolRole role) async {
    final member = _member(role);
    await session.setMemberships([member]);
    await session.selectSchool(member);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    database = _Database();
    session = SchoolSessionController(store: SchoolSessionStore());
    repository = TransportRepository(localDatabase: database, schoolSession: session);
  });
  tearDown(() => session.dispose());

  test('a fresh school sees a genuinely empty route register and honest zero stats, never fabricated routes', () async {
    await actAs(SchoolRole.proprietor);
    final snapshot = await repository.load();
    expect(snapshot.routes, isEmpty);
    expect(snapshot.morningExceptionsToday, 0);
  });

  group('permissionsFor mirrors apps.schoollife.specs.campus.TRANSPORT exactly', () {
    test('proprietor, principal and administrator (MANAGERS) can view operations control', () async {
      for (final role in [SchoolRole.proprietor, SchoolRole.principal, SchoolRole.administrator]) {
        await actAs(role);
        final p = repository.permissionsFor(session.requireActiveMembership());
        expect(p.canViewOperationsControl, isTrue, reason: role.name);
      }
      await actAs(SchoolRole.teacher);
      expect(
        repository.permissionsFor(session.requireActiveMembership()).canViewOperationsControl,
        isFalse,
      );
    });

    test('only the proprietor and principal (LEADERS) can review routes, administrator cannot', () async {
      await actAs(SchoolRole.administrator);
      expect(repository.permissionsFor(session.requireActiveMembership()).canReviewRoutes, isFalse);
      for (final role in [SchoolRole.proprietor, SchoolRole.principal]) {
        await actAs(role);
        expect(
          repository.permissionsFor(session.requireActiveMembership()).canReviewRoutes,
          isTrue,
          reason: role.name,
        );
      }
    });

    test(
      'only the proprietor and administrator can manage driver assignments - apps.transport.constants\' own '
      'narrower MANAGERS, which deliberately excludes principal, unlike the route record itself',
      () async {
        await actAs(SchoolRole.principal);
        expect(
          repository.permissionsFor(session.requireActiveMembership()).canManageDriverAssignments,
          isFalse,
        );
        for (final role in [SchoolRole.proprietor, SchoolRole.administrator]) {
          await actAs(role);
          expect(
            repository.permissionsFor(session.requireActiveMembership()).canManageDriverAssignments,
            isTrue,
            reason: role.name,
          );
        }
      },
    );
  });

  test('morning exceptions are a real count from today\'s recorded runs, never a fixed placeholder', () async {
    await actAs(SchoolRole.proprietor);
    final member = session.requireActiveMembership();
    final run = DriverMorningRun(
      id: 'run-1',
      membershipId: 'membership-driver-001',
      routeId: 'BUS-02',
      serviceDate: _todayKey(),
      vehicle: 'Toyota Hiace',
      driverName: 'Driver',
      assistantName: '',
      stops: const [
        DriverMorningStop(
          id: 'stop-1',
          sequence: 1,
          name: 'Stop 1',
          scheduledTime: '07:00',
          riders: [
            DriverMorningRider(
              studentId: 'STU-001',
              name: 'Maryam Abdullahi',
              className: 'JSS 2A',
              stopId: 'stop-1',
              status: DriverMorningRiderStatus.noShow,
            ),
          ],
        ),
      ],
    );
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: 'driver_morning_run',
      entityId: run.id,
      payload: run.toJson(),
      isDirty: false,
    );

    final snapshot = await repository.load();
    expect(snapshot.morningExceptionsToday, 1);
  });

  test('a morning run from a prior day never counts toward today\'s exceptions', () async {
    await actAs(SchoolRole.proprietor);
    final member = session.requireActiveMembership();
    const run = DriverMorningRun(
      id: 'run-old',
      membershipId: 'membership-driver-001',
      routeId: 'BUS-02',
      serviceDate: '2020-01-01',
      vehicle: 'Toyota Hiace',
      driverName: 'Driver',
      assistantName: '',
      stops: [
        DriverMorningStop(
          id: 'stop-1',
          sequence: 1,
          name: 'Stop 1',
          scheduledTime: '07:00',
          riders: [
            DriverMorningRider(
              studentId: 'STU-001',
              name: 'Maryam Abdullahi',
              className: 'JSS 2A',
              stopId: 'stop-1',
              status: DriverMorningRiderStatus.noShow,
            ),
          ],
        ),
      ],
    );
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: 'driver_morning_run',
      entityId: run.id,
      payload: run.toJson(),
      isDirty: false,
    );

    final snapshot = await repository.load();
    expect(snapshot.morningExceptionsToday, 0);
  });
}
