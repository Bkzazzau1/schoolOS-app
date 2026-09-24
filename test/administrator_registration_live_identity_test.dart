import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_demo_data.dart';
import 'package:schoolos_app/features/administrator/data/administrator_registration_repository.dart';
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
  late AdministratorRegistrationRepository repository;

  setUp(() async {
    LocalDatabase.blockDemoSeeds = true;
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([admin]);
    await session.selectSchool(admin);
    repository = AdministratorRegistrationRepository(localDatabase: db, schoolSession: session);
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  // A live (server-backed) direct registration draft is seeded from the device
  // clock. Two drafts created back to back must never be handed the same
  // admission number or student ID, even if their timestamps land on the same
  // trailing digits, because nothing else in the registration flow re-checks
  // these identifiers for a collision before queuing them for sync.
  test('every fresh live draft gets a genuinely unique admission number and student ID', () async {
    final seen = <String>{};
    for (var i = 0; i < 25; i++) {
      // A brand-new applicant each time, so load() always mints a fresh draft
      // instead of reusing a previously stored one for the same registrationId.
      final snapshot = await repository.load();
      final record = snapshot.record;
      expect(seen.contains(record.admissionNumber), isFalse,
          reason: 'Duplicate admission number: ${record.admissionNumber}');
      expect(seen.contains(record.studentId), isFalse,
          reason: 'Duplicate student ID: ${record.studentId}');
      seen.add(record.admissionNumber);
      seen.add(record.studentId);

      // Complete this registration so the next iteration's uniqueness scan has
      // to look past a real, already-persisted record - not an empty table.
      final phone = '080${(30000000 + i).toString()}';
      final completed = await repository.completeRegistration(
        record.copyWith(
          firstName: 'Test',
          surname: 'Student$i',
          primaryGuardian: 'Guardian $i',
          guardianPhone: phone,
          academicSection: 'Primary',
          proposedClass: 'Primary 1',
        ),
      );
      expect(completed.success, isTrue, reason: completed.message);
    }
  });

  test('a live draft never reuses the fixed website sample admission number', () async {
    final snapshot = await repository.load();
    expect(snapshot.record.admissionNumber, isNot(administratorRegistrationWebsiteSeed.admissionNumber));
    expect(snapshot.record.firstName, isEmpty);
  });
}
