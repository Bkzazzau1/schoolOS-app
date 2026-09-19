import '../../../core/database/local_database.dart';
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

  static const _entityType = 'admission_applicant';

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
}
