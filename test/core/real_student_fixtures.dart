import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_registration_models.dart';

/// Writes a real, completed student registration directly to local storage, the same real entity
/// [AdministratorStudentsRepository.load] merges into the register. Tests use this instead of the
/// fabricated directory seed that used to populate a fresh school's register automatically: every
/// student this creates is one [AdministratorStudentsRepository.load] would show as a real, active,
/// already-registered student - not a stand-in for one.
Future<void> seedRealStudent(
  LocalDatabase db, {
  required String tenantId,
  required String id,
  required String name,
  required String className,
  String guardian = 'Guardian',
}) async {
  final parts = name.trim().split(RegExp(r'\s+'));
  final firstName = parts.first;
  final surname = parts.length > 1 ? parts.skip(1).join(' ') : '';
  final registration = StudentRegistrationRecord(
    registrationId: 'REG-FIXTURE-$id',
    firstName: firstName,
    surname: surname,
    otherName: '',
    dateOfBirth: '',
    gender: '',
    academicSection: '',
    proposedClass: className,
    previousSchool: '',
    address: '',
    admissionNumber: '',
    studentId: id,
    status: StudentRegistrationStatus.active,
    primaryGuardian: guardian,
    relationship: '',
    guardianPhone: '',
    guardianEmail: '',
    familyAccount: '',
    siblingLink: '',
    birthCertificateStatus: '',
    previousSchoolRecordStatus: '',
    guardianIdentificationStatus: '',
    financeSetupStatus: '',
    transportMealStatus: '',
    canonicalStudentId: id,
  );
  await db.upsertLocalRecord(
    tenantId: tenantId,
    entityType: AdministratorStudentsRepository.registrationEntityType,
    entityId: registration.registrationId,
    payload: registration.toJson(),
  );
}

/// The same 16 named students the app's old, now-removed fabricated directory seed used to invent
/// (4 from the website seed, 12 from the demo-school extras) - kept here as real registrations so
/// tests written against that roster's names, classes and class-option set keep working without each
/// hand-rolling the same list. Every id, name, class and guardian matches the removed seed exactly.
const classicRosterFixture = <({String id, String name, String className, String guardian})>[
  (id: 'STU-001', name: 'Maryam Abdullahi', className: 'JSS 2A', guardian: 'Alhaji Abdullahi Musa'),
  (id: 'STU-002', name: 'Ibrahim Sani', className: 'JSS 2A', guardian: 'Alhaji Sani Ibrahim'),
  (id: 'STU-003', name: 'Yusuf Bello', className: 'JSS 2B', guardian: 'Alhaji Musa Bello'),
  (id: 'PRI-003', name: 'Hafsa Abdullahi', className: 'Primary 3', guardian: 'Alhaji Abdullahi Sani'),
  (id: 'NUR-001', name: 'Zainab Yusuf', className: 'Nursery 2', guardian: 'Mrs. Amina Yusuf'),
  (id: 'NUR-002', name: 'Bilal Kabir', className: 'Nursery 1', guardian: 'Mr. Sani Kabir'),
  (id: 'PRI-001', name: 'Aisha Danladi', className: 'Primary 1', guardian: 'Mr. Ibrahim Danladi'),
  (id: 'PRI-002', name: 'Hassan Faruq', className: 'Primary 2', guardian: 'Mrs. Hauwa Faruq'),
  (id: 'PRI-004', name: 'Khadija Sule', className: 'Primary 4', guardian: 'Mrs. Hauwa Sule'),
  (id: 'PRI-005', name: 'Musa Abubakar', className: 'Primary 5', guardian: 'Mr. Musa Abubakar'),
  (id: 'PRI-006', name: 'Ahmad Musa', className: 'Primary 6', guardian: 'Mrs. Grace Musa'),
  (id: 'PRI-007', name: 'Fatima Aliyu', className: 'Primary 6', guardian: 'Mr. Aliyu Garba'),
  (id: 'STU-004', name: 'Halima Sani', className: 'JSS 1', guardian: 'Alhaji Sani Halima'),
  (id: 'STU-005', name: 'Abdullahi Umar', className: 'SS1A', guardian: 'Mr. Umar Abdullahi'),
  (id: 'STU-006', name: 'Ruth John', className: 'SS1A', guardian: 'Mr. Daniel John'),
  (id: 'STU-007', name: 'Samuel Peter', className: 'SS2A', guardian: 'Mr. Peter James'),
  (id: 'STU-008', name: 'Maimuna Bello', className: 'SS2B', guardian: 'Alhaji Musa Bello'),
  (id: 'STU-009', name: 'Yakubu Garba', className: 'SS3A', guardian: 'Mr. Aliyu Garba'),
  (id: 'STU-010', name: 'Rahma Ibrahim', className: 'JSS 3A', guardian: 'Alhaji Ibrahim Bashir'),
  (id: 'STU-011', name: 'Ahmed Yusuf', className: 'JSS 2B', guardian: 'Mrs. Amina Yusuf'),
  (id: 'STU-012', name: 'Fatima Musa', className: 'JSS 2', guardian: 'Alhaji Musa Bello'),
];

/// Seeds the entire [classicRosterFixture] as real registrations.
Future<void> seedClassicRoster(LocalDatabase db, {required String tenantId}) async {
  for (final s in classicRosterFixture) {
    await seedRealStudent(db, tenantId: tenantId, id: s.id, name: s.name, className: s.className, guardian: s.guardian);
  }
}
