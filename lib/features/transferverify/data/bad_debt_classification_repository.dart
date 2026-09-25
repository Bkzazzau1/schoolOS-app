import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/data/administrator_students_repository.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../domain/bad_debt_classification_models.dart';

/// Mirrors apps.transferverify.services.BAD_DEBT_ENTITY on the backend
/// exactly - one canonical entity type every classify/update/advanceStatus/
/// resolve/publish/withdrawPublication action is pushed through.
const badDebtClassificationEntityType = 'transferverify_bad_debt_classification';

/// Mirrors apps.owner.jobs.access.JOB - read here only, never written; a
/// Proprietor gives this duty through the existing Owner Jobs screen.
const _jobAssignmentEntityType = 'owner_job_assignment';

/// Mirrors apps.transferverify.services.CLASSIFY_DUTY.
const badDebtClassifyDuty = 'finance.bad_debt_classification';

class BadDebtClassificationRepository {
  BadDebtClassificationRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const entityType = badDebtClassificationEntityType;

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  /// The real, canonically-identified students this school has - reused
  /// rather than duplicated, since a classification must key on the same
  /// Student.id the backend does (see the model's own docstring on why
  /// Finance/Concessions' weak name-matching identity must not repeat here).
  Future<List<AdministratorStudentRecord>> students() async {
    final snapshot = await AdministratorStudentsRepository(
      localDatabase: _localDatabase,
      schoolSession: _schoolSession,
    ).load();
    return snapshot.students;
  }

