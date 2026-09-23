import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_dashboard_repository.dart';
import 'package:schoolos_app/features/driver/data/driver_morning_run_repository.dart';
import 'package:schoolos_app/features/transport/data/transport_demo_data.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

// The one demo Driver membership id the app's own seeding logic specifically recognizes
// (DriverDashboardRepository._loadAssignment only auto-assigns this exact id to BUS-02).
const driver = SchoolMembership(id: 'membership-driver-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.driver);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late DriverDashboardRepository dashboard;
  late DriverMorningRunRepository morningRun;

  Future<void> setUpSchool() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([driver, teacher]);
    await session.selectSchool(driver);
    dashboard = DriverDashboardRepository(localDatabase: database, schoolSession: session);
    morningRun = DriverMorningRunRepository(localDatabase: database, schoolSession: session);
  }

  tearDown(() => db?.close());

  test('the seeded demo driver assignment carries an honest role label, never a fabricated person', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.assignment.driverDisplayName, 'Driver');
    expect(snapshot.assignment.routeId, 'BUS-02');
  });

  test('the real BUS-02 rider count matches the real register: one real student, not a fabricated roster', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    // Before any run is recorded today, the dashboard falls back to the route's own real rider
    // count — this must match the real registered roster, not an invented headcount.
    expect(snapshot.morningExpected, 1);
    expect(snapshot.afternoonExpected, 1);
  });

  test('the real morning manifest has only real registered students, every other stop honestly empty', () async {
    await setUpSchool();
    final run = await morningRun.loadToday();
    expect(run.expectedRiders, 1);

    final allRiders = [for (final stop in run.stops) ...stop.riders];
    expect(allRiders, hasLength(1));
    expect(allRiders.single.studentId, 'STU-001');
    expect(allRiders.single.name, 'Maryam Abdullahi');
    expect(allRiders.single.className, 'JSS 2A');

    // Every other stop on the route is honestly empty rather than padded with invented riders.
    final emptyStops = run.stops.where((stop) => stop.riders.isEmpty);
    expect(emptyStops, hasLength(run.stops.length - 1));
  });

  test('BUS-02 seed reconciles with the real trimmed roster', () async {
    final route = transportWebsiteSeed.firstWhere((r) => r.id == 'BUS-02');
    await setUpSchool();
    final run = await morningRun.loadToday();
    expect(route.riders, run.expectedRiders);
  });

  test('only a Driver membership can load the transport dashboard', () async {
    await setUpSchool();
    await session.selectSchool(teacher);
    expect(dashboard.load(), throwsStateError);
  });
}
