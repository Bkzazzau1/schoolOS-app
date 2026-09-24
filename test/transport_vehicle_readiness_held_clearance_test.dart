import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/transport/data/transport_repository.dart';
import 'package:schoolos_app/features/transport/data/transport_vehicle_readiness_repository.dart';
import 'package:schoolos_app/features/transport/domain/transport_vehicle_readiness_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const owner = SchoolMembership(
  id: 'membership-owner-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.proprietor,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TransportVehicleReadinessRepository readiness;
  late TransportRepository transport;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
    readiness = TransportVehicleReadinessRepository(localDatabase: db, schoolSession: session);
    transport = TransportRepository(localDatabase: db, schoolSession: session);
  });

  tearDown(() => db.close());

  // Holding a vehicle must make the legacy route look unavailable too:
  // route.isAvailable is `status != maintenance`, so if a held clearance
  // never touches route.status, the vehicle still looks assignable/available
  // even though Transport Control explicitly held it.
  test('holding a vehicle makes the legacy route unavailable, and releasing it restores availability', () async {
    final before = (await transport.load()).routes.firstWhere((r) => r.id == 'BUS-01');
    expect(before.isAvailable, isTrue);

    final held = await readiness.setClearance(
      routeId: 'BUS-01',
      status: TransportVehicleClearanceStatus.held,
      note: 'Brake inspection pending.',
    );
    expect(held.success, isTrue, reason: held.message);

    final afterHold = (await transport.load()).routes.firstWhere((r) => r.id == 'BUS-01');
    expect(afterHold.isAvailable, isFalse);

    final released = await readiness.setClearance(
      routeId: 'BUS-01',
      status: TransportVehicleClearanceStatus.released,
    );
    expect(released.success, isTrue, reason: released.message);

    final afterRelease = (await transport.load()).routes.firstWhere((r) => r.id == 'BUS-01');
    expect(afterRelease.isAvailable, isTrue);
  });
}
