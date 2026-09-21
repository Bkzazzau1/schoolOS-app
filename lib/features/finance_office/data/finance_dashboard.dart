import '../../proprietor/domain/concession_request.dart';
import '../domain/finance_ledger_models.dart';
import 'finance_aging.dart';
import 'finance_billing.dart';

/// One thing that needs the finance office's attention.
class FinanceAttention {
  const FinanceAttention({required this.title, required this.detail, required this.target});

  final String title;
  final String detail;

  /// The finance screen where it is dealt with.
  final String target;
}

/// What the finance desk shows, worked out from the ledger: fees, payments, who owes and what is waiting.
class FinanceDashboard {
  const FinanceDashboard({
    required this.totals,
    required this.receiptsToday,
    required this.receivedToday,
    required this.owingAccounts,
    required this.pendingConcessions,
    required this.remindersQueued,
    required this.attention,
    required this.recent,
    required this.byMethod,
    required this.aging,
  });

  final BillingTotals totals;
  final int receiptsToday;
  final int receivedToday;
  final int owingAccounts;
  final int pendingConcessions;
  final int remindersQueued;
  final List<FinanceAttention> attention;

  /// The latest valid payments, newest first.
  final List<Payment> recent;

  /// Money received by how it was paid.
  final Map<String, int> byMethod;
  final AgingReport aging;
}

FinanceDashboard buildFinanceDashboard({
  required List<StudentAccount> accounts,
  required List<Payment> payments,
  required List<ConcessionRequest> concessions,
  required List<FeeReminder> reminders,
  required AgingReport aging,
  required DateTime now,
}) {
  final valid = payments.where((p) => !p.isVoided && p.term == financeCurrentTerm).toList();
  bool sameDay(Payment p) {
    final at = DateTime.parse(p.receivedAt).toLocal();
    return at.year == now.year && at.month == now.month && at.day == now.day;
  }

  final today = valid.where(sameDay).toList();
  final byMethod = <String, int>{};
  for (final p in valid) {
    byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
  }
  final pending = concessions.where((c) => c.status == ConcessionStatus.pendingApproval).toList();

  final attention = [
    if (aging.overdue && aging.owing.isNotEmpty)
      FinanceAttention(
        title: '${aging.owing.length} accounts owe ${formatNaira(aging.outstanding)}',
        detail: 'Fees are ${aging.days} days overdue. The largest balance is ${formatNaira(aging.owing.first.balance)} (${aging.owing.first.student.name}).',
        target: 'debt-aging',
      ),
    if (aging.overdue && aging.owing.isNotEmpty && reminders.where((r) => r.term == financeCurrentTerm).isEmpty)
      const FinanceAttention(
        title: 'No reminders have been queued yet',
        detail: 'Families who owe have not been reminded this term.',
        target: 'reminders',
      ),
    for (final c in pending)
      FinanceAttention(
        title: '${c.type == ConcessionType.scholarship ? 'Scholarship' : 'Discount'} for ${c.student} waits for the owner',
        detail: '${formatNaira(c.amount)} requested. It does not lower the bill until the owner approves it.',
        target: 'scholarships',
      ),
    for (final a in accounts.where((a) => a.gross == 0))
      FinanceAttention(
        title: 'No fees set for ${a.section}',
        detail: '${a.student.name} and others in ${a.section} cannot be billed.',
        target: 'fee-structure',
      ),
  ];
  // The same section is listed once.
  final seen = <String>{};
  final deduped = [for (final a in attention) if (seen.add(a.title)) a];

  return FinanceDashboard(
    totals: totalsOf(accounts),
    receiptsToday: today.length,
    receivedToday: today.fold(0, (n, p) => n + p.amount),
    owingAccounts: accounts.where((a) => a.balance > 0 && a.gross > 0).length,
    pendingConcessions: pending.length,
    remindersQueued: reminders.length,
    attention: deduped,
    recent: (valid..sort((a, b) => b.receivedAt.compareTo(a.receivedAt))).take(6).toList(),
    byMethod: byMethod,
    aging: aging,
  );
}
