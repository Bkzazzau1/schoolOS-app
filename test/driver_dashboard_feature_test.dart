import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/driver/data/driver_dashboard_repository.dart';
import 'package:schoolos_app/features/driver/data/driver_morning_run_repository.dart';
import 'package:schoolos_app/features/driver/domain/driver_dashboard_models.dart';
import 'package:schoolos_app/features/transport/data/transport_rider_assignment_repository.dart';
import 'package:schoolos_app/features/transport/data/transport_route_management_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const driver = SchoolMembership(id: 'membership-driver-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.driver);
const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const admin = SchoolMembership(id: 'membership-admin-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);

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
    await session.setMemberships([driver, teacher, admin]);

    // Build the real chain Transport Control would really have in place before a Driver ever
    // opens the app: a real route, a real stop plan, a real driver assignment, and one real
    // registered rider - nothing here is a fabricated seed.
    await session.selectSchool(admin);
    final routeManagement = TransportRouteManagementRepository(localDatabase: database, schoolSession: session);
    await routeManagement.createRoute(
      name: 'Barnawa / Kakuri Route',
      vehicle: 'Toyota Hiace · BGA-02',
      assistant: 'Not recorded yet',
    );
    await routeManagement.addStop(
      routeId: 'BUS-01',
      name: 'Barnawa Junction',
      morningTime: '07:00',
      afternoonTime: '15:00',
    );
    await routeManagement.addStop(
      routeId: 'BUS-01',
      name: 'Kakuri Junction',
      morningTime: '07:10',
      afternoonTime: '15:10',
    );

    const assignment = DriverTransportAssignment(
      membershipId: 'membership-driver-001',
      routeId: 'BUS-01',
      driverDisplayName: 'Driver',
    );
    await database.upsertLocalRecord(
      tenantId: driver.schoolId,
      entityType: DriverDashboardRepository.assignmentEntityType,
      entityId: assignment.membershipId,
      payload: assignment.toJson(),
      isDirty: false,
    );

    final riderAssignments = TransportRiderAssignmentRepository(localDatabase: database, schoolSession: session);
    final plan = await routeManagement.loadPlanForRoute('BUS-01');
    final firstStopId = plan.activeStops.first.id;
    // STU-001 Maryam Abdullahi is the real, already-seeded administrator student directory entry
    // (administrator_students_demo_data.dart) - the same single source every other role's tests
    // treat as this demo school's real roster.
    await riderAssignments.assignStudent(studentId: 'STU-001', routeId: 'BUS-01', stopId: firstStopId);

    await session.selectSchool(driver);
    dashboard = DriverDashboardRepository(localDatabase: database, schoolSession: session);
    morningRun = DriverMorningRunRepository(localDatabase: database, schoolSession: session);
  }

  tearDown(() => db?.close());

  test('a real driver assignment carries an honest role label, never a fabricated person', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    expect(snapshot.assignment.driverDisplayName, 'Driver');
    expect(snapshot.assignment.routeId, 'BUS-01');
  });

  test('the real rider count matches the real register: one real student, not a fabricated roster', () async {
    await setUpSchool();
    final snapshot = await dashboard.load();
    // Before any run is recorded today, the dashboard falls back to the route's own real rider
    // count — this must match the real registered roster, not an invented headcount.
    expect(snapshot.morningExpected, 1);
    expect(snapshot.afternoonExpected, 1);
  });

  test('the real morning manifest has only the real registered student, the other stop honestly empty', () async {
    await setUpSchool();
    final run = await morningRun.loadToday();
    expect(run.expectedRiders, 1);

    final allRiders = [for (final stop in run.stops) ...stop.riders];
    expect(allRiders, hasLength(1));
    expect(allRiders.single.studentId, 'STU-001');
    expect(allRiders.single.name, 'Maryam Abdullahi');
    expect(allRiders.single.className, 'JSS 2A');

    // The second stop has no rider assigned to it and is honestly empty rather than padded with
    // invented riders.
    final emptyStops = run.stops.where((stop) => stop.riders.isEmpty);
    expect(emptyStops, hasLength(1));
  });

  test('only a Driver membership can load the transport dashboard', () async {
    await setUpSchool();
    await session.selectSchool(teacher);
    expect(dashboard.load(), throwsStateError);
  });
}
