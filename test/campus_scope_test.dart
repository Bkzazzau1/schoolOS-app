import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/campus_scope.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_job_assignment_fixtures.dart';

const admin = SchoolMembership(id: 'm-admin', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);
const other = SchoolMembership(id: 'm-other', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.administrator);

void main() {
  late LocalDatabase db;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
  });

  tearDown(() => db.close());

  test('with no real job assignment at all, scope is whole-school (null)', () async {
    expect(await campusScopeFor(db, admin), isNull);
  });

  test('a real direct campus grant scopes to that campus', () async {
    await seedJobAssignment(db, membership: admin, campusId: 'CAMPUS-1');
    expect(await campusScopeFor(db, admin), 'CAMPUS-1');
  });

  test('a sectionHead-style grant resolves through the section\'s own real campus', () async {
    await seedStructureSection(db, tenantId: admin.schoolId, id: 'SEC-1', campusId: 'CAMPUS-2');
    await seedJobAssignment(db, membership: admin, sectionId: 'SEC-1');
    expect(await campusScopeFor(db, admin), 'CAMPUS-2');
  });

  test('a section with no real campus assigned yet leaves the grant whole-school', () async {
    await seedStructureSection(db, tenantId: admin.schoolId, id: 'SEC-1');
    await seedJobAssignment(db, membership: admin, sectionId: 'SEC-1');
    expect(await campusScopeFor(db, admin), isNull);
  });

  test('a pending (not yet active) assignment grants no scope', () async {
    await seedJobAssignment(db, membership: admin, campusId: 'CAMPUS-1', status: 'pendingActivation');
    expect(await campusScopeFor(db, admin), isNull);
  });

  test('someone else\'s assignment never scopes this membership', () async {
    await seedJobAssignment(db, membership: other, campusId: 'CAMPUS-1');
    expect(await campusScopeFor(db, admin), isNull);
  });
}
