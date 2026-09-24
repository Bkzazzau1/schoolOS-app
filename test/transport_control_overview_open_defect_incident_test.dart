import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/transport/data/transport_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(
  id: 'membership-admin-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.administrator,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TransportRepository repository;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    repository = TransportRepository(localDatabase: db, schoolSession: session);
  });

  tearDown(() => db.close());

  // An open, trip-blocking defect reported yesterday and never cleared is
  // still a real condition today: the vehicle is still blocked. Scoping the
  // aggregation to serviceDate == today alone would silently drop it and
  // show "0 blocking defects" for a vehicle that is actually still blocked.
  test('a still-open trip-blocking defect from a prior day still counts on today\'s overview', () async {
    await db.upsertLocalRecord(
      tenantId: admin.schoolId,
      entityType: 'driver_vehicle_defect',
      entityId: 'defect-1',
      payload: {
        'routeId': 'BUS-01',
        'vehicle': 'Bus 01',
        'serviceDate': '2020-01-01',
        'status': 'open',
        'blocksTrip': true,
      },
      isDirty: true,
    );

    final overview = await repository.loadControlOverview();
    final route = overview.routes.firstWhere((r) => r.routeId == 'BUS-01');
    expect(route.blockingVehicleDefectCount, 1);
    expect(route.vehicleDefectCount, 1);
    expect(overview.blockingVehicleDefectsToday, 1);
  });

  test('a defect that has been cleared does not count, even if reported today', () async {
    await db.upsertLocalRecord(
      tenantId: admin.schoolId,
      entityType: 'driver_vehicle_defect',
      entityId: 'defect-2',
      payload: {
        'routeId': 'BUS-01',
        'vehicle': 'Bus 01',
        'serviceDate': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'cleared',
        'blocksTrip': true,
      },
      isDirty: true,
    );

    final overview = await repository.loadControlOverview();
    final route = overview.routes.firstWhere((r) => r.routeId == 'BUS-01');
    expect(route.blockingVehicleDefectCount, 0);
    expect(route.vehicleDefectCount, 0);
  });

  // Same principle for incidents: one still awaiting resolution from a prior
  // day is still an open safety matter today.
  test('an unresolved incident from a prior day still counts on today\'s overview', () async {
    await db.upsertLocalRecord(
      tenantId: admin.schoolId,
      entityType: 'driver_transport_incident',
      entityId: 'incident-1',
      payload: {
        'routeId': 'BUS-01',
        'serviceDate': '2020-01-01',
        'status': 'open',
        'requiresImmediateEscalation': true,
      },
      isDirty: true,
    );

    final overview = await repository.loadControlOverview();
    final route = overview.routes.firstWhere((r) => r.routeId == 'BUS-01');
    expect(route.incidentCount, 1);
    expect(route.urgentIncidentCount, 1);
    expect(route.needsAttention, isTrue);
  });
}
