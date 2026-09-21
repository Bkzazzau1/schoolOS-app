import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../../proprietor/presentation/owner_dialogs.dart';
import '../data/finance_ledger_repository.dart';
import '../domain/finance_ledger_models.dart';

/// Every payment received, newest first, each with its numbered receipt. A payment recorded by mistake is voided with a
/// reason; it is never deleted.
class FinanceReceiptsPage extends StatefulWidget {
  const FinanceReceiptsPage({super.key, required this.ledger, required this.schoolName, this.onChanged});

  final FinanceLedgerRepository ledger;
  final String schoolName;
  final VoidCallback? onChanged;

  @override
  State<FinanceReceiptsPage> createState() => _FinanceReceiptsPageState();
}

class _FinanceReceiptsPageState extends State<FinanceReceiptsPage> with SyncRefresh<FinanceReceiptsPage> {
  List<Payment> _payments = const [];
  String _search = '';
  bool _showVoided = true;
  bool _loading = true;
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
      // Opening accounts first puts the demo school's payments in place.
      await widget.ledger.accounts();
      final payments = await widget.ledger.allPayments();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  String _receiptText(Payment p) => [
        widget.schoolName,
        'PAYMENT RECEIPT ${p.receiptNumber}',
        'Date: ${p.receivedAt.split('T').first}',
        'Student: ${p.studentName} (${p.className})',
        'Term: ${p.term}',
        'Amount: ${formatNaira(p.amount)}',
        'Paid by: ${p.method}${p.reference.isEmpty ? '' : ' (ref ${p.reference})'}',
        if (p.isVoided) 'VOIDED: ${p.voidedReason}',
      ].join('\n');

  Future<void> _open(Payment p) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.receiptNumber),
        content: SelectableText(_receiptText(p)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (!p.isVoided) TextButton(key: const ValueKey('receipt-void'), onPressed: () => Navigator.pop(context, 'void'), child: const Text('Void payment')),
        ],
      ),
    );
    if (action != 'void' || !mounted) return;
    final reason = await askReason(context, title: 'Void ${p.receiptNumber}?', action: 'Void payment', label: 'Why (required)');
    if (reason == null) return;
    final result = await widget.ledger.voidPayment(p, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    final theme = Theme.of(context);
    final q = _search.trim().toLowerCase();
    final shown = [
      for (final p in _payments)
        if ((_showVoided || !p.isVoided) &&
            (q.isEmpty || p.studentName.toLowerCase().contains(q) || p.receiptNumber.toLowerCase().contains(q) || p.reference.toLowerCase().contains(q)))
          p,
    ];
    final valid = _payments.where((p) => !p.isVoided);
    final total = valid.fold<int>(0, (n, p) => n + p.amount);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · RECEIPTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Receipts', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${valid.length} receipts worth ${formatNaira(total)}. Record new payments from Student Accounts.'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('receipts-search'),
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search name, receipt or reference', isDense: true),
              ),
            ),
            FilterChip(
              label: const Text('Show voided'),
              selected: _showVoided,
              onSelected: (v) => setState(() => _showVoided = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No receipts.')),
        for (final p in shown)
          Card(
            key: ValueKey('receipt-${p.receiptNumber}'),
            elevation: 0,
            child: ListTile(
              onTap: () => _open(p),
              title: Text('${p.receiptNumber} · ${p.studentName}', style: TextStyle(fontWeight: FontWeight.w800, decoration: p.isVoided ? TextDecoration.lineThrough : null)),
              subtitle: Text('${p.className} · ${p.receivedAt.split('T').first} · ${p.method}${p.reference.isEmpty ? '' : ' · ${p.reference}'}${p.isVoided ? '\nVoided: ${p.voidedReason}' : ''}'),
              isThreeLine: p.isVoided,
              trailing: Text(formatNaira(p.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}
