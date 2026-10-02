import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_operations_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorOperationsRepository operations;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    operations = AdministratorOperationsRepository(localDatabase: db, schoolSession: session);
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  test('a fresh demo school shows the sample operations queue', () async {
    final snapshot = await operations.load();
    expect(snapshot.tasks, hasLength(5));
  });

  test('connected to a real backend, the sample operations queue is never seeded', () async {
    LocalDatabase.blockDemoSeeds = true;
    final snapshot = await operations.load();
    expect(snapshot.tasks, isEmpty);
  });
}
