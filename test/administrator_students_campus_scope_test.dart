import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_job_assignment_fixtures.dart';
import 'core/real_student_fixtures.dart';

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);

Future<void> seedClassCampus(LocalDatabase db, {required String tenantId, required String className, String? campusId}) =>
    db.upsertLocalRecord(
      tenantId: tenantId,
      entityType: 'academic_class',
      entityId: 'CLASS-${className.replaceAll(' ', '-')}',
      payload: {'id': 'CLASS-${className.replaceAll(' ', '-')}', 'name': className, if (campusId != null) 'campusId': campusId},
    );

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late AdministratorStudentsRepository repository;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    repository = AdministratorStudentsRepository(localDatabase: db, schoolSession: session);
    await seedClassicRoster(db, tenantId: admin.schoolId);
  });

  tearDown(() => db.close());

  test('with no real job assignment, every real student is visible (unscoped, whole-school)', () async {
    final snapshot = await repository.load();
    expect(snapshot.students.map((s) => s.className).toSet(), contains('JSS 2A'));
    expect(snapshot.students.map((s) => s.className).toSet(), contains('Primary 3'));
  });

  test('a real campus-scoped assignment hides every other campus\'s real students', () async {
    await seedClassCampus(db, tenantId: admin.schoolId, className: 'JSS 2A', campusId: 'CAMPUS-1');
    await seedClassCampus(db, tenantId: admin.schoolId, className: 'Primary 3', campusId: 'CAMPUS-2');
    await seedJobAssignment(db, membership: admin, campusId: 'CAMPUS-1');

    final snapshot = await repository.load();
    final classNames = snapshot.students.map((s) => s.className).toSet();
    expect(classNames, contains('JSS 2A'));
    expect(classNames, isNot(contains('Primary 3')));
  });

  test('a class never assigned to a campus stays hidden from a campus-scoped membership', () async {
    await seedClassCampus(db, tenantId: admin.schoolId, className: 'JSS 2A', campusId: 'CAMPUS-1');
    // 'Primary 3' is deliberately never given a campusId here.
    await seedJobAssignment(db, membership: admin, campusId: 'CAMPUS-1');

    final snapshot = await repository.load();
    expect(snapshot.students.map((s) => s.className), isNot(contains('Primary 3')));
  });
}
