import '../../../core/database/local_database.dart';
import '../../finance_office/data/finance_aging.dart';
import '../../finance_office/data/finance_billing.dart';
import '../../finance_office/data/finance_ledger_repository.dart';
import '../../finance_office/domain/finance_ledger_models.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../domain/concession_request.dart';
import '../domain/proprietor_finance_models.dart';
import 'concession_repository.dart';
import 'owner_payroll_repository.dart';
import 'payroll_batch_repository.dart';

/// What the owner's finance page can say from real records: scholarships and discounts, and payroll.
/// (Fees billed, collections, store and aging need the Finance role's data and are not here yet.)
/// One section's fees for the term.
class OwnerFeeSection {
  const OwnerFeeSection({required this.section, required this.students, required this.net, required this.paid, required this.balance});

  final String section;
  final int students;
  final int net;
  final int paid;
  final int balance;

  int get rate => net == 0 ? 0 : (paid * 100 / net).round();
}

/// Fees billed and collected this term, from the finance office's ledger.
class OwnerFeeSummary {
  const OwnerFeeSummary({
    required this.term,
    required this.totals,
    required this.sections,
    required this.byMethod,
    required this.due,
    required this.daysOverdue,
    required this.band,
    required this.owingAccounts,
    required this.topOwing,
  });

  final String term;
  final BillingTotals totals;
  final List<OwnerFeeSection> sections;
  final Map<String, int> byMethod;
  final DateTime due;
  final int daysOverdue;
  final String band;
  final int owingAccounts;

  /// The largest balances: (student, class, amount).
  final List<(String, String, int)> topOwing;
}

OwnerFeeSummary buildOwnerFeeSummary({
  required String term,
  required List<StudentAccount> accounts,
  required List<Payment> payments,
  required AgingReport aging,
}) {
  final byMethod = <String, int>{};
  for (final p in payments.where((p) => !p.isVoided && p.term == term)) {
    byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
  }
  return OwnerFeeSummary(
    term: term,
    totals: totalsOf(accounts),
    sections: [
      for (final name in financeSections)
        () {
          final mine = accounts.where((a) => a.section == name).toList();
          final t = totalsOf(mine);
          return OwnerFeeSection(section: name, students: mine.length, net: t.net, paid: t.paid, balance: t.balance);
        }(),
    ],
    byMethod: byMethod,
    due: aging.due,
    daysOverdue: aging.days,
    band: aging.band.label,
    owingAccounts: aging.owing.length,
    topOwing: [for (final a in aging.owing.take(5)) (a.student.name, a.student.className, a.balance)],
  );
}

class OwnerFinanceOverview {
  const OwnerFinanceOverview({required this.kpis, required this.attention, required this.decidedRecently, this.fees});

  /// Fees billed and collected, or null when the ledger could not be read.
  final OwnerFeeSummary? fees;

  final List<OwnerFinanceKpi> kpis;
  final List<OwnerFinanceListItem> attention;

  /// The last few concession decisions, newest first.
  final List<OwnerFinanceListItem> decidedRecently;
}

OwnerFinanceOverview buildFinanceOverview({
  required List<ConcessionRequest> concessions,
  required PayrollSnapshot payroll,
  required List<PayrollBatch> batches,
  OwnerFeeSummary? fees,
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

  return OwnerFinanceOverview(kpis: kpis, attention: attention, decidedRecently: decided, fees: fees);
}

class OwnerFinanceOverviewRepository {
  OwnerFinanceOverviewRepository({
    required this.concessions,
    required this.payroll,
    required this.database,
    required this.session,
    this.ledger,
  });

  final FinanceLedgerRepository? ledger;
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
      fees: await _fees(),
    );
  }

  Future<OwnerFeeSummary?> _fees() async {
    final l = ledger;
    if (l == null) return null;
    try {
      return buildOwnerFeeSummary(
        term: financeCurrentTerm,
        accounts: await l.accounts(),
        payments: await l.allPayments(),
        aging: await l.aging(),
      );
    } catch (_) {
      return null;
    }
  }
}
