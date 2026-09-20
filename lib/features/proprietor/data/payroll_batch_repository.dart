import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../finance_office/domain/finance_payroll_models.dart';
import 'owner_payroll_repository.dart';

enum PayrollBatchStatus { prepared, approved, rejected, disbursementInstructed }

class PayrollBatch {
  const PayrollBatch({
    required this.period,
    required this.status,
    required this.lines,
    required this.total,
    required this.preparedBy,
    this.approvedBy = '',
    this.instructedBy = '',
    this.rejectionReason = '',
  });

  final String period;
  final PayrollBatchStatus status;

  /// Snapshot of who is paid what, taken when the batch was prepared.
  final List<Map<String, Object?>> lines;
  final int total;
  final String preparedBy;
  final String approvedBy;
  final String instructedBy;
  final String rejectionReason;

  factory PayrollBatch.fromPayload(Map<String, Object?> json) => PayrollBatch(
    period: json['period'] as String? ?? '',
    status: PayrollBatchStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => PayrollBatchStatus.prepared,
    ),
    lines: [
      for (final l in (json['lines'] as List? ?? const []))
        Map<String, Object?>.from(l as Map),
    ],
    total: json['total'] as int? ?? 0,
    preparedBy: json['preparedByMembershipId'] as String? ?? '',
    approvedBy: json['approvedByMembershipId'] as String? ?? '',
    instructedBy: json['instructedByMembershipId'] as String? ?? '',
    rejectionReason: json['rejectionReason'] as String? ?? '',
  );
}

/// Payroll batch workflow: prepare, approve, then instruct disbursement.
///
/// Preparing needs the prepare authority, approving needs approve authority
/// and must be done by someone other than the preparer, and instructing
/// disbursement needs pay authority on an approved batch. Instructing only
/// queues the instruction; a salary is never marked Paid here because Paid
/// needs real bank or payment evidence.
class PayrollBatchRepository {
  PayrollBatchRepository({required this.database, required this.session});

  final LocalDatabase database;
  final SchoolSessionController session;

  static const entityType = 'payroll_batch';

  static String periodFor(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<Set<String>> authorities() async {
    final member = session.requireActiveMembership();
    final authorizers = (await database.getLocalRecords(
      tenantId: member.schoolId,
      entityType: OwnerPayrollRepository.authorizerType,
    )).map(PayrollAuthorizer.fromRecord);
    return payrollAuthoritiesFor(member, authorizers);
  }

  Future<LocalRecord?> _record(SchoolMembership member, String period) =>
      database.getLocalRecord(
        tenantId: member.schoolId,
        entityType: entityType,
        entityId: period,
      );

  Future<PayrollBatch?> load(String period) async {
    final member = session.requireActiveMembership();
    if (!(await authorities()).contains('view')) {
      throw StateError('You are not authorized to view payroll.');
    }
    final record = await _record(member, period);
    return record == null ? null : PayrollBatch.fromPayload(record.payload);
  }

  Future<SchoolMembership> _require(String authority, String action) async {
    final member = session.requireActiveMembership();
    if (!(await authorities()).contains(authority)) {
      throw StateError('You are not authorized to $action.');
    }
    return member;
  }

  /// Prepares the batch for [period] from attendance-cleared rows only.
  Future<void> prepare(String period, List<FinancePayrollRow> ready) async {
    final member = await _require('prepare', 'prepare payroll batches');
    if (ready.isEmpty) {
      throw ArgumentError('There are no attendance-cleared staff to include.');
    }
    if (ready.any((r) => !r.isReady || !r.arithmeticReconciles)) {
      throw ArgumentError('Only reconciled, attendance-cleared rows can be batched.');
    }
    final existing = await _record(member, period);
    final current = existing == null
        ? null
        : PayrollBatch.fromPayload(existing.payload);
    if (current != null &&
        (current.status == PayrollBatchStatus.approved ||
            current.status == PayrollBatchStatus.disbursementInstructed)) {
      throw StateError('This batch is already approved and cannot be changed.');
    }
    await _save(member, period, existing, {
      'period': period,
      'status': PayrollBatchStatus.prepared.name,
      'lines': [
        for (final r in ready)
          {'staffId': r.staffId, 'name': r.name, 'net': r.net},
      ],
      'total': ready.fold<int>(0, (sum, r) => sum + r.net),
      'preparedByMembershipId': member.id,
      'preparedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<PayrollBatch> _existingBatch(
    SchoolMembership member,
    String period,
    PayrollBatchStatus expected,
  ) async {
    final record = await _record(member, period);
    if (record == null) throw StateError('No batch has been prepared.');
    final batch = PayrollBatch.fromPayload(record.payload);
    if (batch.status != expected) {
      throw StateError('This batch is ${batch.status.name}, not ${expected.name}.');
    }
    return batch;
  }

  Future<void> approve(String period) async {
    final member = await _require('approve', 'approve payroll batches');
    final batch = await _existingBatch(member, period, PayrollBatchStatus.prepared);
    if (batch.preparedBy == member.id) {
      throw StateError('A different person must approve a batch you prepared.');
    }
    await _transition(member, period, {
      'status': PayrollBatchStatus.approved.name,
      'approvedByMembershipId': member.id,
      'approvedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> reject(String period, String reason) async {
    final member = await _require('approve', 'reject payroll batches');
    await _existingBatch(member, period, PayrollBatchStatus.prepared);
    await _transition(member, period, {
      'status': PayrollBatchStatus.rejected.name,
      'rejectionReason': reason.trim(),
      'rejectedByMembershipId': member.id,
    });
  }

  /// Queues the instruction to pay an approved batch. It does not mark any
  /// salary as Paid.
  Future<void> instructDisbursement(String period) async {
    final member = await _require('pay', 'make payroll payments');
    await _existingBatch(member, period, PayrollBatchStatus.approved);
    await _transition(member, period, {
      'status': PayrollBatchStatus.disbursementInstructed.name,
      'instructedByMembershipId': member.id,
      'instructedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _transition(
    SchoolMembership member,
    String period,
    Map<String, Object?> changes,
  ) async {
    final existing = await _record(member, period);
    await _save(member, period, existing, {...existing!.payload, ...changes});
  }

  Future<void> _save(
    SchoolMembership member,
    String period,
    LocalRecord? existing,
    Map<String, Object?> payload,
  ) async {
    final withStamp = {
      ...payload,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await database.upsertLocalRecord(
      tenantId: member.schoolId,
      entityType: entityType,
      entityId: period,
      payload: withStamp,
      serverVersion: existing?.serverVersion,
      isDirty: true,
    );
    await database.queueMutation(
      tenantId: member.schoolId,
      membershipId: member.id,
      entityType: entityType,
      entityId: period,
      operation: existing == null ? SyncOperation.create : SyncOperation.update,
      payload: withStamp,
      baseVersion: existing?.serverVersion,
    );
  }
}
