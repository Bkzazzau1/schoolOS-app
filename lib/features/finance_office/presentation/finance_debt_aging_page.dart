import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_aging.dart';
import '../data/finance_billing.dart';
import '../data/finance_ledger_repository.dart';

/// Who still owes, how much, and how overdue it is. The due date is the finance office's to set.
class FinanceDebtAgingPage extends StatefulWidget {
  const FinanceDebtAgingPage({super.key, required this.ledger, this.onChanged, this.onOpenReminders});

  final FinanceLedgerRepository ledger;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenReminders;

  @override
  State<FinanceDebtAgingPage> createState() => _FinanceDebtAgingPageState();
}

class _FinanceDebtAgingPageState extends State<FinanceDebtAgingPage> with SyncRefresh<FinanceDebtAgingPage> {
  AgingReport? _report;
  String _section = 'All';
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
      final report = await widget.ledger.aging();
      if (!mounted) return;
      setState(() {
        _report = report;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _changeDue(AgingReport report) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: report.due,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      helpText: 'Fees for $financeCurrentTerm are due',
    );
    if (picked == null) return;
    final result = await widget.ledger.setDueDate(financeCurrentTerm, picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  static String _date(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    final owing = [for (final a in report.owing) if (_section == 'All' || a.section == _section) a];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · RECEIVABLES', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Outstanding & Aging', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Fees for $financeCurrentTerm are due ${_date(report.due)}. ${report.overdue ? '${report.days} days overdue.' : 'Not yet due.'}'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('aging-due'),
              onPressed: () => _changeDue(report),
              icon: const Icon(Icons.event_outlined, size: 18),
              label: const Text('Change due date'),
            ),
            if (widget.onOpenReminders != null)
              FilledButton.icon(
                onPressed: widget.onOpenReminders,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Fee reminders'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final b in report.bands)
              SizedBox(
                width: 200,
                child: Card(
                  key: ValueKey('band-${b.band.name}'),
                  elevation: 0,
                  color: b.accounts > 0 ? theme.colorScheme.primaryContainer : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.band.label, style: theme.textTheme.labelMedium),
                        const SizedBox(height: 6),
                        Text(formatNaira(b.amount), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        Text('${b.accounts} accounts', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'All fees share one due date, so every unpaid account sits in the same band today. As days pass they move down the bands together.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final s in ['All', ...financeSections])
              ChoiceChip(label: Text(s), selected: _section == s, onSelected: (_) => setState(() => _section = s)),
          ],
        ),
        const SizedBox(height: 12),
        Text('${owing.length} accounts owe ${formatNaira(owing.fold(0, (n, a) => n + a.balance))}', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (owing.isEmpty) const Text('Nobody owes anything.'),
        for (final a in owing)
          Card(
            key: ValueKey('owing-${a.student.id}'),
            elevation: 0,
            child: ListTile(
              title: Text(a.student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${a.student.className} · Guardian ${a.student.primaryGuardian}\nNet ${formatNaira(a.net)} · Paid ${formatNaira(a.paid)}'),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatNaira(a.balance), style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(report.band.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
