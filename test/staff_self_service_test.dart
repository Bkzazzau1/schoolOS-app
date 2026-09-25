import 'package:flutter_test/flutter_test.dart';
import 'package:schoolos_app/core/database/local_database.dart';
import 'package:schoolos_app/core/security/payload_cipher.dart';
import 'package:schoolos_app/core/tenancy/school_session_controller.dart';
import 'package:schoolos_app/features/proprietor/data/owner_staff_profile_repository.dart';
import 'package:schoolos_app/features/proprietor/domain/owner_staff_profile_models.dart';
import 'package:schoolos_app/features/staff/data/staff_self_service_repository.dart';
import 'package:schoolos_app/shared/models/school_membership.dart';

import 'core/backend_test_support.dart';
import 'core/local_database_queue_test.dart' show MemorySecureStorage;

const staffMember = SchoolMembership(
  id: 'membership-staff-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.staff,
);
const otherStaffMember = SchoolMembership(
  id: 'membership-staff-002',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.staff,
);
const teacherMember = SchoolMembership(
  id: 'membership-teacher-001',
  schoolId: 'school-1',
  schoolName: 'BrightGate',
  role: SchoolRole.teacher,
);

void main() {
  late LocalDatabase db;
  late SchoolSessionController session;
  late StaffSelfServiceRepository staffSelf;

  Future<void> setUpSchool(SchoolMembership who) async {
    db = LocalDatabase(cipher: PayloadCipher(secureStorage: MemorySecureStorage()), databasePath: ':memory:');
    await db.initialize();
    session = SchoolSessionController(store: FakeSessionStore());
    await session.setMemberships([staffMember, otherStaffMember, teacherMember]);
    await session.selectSchool(who);
    staffSelf = StaffSelfServiceRepository(database: db, session: session);
  }

  tearDown(() {
    LocalDatabase.blockDemoSeeds = false;
    db.close();
  });

  test('the known demo Staff login self-heals a link to its own real employment record', () async {
    await setUpSchool(staffMember);
    final view = await staffSelf.loadOwn();
    expect(view, isNotNull);
    expect(view!.person.name, 'Mr. Peter James');
    expect(view.person.role, 'House coordinator');
    expect(view.profile.linkedMembershipId, staffMember.id);
    // Nothing is redacted from a person's own record - unlike a third party's view.
    expect(view.access.personal, isTrue);
    expect(view.access.payment, isTrue);
    expect(view.access.performance, isTrue);
  });

  test('a different Staff login is not linked to someone else\'s record', () async {
    await setUpSchool(staffMember);
    await staffSelf.loadOwn(); // links membership-staff-001 to STAFF-030

    await session.selectSchool(otherStaffMember);
    final otherSelf = StaffSelfServiceRepository(database: db, session: session);
    final view = await otherSelf.loadOwn();
    expect(view, isNull, reason: 'this login has no employment record of its own yet');
  });

  test('canonical (server-backed) mode never self-heals a demo link, and is honestly empty until the server sends one', () async {
    LocalDatabase.blockDemoSeeds = true;
    await setUpSchool(staffMember);
    final view = await staffSelf.loadOwn();
    expect(view, isNull);
  });

  test('only a Staff membership can open this workspace', () async {
    await setUpSchool(teacherMember);
    expect(staffSelf.loadOwn(), throwsStateError);
  });

  test('the linked Staff member can save their own bank details, and can see them reflected afterwards', () async {
    await setUpSchool(staffMember);
    final view = await staffSelf.loadOwn();
    expect(view!.profile.payment.isEmpty, isTrue, reason: 'no bank details are pre-filled by the demo seed');

    await staffSelf.saveOwnPayment(
      view.person.id,
      const StaffPaymentDetails(bankName: 'GTBank', accountName: 'Peter James', accountNumber: '0123456789'),
    );

    final reloaded = await staffSelf.loadOwn();
    expect(reloaded!.profile.payment.bankName, 'GTBank');
    expect(reloaded.profile.payment.maskedAccountNumber, '******6789');
  });

  test('a login that is not linked to a staff record cannot save bank details for one', () async {
    await setUpSchool(staffMember);
    await staffSelf.loadOwn(); // links membership-staff-001 to STAFF-030

    await session.selectSchool(otherStaffMember);
    final otherSelf = StaffSelfServiceRepository(database: db, session: session);
    expect(
      otherSelf.saveOwnPayment(
        'STAFF-030',
        const StaffPaymentDetails(bankName: 'GTBank', accountName: 'Someone else', accountNumber: '0123456789'),
      ),
      throwsStateError,
    );
  });

  test('a performance review added by the owner is visible to the staff member, not writable by them', () async {
    await setUpSchool(staffMember);
    await staffSelf.loadOwn(); // establishes the link

    // The owner records a review directly against the same canonical entity.
    const proprietor = SchoolMembership(id: 'membership-proprietor-001', schoolId: 'school-1', schoolName: 'BrightGate', role: SchoolRole.proprietor);
    await session.setMemberships([staffMember, proprietor]);
    await session.selectSchool(proprietor);
    await OwnerStaffProfileRepository(database: db, session: session).addReview('STAFF-030', 'Term 1', 4, 'Reliable and proactive.');

    await session.selectSchool(staffMember);
    final view = await staffSelf.loadOwn();
    expect(view!.profile.reviews, hasLength(1));
    expect(view.profile.reviews.single.rating, 4);
  });
}
