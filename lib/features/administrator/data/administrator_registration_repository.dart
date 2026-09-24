import '../../../core/database/local_database.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_admissions_models.dart';
import '../domain/administrator_registration_models.dart';
import 'administrator_admissions_repository.dart';
import 'administrator_registration_demo_data.dart';

class AdministratorRegistrationSnapshot {
  const AdministratorRegistrationSnapshot({
    required this.record,
    required this.permissions,
  });

  final StudentRegistrationRecord record;
  final RegistrationPermissions permissions;
}

class AdministratorRegistrationActionResult {
  const AdministratorRegistrationActionResult({
    required this.success,
    required this.message,
    this.record,
  });

  final bool success;
  final String message;
  final StudentRegistrationRecord? record;
}

class AdministratorRegistrationRepository {
  AdministratorRegistrationRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _entityType = 'student_registration';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  SchoolMembership get activeMembership =>
      _schoolSession.requireActiveMembership();

  RegistrationPermissions permissionsFor(SchoolMembership membership) {
    return RegistrationPermissions(
      canRegisterStudent: membership.role == SchoolRole.administrator,
    );
  }

  Future<AdministratorRegistrationSnapshot> load({
    AdmissionApplicant? sourceApplicant,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final seed = sourceApplicant != null
        ? _fromApplicant(sourceApplicant)
        : LocalDatabase.blockDemoSeeds
            ? _newLiveDraft()
            : administratorRegistrationWebsiteSeed;

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: seed.registrationId,
    );

    if (existing == null) {
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _entityType,
        entityId: seed.registrationId,
        payload: seed.toJson(),
      );
    }

