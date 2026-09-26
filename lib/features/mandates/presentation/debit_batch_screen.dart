import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_widgets.dart';

/// One direct-debit batch. The MAKER reviews every family, selects and deselects, lowers an amount and submits it; a DIFFERENT CHECKER sees
/// exactly what would be debited and approves or rejects it; only an approved batch can be started. A partial failure keeps the successes and
/// offers to retry the failures; a debit whose outcome is not known is asked about, never sent again.
///
/// Nothing here decides what a family owes: every figure is the server's, worked out from the receivables ledger.
class DebitBatchScreen extends StatefulWidget {
  const DebitBatchScreen({super.key, required this.api, required this.membership, required this.batchId, this.pollEvery = const Duration(seconds: 4)});

  final MandatesApi api;
  final SchoolMembership membership;
  final String batchId;

  /// How often progress is asked for while a batch is running.
  final Duration pollEvery;

  @override
  State<DebitBatchScreen> createState() => _DebitBatchScreenState();
}

class _DebitBatchScreenState extends State<DebitBatchScreen> {
  DebitBatchDetail? _detail;
  DebitItemsPage? _items;
  List<BatchEvent> _events = const [];
  DebitProgress? _progress;
  String? _error;
  bool _busy = false;
  String? _filter;
  final Set<String> _retryTicks = {};
  Timer? _timer;

