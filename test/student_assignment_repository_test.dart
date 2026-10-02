import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_registration_models.dart';
import 'package:schoolos_app/features/student/data/student_assignment_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_student_fixtures.dart';

// STU-001 (Maryam Abdullahi) is JSS 2A; STU-003/STU-011 are JSS 2B, in classicRosterFixture.
const student = SchoolMembership(id: 'membership-student-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.student);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;
  late StudentAssignmentRepository repository;

  Future<void> publishAssignment({required String id, required String className}) async {
    await db!.upsertLocalRecord(
      tenantId: student.schoolId,
      entityType: studentAssignmentEntityType,
      entityId: id,
      payload: {
        'id': id,
        'title': 'Assignment for $className',
        'instructions': 'Do the work.',
        'className': className,
        'subject': 'Mathematics',
        'type': 'homework',
        'dueAt': '2026-10-20',
        'maximumScore': 100,
        'state': 'published',
      },
    );
  }

  Future<void> linkMyClass(String studentId) async {
    await db!.upsertLocalRecord(
      tenantId: student.schoolId,
      entityType: 'student_class_link',
      entityId: student.id,
      payload: {'studentId': studentId},
    );
  }

  /// A connected-backend scenario needs a registration the server has actually confirmed as
  /// canonical (AdministratorStudentsRepository.load only counts those once blockDemoSeeds is
  /// true) - seedRealStudent/classicRosterFixture deliberately never set this flag themselves, so
  /// the real-backend tests below seed one directly instead.
  Future<void> seedCanonicalStudent({required String id, required String className}) async {
    final registration = StudentRegistrationRecord(
      registrationId: 'REG-CANON-$id',
      firstName: 'Maryam',
      surname: 'Abdullahi',
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
      primaryGuardian: 'Guardian',
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
      canonicalActive: true,
      canonicalStudentId: id,
    );
    await db!.upsertLocalRecord(
      tenantId: student.schoolId,
      entityType: AdministratorStudentsRepository.registrationEntityType,
      entityId: registration.registrationId,
      payload: registration.toJson(),
    );
  }

  setUp(() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([student]);
    await session.selectSchool(student);
    await seedClassicRoster(database, tenantId: student.schoolId);
    repository = StudentAssignmentRepository(
      localDatabase: database,
      schoolSession: session,
      students: AdministratorStudentsRepository(localDatabase: database, schoolSession: session),
    );
    LocalDatabase.blockDemoSeeds = false;
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db?.close();
  });

  test('connected to a real backend, a student sees only assignments published to their own real class', () async {
    await seedCanonicalStudent(id: 'STU-001', className: 'JSS 2A');
    await linkMyClass('STU-001');
    await publishAssignment(id: 'A-JSS2A', className: 'JSS 2A');
    await publishAssignment(id: 'A-JSS2B', className: 'JSS 2B');
    LocalDatabase.blockDemoSeeds = true;

    final items = await repository.load();

    expect(items.map((i) => i.assignment.id), ['A-JSS2A']);
  });

  test('connected to a real backend, no class link at all means honestly nothing, never every class', () async {
    await publishAssignment(id: 'A-JSS2A', className: 'JSS 2A');
    await publishAssignment(id: 'A-JSS2B', className: 'JSS 2B');
    LocalDatabase.blockDemoSeeds = true;

    expect(await repository.load(), isEmpty);
  });

  test('standalone demo mode (no real backend) shows every class, matching Parent\'s own demo-mode convention', () async {
    await linkMyClass('STU-001'); // JSS 2A
    await publishAssignment(id: 'A-JSS2A', className: 'JSS 2A');
    await publishAssignment(id: 'A-JSS2B', className: 'JSS 2B');
    // blockDemoSeeds stays false here.

    final items = await repository.load();

    expect(items.map((i) => i.assignment.id).toSet(), {'A-JSS2A', 'A-JSS2B'});
  });

  test('a closed assignment from the student\'s own class still appears; a draft never does', () async {
    await seedCanonicalStudent(id: 'STU-001', className: 'JSS 2A');
    await linkMyClass('STU-001');
    await publishAssignment(id: 'A-closed', className: 'JSS 2A');
    await db!.upsertLocalRecord(
      tenantId: student.schoolId,
      entityType: studentAssignmentEntityType,
      entityId: 'A-closed',
      payload: {'id': 'A-closed', 'title': 'x', 'instructions': 'x', 'className': 'JSS 2A', 'subject': 'Mathematics', 'type': 'homework', 'dueAt': '2026-10-20', 'maximumScore': 100, 'state': 'closed'},
    );
    await db!.upsertLocalRecord(
      tenantId: student.schoolId,
      entityType: studentAssignmentEntityType,
      entityId: 'A-draft',
      payload: {'id': 'A-draft', 'title': 'x', 'instructions': 'x', 'className': 'JSS 2A', 'subject': 'Mathematics', 'type': 'homework', 'dueAt': '2026-10-20', 'maximumScore': 100, 'state': 'draft'},
    );
    LocalDatabase.blockDemoSeeds = true;

    final items = await repository.load();

    expect(items.map((i) => i.assignment.id), ['A-closed']);
  });

  test('only a Student membership can load assignments', () async {
    const teacher = SchoolMembership(id: 'm-teacher', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.teacher);
    await session.setMemberships([student, teacher]);
    await session.selectSchool(teacher);

    expect(await repository.load(), isEmpty);
  });
}
