import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_staff_attendance_repository.dart';
import '../../administrator/data/administrator_staff_repository.dart';
import '../../administrator/domain/administrator_staff_attendance_models.dart';
import '../../administrator/domain/administrator_staff_models.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../domain/owner_staff_profile_models.dart';
import 'staff_identity.dart';

/// Which parts of a staff record a role may see and change.
///
/// The owner and the principal have the same full access, including viewing
/// bank details, and both edit. Bank details themselves can be changed only by
/// the staff member. The administrator sees the HR file (personal
/// details, academics, credentials, documents) and attendance, but not bank
/// details or performance, and may send onboarding requests. Access is
/// school-wide because members are not yet linked to a section.
class StaffProfileAccess {
  const StaffProfileAccess({
    this.personal = false,
    this.academics = false,
    this.credentials = false,
    this.payment = false,
    this.performance = false,
    this.attendance = false,
    this.canEdit = false,
    this.canReview = false,
    this.canInvite = false,
  });

  final bool personal;
  final bool academics;
  final bool credentials;
  final bool payment;
  final bool performance;
  final bool attendance;
  final bool canEdit;
  final bool canReview;

  /// May send a new staff member their onboarding request.
  final bool canInvite;

  bool get any =>
      personal || academics || credentials || payment || performance || attendance;
}

StaffProfileAccess staffProfileAccessFor(SchoolRole role) => switch (role) {
  SchoolRole.proprietor => const StaffProfileAccess(
    personal: true, academics: true, credentials: true, payment: true,
    performance: true, attendance: true,
    canEdit: true, canReview: true, canInvite: true,
  ),
  SchoolRole.principal => const StaffProfileAccess(
    personal: true, academics: true, credentials: true, payment: true,
    performance: true, attendance: true,
    canEdit: true, canReview: true, canInvite: true,
  ),
  SchoolRole.administrator => const StaffProfileAccess(
    personal: true, academics: true, credentials: true, attendance: true,
    canInvite: true,
  ),
  _ => const StaffProfileAccess(),
};

/// A phone number or NIN that already belongs to someone else.
class DuplicateIdentityError implements Exception {
  DuplicateIdentityError(this.message, {this.matches = const []});
  final String message;

  /// The specific matches this came from, so a caller can offer "appoint
  /// this same person to a new role" when every match is a confirmable one
  /// (see StaffIdentityMatch.isApprovedStaffMember) rather than only showing an
  /// error. Empty wherever that offer would never make sense.
  final List<StaffIdentityMatch> matches;

  @override
  String toString() => message;
}

class StaffProfileView {
  const StaffProfileView({
    required this.person,
    required this.profile,
    required this.attendance,
    this.access = const StaffProfileAccess(canEdit: true, canReview: true, canInvite: true),
  });

  final StaffProfileAccess access;

  final AdministratorStaffRecord person;
  final StaffProfile profile;

  /// Null when no attendance has been recorded for this person.
  final StaffAttendanceRecord? attendance;

  /// Verified present days over expected days, as a percentage.
  double? get attendanceRate {
    final a = attendance;
    if (a == null || a.expected == 0) return null;
    return a.present / a.expected * 100;
  }
}

/// Owner-only full staff records: personal details, academic records,
/// credentials and performance reviews.
class OwnerStaffProfileRepository {
  OwnerStaffProfileRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const entityType = 'owner_staff_profile';

  SchoolMembership _viewer() {
    final member = session.requireActiveMembership();
    if (!staffProfileAccessFor(member.role).any) {
      throw StateError('You do not have access to staff profiles.');
    }
    return member;
  }

  SchoolMembership _reviewer() {
    final member = session.requireActiveMembership();
    if (!staffProfileAccessFor(member.role).canReview) {
      throw StateError('You are not allowed to add performance reviews.');
    }
    return member;
  }

  SchoolMembership _inviter() {
    final member = session.requireActiveMembership();
    if (!staffProfileAccessFor(member.role).canInvite) {
      throw StateError('You are not allowed to send onboarding requests.');
    }
    return member;
  }

  SchoolMembership _owner() {
    final member = session.requireActiveMembership();
    if (!staffProfileAccessFor(member.role).canEdit) {
      throw StateError('Only the owner or principal can edit staff profiles.');
    }
    return member;
  }

  Future<List<AdministratorStaffRecord>> people() async {
    _viewer();
    return (await AdministratorStaffRepository(
      localDatabase: database,
      schoolSession: session,
    ).load()).staff;
  }