  DebitBatch? get _batch => _detail?.batch;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.api.batch(widget.membership, widget.batchId);
      final items = await widget.api.items(widget.membership, widget.batchId);
      final events = await widget.api.events(widget.membership, widget.batchId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _items = items;
        _events = events;
        _error = null;
      });
      _watch(detail.batch);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  /// While debits are being carried out, ask how they are getting on. (Where no worker runs, watching is what drives the queue.)
  void _watch(DebitBatch batch) {
    _timer?.cancel();
    if (batch.status != 'processing') return;
    _timer = Timer.periodic(widget.pollEvery, (_) async {
      try {
        final progress = await widget.api.progress(widget.membership, widget.batchId);
        if (!mounted) return;
        setState(() => _progress = progress);
        if (progress.done) await _load();
      } catch (_) {
        // A missed answer is asked again next time.
      }
    });
  }

  Future<void> _run(Future<DebitBatchDetail> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      final detail = await action();
      final items = await widget.api.items(widget.membership, widget.batchId);
      final events = await widget.api.events(widget.membership, widget.batchId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _items = items;
        _events = events;
        _retryTicks.clear();
      });
      _watch(detail.batch);
      final retry = detail.retry;
      if (retry != null && retry.needsFreshApproval.isNotEmpty) {
        showBankMessage(context, '${retry.needsFreshApproval.join(', ')} changed since approval, so they need a fresh maker and checker. Nothing was sent for them.');
      } else if (done != null) {
        showBankMessage(context, done);
      }
    } catch (error) {
      if (mounted) {
        showBankMessage(context, describeBankError(error));
        await _load(); // what the person was looking at may be out of date: show what is true now
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _iAmMaker {
    final b = _batch;
    final me = widget.membership.id;
    return b != null && (b.preparedBy?.id == me || b.submittedBy?.id == me);
  }

  Future<void> _lower(DebitItem item) async {
    final answer = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: 'Lower the debit for ${item.familyName}',
        intro: 'A debit can be lowered, never raised: it can never be more than the ledger says the family owes.',
        fields: [DialogField(name: 'amount', label: 'Amount (naira)', fieldKey: const ValueKey('lower-amount'), decimal: true, initial: (item.proposedDebitMinor / 100).toStringAsFixed(2))],
        action: 'Lower it',
        confirmKey: const ValueKey('lower-confirm'),
      ),
    );
    final amount = answer == null ? null : double.tryParse(answer['amount']!.replaceAll(',', ''));
    if (amount == null || amount <= 0 || !mounted) return;
    final batch = _batch!;
    await _run(() => widget.api.lowerAmount(widget.membership, batch.id, item.id, amountMinor: (amount * 100).round(), version: batch.version), done: 'The debit was lowered.');
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.batch.heading ?? 'Direct-debit batch')),
      body: detail == null
          ? (_error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(onRefresh: _load, child: _body(detail)),
    );
  }

  Widget _body(DebitBatchDetail detail) {
    final b = detail.batch;
    final items = _items?.items ?? const <DebitItem>[];
    final shown = [
      for (final i in items)
        if (_filter == null || (_filter == 'selected' ? i.selected : (_filter == 'failed' ? (i.failed || i.unknown) : i.eligibilityStatus == _filter))) i,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          BatchStatusChip(b.status),
          Text('${b.sessionName}${b.termName.isEmpty ? '' : ' - ${b.termName}'}'),
        ]),
        const SizedBox(height: 12),
        _summary(detail),
        if (b.status == 'rejected') _rejected(b),
        if (b.status == 'pending_approval') _pending(detail),
        if (b.status == 'processing' || _progress != null && b.status == 'processing') _running(b),
        if (b.status == 'partially_successful' || b.status == 'failed') _finishedWithFailures(b),
        _actions(detail),
        const SizedBox(height: 8),
        _filters(),
        const SizedBox(height: 8),
        if (shown.isEmpty) const Text('No families match.'),
        for (final i in shown) _tile(i, detail),
        const SizedBox(height: 16),
        BankSection(
          title: 'History',
          child: Column(children: [
            for (final e in _events)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(batchEventLabel(e.kind)),
                subtitle: Text('${shortDateTime(e.at)}${e.actor.isEmpty ? '' : ' - ${e.actor}'}${e.reason.isEmpty ? '' : '\n${e.reason}'}'),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _summary(DebitBatchDetail detail) {
    final b = detail.batch;
    final s = detail.summary;
    int n(String k) => s.byEligibility[k] ?? 0;
    return BankSection(
      title: 'Direct Debit Preview',
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        CountTile(tileKey: const ValueKey('sum-families'), label: 'Families', value: '${s.families}'),
        CountTile(tileKey: const ValueKey('sum-ready'), label: 'Ready to debit', value: '${n('eligible')}'),
        CountTile(tileKey: const ValueKey('sum-not-ready'), label: 'Mandate not ready', value: '${n('not_ready') + n('provider_unavailable') + n('provider_cannot_debit')}', warn: n('not_ready') > 0),
        CountTile(tileKey: const ValueKey('sum-no-mandate'), label: 'No mandate', value: '${n('no_mandate')}'),
        CountTile(tileKey: const ValueKey('sum-selected'), label: 'Selected', value: '${b.totalItems}'),
        CountTile(tileKey: const ValueKey('sum-outstanding'), label: 'Outstanding (selected)', value: formatMoneyMinor(b.totalOutstandingMinor)),
        CountTile(tileKey: const ValueKey('sum-proposed'), label: 'Proposed debit', value: formatMoneyMinor(b.totalAmountMinor)),
      ]),
    );
  }

  Widget _rejected(DebitBatch b) => BankSection(
        title: 'Rejected${b.rejectedBy == null ? '' : ' by ${b.rejectedBy!.name}'}',
        child: Text(b.rejectionReason, key: const ValueKey('rejection-reason')),
      );

  Widget _pending(DebitBatchDetail detail) {
    final b = detail.batch;
    final can = detail.permissions.canApprove && !_iAmMaker;
    return BankSection(
      title: 'Waiting for approval',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Submitted${b.submittedBy == null ? '' : ' by ${b.submittedBy!.name}'}. Approving means approving exactly these ${b.totalItems} debits, ${formatMoneyMinor(b.totalAmountMinor)} in all.'),
        if (detail.permissions.canApprove && _iAmMaker)
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('You prepared or submitted this batch, so someone else must approve it.', key: ValueKey('maker-cannot-approve'), style: TextStyle(color: Color(0xFF8A6D00)))),
        if (can) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            FilledButton(
              key: const ValueKey('approve'),
              onPressed: _busy ? null : () => _run(() => widget.api.approve(widget.membership, b.id, snapshotHash: b.snapshotHash), done: 'Approved.'),
              child: const Text('Approve Debits'),
            ),
            OutlinedButton(
              key: const ValueKey('reject'),
              onPressed: _busy
                  ? null
                  : () async {
                      final reason = await askReason(context, title: 'Reject this batch', hint: 'Why is it being rejected?', action: 'Reject');
                      if (reason != null) await _run(() => widget.api.reject(widget.membership, b.id, reason: reason), done: 'Rejected. It is back with the maker.');
                    },
              child: const Text('Reject'),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _running(DebitBatch b) {
    final p = _progress;
    return BankSection(
      title: 'Debiting',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LinearProgressIndicator(value: p == null || p.total == 0 ? null : (p.success + p.failed) / p.total),
        const SizedBox(height: 8),
        Text(p == null ? 'Starting...' : '${p.success} debited, ${p.failed} failed, ${p.unknown} waiting for the provider to say, ${p.queued} queued.', key: const ValueKey('progress-text')),
        const Text('A debit the provider has not answered is asked about, never sent a second time.', style: TextStyle(color: Color(0xFF5F6B7A))),
      ]),
    );
  }

  Widget _finishedWithFailures(DebitBatch b) => BankSection(
        title: b.status == 'failed' ? 'Every debit failed' : 'Completed with failures',
        child: Text('${b.successCount} debited and kept. ${b.failedCount} did not go through. Retrying re-sends only the ones whose approved details have not changed; a changed one needs a fresh maker and checker.', key: const ValueKey('failure-note')),
      );

  Widget _actions(DebitBatchDetail detail) {
    final b = detail.batch;
    final p = detail.permissions;
    final children = <Widget>[];
    if (b.editable && p.canPrepare) {
      children.addAll([
        OutlinedButton(key: const ValueKey('select-all'), onPressed: _busy ? null : () => _run(() => widget.api.select(widget.membership, b.id, version: b.version, selectAllEligible: true)), child: const Text('Select all ready')),
        OutlinedButton(key: const ValueKey('deselect-all'), onPressed: _busy ? null : () => _run(() => widget.api.select(widget.membership, b.id, version: b.version, deselectAll: true)), child: const Text('Deselect all')),
        OutlinedButton(key: const ValueKey('refresh-preview'), onPressed: _busy ? null : () => _run(() => widget.api.refreshPreview(widget.membership, b.id, version: b.version), done: 'The preview was refreshed from the ledger.'), child: const Text('Refresh preview')),
        FilledButton(
          key: const ValueKey('submit'),
          onPressed: _busy || b.totalItems == 0 ? null : () => _run(() => widget.api.submit(widget.membership, b.id, snapshotHash: b.snapshotHash, version: b.version), done: 'Submitted for approval.'),
          child: const Text('Submit for Approval'),
        ),
        TextButton(
          key: const ValueKey('cancel-batch'),
          onPressed: _busy
              ? null
              : () async {
                  if (await confirmAction(context, title: 'Cancel this batch?', message: 'Nothing has been debited. The batch is closed.', action: 'Cancel the batch', danger: true)) {
                    await _run(() => widget.api.cancelBatch(widget.membership, b.id));
                  }
                },
          child: const Text('Cancel batch', style: TextStyle(color: Color(0xFFB3261E))),
        ),
      ]);
    }
    if (b.status == 'approved' && (p.canPrepare || p.canApprove)) {
      children.add(
        FilledButton(
          key: const ValueKey('start'),
          onPressed: _busy
              ? null
              : () async {
                  if (await confirmAction(context, title: 'Start debiting?', message: 'This sends ${b.totalItems} approved debits (${formatMoneyMinor(b.totalAmountMinor)}) to the providers. Before each one, SchoolOS checks the family\'s balance and mandate again and sends nothing that changed.', action: 'Start debiting')) {
                    await _run(() => widget.api.startDebiting(widget.membership, b.id), done: 'Debiting started.');
                  }
                },
          child: const Text('Start Debiting'),
        ),
      );
    }
    if ((b.status == 'partially_successful' || b.status == 'failed') && (p.canPrepare || p.canApprove)) {
      children.addAll([
        FilledButton(key: const ValueKey('retry-all'), onPressed: _busy ? null : () => _run(() => widget.api.retry(widget.membership, b.id)), child: const Text('Retry all failed')),
        OutlinedButton(
          key: const ValueKey('retry-selected'),
          onPressed: _busy || _retryTicks.isEmpty ? null : () => _run(() => widget.api.retry(widget.membership, b.id, itemIds: _retryTicks.toList())),
          child: Text('Retry selected (${_retryTicks.length})'),
        ),
      ]);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: children));
  }

  Widget _filters() => Wrap(spacing: 8, runSpacing: 4, children: [
        for (final (key, label) in const [(null, 'All'), ('eligible', 'Ready'), ('not_ready', 'Not ready'), ('no_mandate', 'No mandate'), ('selected', 'Selected'), ('failed', 'Failed or waiting')])
          ChoiceChip(key: ValueKey('bfilter-${key ?? 'all'}'), label: Text(label), selected: _filter == key, onSelected: (_) => setState(() => _filter = key)),
      ]);

  Widget _tile(DebitItem i, DebitBatchDetail detail) {
    final b = detail.batch;
    final editable = b.editable && detail.permissions.canPrepare && i.status != 'success';
    final retryMode = (b.status == 'partially_successful' || b.status == 'failed') && i.failed;
    return Card(
      key: ValueKey('item-${i.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (retryMode)
            Checkbox(key: ValueKey('retry-${i.id}'), value: _retryTicks.contains(i.id), onChanged: (v) => setState(() => v == true ? _retryTicks.add(i.id) : _retryTicks.remove(i.id)))
          else if (editable)
            Checkbox(
              key: ValueKey('select-${i.id}'),
              value: i.selected,
              onChanged: i.canSelect ? (v) => _run(() => widget.api.select(widget.membership, b.id, version: b.version, select: v == true ? [i.id] : const [], deselect: v == true ? const [] : [i.id])) : null,
            )
          else
            Padding(padding: const EdgeInsets.all(12), child: Icon(i.selected ? Icons.check_box : Icons.check_box_outline_blank, color: const Color(0xFF5F6B7A))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(i.familyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                EligibilityChip(i.eligibilityStatus),
              ]),
              if (i.payer.isNotEmpty || i.provider.isNotEmpty)
                Text('${i.payer}${i.provider.isEmpty ? '' : ' - ${providerDisplayName(i.provider)}'}${i.bankName.isEmpty ? '' : ' - ${i.bankName} ${i.accountMask}'}', style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 16, runSpacing: 2, children: [
                _figure('Outstanding', i.outstandingMinor),
                _figure('Proposed debit', i.proposedDebitMinor, bold: true),
              ]),
              if (i.amountAdjusted) const Padding(padding: EdgeInsets.only(top: 2), child: Text('Lowered by the maker', style: TextStyle(color: Color(0xFF8A6D00), fontSize: 12))),
              if (i.eligibilityNote.isNotEmpty && i.eligibilityStatus != 'eligible') Padding(padding: const EdgeInsets.only(top: 4), child: Text(i.eligibilityNote, style: const TextStyle(color: Color(0xFF5F6B7A)))),
              if (b.status != 'draft' && b.status != 'rejected' && i.selected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    DebitStatusChip(i.status),
                    if (i.errorMessage.isNotEmpty || i.errorCode.isNotEmpty)
                      Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(i.errorMessage.isNotEmpty ? i.errorMessage : debitFailureLabel(i.errorCode), style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12)))),
                    if (i.unknown)
                      const Expanded(child: Padding(padding: EdgeInsets.only(left: 8), child: Text('The provider has not said. It is being asked, and will not be sent again.', style: TextStyle(color: Color(0xFF8A6D00), fontSize: 12)))),
                  ]),
                ),
              if (editable && i.selected && i.canSelect)
                Align(alignment: Alignment.centerLeft, child: TextButton(key: ValueKey('lower-${i.id}'), onPressed: _busy ? null : () => _lower(i), child: const Text('Lower the amount'))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _figure(String label, int minor, {bool bold = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 11)),
          Text(formatMoneyMinor(minor), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      );
}
