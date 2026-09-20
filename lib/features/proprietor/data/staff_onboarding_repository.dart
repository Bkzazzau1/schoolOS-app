import '../../../core/database/local_database.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/owner_staff_profile_models.dart';
import 'owner_staff_profile_repository.dart';
import 'staff_identity.dart';

/// The registration form a new staff member fills in after the owner approves
/// them and they receive their invitation.
///
/// Only the login linked to the staff record (set when their account is
/// activated from the invitation) can use this, and only while an onboarding
/// request is open. It can change nothing but the person's own details, bank
/// details and which documents they have provided, so reviews, credentials
/// and salary stay untouched.
class StaffOnboardingRepository {
  StaffOnboardingRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  Future<LocalRecord?> _ownRecord() async {
    final member = session.requireActiveMembership();
    final records = await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
    );
    for (final r in records) {
      if ((r.payload['linkedMembershipId'] as String? ?? '') == member.id) {
        return r;
      }
    }
    return null;
  }

  /// The signed-in person's profile if an onboarding request is waiting for
  /// them, otherwise null.
  Future<StaffProfile?> openRequest() async {
    final record = await _ownRecord();
    if (record == null) return null;
    final profile = StaffProfile.fromJson(record.payload);
    return profile.onboardingStatus == StaffOnboardingStatus.invitePending
        ? profile
        : null;
  }

  Future<void> submit({
    required StaffPersonalInfo personal,
    required StaffPaymentDetails payment,

    /// Required document name -> where or how it was provided. A document with
    /// a note is marked received; files themselves are not stored by the app.
    Map<String, String> documents = const {},
  }) async {
    final member = session.requireActiveMembership();
    final record = await _ownRecord();
    final profile = record == null ? null : StaffProfile.fromJson(record.payload);
    if (record == null ||
        profile == null ||
        profile.onboardingStatus != StaffOnboardingStatus.invitePending) {
      throw StateError('There is no open registration request for you.');
    }

    final phone = normalizeNigerianPhone(personal.phone);
    if (phone == null) {
      throw ArgumentError('Enter a valid Nigerian phone number, for example 0803 123 4567.');
    }
    final nin = normalizeNin(personal.nin);
    if (nin == null) throw ArgumentError('A NIN is exactly 11 digits.');
    final email = personal.email.trim();
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw ArgumentError('Enter a valid email address.');
    }
    final kinPhone = normalizeNigerianPhone(personal.nextOfKinPhone);
    if (personal.address.trim().isEmpty ||
        personal.dateOfBirth.trim().isEmpty ||
        DateTime.tryParse(personal.dateOfBirth.trim()) == null ||
        personal.nextOfKinName.trim().isEmpty ||
        kinPhone == null) {
      throw ArgumentError(
        'Enter your address, date of birth (yyyy-mm-dd) and your next of kin with a valid phone number.',
      );
    }
    if (payment.bankName.trim().isEmpty ||
        payment.accountName.trim().isEmpty ||
        !RegExp(r'^\d{10}$').hasMatch(payment.accountNumber.trim())) {
      throw ArgumentError(
        'Enter your bank, the account name and a 10-digit account number.',
      );
    }
    final matches = await findStaffIdentityMatches(
      database,
      member.schoolId,
      phone: phone,
      nin: nin,
      excludeStaffId: record.entityId,
    );
    if (matches.isNotEmpty) {
      throw DuplicateIdentityError(
        '${matches.map((m) => m.message).toSet().join(' ')} If this is you, contact the school office.',
      );
    }

    final updated = profile.copyWith(
      personal: StaffPersonalInfo(
        phone: phone,
        nin: nin,
        email: email,
        address: personal.address.trim(),
        dateOfBirth: personal.dateOfBirth.trim(),
        gender: personal.gender.trim(),
        stateOfOrigin: personal.stateOfOrigin.trim(),
        nextOfKinName: personal.nextOfKinName.trim(),
        nextOfKinPhone: kinPhone,
        // Employment terms are set by the school, not the new staff member.
        employmentDate: profile.personal.employmentDate,
        employmentType: profile.personal.employmentType,
      ),
      payment: StaffPaymentDetails(
        bankName: payment.bankName.trim(),
        accountName: payment.accountName.trim(),
        accountNumber: payment.accountNumber.trim(),
      ),
      documents: [
        for (final d in profile.documents)
          if ((documents[d.name] ?? '').trim().isNotEmpty &&
              d.status == StaffDocumentStatus.requested)
            d.copyWith(
              status: StaffDocumentStatus.received,
              reference: documents[d.name]!.trim(),
            )
          else
            d,
      ],
      onboardingStatus: StaffOnboardingStatus.submitted,
    );
    final payload = {
      ...updated.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedByMembershipId': member.id,
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: record.entityId,
      payload: payload,
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: OwnerStaffProfileRepository.entityType,
      entityId: record.entityId,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: record.serverVersion,
    );
  }
}
