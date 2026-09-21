import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_billing.dart';
import '../data/finance_dashboard.dart';
import '../data/finance_ledger_repository.dart';

/// The finance desk: fees billed, money collected, who owes, and what is waiting, all worked out from the ledger.
class FinanceOfficeDashboardPage extends StatefulWidget {
  const FinanceOfficeDashboardPage({super.key, required this.schoolName, required this.onNavigate, required this.ledger});

  final String schoolName;
  final ValueChanged<String> onNavigate;
  final FinanceLedgerRepository ledger;

  @override
  State<FinanceOfficeDashboardPage> createState() => _FinanceOfficeDashboardPageState();
}

class _FinanceOfficeDashboardPageState extends State<FinanceOfficeDashboardPage> with SyncRefresh<FinanceOfficeDashboardPage> {
  FinanceDashboard? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final accounts = await widget.ledger.accounts();
      final data = buildFinanceDashboard(
        accounts: accounts,
        payments: await widget.ledger.allPayments(),
        concessions: await widget.ledger.concessions.loadRequests(),
        reminders: await widget.ledger.reminders(),
        aging: await widget.ledger.aging(),
        now: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    final t = data.totals;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Finance Dashboard', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${widget.schoolName} · $financeCurrentTerm. Worked out from the fee structure, student accounts and receipts.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Net collectible', formatNaira(t.net), 'After ${formatNaira(t.gross - t.net)} scholarships and discounts'),
            _Kpi('Collected', formatNaira(t.paid), '${t.collectedPercent}% of net collectible'),
            _Kpi('Still owed', formatNaira(t.balance), '${data.owingAccounts} accounts'),
            _Kpi('Received today', formatNaira(data.receivedToday), '${data.receiptsToday} receipts'),
            _Kpi('Awaiting the owner', '${data.pendingConcessions}', 'Scholarships and discounts'),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs attention', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (data.attention.isEmpty) const Text('Nothing needs attention.'),
                for (final a in data.attention)
                  ListTile(
                    key: ValueKey('attention-${a.title}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(a.detail),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => widget.onNavigate(a.target),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(
              width: 520,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent receipts', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (data.recent.isEmpty) const Text('No payments recorded yet.'),
                      for (final p in data.recent)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${p.receiptNumber} · ${p.studentName}'),
                          subtitle: Text('${p.receivedAt.split('T').first} · ${p.method}'),
                          trailing: Text(formatNaira(p.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How families paid', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (data.byMethod.isEmpty) const Text('No payments yet.'),
                      for (final e in data.byMethod.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [Expanded(child: Text(e.key)), Text(formatNaira(e.value), style: const TextStyle(fontWeight: FontWeight.w800))]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(onPressed: () => widget.onNavigate('accounts'), icon: const Icon(Icons.add_card_outlined, size: 18), label: const Text('Record a payment')),
            OutlinedButton(onPressed: () => widget.onNavigate('fee-structure'), child: const Text('Fee Structure')),
            OutlinedButton(onPressed: () => widget.onNavigate('debt-aging'), child: const Text('Outstanding & Aging')),
            OutlinedButton(onPressed: () => widget.onNavigate('receipts'), child: const Text('Receipts')),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Other finance screens (collections, store, mandates, reconciliation, expenses, reports) are still being connected and show sample figures.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
