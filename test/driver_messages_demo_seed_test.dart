import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_dashboard_repository.dart';
import 'package:schoolos_app/features/driver/data/driver_messages_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const driver = SchoolMembership(
  id: 'membership-driver-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.driver,
);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;

  Future<void> setUpDriver() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([driver]);
    await session.selectSchool(driver);
  }

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db?.close();
  });

  test('in demo mode the Driver sees the sample conversations and alerts', () async {
    await setUpDriver();
    final messages = DriverMessagesRepository(localDatabase: db!, schoolSession: session);
    final snapshot = await messages.load();
    expect(snapshot.threads, isNotEmpty);
    expect(snapshot.alerts, isNotEmpty);
  });

  test('on a school with a server the sample conversations are never shown as if they had been sent', () async {
    await setUpDriver();
    // The route and assignment exist first (a real school has them from the server).
    await DriverDashboardRepository(localDatabase: db!, schoolSession: session).load();

    LocalDatabase.blockDemoSeeds = true;
    final messages = DriverMessagesRepository(localDatabase: db!, schoolSession: session);
    final snapshot = await messages.load();
    expect(snapshot.threads, isEmpty);
    expect(snapshot.alerts, isEmpty);
    expect(snapshot.routeId, isNotEmpty, reason: 'still scoped to the Driver\'s real route');
  });
}
