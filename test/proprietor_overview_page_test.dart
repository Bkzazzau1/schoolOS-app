import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_admissions_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_registration_models.dart';
import 'package:schoolos_app/features/proprietor/data/concession_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_attention_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_enrollment.dart';
import 'package:schoolos_app/features/proprietor/data/owner_finance_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_payroll_repository.dart';
import 'package:schoolos_app/features/proprietor/data/owner_reports.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_overview.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/proprietor_structure_repository.dart';
import 'package:schoolos_app/features/proprietor/data/staff_proposal_repository.dart';
import 'package:schoolos_app/features/proprietor/presentation/proprietor_overview_page.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;
import 'core/real_staff_fixtures.dart';

const owner = SchoolMembership(id: 'm-owner', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);

void main() {
  LocalDatabase? db;
  late SchoolSessionController session;

  OwnerReportsRepository reportsRepository() {
    final structure = ProprietorStructureRepository(localDatabase: db!, schoolSession: session);
    final profiles = OwnerStaffProfileRepository(database: db!, session: session);
    return OwnerReportsRepository(
      staff: OwnerStaffOverviewRepository(profiles: profiles, structure: structure),
      finance: OwnerFinanceOverviewRepository(
        concessions: ConcessionRepository(localDatabase: db!, schoolSession: session),
        payroll: OwnerPayrollRepository(database: db!, session: session),
        database: db!,
        session: session,
      ),
      attention: OwnerAttentionRepository(
        database: db!,
        session: session,
        proposals: StaffProposalRepository(remote: null, database: db!, session: session),
        concessions: ConcessionRepository(localDatabase: db!, schoolSession: session),
        staff: OwnerStaffOverviewRepository(profiles: profiles, structure: structure),
        structure: structure,
      ),
      enrollment: OwnerEnrollmentRepository(
        students: AdministratorStudentsRepository(localDatabase: db!, schoolSession: session),
        admissions: AdministratorAdmissionsRepository(localDatabase: db!, schoolSession: session),
      ),
    );
  }

  setUp(() async {
    final database = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await database.initialize();
    db = database;
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([owner]);
    await session.selectSchool(owner);
  });

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db?.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: ProprietorOverviewPage(schoolName: owner.schoolName, reports: reportsRepository()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh school has no fabricated leaders, figures or trend chart anywhere', (tester) async {
    // Every assertion here is about a real, connected-backend production deployment - demo mode is
    // allowed its own already-reviewed gated seeds (e.g. Structure's starter leadership names).
    LocalDatabase.blockDemoSeeds = true;
    await pump(tester);

    for (final fake in [
      'Mrs. Maryam Abdullahi',
      'Mrs. Hauwa Sule',
      'Mr. Ibrahim Danladi',
      'Mrs. Zainab Musa',
      '₦62.8m',
      '₦59.1m',
      '₦3.7m',
      '₦150k',
      '94.1%',
      '87',
      '648',
      '+4.8% YoY',
    ]) {
      expect(find.textContaining(fake), findsNothing, reason: '"$fake" is fabricated and must never appear');
    }
    expect(find.text('Not available yet'), findsWidgets);
    expect(find.text('No leadership appointed yet.'), findsOneWidget);
  });

  testWidgets('real students on the register produce a real active-student count', (tester) async {
    // A connected backend only counts a registration once the server has confirmed it as canonical
    // (see student_assignment_repository_test.dart's identical finding) - seedRealStudent
    // deliberately never sets that flag itself, so it's set directly here.
    for (final s in [('STU-001', 'Maryam Abdullahi'), ('STU-002', 'Ibrahim Sani')]) {
      final registration = StudentRegistrationRecord(
        registrationId: 'REG-CANON-${s.$1}',
        firstName: s.$2.split(' ').first,
        surname: s.$2.split(' ').skip(1).join(' '),
        otherName: '',
        dateOfBirth: '',
        gender: '',
        academicSection: '',
        proposedClass: 'JSS 2A',
        previousSchool: '',
        address: '',
        admissionNumber: '',
        studentId: s.$1,
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
        canonicalStudentId: s.$1,
      );
      await db!.upsertLocalRecord(
        tenantId: owner.schoolId,
        entityType: AdministratorStudentsRepository.registrationEntityType,
        entityId: registration.registrationId,
        payload: registration.toJson(),
      );
    }
    LocalDatabase.blockDemoSeeds = true;

    await pump(tester);

    expect(find.text('2'), findsWidgets);
  });

  testWidgets('a real teacher on the staff file produces a real teaching-staff count', (tester) async {
    await seedRealStaff(db!, tenantId: owner.schoolId, id: 'STAFF-001', name: 'Mrs. Amina Yusuf', role: 'Teacher', section: 'Primary');
    LocalDatabase.blockDemoSeeds = true;

    await pump(tester);

    expect(find.text('1'), findsWidgets);
  });
}
