import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/administrator/data/administrator_staff_repository.dart';
import 'package:schoolos_app/features/administrator/data/administrator_students_repository.dart';
import 'package:schoolos_app/features/administrator/domain/administrator_staff_models.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/data/payroll_batch_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/teacher/data/teacher_profile_repository.dart';
import 'package:schoolos_app/features/teacher/data/teacher_roster.dart';
import 'package:schoolos_app/features/teacher/domain/teacher_profile_models.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const teacher = SchoolMembership(
  id: 'membership-teacher-1',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.teacher,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late TeacherProfileRepository repository;

  setUp(() async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([teacher]);
    await session.selectSchool(teacher);
    final roster = TeacherRoster(
      database: db,
      session: session,
      students: AdministratorStudentsRepository(localDatabase: db, schoolSession: session),
    );
    repository = TeacherProfileRepository(localDatabase: db, schoolSession: session, roster: roster);
  });

  tearDown(() => db.close());

  Future<void> linkStaffProfile() async {
    await db.upsertLocalRecord(
      tenantId: teacher.schoolId,
      entityType: AdministratorStaffRepository.directoryEntityType,
      entityId: 'STF-01',
      payload: const AdministratorStaffRecord(
        id: 'STF-01',
        name: 'Amina Yusuf',
        role: 'Mathematics Teacher',
        section: 'Mathematics',
        fileStatus: AdministratorStaffFileStatus.complete,
      ).toJson(),
      isDirty: false,
    );
    final profile = StaffProfile(
      staffId: 'STF-01',
      linkedMembershipId: teacher.id,
      personal: const StaffPersonalInfo(
        employmentType: 'Full-time',
        employmentDate: '2022-01-15',
      ),
      academics: const [
        StaffAcademicRecord(level: 'B.Ed', institution: 'Ahmadu Bello University', course: 'Mathematics', year: 2018, grade: 'First Class'),
      ],
      documents: const [
        StaffRequiredDocument(name: 'Appointment letter', status: StaffDocumentStatus.verified),
      ],
      payment: const StaffPaymentDetails(bankName: 'Test Bank', accountNumber: '0123456789'),
    );
    await db.upsertLocalRecord(
      tenantId: teacher.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: 'STF-01',
      payload: profile.toJson(),
      isDirty: false,
    );
  }

  test('a teacher with no linked staff record sees an honestly blank profile, never a placeholder person', () async {
    final snapshot = await repository.load();
    expect(snapshot.profile.hasLinkedStaffRecord, isFalse);
    expect(snapshot.profile.displayName, 'Teacher');
    expect(snapshot.profile.staffId, isEmpty);
    expect(snapshot.profile.qualifications, isEmpty);
    expect(snapshot.profile.documents, isEmpty);
    expect(snapshot.profile.payslips, isEmpty);
    expect(snapshot.profile.profileCompleteness, 0);
  });

  test('a real linked staff profile supplies real identity, qualifications, documents and completeness', () async {
    await linkStaffProfile();
    final snapshot = await repository.load();
    final profile = snapshot.profile;

    expect(profile.hasLinkedStaffRecord, isTrue);
    expect(profile.displayName, 'Amina Yusuf');
    expect(profile.department, 'Mathematics');
    expect(profile.jobTitle, 'Mathematics Teacher');
    expect(profile.employmentType, 'Full-time');
    expect(profile.hireDate, '2022-01-15');
    expect(profile.bank, 'Test Bank');
    expect(profile.qualifications, hasLength(1));
    expect(profile.qualifications.single.$1, contains('Mathematics'));
    expect(profile.documents, hasLength(1));
    expect(profile.documents.single.$2, 'Verified');
    // The only real document is verified, so completeness is honestly 100%.
    expect(profile.profileCompleteness, 100);
  });

  test('a real prepared payroll batch becomes a real net-only payslip for this teacher, never an itemized one', () async {
    await linkStaffProfile();
    await db.upsertLocalRecord(
      tenantId: teacher.schoolId,
      entityType: PayrollBatchRepository.entityType,
      entityId: '2026-08',
      payload: {
        'period': '2026-08',
        'status': 'disbursementInstructed',
        'lines': [
          {'staffId': 'STF-01', 'name': 'Amina Yusuf', 'net': 194000},
          {'staffId': 'STF-02', 'name': 'Someone Else', 'net': 150000},
        ],
        'total': 344000,
        'preparedByMembershipId': 'membership-admin-1',
      },
      isDirty: false,
    );

    final snapshot = await repository.load();
    final payslip = snapshot.profile.payslips.single;
    expect(payslip.period, '2026-08');
    expect(payslip.net, 194000, reason: 'only this teacher\'s own line, not the other staff member\'s');
    expect(payslip.status, 'Disbursement instructed');
    expect(snapshot.profile.netMonthly, 194000);
    expect(snapshot.profile.timeline, isNotEmpty);
  });

  test('a batch still only prepared (not disbursed) never appears in the real staff timeline', () async {
    await linkStaffProfile();
    await db.upsertLocalRecord(
      tenantId: teacher.schoolId,
      entityType: PayrollBatchRepository.entityType,
      entityId: '2026-09',
      payload: {
        'period': '2026-09',
        'status': 'prepared',
        'lines': [
          {'staffId': 'STF-01', 'name': 'Amina Yusuf', 'net': 194000},
        ],
        'total': 194000,
        'preparedByMembershipId': 'membership-admin-1',
      },
      isDirty: false,
    );

    final snapshot = await repository.load();
    expect(snapshot.profile.payslips.single.status, 'Prepared');
    expect(
      snapshot.profile.timeline.any((row) => row.$2 == 'Payroll disbursement instructed'),
      isFalse,
      reason: 'disbursement was never instructed for this batch',
    );
  });

  test('saveContact requires every field and queues a real mutation', () async {
    final rejected = await repository.saveContact(
      const TeacherProfileContact(phone: '', email: '', address: '', nextOfKin: '', emergencyPhone: ''),
    );
    expect(rejected.success, isFalse);

    final saved = await repository.saveContact(
      const TeacherProfileContact(
        phone: '+234 800 000 0000',
        email: 'amina@example.edu',
        address: 'Kaduna',
        nextOfKin: 'A. Yusuf',
        emergencyPhone: '+234 800 000 0101',
      ),
    );
    expect(saved.success, isTrue, reason: saved.message);
    final reloaded = await repository.load();
    expect(reloaded.profile.contact.email, 'amina@example.edu');
    expect(reloaded.profile.contact.pendingSync, isTrue);
  });
}
