import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_ledger_repository.dart';
import '../data/finance_reconciliation.dart';
import 'finance_reconciliation_dialogs.dart';

/// The bank statement set against the receipts. Bank transfers and POS receipts should each appear on the statement with the
/// same reference and amount. What does not is listed to look into; cash is not on a statement, so it is not matched.
class FinanceReconciliationPage extends StatefulWidget {
  const FinanceReconciliationPage({super.key, required this.ledger, this.onChanged});

  final FinanceLedgerRepository ledger;
  final VoidCallback? onChanged;

  @override
  State<FinanceReconciliationPage> createState() => _FinanceReconciliationPageState();
}

class _FinanceReconciliationPageState extends State<FinanceReconciliationPage> with SyncRefresh<FinanceReconciliationPage> {
  ReconciliationReport? _report;
  List<AdministratorStudentRecord> _owing = const [];
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
      final report = await widget.ledger.reconciliation();
      final accounts = await widget.ledger.accounts();
      if (!mounted) return;
      setState(() {
        _report = report;
        _owing = [for (final a in accounts) if (a.balance > 0) a.student];
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addLine() async {
    final choice = await askBankLine(context);
    if (choice == null) return;
    final result = await widget.ledger.addBankLine(
      date: choice.date,
      amount: choice.amount,
      reference: choice.reference,
      narration: choice.narration,
    );
    _say(result.message);
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _record(BankLine line) async {
    final student = await askStatementStudent(context, line: line, students: _owing);
    if (student == null) return;
    final result = await widget.ledger.recordFromStatement(line, student);
    _say(result.message);
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    if (r == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · RECONCILIATION', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Reconciliation', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(r.clear ? 'Everything on the statement matches a receipt.' : 'Some lines and receipts need a look.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('recon-add'),
          onPressed: _addLine,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add a statement line'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Matched', '${r.matched.length}', formatNaira(r.matchedAmount)),
            _Kpi('Amounts disagree', '${r.amountMismatches.length}', 'Bank and receipt differ'),
            _Kpi('Bank money, no receipt', '${r.unmatchedLines.length}', formatNaira(r.unmatchedLineAmount)),
            _Kpi('Receipt, not on statement', '${r.unmatchedPayments.length}', formatNaira(r.unmatchedPaymentAmount)),
          ],
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Bank money nobody recorded',
          empty: 'None.',
          children: [
            for (final l in r.unmatchedLines)
              ListTile(
                key: ValueKey('line-${l.reference}'),
                contentPadding: EdgeInsets.zero,
                title: Text('${formatNaira(l.amount)} · ${l.reference}'),
                subtitle: Text('${l.date}${l.narration.isEmpty ? '' : ' · ${l.narration}'}'),
                trailing: TextButton(key: ValueKey('record-${l.reference}'), onPressed: () => _record(l), child: const Text('Record payment')),
              ),
          ],
        ),
        _Section(
          title: 'Bank and receipt disagree',
          empty: 'None.',
          children: [
            for (final p in r.amountMismatches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p.payment.receiptNumber} · ${p.payment.studentName}'),
                subtitle: Text('Receipt ${formatNaira(p.payment.amount)}, bank ${formatNaira(p.line.amount)} (${p.line.reference}). Check with the bank, then void and re-record the receipt if it was wrong.'),
              ),
          ],
        ),
        _Section(
          title: 'Receipts not on the statement yet',
          empty: 'None.',
          children: [
            for (final p in r.unmatchedPayments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p.receiptNumber} · ${p.studentName}'),
                subtitle: Text('${formatNaira(p.amount)} · ${p.method} · ${p.reference} · ${p.receivedAt.split('T').first}'),
              ),
          ],
        ),
        _Section(
          title: 'Matched',
          empty: 'Nothing matched yet.',
          children: [
            for (final p in r.matched.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p.payment.receiptNumber} · ${p.payment.studentName}'),
                subtitle: Text('${formatNaira(p.payment.amount)} · ${p.line.reference}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.empty, required this.children});

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (children.isEmpty) Text(empty),
                ...children,
              ],
            ),
          ),
        ),
      );
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
