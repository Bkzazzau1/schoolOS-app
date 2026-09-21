import '../../../core/database/local_database.dart';
import '../../../core/identity/identity_normalizer.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/administrator_admissions_models.dart';
import 'administrator_admissions_demo_data.dart';

class AdministratorAdmissionsSnapshot {
  const AdministratorAdmissionsSnapshot({
    required this.applicants,
    required this.permissions,
  });

  final List<AdmissionApplicant> applicants;
  final AdmissionPermissions permissions;
}

class AdministratorAdmissionsActionResult {
  const AdministratorAdmissionsActionResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class AdministratorAdmissionsRepository {
  AdministratorAdmissionsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const entityType = 'admission_applicant';
  static const _entityType = entityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  AdmissionPermissions permissionsFor(SchoolMembership membership) {
    return AdmissionPermissions(
      canManagePipeline: membership.role == SchoolRole.administrator,
    );
  }

  Future<AdministratorAdmissionsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _entityType,
    );

    if (records.isEmpty) {
      for (final applicant in administratorAdmissionsWebsiteSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: _entityType,
          entityId: applicant.reference,
          payload: applicant.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: _entityType,
      );
    }

    final applicants = records
        .map((record) => AdmissionApplicant.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.reference.compareTo(a.reference));

    return AdministratorAdmissionsSnapshot(
      applicants: applicants,
      permissions: permissionsFor(membership),
    );
  }

  Future<AdministratorAdmissionsActionResult> requestDocument(
    String reference,
  ) async {
    return _updateApplicant(
      reference,
      transform: (current) => current.copyWith(documentRequestQueued: true),
      successMessage: 'Document follow-up queued offline and waiting for sync.',
    );
  }

  Future<AdministratorAdmissionsActionResult> scheduleScreening(
    String reference,
  ) async {
    return _updateApplicant(
      reference,
      validate: (current) {
        if (current.stage.index > AdmissionStage.screening.index) {
          return 'This applicant is already beyond the Screening stage. The pipeline will not be moved backward.';
        }
        final pending = pendingDocuments(current);
        if (pending.isNotEmpty) {
          return 'Documents are still pending (${pending.join(', ')}). Receive them before screening.';
        }
        return null;
      },
      transform: (current) => current.copyWith(stage: AdmissionStage.screening),
      successMessage: 'Screening stage saved offline and queued for sync.',
    );
  }

  Future<AdministratorAdmissionsActionResult> issueOffer(
    String reference,
  ) async {
    return _updateApplicant(
      reference,
      validate: (current) {
        if (current.stage.index > AdmissionStage.offer.index) {
          return 'This applicant is already beyond the Offer stage. The pipeline will not be moved backward.';
        }
        if (current.stage.index < AdmissionStage.screening.index) {
          return 'Screening comes before an offer.';
        }
        return null;
      },
      transform: (current) => current.copyWith(stage: AdmissionStage.offer),
      successMessage: 'Offer stage saved offline and queued for sync.',
    );
  }

  Future<AdministratorAdmissionsActionResult> _updateApplicant(
    String reference, {
    required AdmissionApplicant Function(AdmissionApplicant current) transform,
    required String successMessage,
    String? Function(AdmissionApplicant current)? validate,
    bool allowClosed = false,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManagePipeline) {
      return const AdministratorAdmissionsActionResult(
        success: false,
        message: 'This membership cannot manage the admissions pipeline.',
      );
    }

    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: reference,
    );
    if (record == null) {
      return const AdministratorAdmissionsActionResult(
        success: false,
        message: 'Applicant record was not found for this school.',
      );
    }

    final current = AdmissionApplicant.fromJson(record.payload);
    if (current.isClosed && !allowClosed) {
      return AdministratorAdmissionsActionResult(success: false, message: 'This application is closed: ${current.closedReason}');
    }
    final validationMessage = validate?.call(current);
    if (validationMessage != null) {
      return AdministratorAdmissionsActionResult(
        success: false,
        message: validationMessage,
      );
    }

    final updated = transform(current);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: updated.reference,
      payload: updated.toJson(),
      serverVersion: record.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: updated.reference,
      operation: SyncOperation.update,
      payload: updated.toJson(),
      baseVersion: record.serverVersion,
    );

    return AdministratorAdmissionsActionResult(
      success: true,
      message: successMessage,
    );
  }

  static const documents = ['Birth certificate', 'Previous school report', 'Guardian ID'];
  static const sections = ['Nursery', 'Primary', 'Secondary'];

  AdmissionDocumentStatus _statusOf(AdmissionApplicant a, String document) => switch (document) {
        'Birth certificate' => a.birthCertificate,
        'Previous school report' => a.previousSchoolReport,
        _ => a.guardianId,
      };

  /// The documents an applicant has not handed in yet.
  static List<String> pendingDocuments(AdmissionApplicant a) => [
        if (a.birthCertificate == AdmissionDocumentStatus.pending) 'Birth certificate',
        if (a.previousSchoolReport == AdmissionDocumentStatus.pending) 'Previous school report',
        if (a.guardianId == AdmissionDocumentStatus.pending) 'Guardian ID',
      ];

  /// Records a new application taken at the school (a walk-in or a phone call). Online applications arrive on their own.
  Future<AdministratorAdmissionsActionResult> addApplicant({
    required String name,
    required String section,
    required String className,
    required String guardian,
    required String phone,
    String source = 'Walk-in',
    DateTime? now,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (!permissionsFor(membership).canManagePipeline) {
      return const AdministratorAdmissionsActionResult(success: false, message: 'This membership cannot manage the admissions pipeline.');
    }
    if (name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).length < 2) {
      return const AdministratorAdmissionsActionResult(success: false, message: "Enter the child's first name and surname.");
    }
    if (!sections.contains(section) || className.trim().isEmpty) {
      return const AdministratorAdmissionsActionResult(success: false, message: 'Choose the section and say which class the child is applying for.');
    }
    if (guardian.trim().isEmpty) {
      return const AdministratorAdmissionsActionResult(success: false, message: "Enter the guardian's name.");
    }
    final normalized = normalizeNigerianPhone(phone);
    if (normalized == null) {
      return const AdministratorAdmissionsActionResult(
        success: false,
        message: 'Enter a valid Nigerian phone number for the guardian, for example 0803 123 4567.',
      );
    }

    final existing = (await load()).applicants;
    final duplicate = existing.any(
      (a) =>
          !a.isClosed &&
          a.stage != AdmissionStage.registered &&
          a.name.trim().toLowerCase() == name.trim().toLowerCase() &&
          normalizeNigerianPhone(a.phone) == normalized,
    );
    if (duplicate) {
      return AdministratorAdmissionsActionResult(success: false, message: '${name.trim()} already has an open application from this guardian.');
    }

    var highest = 26000;
    for (final a in existing) {
      final digits = int.tryParse(a.reference.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (digits > highest) highest = digits;
    }
    final reference = 'BGA-ADM-${highest + 1}';
    final at = now ?? DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final applicant = AdmissionApplicant(
      reference: reference,
      name: name.trim(),
      section: section,
      className: className.trim(),
      guardian: guardian.trim(),
      phone: normalized,
      stage: AdmissionStage.newApplication,
      submitted: '${at.day} ${months[at.month - 1]}',
      source: source,
      birthCertificate: AdmissionDocumentStatus.pending,
      previousSchoolReport: AdmissionDocumentStatus.pending,
      guardianId: AdmissionDocumentStatus.pending,
    );
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _entityType,
      entityId: reference,
      payload: applicant.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _entityType,
      entityId: reference,
      operation: SyncOperation.create,
      payload: applicant.toJson(),
    );
    return AdministratorAdmissionsActionResult(success: true, message: '${applicant.name} added as $reference.');
  }

  /// A document has been handed in. The first one moves a new application into document collection.
  Future<AdministratorAdmissionsActionResult> markDocumentReceived(String reference, String document) async {
    if (!documents.contains(document)) {
      return const AdministratorAdmissionsActionResult(success: false, message: 'That is not one of the application documents.');
    }
    return _updateApplicant(
      reference,
      validate: (current) {
        if (_statusOf(current, document) == AdmissionDocumentStatus.received) return '$document is already received.';
        return null;
      },
      transform: (current) {
        final updated = current.copyWith(
          birthCertificate: document == 'Birth certificate' ? AdmissionDocumentStatus.received : null,
          previousSchoolReport: document == 'Previous school report' ? AdmissionDocumentStatus.received : null,
          guardianId: document == 'Guardian ID' ? AdmissionDocumentStatus.received : null,
        );
        final complete = pendingDocuments(updated).isEmpty;
        return updated.copyWith(
          stage: current.stage == AdmissionStage.newApplication ? AdmissionStage.documents : null,
          documentRequestQueued: complete ? false : null,
        );
      },
      successMessage: '$document received.',
    );
  }

  /// The guardian has accepted the offer.
  Future<AdministratorAdmissionsActionResult> acceptOffer(String reference) => _updateApplicant(
        reference,
        validate: (current) {
          if (current.stage == AdmissionStage.accepted || current.stage == AdmissionStage.registered) {
            return 'This offer has already been accepted.';
          }
          if (current.stage != AdmissionStage.offer) return 'An offer has to be issued before it can be accepted.';
          return null;
        },
        transform: (current) => current.copyWith(stage: AdmissionStage.accepted),
        successMessage: 'Offer accepted. Ready for registration.',
      );

  /// Closes an application that will not go ahead (declined, withdrawn, no place). The record is kept with the reason.
  Future<AdministratorAdmissionsActionResult> close(String reference, String reason) {
    if (reason.trim().isEmpty) {
      return Future.value(const AdministratorAdmissionsActionResult(success: false, message: 'Say why the application is closed.'));
    }
    return _updateApplicant(
      reference,
      validate: (current) => current.stage == AdmissionStage.registered ? 'A registered student cannot be closed as an applicant.' : null,
      transform: (current) => current.copyWith(closedReason: reason.trim()),
      successMessage: 'Application closed.',
    );
  }

  /// Registration finished: the applicant is now a registered student.
  Future<void> markRegistered(String reference) async {
    await _updateApplicant(
      reference,
      transform: (current) => current.copyWith(stage: AdmissionStage.registered),
      successMessage: 'Registered.',
      allowClosed: true,
    );
  }
}
