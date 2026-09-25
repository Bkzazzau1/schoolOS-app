import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_attendance_repository.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_attendance_models.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../proprietor/data/owner_staff_profile_repository.dart';
import '../../proprietor/domain/owner_staff_profile_models.dart';

/// Which real, standalone-demo login is known to belong to which seeded
/// staff record - the same idea as TeacherRoster's own `_demoAssignments`,
/// just for the one-to-one Staff-login-to-HR-record link that a connected
/// school sets when an invitation is accepted. A server-backed school never
/// reads this map: `linkedMembershipId` arrives from the server instead.
const _demoSelfLink = <String, String>{'membership-staff-001': 'STAFF-030'};

/// The signed-in Staff member's own employment record, found the same way
/// StaffOnboardingRepository already finds it during registration: by
/// matching this membership's id against the owner_staff_profile record
/// whose `linkedMembershipId` names them. Everything returned here is that
/// person's own data, so unlike OwnerStaffProfileRepository's role-based
/// StaffProfileAccess (built for a third party looking at someone else's
/// file), nothing here is redacted - a person can always see their own
/// details. Editing stays exactly as narrow as it already is: only
/// OwnerStaffProfileRepository.saveOwnPayment (bank details) accepts writes
/// from a login that merely matches `linkedMembershipId`.
class StaffSelfServiceRepository {
  StaffSelfServiceRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const _access = StaffProfileAccess(
    personal: true,
    academics: true,
    credentials: true,
    payment: true,
    performance: true,
    attendance: true,
  );

  SchoolMembership _member() {
    final member = session.requireActiveMembership();
    if (member.role != SchoolRole.staff) {
      throw StateError('This workspace belongs to the signed-in Staff member.');
    }
    return member;
  }

  /// Null when this login has not yet been linked to an employment record -
  /// true before an onboarding invitation has ever been accepted. Once
  /// linked, the link is permanent, the same as every other role's identity
  /// link (Teacher's teacher_class_assignment, Student's student_class_link).
  Future<StaffProfileView?> loadOwn() async {
    final member = _member();
    var record = await _findLinkedRecord(member);
    if (record == null && !LocalDatabase.blockDemoSeeds) {
      record = await _seedDemoSelfIfKnown(member);
    }
    if (record == null) return null;

    final directory =
        (await AdministratorStaffRepository(localDatabase: database, schoolSession: session).load()).staff;
    AdministratorStaffRecord? person;
    for (final candidate in directory) {
      if (candidate.id == record.entityId) {
        person = candidate;
        break;
      }
    }
    if (person == null) return null;

    final attendanceRecords = (await AdministratorStaffAttendanceRepository(
      localDatabase: database,
      schoolSession: session,
    ).load()).records;
    StaffAttendanceRecord? attendance;
    for (final candidate in attendanceRecords) {
      if (candidate.id == person.id) {
        attendance = candidate;
        break;
      }
    }

    return StaffProfileView(
      person: person,
      profile: StaffProfile.fromJson(record.payload),
      attendance: attendance,
      access: _access,
    );
  }

  /// Delegates to the same self-only bank-details write everyone else's
  /// login uses; that method already checks `linkedMembershipId` itself, so
  /// no extra authority check belongs here.
  Future<void> saveOwnPayment(String staffId, StaffPaymentDetails details) =>
      OwnerStaffProfileRepository(database: database, session: session).saveOwnPayment(staffId, details);

  Future<LocalRecord?> _findLinkedRecord(SchoolMembership member) async {
    final records = await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );
    for (final record in records) {
      if ((record.payload['linkedMembershipId'] as String? ?? '') == member.id) {
        return record;
      }
    }
    return null;
  }

  Future<LocalRecord?> _seedDemoSelfIfKnown(SchoolMembership member) async {
    final staffId = _demoSelfLink[member.id];
    if (staffId == null) return null;
    // Ensures STAFF-030 itself exists in the directory before linking to it.
    await AdministratorStaffRepository(localDatabase: database, schoolSession: session).load();

    final existing = await database.getLocalRecord(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: staffId,
    );
    if (existing != null && existing.payload['linkedMembershipId'] == member.id) {
      return existing;
    }

    final seeded = StaffProfile(
      staffId: staffId,
      systemRole: 'staff',
      linkedMembershipId: member.id,
      personal: const StaffPersonalInfo(
        employmentDate: '2023-01-16',
        employmentType: 'Full-time',
      ),
      credentials: const [
        StaffCredential(
          title: 'First Aid Certificate',
          issuer: 'Nigerian Red Cross',
          expiry: '2027-03-01',
          verified: true,
        ),
      ],
      documents: [for (final name in defaultRequiredDocuments) StaffRequiredDocument(name: name)],
    );
    final payload = {
      ...seeded.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: staffId,
      payload: payload,
    );
    return database.getLocalRecord(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: staffId,
    );
  }
}