    final stored = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: seed.registrationId,
    );

    return AdministratorRegistrationSnapshot(
      record: stored == null
          ? seed
          : StudentRegistrationRecord.fromJson(stored.payload),
      permissions: permissionsFor(membership),
    );
  }

  Future<AdministratorRegistrationActionResult> saveDraft(
    StudentRegistrationRecord record,
  ) async {
    return _save(
      record.copyWith(status: StudentRegistrationStatus.inProgress),
      completed: false,
    );
  }

  Future<AdministratorRegistrationActionResult> completeRegistration(
    StudentRegistrationRecord record,
  ) async {
    return _save(
      record.copyWith(status: StudentRegistrationStatus.active),
      completed: true,
    );
  }

  Future<AdministratorRegistrationActionResult> _save(
    StudentRegistrationRecord record, {
    required bool completed,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canRegisterStudent) {
      return const AdministratorRegistrationActionResult(
        success: false,
        message:
            'This membership cannot create or complete student registrations.',
      );
    }

    final applicantReference = record.sourceApplicantReference;
    if (completed && applicantReference != null && applicantReference.isNotEmpty) {
      final applicantRecord = await _localDatabase.getLocalRecord(
        tenantId: membership.schoolId,
        entityType: AdministratorAdmissionsRepository.entityType,
        entityId: applicantReference,
      );
      if (applicantRecord != null) {
        final applicant = AdmissionApplicant.fromJson(applicantRecord.payload);
        if (applicant.isClosed) {
          return AdministratorRegistrationActionResult(
            success: false,
            message:
                '${applicant.name}\'s application is closed: ${applicant.closedReason}',
          );
        }
        if (applicant.stage.index < AdmissionStage.accepted.index) {
          return AdministratorRegistrationActionResult(
            success: false,
            message:
                'The offer to ${applicant.name} has not been accepted yet. Accept it in Admissions before completing registration.',
          );
        }
      }
    }

    if (record.firstName.trim().isEmpty || record.surname.trim().isEmpty) {
      return const AdministratorRegistrationActionResult(
        success: false,
        message: 'First name and surname are required.',
      );
    }
    if (record.primaryGuardian.trim().isEmpty ||
        record.guardianPhone.trim().isEmpty) {
      return const AdministratorRegistrationActionResult(
        success: false,
        message: 'Primary guardian and guardian phone are required.',
      );
    }
    if (record.academicSection.trim().isEmpty ||
        record.proposedClass.trim().isEmpty) {
      return const AdministratorRegistrationActionResult(
        success: false,
        message: 'Academic section and proposed class are required.',
      );
    }

    final phone = normalizeNigerianPhone(record.guardianPhone);
    if (phone == null) {
      return const AdministratorRegistrationActionResult(
        success: false,
        message:
            'Enter a valid Nigerian phone number for the guardian, for example 0803 123 4567.',
      );
    }
    final others = (await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    )).where((r) => r.entityId != record.registrationId);
    StudentRegistrationRecord? sibling;
    for (final other in others) {
      final candidate = StudentRegistrationRecord.fromJson(other.payload);
      if (normalizeNigerianPhone(candidate.guardianPhone) != phone) continue;
      if (normalizeName(candidate.primaryGuardian) !=
          normalizeName(record.primaryGuardian)) {
        return AdministratorRegistrationActionResult(
          success: false,
          message:
              'This phone number already belongs to guardian ${candidate.primaryGuardian} (child ${candidate.fullName}). A phone number identifies one parent. Use the same guardian name to register a sibling, or correct the number.',
        );
      }
      sibling ??= candidate;
    }

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: record.registrationId,
    );
    final acceptedDraft = existing?.serverVersion != null
        ? StudentRegistrationRecord.fromJson(existing!.payload)
        : null;
    final admissionNumber = acceptedDraft != null &&
            acceptedDraft.admissionNumber.trim().isNotEmpty
        ? acceptedDraft.admissionNumber
        : admissionNumberForSection(record.academicSection)
            .replaceFirst(RegExp(r'\d{3,8}$'), _serialFor(record));

    final normalized = record.copyWith(
      guardianPhone: phone,
      admissionNumber: admissionNumber,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: normalized.registrationId,
      payload: normalized.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: normalized.registrationId,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: normalized.toJson(),
      baseVersion: existing?.serverVersion,
    );

    if (completed && applicantReference != null && applicantReference.isNotEmpty) {
      await AdministratorAdmissionsRepository(
        localDatabase: _localDatabase,
        schoolSession: _schoolSession,
      ).markRegistered(applicantReference);
    }

    return AdministratorRegistrationActionResult(
      success: true,
      message: (completed
              ? 'Registration completion saved offline and queued for sync. The student becomes canonical Active and billable only after the SchoolOS server accepts this change.'
              : 'Registration draft saved offline and queued for sync.') +
          (sibling == null
              ? ''
              : ' This guardian phone is already registered for ${sibling.fullName}, so this child is a sibling in the same family. Link the family account accordingly.'),
      record: normalized,
    );
  }

  StudentRegistrationRecord _newLiveDraft() {
    final now = DateTime.now();
    final stamp = now.microsecondsSinceEpoch.toString();
    final serial = stamp.substring(stamp.length - 6);
    final studentSuffix = stamp.substring(stamp.length - 10);
    final year = (now.year % 100).toString().padLeft(2, '0');
    return administratorRegistrationWebsiteSeed.copyWith(
      registrationId: 'REG-$stamp',
      firstName: '',
      surname: '',
      otherName: '',
      dateOfBirth: '',
      previousSchool: '',
      address: '',
      admissionNumber: 'BGA/KD/PRI/$year/$serial',
      studentId: 'STU-$studentSuffix',
      primaryGuardian: '',
      guardianPhone: '',
      guardianEmail: '',
      familyAccount: 'Create new family account',
      siblingLink: 'No existing sibling',
      status: StudentRegistrationStatus.inProgress,
    );
  }

  StudentRegistrationRecord _fromApplicant(AdmissionApplicant applicant) {
    final names = applicant.name.trim().split(RegExp(r'\s+'));
    final firstName = names.isEmpty ? '' : names.first;
    final surname = names.length > 1 ? names.last : '';
    final otherName = names.length > 2
        ? names.sublist(1, names.length - 1).join(' ')
        : '';
    final serial = _digitsFromReference(applicant.reference);
    final code = switch (applicant.section) {
      'Primary' => 'PRI',
      'Secondary' => 'SEC',
      _ => 'EYR',
    };
    final year = (DateTime.now().year % 100).toString().padLeft(2, '0');

    return administratorRegistrationWebsiteSeed.copyWith(
      registrationId: 'REG-${applicant.reference}',
      firstName: firstName,
      surname: surname,
      otherName: otherName,
      academicSection: applicant.section == 'Nursery'
          ? 'Early Years'
          : applicant.section,
      proposedClass: applicant.className,
      admissionNumber: 'BGA/KD/$code/$year/$serial',
      studentId: 'STU-$serial',
      primaryGuardian: applicant.guardian,
      guardianPhone: applicant.phone,
      guardianEmail: '',
      previousSchool: '',
      address: '',
      sourceApplicantReference: applicant.reference,
      status: StudentRegistrationStatus.inProgress,
    );
  }

  String _serialFor(StudentRegistrationRecord record) {
    final reference = record.sourceApplicantReference;
    if (reference != null && reference.isNotEmpty) {
      return _digitsFromReference(reference);
    }
    final match = RegExp(r'(\d{3,8})$').firstMatch(record.admissionNumber);
    return match?.group(1) ?? _digitsFromReference(record.registrationId);
  }

  String _digitsFromReference(String reference) {
    final digits = reference.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    return digits.padLeft(6, '0');
  }
}
