import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../finance_office/data/finance_ledger_repository.dart';
import '../../finance_office/domain/finance_ledger_models.dart';
import '../domain/parent_documents_models.dart';
import 'parent_children_repository.dart';

class ParentDocumentsRepository {
  ParentDocumentsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
    required ParentChildrenRepository children,
    required FinanceLedgerRepository ledger,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession,
        _children = children,
        _ledger = ledger;

  static const _consentEntityType = 'parent_consent_response';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;
  final ParentChildrenRepository _children;
  final FinanceLedgerRepository _ledger;

  /// A family's real payment receipts — read from the same real ledger Finance Office and Parent
  /// Finance already use — become this family's real documents.
  ///
  /// `consentRequests` and `consentHistory` stay honestly empty: no real report-card/PDF generation
  /// system exists anywhere in the app, and no real per-student excursion-consent request exists
  /// either (the real Excursions module only tracks a whole-trip aggregate consent count, e.g.
  /// "38 of 42 consents received", never which specific student still needs to respond — the same
  /// aggregate-only limitation School Life's Activities section already documents). [queueConsent]
  /// stays implemented and correct below for the same reason `AwardRepository.addDraft` was kept: it
  /// is real, validated logic that would work the moment a real per-student consent-request source
  /// exists, not something to delete just because nothing currently feeds it.
  Future<ParentDocumentsSnapshot> load() async {
    final membership = _requireParentMembership();
    final linked = (await _children.load()).children;
    final accounts = await _ledger.accounts();

    final documents = <ParentFamilyDocument>[];
    for (final child in linked) {
      StudentAccount? account;
      for (final candidate in accounts) {
        if (candidate.student.id == child.id) {
          account = candidate;
          break;
        }
      }
      if (account == null) continue;
      for (final payment in account.payments) {
        if (payment.isVoided) continue;
        documents.add(ParentFamilyDocument(
          id: 'DOC-${payment.id}',
          ownerLabel: child.name,
          title: 'Payment receipt ${payment.receiptNumber}',
          typeLabel: 'Finance',
          status: ParentDocumentStatus.ready,
        ));
      }
    }
    documents.sort((a, b) => a.id.compareTo(b.id));

    return ParentDocumentsSnapshot(
      familyAccountId: membership.id,
      documents: documents,
      consentRequests: const [],
      consentHistory: const [],
    );
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
    final queued = request.copyWith(localDecisionQueued: true, queuedAt: now);

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

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family documents require an active Parent membership.');
    }
    return membership;
  }
}
