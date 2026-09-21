import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/concession_request.dart';
import '../domain/proprietor_finance_models.dart';
import 'concession_repository.dart';
import 'owner_payroll_repository.dart';
import 'payroll_batch_repository.dart';

/// What the owner's finance page can say from real records: scholarships and discounts, and payroll.
/// (Fees billed, collections, store and aging need the Finance role's data and are not here yet.)
class OwnerFinanceOverview {
  const OwnerFinanceOverview({required this.kpis, required this.attention, required this.decidedRecently});

  final List<OwnerFinanceKpi> kpis;
  final List<OwnerFinanceListItem> attention;

  /// The last few concession decisions, newest first.
  final List<OwnerFinanceListItem> decidedRecently;
}

OwnerFinanceOverview buildFinanceOverview({
  required List<ConcessionRequest> concessions,
  required PayrollSnapshot payroll,
  required List<PayrollBatch> batches,
}) {
  final approved = concessions.where((c) => c.status == ConcessionStatus.approved).toList();
  final pending = concessions.where((c) => c.status == ConcessionStatus.pendingApproval).toList();
  final approvedTotal = approved.fold<int>(0, (sum, c) => sum + c.amount);
  final pendingTotal = pending.fold<int>(0, (sum, c) => sum + c.amount);
  final onPayroll = payroll.onPayroll.length;
  final waiting = batches.where((b) => b.status == PayrollBatchStatus.prepared).toList();

  final kpis = [
    OwnerFinanceKpi(
      label: 'Scholarships & discounts',
      value: formatNaira(approvedTotal),
      note: '${approved.length} approved',
    ),
    OwnerFinanceKpi(
      label: 'Awaiting your decision',
      value: '${pending.length}',
      note: pending.isEmpty ? 'Nothing waiting' : '${formatNaira(pendingTotal)} requested',
    ),
    OwnerFinanceKpi(
      label: 'Monthly payroll (net)',
      value: onPayroll == 0 ? 'Not set up' : formatNaira(payroll.totalNet),
      note: onPayroll == 0 ? 'No salaries recorded yet' : '$onPayroll people · gross ${formatNaira(payroll.totalGross)}',
    ),
    OwnerFinanceKpi(
      label: 'Payroll batches',
      value: '${batches.length}',
      note: waiting.isEmpty ? 'None waiting for approval' : '${waiting.length} waiting for approval',
    ),
  ];

  final attention = [
    for (final c in pending)
      OwnerFinanceListItem(
        title: '${c.type == ConcessionType.scholarship ? 'Scholarship' : 'Discount'} for ${c.student} · ${formatNaira(c.amount)}',
        detail: '${c.className}. ${c.reason}',
        note: 'Requested by ${c.requestedBy}',
        isWarning: true,
      ),
    for (final b in waiting)
      OwnerFinanceListItem(
        title: 'Payroll for ${b.period} · ${formatNaira(b.total)}',
        detail: '${b.lines.length} people. Waiting for someone with approval authority.',
        note: 'Payroll & Salaries',
        isWarning: true,
      ),
  ];

  final decided = [
    for (final c in concessions.where((c) => c.status != ConcessionStatus.pendingApproval).take(5))
      OwnerFinanceListItem(
        title: '${c.status == ConcessionStatus.approved ? 'Approved' : 'Declined'}: ${c.student} · ${formatNaira(c.amount)}',
        detail: '${c.className}. ${c.decisionNote ?? ''}'.trim(),
        note: c.decidedAt ?? '',
      ),
  ];

  return OwnerFinanceOverview(kpis: kpis, attention: attention, decidedRecently: decided);
}

class OwnerFinanceOverviewRepository {
  OwnerFinanceOverviewRepository({
    required this.concessions,
    required this.payroll,
    required this.database,
    required this.session,
  });

  final ConcessionRepository concessions;
  final OwnerPayrollRepository payroll;
  final LocalDatabase database;
  final SchoolSessionController session;

  Future<OwnerFinanceOverview> load() async {
    final school = session.requireActiveMembership().schoolId;
    final records = await database.getLocalRecords(tenantId: school, entityType: PayrollBatchRepository.entityType);
    return buildFinanceOverview(
      concessions: await concessions.loadRequests(),
      payroll: await payroll.load(),
      batches: [for (final r in records) PayrollBatch.fromPayload(r.payload)],
    );
  }
}