  /// Loads a person's record with everything the viewer may not see removed,
  /// so screens cannot leak it.
  Future<StaffProfileView> view(AdministratorStaffRecord person) async {
    final viewer = _viewer();
    final access = staffProfileAccessFor(viewer.role);
    final record = await database.getLocalRecord(
      tenantId: viewer.schoolId,
      entityType: entityType,
      entityId: person.id,
    );
    final attendance = access.attendance
        ? (await AdministratorStaffAttendanceRepository(
            localDatabase: database,
            schoolSession: session,
          ).load()).records.where((r) => r.id == person.id).firstOrNull
        : null;
    final full = record == null
        ? StaffProfile(staffId: person.id)
        : StaffProfile.fromJson(record.payload);
    return StaffProfileView(
      person: person,
      access: access,
      attendance: attendance,
      profile: StaffProfile(
        staffId: full.staffId,
        personal: access.personal ? full.personal : const StaffPersonalInfo(),
        academics: access.academics ? full.academics : const [],
        credentials: access.credentials ? full.credentials : const [],
        reviews: access.performance ? full.reviews : const [],
        payment: access.payment ? full.payment : const StaffPaymentDetails(),
        documents: access.credentials ? full.documents : const [],
        onboardingStatus: full.onboardingStatus,
        onboardingEmail: access.personal ? full.onboardingEmail : '',
        systemRole: full.systemRole,
      ),
    );
  }

