import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../smartcollect/domain/collection_models.dart' show PeriodSession, Periods;
import '../data/mandates_api.dart';
import '../domain/mandate_models.dart';
import 'debit_batch_screen.dart';
import 'mandate_widgets.dart';

/// Direct-debit batches: prepared by one person and approved by another. A batch reads what families owe from the ledger and debits only
/// what it says, and only after a different person has approved exactly what it contains.
class DebitBatchesTab extends StatefulWidget {
  const DebitBatchesTab({super.key, required this.api, required this.membership, this.onChanged});

  final MandatesApi api;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<DebitBatchesTab> createState() => _DebitBatchesTabState();
}

class _DebitBatchesTabState extends State<DebitBatchesTab> {
  List<DebitBatch>? _batches;
  MandatePermissions? _permissions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final batches = await widget.api.batches(widget.membership);
      final overview = await widget.api.overview(widget.membership);
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _permissions = overview.permissions;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DebitBatchScreen(api: widget.api, membership: widget.membership, batchId: id)),
    );
    widget.onChanged?.call();
    await _load();
  }

  Future<void> _prepare() async {
    Periods? periods;
    try {
      periods = await widget.api.periods(widget.membership);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<(String, String?, String)>(context: context, builder: (_) => _NewBatchDialog(periods: periods!));
    if (chosen == null || !mounted) return;
    try {
      final made = await widget.api.createBatch(widget.membership, sessionId: chosen.$1, termId: chosen.$2, title: chosen.$3);
      if (!mounted) return;
      await _open(made.batch.id);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = _batches;
    if (batches == null) {
      if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }
    final canPrepare = _permissions?.canPrepare == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A maker prepares a direct-debit batch from what the ledger says families owe; a different person approves exactly what it contains. '
            'Nothing is sent to a provider until it is approved and started.',
          ),
          const SizedBox(height: 12),
          if (canPrepare)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(key: const ValueKey('prepare-batch'), onPressed: _prepare, icon: const Icon(Icons.playlist_add_check), label: const Text('Prepare Direct Debit Batch')),
            ),
          const SizedBox(height: 12),
          if (batches.isEmpty) const BankSection(title: 'No batches yet', child: Text('A batch is where debits are prepared, approved and run.')),
          for (final b in batches)
            Card(
              key: ValueKey('batch-${b.id}'),
              child: ListTile(
                onTap: () => _open(b.id),
                title: Text(b.heading, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 6, children: [BatchStatusChip(b.status)]),
                      const SizedBox(height: 4),
                      Text('${b.totalItems} debits, ${formatMoneyMinor(b.totalAmountMinor)}${b.successCount + b.failedCount > 0 ? ' - ${b.successCount} done, ${b.failedCount} failed' : ''}'),
                      if (b.preparedBy != null) Text('Prepared by ${b.preparedBy!.name}${b.approvedBy == null ? '' : ', approved by ${b.approvedBy!.name}'}', style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewBatchDialog extends StatefulWidget {
  const _NewBatchDialog({required this.periods});

  final Periods periods;

  @override
  State<_NewBatchDialog> createState() => _NewBatchDialogState();
}

class _NewBatchDialogState extends State<_NewBatchDialog> {
  late String? _session = widget.periods.currentSessionId ?? (widget.periods.sessions.isEmpty ? null : widget.periods.sessions.first.id);
  late String? _term = widget.periods.currentTermId;
  final _title = TextEditingController();

  PeriodSession? get _selected {
    for (final s in widget.periods.sessions) {
      if (s.id == _session) return s;
    }
    return null;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _selected;
    final terms = session?.terms ?? const [];
    if (_term != null && !terms.any((t) => t.id == _term)) _term = null;
    return AlertDialog(
      title: const Text('Prepare Direct Debit Batch'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('batch-session'),
            initialValue: _session,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Session', border: OutlineInputBorder()),
            items: [for (final s in widget.periods.sessions) DropdownMenuItem(value: s.id, child: Text(s.name))],
            onChanged: (v) => setState(() => _session = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const ValueKey('batch-term'),
            initialValue: _term,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('The whole session')), for (final t in terms) DropdownMenuItem<String?>(value: t.id, child: Text(t.name))],
            onChanged: (v) => setState(() => _term = v),
          ),
          const SizedBox(height: 12),
          TextField(key: const ValueKey('batch-title'), controller: _title, decoration: const InputDecoration(labelText: 'A name (optional)', border: OutlineInputBorder())),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('batch-create'),
          onPressed: _session == null ? null : () => Navigator.pop(context, (_session!, _term, _title.text)),
          child: const Text('Build the preview'),
        ),
      ],
    );
  }
}
