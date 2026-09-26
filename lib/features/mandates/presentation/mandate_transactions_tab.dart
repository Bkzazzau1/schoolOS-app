import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_widgets.dart';

/// The debits the providers reported, each with whether it has been put towards the family's charges. Only a debit the provider confirmed
/// ever is: a pending, failed or unknown one changes nothing in the ledger.
class MandateTransactionsTab extends StatefulWidget {
  const MandateTransactionsTab({super.key, required this.api, required this.membership, this.canCheck = false});

  final MandatesApi api;
  final SchoolMembership membership;

  /// Whether this person may ask the provider again about a debit (someone who prepares or approves batches).
  final bool canCheck;

  @override
  State<MandateTransactionsTab> createState() => _MandateTransactionsTabState();
}

class _MandateTransactionsTabState extends State<MandateTransactionsTab> {
  List<MandateTransactionRow>? _rows;
  String? _status;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.transactions(widget.membership, status: _status);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _check(MandateTransactionRow row) async {
    setState(() => _busyId = row.id);
    try {
      await widget.api.checkTransaction(widget.membership, row.id);
      if (mounted) showBankMessage(context, 'Asked the provider.');
      await _load();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final (key, label) in const [(null, 'All'), ('success', 'Successful'), ('pending', 'Pending'), ('unknown', 'Not known yet'), ('failed', 'Failed'), ('reversed', 'Reversed')])
              ChoiceChip(
                key: ValueKey('tx-filter-${key ?? 'all'}'),
                label: Text(label),
                selected: _status == key,
                onSelected: (_) {
                  setState(() => _status = key);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 12),
          if (rows.isEmpty) const BankSection(title: 'No debits yet', child: Text('Debits appear here once a batch has been started.')),
          for (final t in rows)
            Card(
              key: ValueKey('tx-${t.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Row(children: [
                  Expanded(child: Text(t.familyName, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(formatMoneyMinor(t.amountMinor), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${providerDisplayName(t.provider)} - ${t.bankName.isEmpty ? '' : '${t.bankName} '}${t.accountMask}'),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      TransactionStatusChip(t.status),
                      if (t.settled) const StatusChip(label: 'Put towards the fees', color: Color(0xFF1B7F3B)),
                      if (t.isSandbox) const SandboxTag(),
                    ]),
                    if (t.failureCode.isNotEmpty) Text(debitFailureLabel(t.failureCode), style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12)),
                    Text(shortDateTime(t.createdAt), style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
                  ]),
                ),
                trailing: widget.canCheck && (t.status == 'pending' || t.status == 'unknown')
                    ? TextButton(key: ValueKey('check-${t.id}'), onPressed: _busyId == t.id ? null : () => _check(t), child: const Text('Ask the provider'))
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
