import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/features/duties/data/my_duties_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_finance_fixtures.dart';

const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
const otherTeacher = SchoolMembership(id: 'm-other-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);

void main() {
  late LocalDatabase db;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
  });

  tearDown(() => db.close());

  test('a person given no job-assignment duty has nothing here, honestly', () async {
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.activeDuties(), isEmpty);
    expect(await repository.hasAnyHubAccess(), isFalse);
  });

  test('a real duty to prepare direct-debit batches unlocks Mandates and nothing else', () async {
    await seedBillingAuthority(db, membership: teacher, duties: const ['finance.mandate_prepare']);
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.hasMandatesAccess(), isTrue);
    expect(await repository.hasCollectionsAccess(), isFalse);
    expect(await repository.hasAnyHubAccess(), isTrue);
  });

  test('a real duty to approve collection batches unlocks Smart Money Collection and nothing else', () async {
    await seedBillingAuthority(db, membership: teacher, duties: const ['finance.collection_approve']);
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.hasCollectionsAccess(), isTrue);
    expect(await repository.hasMandatesAccess(), isFalse);
  });

  test('a duty given to someone else never leaks into this person\'s own duties', () async {
    await seedBillingAuthority(db, membership: otherTeacher, duties: const ['finance.mandate_approve']);
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.activeDuties(), isEmpty);
  });

  test('a duty that is not yet active (still pending activation) grants nothing', () async {
    await db.upsertLocalRecord(
      tenantId: teacher.schoolId,
      entityType: myDutiesJobAssignmentEntityType,
      entityId: 'JOB-${teacher.id}',
      payload: const {
        'membershipId': 'm-teacher',
        'duties': ['finance.mandate_prepare'],
        'status': 'pendingActivation',
      },
    );
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.hasAnyHubAccess(), isFalse);
  });

  test('billing authority alone never unlocks a hub it was never meant to', () async {
    await seedBillingAuthority(db, membership: teacher);
    final repository = MyDutiesRepository(database: db, membership: teacher);
    expect(await repository.hasAnyHubAccess(), isFalse);
  });
}
