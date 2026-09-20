import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/parent_finance_models.dart';
import 'parent_finance_demo_data.dart';

class ParentFinanceRepository {
  ParentFinanceRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  static const _snapshotEntityType = 'parent_finance_snapshot';
  static const _mandateEntityType = 'parent_finance_mandate_preference';
  static const _paymentRequestEntityType = 'parent_finance_combined_payment_request';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<ParentFinanceViewData> load() async {
    final membership = _requireParentMembership();
    final snapshotRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _snapshotEntityType,
      entityId: membership.id,
    );

    ParentFinanceSnapshot snapshot;
    if (snapshotRecord == null) {
      snapshot = parentDefaultFinance;
      _validateSnapshot(snapshot);
      await _localDatabase.upsertLocalRecord(
        tenantId: membership.schoolId,
        entityType: _snapshotEntityType,
        entityId: membership.id,
        payload: snapshot.toJson(),
      );
    } else {
      snapshot = ParentFinanceSnapshot.fromJson(snapshotRecord.payload);
      _validateSnapshot(snapshot);
    }

    final mandateRecord = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
    );
    if (mandateRecord != null) {
      final preference = ParentPaymentMandatePreference.fromJson(
        Map<String, dynamic>.from(
          mandateRecord.payload['preference'] as Map? ?? const <String, dynamic>{},
        ),
      );
      snapshot = snapshot.copyWith(mandate: preference);
    }

    final requestRecords = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: _paymentRequestEntityType,
    );
    final requests = <ParentCombinedPaymentRequest>[];
    for (final record in requestRecords) {
      final request = ParentCombinedPaymentRequest.fromJson(record.payload);
      if (request.membershipId == membership.id) {
        requests.add(request);
      }
    }
    requests.sort((a, b) => b.queuedAt.compareTo(a.queuedAt));

    return ParentFinanceViewData(
      snapshot: snapshot,
      pendingCombinedRequests: requests,
      mandateQueued: mandateRecord?.isDirty ?? false,
    );
  }

  Future<void> replaceFromServer({
    required ParentFinanceSnapshot snapshot,
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

  Future<String> saveMandatePreference(
    ParentPaymentMandatePreference preference,
  ) async {
    final membership = _requireParentMembership();
    _validateMandate(preference);

    final existing = await _localDatabase.getLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
    );
    final payload = <String, Object?>{
      'membershipId': membership.id,
      'schoolId': membership.schoolId,
      'preference': preference.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'state': 'queued',
    };

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _mandateEntityType,
      entityId: membership.id,
      payload: payload,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );

    return _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _mandateEntityType,
      entityId: membership.id,
      operation: SyncOperation.update,
      payload: payload,
      baseVersion: existing?.serverVersion,
    );
  }

  Future<ParentCombinedPaymentRequest> queueCombinedPayment({
    required List<ParentCombinedPaymentAllocation> allocations,
  }) async {
    final membership = _requireParentMembership();
    final view = await load();
    _validateCombinedPayment(view.snapshot, allocations);

    final now = DateTime.now().toUtc();
    final requestId = _newFamilyPaymentReference(now);
    final request = ParentCombinedPaymentRequest(
      id: requestId,
      membershipId: membership.id,
      familyAccountId: view.snapshot.familyAccountId,
      allocations: List.unmodifiable(allocations),
      queuedAt: now,
    );
    final entityId = '${membership.id}:$requestId';

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: _paymentRequestEntityType,
      entityId: entityId,
      payload: request.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: _paymentRequestEntityType,
      entityId: entityId,
      operation: SyncOperation.create,
      payload: request.toJson(),
    );

    return request;
  }

  void _validateSnapshot(ParentFinanceSnapshot snapshot) {
    if (snapshot.familyAccountId.trim().isEmpty) {
      throw StateError('Finance snapshot is missing its family account id.');
    }
    if (snapshot.academicPeriod.trim().isEmpty) {
      throw StateError('Finance snapshot is missing its academic period.');
    }

    final childIds = <String>{};
    final accounts = <String>{};
    for (final child in snapshot.children) {
      if (child.id.trim().isEmpty || !childIds.add(child.id)) {
        throw StateError('Finance snapshot contains an invalid child id.');
      }
      if (child.accountNumber.trim().isEmpty || !accounts.add(child.accountNumber)) {
        throw StateError('Each linked child must have a unique term account.');
      }
      if (child.grossFees < 0 ||
          child.discountAmount < 0 ||
          child.paidAmount < 0 ||
          child.balance < 0 ||
          child.discountAmount > child.grossFees) {
        throw StateError('Finance snapshot contains an invalid monetary value.');
      }
      if (child.netFees != child.paidAmount + child.balance) {
        throw StateError(
          'A child finance account does not reconcile paid and outstanding amounts.',
        );
      }
    }

    for (final entry in snapshot.ledger) {
      if (!childIds.contains(entry.childId) || entry.amount <= 0) {
        throw StateError('Payment history contains an invalid family ledger entry.');
      }
    }
    for (final receipt in snapshot.receipts) {
      if (!childIds.contains(receipt.childId) || receipt.amount <= 0) {
        throw StateError('Receipt history contains an invalid family receipt.');
      }
    }
    for (final reminder in snapshot.reminders) {
      if (!childIds.contains(reminder.childId) ||
          reminder.balance < 0 ||
          reminder.nextAmount < 0) {
        throw StateError('Fee reminder data is invalid for this family account.');
      }
    }

    _validateMandate(snapshot.mandate);
  }

  void _validateMandate(ParentPaymentMandatePreference preference) {
    const allowedDays = {'5th', '10th', '15th', '20th', '25th', '28th'};
    if (preference.monthlyAmount < 0) {
      throw ArgumentError.value(
        preference.monthlyAmount,
        'monthlyAmount',
        'Monthly amount cannot be negative.',
      );
    }
    if (!allowedDays.contains(preference.debitDay)) {
      throw ArgumentError.value(
        preference.debitDay,
        'debitDay',
        'Unsupported preferred debit day.',
      );
    }
    if (preference.collectionMethod.trim().isEmpty) {
      throw ArgumentError.value(
        preference.collectionMethod,
        'collectionMethod',
        'Collection method is required.',
      );
    }
  }

  void _validateCombinedPayment(
    ParentFinanceSnapshot snapshot,
    List<ParentCombinedPaymentAllocation> allocations,
  ) {
    if (allocations.length < 2) {
      throw StateError('Select at least two children for a combined payment.');
    }

    final children = {for (final child in snapshot.children) child.id: child};
    final selectedIds = <String>{};
    for (final allocation in allocations) {
      final child = children[allocation.childId];
      if (child == null || !selectedIds.add(allocation.childId)) {
        throw StateError(
          'Combined payment contains a child that is not uniquely linked to this guardian.',
        );
      }
      if (allocation.accountNumber != child.accountNumber) {
        throw StateError('Combined payment account does not match the linked child.');
      }
      if (allocation.amount <= 0 || allocation.amount > child.balance) {
        throw StateError(
          'Combined payment amount must be positive and cannot exceed the confirmed outstanding balance.',
        );
      }
    }
  }

  SchoolMembership _requireParentMembership() {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.parent) {
      throw StateError('Family finance requires an active Parent membership.');
    }
    return membership;
  }
}

String _newFamilyPaymentReference(DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${now.year.toString().substring(2)}${two(now.month)}${two(now.day)}';
  final suffix = (now.microsecondsSinceEpoch % 1000000).toString().padLeft(6, '0');
  return 'FAM-$date-$suffix';
}
