import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../domain/finance_concessions_models.dart';
import 'finance_concessions_demo_data.dart';

class FinanceConcessionActionResult {
  const FinanceConcessionActionResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class FinanceConcessionsRepository {
  FinanceConcessionsRepository({
    required LocalDatabase localDatabase,
    required SchoolSessionController schoolSession,
  })  : _localDatabase = localDatabase,
        _schoolSession = schoolSession;

  // Shared with the Proprietor concession approval queue. A Finance request
  // must be visible to the Proprietor offline before any server sync occurs.
  static const entityType = 'concession_request';

  final LocalDatabase _localDatabase;
  final SchoolSessionController _schoolSession;

  Future<FinanceConcessionsSnapshot> load() async {
    final membership = _schoolSession.requireActiveMembership();
    var records = await _localDatabase.getLocalRecords(
      tenantId: membership.schoolId,
      entityType: entityType,
    );

    if (records.isEmpty) {
      for (final request in financeConcessionSeed) {
        await _localDatabase.upsertLocalRecord(
          tenantId: membership.schoolId,
          entityType: entityType,
          entityId: request.id,
          payload: request.toJson(),
        );
      }
      records = await _localDatabase.getLocalRecords(
        tenantId: membership.schoolId,
        entityType: entityType,
      );
    }

    final requests = records
        .map((record) => FinanceConcessionRequest.fromJson(record.payload))
        .toList(growable: false)
      ..sort((a, b) => b.id.compareTo(a.id));

    return FinanceConcessionsSnapshot(
      requests: requests,
      canSubmit: membership.role == SchoolRole.accountant,
      canApprove: membership.role == SchoolRole.proprietor,
    );
  }

  Future<FinanceConcessionActionResult> submit({
    required String student,
    required String className,
    required FinanceConcessionType type,
    required int grossFee,
    required int amount,
    required String reason,
    required String requestedBy,
  }) async {
    final membership = _schoolSession.requireActiveMembership();
    if (membership.role != SchoolRole.accountant) {
      return const FinanceConcessionActionResult(
        success: false,
        message: 'Only an active Finance Officer membership can submit from this workspace.',
      );
    }

    final normalizedStudent = student.trim();
    final normalizedClass = className.trim();
    final normalizedRequester = requestedBy.trim();
    if (normalizedStudent.isEmpty || normalizedClass.isEmpty || normalizedRequester.isEmpty) {
      return const FinanceConcessionActionResult(
        success: false,
        message: 'Student, class and requester name are required.',
      );
    }
    if (grossFee < 0 || amount < 0) {
      return const FinanceConcessionActionResult(
        success: false,
        message: 'Fee and concession amounts cannot be negative.',
      );
    }
    if (amount > grossFee) {
      return const FinanceConcessionActionResult(
        success: false,
        message: 'Concession amount cannot exceed the gross term fee.',
      );
    }

    final existing = await load();
    final nextNumber = existing.requests.length + 41;
    final id = 'CNC-2026-${nextNumber.toString().padLeft(3, '0')}';
    final now = DateTime.now();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final requestedAt =
        '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
    final request = FinanceConcessionRequest(
      id: id,
      student: normalizedStudent,
      className: normalizedClass,
      type: type,
      grossFee: grossFee,
      amount: amount,
      reason: reason.trim().isEmpty
          ? '${financeConcessionTypeLabel(type)} request'
          : reason.trim(),
      requestedBy: normalizedRequester,
      requestedByRole: 'Finance Office',
      requestedAt: requestedAt,
      status: FinanceConcessionStatus.pendingApproval,
    );

    await _localDatabase.upsertLocalRecord(
      tenantId: membership.schoolId,
      entityType: entityType,
      entityId: request.id,
      payload: request.toJson(),
      isDirty: true,
    );
    await _localDatabase.queueMutation(
      tenantId: membership.schoolId,
      membershipId: membership.id,
      entityType: entityType,
      entityId: request.id,
      operation: SyncOperation.create,
      payload: request.toJson(),
    );

    return FinanceConcessionActionResult(
      success: true,
      message:
          'Request sent to the Proprietor for approval. ${request.student} will see this concession only after it is approved.',
    );
  }
}