  /// Saves personal details. Phone and NIN are stored normalized and must not
  /// belong to any other staff member or pending proposal.
  Future<void> savePersonal(
    String staffId,
    StaffPersonalInfo info, {
    String? excludeProposalId,
  }) async {
    final owner = _owner();
    final email = info.email.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw ArgumentError('Enter a valid email address.');
    }
    String? phone;
    if (info.phone.trim().isNotEmpty) {
      phone = normalizeNigerianPhone(info.phone);
      if (phone == null) {
        throw ArgumentError('Enter a valid Nigerian phone number, for example 0803 123 4567.');
      }
    }
    String? nin;
    if (info.nin.trim().isNotEmpty) {
      nin = normalizeNin(info.nin);
      if (nin == null) throw ArgumentError('A NIN is exactly 11 digits.');
    }
    final matches = await findStaffIdentityMatches(
      database,
      owner.schoolId,
      phone: phone,
      nin: nin,
      excludeStaffId: staffId,
      excludeProposalId: excludeProposalId,
    );
    if (matches.isNotEmpty) {
      throw DuplicateIdentityError(matches.map((m) => m.message).toSet().join(' '), matches: matches);
    }
    final clean = info.copyWith(phone: phone ?? '', nin: nin ?? '');
    await _update(staffId, (p) => p.copyWith(personal: clean));
  }

  /// Bank details can only be changed by the staff member themselves, from
  /// their own linked login. The owner, principal and administrator can view
  /// them (where their role allows) but no one else can edit them.
  Future<void> saveOwnPayment(
    String staffId,
    StaffPaymentDetails details,
  ) async {
    final member = session.requireActiveMembership();
    final existing = await database.getLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: staffId,
    );
    final linked = existing?.payload['linkedMembershipId'] as String? ?? '';
    if (existing == null || linked.isEmpty || linked != member.id) {
      throw StateError(
        'Only the staff member can change their own bank details.',
      );
    }
    if (details.bankName.trim().isEmpty ||
        details.accountName.trim().isEmpty ||
        !RegExp(r'^\d{10}$').hasMatch(details.accountNumber.trim())) {
      throw ArgumentError(
        'Enter the bank, the account name and a 10-digit account number.',
      );
    }
    final payload = {
      ...existing.payload,
      'payment': StaffPaymentDetails(
        bankName: details.bankName.trim(),
        accountName: details.accountName.trim(),
        accountNumber: details.accountNumber.trim(),
      ).toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedByMembershipId': member.id,
    };
    await _persist(member, staffId, existing, payload);
  }

  /// Sets where a required document is kept and whether it has been received
  /// or verified.
  Future<void> updateDocument(
    String staffId,
    int index,
    StaffDocumentStatus status,
    String reference,
  ) => _update(staffId, (p) {
    final list = [...p.documents];
    list[index] = list[index].copyWith(
      status: status,
      reference: reference.trim(),
    );
    return p.copyWith(documents: list);
  });

  Future<void> addDocument(String staffId, String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Enter the document name.');
    }
    return _update(
      staffId,
      (p) => p.copyWith(
        documents: [...p.documents, StaffRequiredDocument(name: name.trim())],
      ),
    );
  }

  /// Queues an onboarding request asking the staff member to fill in their
  /// details and provide the required documents. Delivery of the email is done
  /// by the school backend once connected; this app does not send it.
  Future<void> requestOnboarding(String staffId, String email) async {
    final inviter = _inviter();
    final address = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address)) {
      throw ArgumentError('Enter a valid email address for the staff member.');
    }
    await _update(staffId, actor: inviter, (p) {
      final have = {for (final d in p.documents) d.name};
      return p.copyWith(
        onboardingEmail: address,
        onboardingStatus: StaffOnboardingStatus.invitePending,
        documents: [
          ...p.documents,
          for (final name in defaultRequiredDocuments)
            if (!have.contains(name)) StaffRequiredDocument(name: name),
        ],
      );
    });
  }

  Future<void> markOnboardingReviewed(String staffId) => _update(
    staffId,
    (p) => p.copyWith(onboardingStatus: StaffOnboardingStatus.reviewed),
  );

  Future<void> addAcademic(String staffId, StaffAcademicRecord record) {
    if (studyLevelRank(record.level) < 0 ||
        record.institution.trim().isEmpty ||
        record.course.trim().isEmpty ||
        record.year < 1950 ||
        record.year > DateTime.now().year) {
      throw ArgumentError(
        'Choose a level and enter the institution, course and a valid year.',
      );
    }
    return _update(
      staffId,
      (p) => p.copyWith(academics: [...p.academics, record]),
    );
  }

  Future<void> removeAcademic(String staffId, int index) => _update(
    staffId,
    (p) => p.copyWith(academics: [...p.academics]..removeAt(index)),
  );

  Future<void> addCredential(String staffId, StaffCredential credential) {
    if (credential.title.trim().isEmpty || credential.issuer.trim().isEmpty) {
      throw ArgumentError('Enter the credential title and who issued it.');
    }
    if (credential.expiry.isNotEmpty &&
        DateTime.tryParse(credential.expiry) == null) {
      throw ArgumentError('Enter the expiry date as yyyy-mm-dd.');
    }
    return _update(
      staffId,
      (p) => p.copyWith(credentials: [...p.credentials, credential]),
    );
  }

  Future<void> setCredentialVerified(
    String staffId,
    int index,
    bool verified,
  ) => _update(staffId, (p) {
    final list = [...p.credentials];
    list[index] = list[index].copyWith(verified: verified);
    return p.copyWith(credentials: list);
  });

  Future<void> removeCredential(String staffId, int index) => _update(
    staffId,
    (p) => p.copyWith(credentials: [...p.credentials]..removeAt(index)),
  );

  /// Reviews are append-only so past performance history is never rewritten.
  Future<void> addReview(
    String staffId,
    String period,
    int rating,
    String notes,
  ) async {
    if (period.trim().isEmpty || rating < 1 || rating > 5) {
      throw ArgumentError('Enter the review period and a rating from 1 to 5.');
    }
    final reviewer = _reviewer();
    await _update(
      staffId,
      actor: reviewer,
      (p) => p.copyWith(
        reviews: [
          ...p.reviews,
          StaffPerformanceReview(
            period: period.trim(),
            rating: rating,
            notes: notes.trim(),
            at: DateTime.now().toUtc().toIso8601String(),
            reviewerRole: reviewer.role.name,
            reviewerMembershipId: reviewer.id,
          ),
        ],
      ),
    );
  }

  Future<void> _update(
    String staffId,
    StaffProfile Function(StaffProfile current) change, {
    SchoolMembership? actor,
  }) async {
    final owner = actor ?? _owner();
    if (!(await people()).any((p) => p.id == staffId)) {
      throw ArgumentError('Choose a person in this school directory.');
    }
    final existing = await database.getLocalRecord(
      tenantId: owner.schoolId,
      entityType: entityType,
      entityId: staffId,
    );
    final current = existing == null
        ? StaffProfile(staffId: staffId)
        : StaffProfile.fromJson(existing.payload);
    final changed = change(current);
    if (changed.payment.toJson().toString() != current.payment.toJson().toString()) {
      throw StateError(
        'Only the staff member can change their own bank details.',
      );
    }
    final payload = {
      ...changed.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedByMembershipId': owner.id,
    };
    await _persist(owner, staffId, existing, payload);
  }

  Future<void> _persist(
    SchoolMembership member,
    String staffId,
    LocalRecord? existing,
    Map<String, Object?> payload,
  ) async {
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: staffId,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: staffId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }
}
