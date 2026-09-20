import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_documents_models.dart';
import 'parent_documents_demo_data.dart';

class ParentDocumentsRepository {
  ParentDocumentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _snapshotEntityType = 'parent_documents_snapshot';
  static const _consentEntityType = 'parent_consent_response';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentDocumentsSnapshot> load() async {
    final membership = _requireParentMembership();
    final record = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
    );

    if (record != null) {
      final snapshot = ParentDocumentsSnapshot.fromJson(record.payload);
      _validateSnapshot(snapshot);
      return snapshot;
    }

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: parentDefaultDocuments.toJson(),
    );
    return parentDefaultDocuments;
  }

  Future<ParentConsentRequest> queueConsent({
    required String requestId,
  }) async {
    final membership = _requireParentMembership();
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'Consent request id is required.');
    }

    final snapshot = await load();
    final request = snapshot.consentById(normalizedId);
    if (request == null) {
      throw StateError('This consent request is not available to the active family account.');
    }
    if (!request.actionNeeded) {
      throw StateError('This consent request no longer requires a guardian decision.');
    }
    if (request.localDecisionQueued) {
      return request;
    }

    final now = DateTime.now();
    final queued = request.copyWith(
      localDecisionQueued: true,
      queuedAt: now,
    );
    final updatedSnapshot = snapshot.replaceConsent(queued);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: updatedSnapshot.toJson(),
      isDirty: true,
    );

    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _consentEntityType,
      entityId: '${membership.id}:${request.id}',
      operation: SyncOperation.create,
      payload: {
        'requestId': request.id,
        'familyAccountId': snapshot.familyAccountId,
        'childName': request.childName,
        'decision': 'consent_given',
        'clientState': 'queued',
        'queuedAt': now.toUtc().toIso8601String(),
      },
    );

    return queued;
  }

  Future<void> replaceFromServer({
    required ParentDocumentsSnapshot snapshot,
    required int serverVersion,
  }) async {
    final membership = _requireParentMembership();
    _validateSnapshot(snapshot);

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
      payload: snapshot.toJson(),
      serverVersion: serverVersion,
      isDirty: false,
    );
  }

  void _validateSnapshot(ParentDocumentsSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Family documents are missing the family account id.');
    }

    final documentIds = <String>{};
    for (final document in snapshot.documents) {
      if (document.id.trim().isEmpty || !documentIds.add(document.id)) {
        throw StateError('Family documents contain an invalid document id.');
      }
      if (!document.approvedForGuardianVisibility) {
        throw StateError('A restricted document cannot appear in the family portal.');
      }
      if (document.ownerLabel.trim().isEmpty ||
          document.title.trim().isEmpty ||
          document.typeLabel.trim().isEmpty) {
        throw StateError('A family-visible document is missing required metadata.');
      }
    }

    final requestIds = <String>{};
    for (final request in snapshot.consentRequests) {
      if (request.id.trim().isEmpty || !requestIds.add(request.id)) {
        throw StateError('Family consent requests contain an invalid request id.');
      }
      if (request.childName.trim().isEmpty ||
          request.title.trim().isEmpty ||
          request.description.trim().isEmpty) {
        throw StateError('A consent request is missing guardian-facing information.');
      }
    }

    final historyIds = <String>{};
    for (final item in snapshot.consentHistory) {
      if (item.id.trim().isEmpty || !historyIds.add(item.id)) {
        throw StateError('Consent history contains an invalid item id.');
      }
      if (item.title.trim().isEmpty || item.subjectLabel.trim().isEmpty) {
        throw StateError('Consent history contains an incomplete record.');
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family documents require an active Parent membership.');
    }
    return membership;
  }
}