  Future<bool> _hasDuty(SchoolMembership membership, String duty) async {
    final records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _jobAssignmentEntityType,
    );
    return records.any((record) {
      final payload = record.payload;
      final duties = payload['duties'];
      return payload['status'] == 'active' &&
          payload['membershipId'] == membership.id &&
          duties is List &&
          duties.contains(duty);
    });
  }

  Future<BadDebtClassificationPermissions> _permissionsFor(SchoolMembership membership) async {
    final owner = membership.role == SchoolRole.proprietor;
    final canClassify = owner || await _hasDuty(membership, badDebtClassifyDuty);
    return BadDebtClassificationPermissions(canClassify: canClassify, canPublish: owner);
  }

  Future<BadDebtClassificationSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    final records = await _localDatabase.getLocalRecords(tenantId: membership.schoolId, entityType: entityType);
    final items = records
        .map((record) => BadDebtClassification.fromJson(record.payload).copyWith(pendingSync: record.isDirty))
        .toList()
      ..sort((a, b) => b.classifiedAt.compareTo(a.classifiedAt));
    final permissions = await _permissionsFor(membership);
    return BadDebtClassificationSnapshot(items: items, permissions: permissions, canonical: LocalDatabase.blockDemoSeeds);
  }

  Future<BadDebtClassificationActionResult> classify({
    required String studentId,
    required String studentName,
    required int outstandingAmountMinor,
    required String classifiedByName,
    String reason = '',
    String notes = '',
    String evidenceReference = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = await _permissionsFor(membership);
    if (!permissions.canClassify) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'Only the owner, or someone the owner has specifically authorized, can classify a bad debt.',
      );
    }
    if (studentId.trim().isEmpty) {
      return const BadDebtClassificationActionResult(success: false, message: 'Choose a student.');
    }
    if (outstandingAmountMinor <= 0) {
      return const BadDebtClassificationActionResult(success: false, message: 'Enter an outstanding amount above zero.');
    }
    if (classifiedByName.trim().isEmpty) {
      return const BadDebtClassificationActionResult(success: false, message: 'Enter your name.');
    }
    final existing = await load();
    final alreadyOpen = existing.items.any((item) => item.studentId == studentId && item.isOpen);
    if (alreadyOpen) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'This student already has an open bad debt classification. Resolve it before opening another.',
      );
    }

    final id = 'BDC-${DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final item = BadDebtClassification(
      id: id,
      studentId: studentId,
      studentName: studentName,
      status: BadDebtStatus.outstanding,
      outstandingAmountMinor: outstandingAmountMinor,
      reason: reason.trim(),
      notes: notes.trim(),
      evidenceReference: evidenceReference.trim(),
      classifiedByMembershipId: membership.id,
      classifiedByName: classifiedByName.trim(),
      classifiedAt: DateTime.now().toUtc(),
    );
    await _persist(membership, item, SyncOperation.create, {...item.toJson(), 'action': 'classify'});
    return BadDebtClassificationActionResult(
      success: true,
      message: 'Classification saved locally and queued for synchronization.',
      item: item,
    );
  }

  Future<BadDebtClassificationActionResult> update(
    BadDebtClassification item, {
    int? outstandingAmountMinor,
    String? reason,
    String? notes,
    String? evidenceReference,
  }) async {
    final guarded = await _guardedEdit(item);
    if (guarded != null) return guarded;
    final membership = _schoolSession.requireActiveMembership();
    final updated = item.copyWith(
      outstandingAmountMinor: outstandingAmountMinor,
      reason: reason,
      notes: notes,
      evidenceReference: evidenceReference,
      lastUpdatedByMembershipId: membership.id,
    );
    await _persist(membership, updated, SyncOperation.update, {
      'id': updated.id,
      'action': 'update',
      'outstandingAmountMinor': updated.outstandingAmountMinor,
      'reason': updated.reason,
      'notes': updated.notes,
      'evidenceReference': updated.evidenceReference,
    });
    return BadDebtClassificationActionResult(success: true, message: 'Changes saved and queued.', item: updated);
  }

  Future<BadDebtClassificationActionResult> advanceStatus(BadDebtClassification item, BadDebtStatus status) async {
    if (status != BadDebtStatus.recoveryInProgress && status != BadDebtStatus.badDebt) {
      return const BadDebtClassificationActionResult(success: false, message: 'That is not a status this action can move to.');
    }
    final guarded = await _guardedEdit(item);
    if (guarded != null) return guarded;
    const order = [BadDebtStatus.outstanding, BadDebtStatus.recoveryInProgress, BadDebtStatus.badDebt];
    if (order.indexOf(status) <= order.indexOf(item.status)) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'A classification can only move forward, never back to an earlier status.',
      );
    }
    final membership = _schoolSession.requireActiveMembership();
    final updated = item.copyWith(status: status, lastUpdatedByMembershipId: membership.id);
    await _persist(membership, updated, SyncOperation.update, {'id': updated.id, 'action': 'advanceStatus', 'status': status.toJson()});
    return BadDebtClassificationActionResult(success: true, message: 'Status updated and queued.', item: updated);
  }

  Future<BadDebtClassificationActionResult> resolve(BadDebtClassification item, {String note = ''}) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = await _permissionsFor(membership);
    if (!permissions.canClassify) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'Only the owner, or someone the owner has specifically authorized, can resolve a bad debt.',
      );
    }
    if (item.status == BadDebtStatus.resolved) {
      return BadDebtClassificationActionResult(success: true, message: 'Already resolved.', item: item);
    }
    final updated = item.copyWith(
      status: BadDebtStatus.resolved,
      resolvedByMembershipId: membership.id,
      resolvedAt: DateTime.now().toUtc(),
      resolutionNote: note.trim(),
      lastUpdatedByMembershipId: membership.id,
    );
    await _persist(membership, updated, SyncOperation.update, {'id': updated.id, 'action': 'resolve', 'note': note.trim()});
    return BadDebtClassificationActionResult(success: true, message: 'Marked resolved. It stays on record, never deleted.', item: updated);
  }

  /// The one action that makes a school's private classification eligible
  /// for TransferVerify to eventually surface to other schools - owner-only,
  /// never delegable, matching apps.transferverify.services exactly.
  Future<BadDebtClassificationActionResult> publish(
    BadDebtClassification item, {
    required TransferVerifyPublicationReason reason,
    String note = '',
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = await _permissionsFor(membership);
    if (!permissions.canPublish) {
      return const BadDebtClassificationActionResult(success: false, message: 'Only the owner can publish a case to TransferVerify.');
    }
    if (item.status != BadDebtStatus.badDebt) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'Only a case classified as bad debt can be published to TransferVerify.',
      );
    }
    if (item.publishedToTransferVerify) {
      return const BadDebtClassificationActionResult(success: false, message: 'This case has already been published to TransferVerify.');
    }
    final updated = item.copyWith(
      publishedToTransferVerify: true,
      publishedByMembershipId: membership.id,
      publishedAt: DateTime.now().toUtc(),
      publicationReason: reason,
      publicationNote: note.trim(),
    );
    await _persist(membership, updated, SyncOperation.update, {
      'id': updated.id,
      'action': 'publish',
      'reason': reason.toJson(),
      'note': note.trim(),
    });
    return BadDebtClassificationActionResult(
      success: true,
      message: 'Publication to TransferVerify queued. It becomes discoverable only once an association scope exists to choose from.',
      item: updated,
    );
  }

  Future<BadDebtClassificationActionResult> withdrawPublication(BadDebtClassification item) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = await _permissionsFor(membership);
    if (!permissions.canPublish) {
      return const BadDebtClassificationActionResult(success: false, message: 'Only the owner can publish a case to TransferVerify.');
    }
    if (!item.publishedToTransferVerify) {
      return const BadDebtClassificationActionResult(success: false, message: 'This case has not been published to TransferVerify.');
    }
    final updated = item.copyWith(clearPublication: true);
    await _persist(membership, updated, SyncOperation.update, {'id': updated.id, 'action': 'withdrawPublication'});
    return BadDebtClassificationActionResult(success: true, message: 'Publication withdrawn and queued.', item: updated);
  }

  Future<BadDebtClassificationActionResult?> _guardedEdit(BadDebtClassification item) async {
    final membership = _schoolSession.requireActiveMembership();
    final permissions = await _permissionsFor(membership);
    if (!permissions.canClassify) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'Only the owner, or someone the owner has specifically authorized, can edit a bad debt classification.',
      );
    }
    if (item.status == BadDebtStatus.resolved) {
      return const BadDebtClassificationActionResult(success: false, message: 'This classification is resolved and cannot be edited.');
    }
    if (item.publishedToTransferVerify) {
      return const BadDebtClassificationActionResult(
        success: false,
        message: 'This case has been published to TransferVerify. Withdraw the publication before editing it.',
      );
    }
    return null;
  }

  Future<void> _persist(
    SchoolMembership membership,
    BadDebtClassification item,
    SyncOperation operation,
    Map<String, Object?> mutationPayload,
  ) async {
    final existing = await _localDatabase.getLocalRecord(tenantId: membership.schoolId, entityType: entityType, entityId: item.id);
    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: item.id,
      payload: item.toJson(),
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: entityType,
      entityId: item.id,
      operation: operation,
      payload: mutationPayload,
      baseVersion: existing?.serverVersion,
    );
  }
}
