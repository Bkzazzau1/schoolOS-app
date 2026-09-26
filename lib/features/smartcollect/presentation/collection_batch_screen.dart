import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'batch_dialogs.dart';
import 'batch_item_tile.dart';
import 'collection_words.dart';

/// Where an exported file is saved. The default writes it to the app's documents folder and returns the path.
typedef SaveExport = Future<String> Function(ExportedFile file);

Future<String> saveExportToDocuments(ExportedFile file) async {
  final directory = await getApplicationDocumentsDirectory();
  final target = File(p.join(directory.path, file.fileName));
  await target.writeAsBytes(file.bytes, flush: true);
  return target.path;
}

/// One collection batch, for the maker who prepares it and the checker who approves it.
///
/// The maker reviews every family, selects and deselects, overrides eligibility with a reason, chooses which earlier balances to carry,
/// exports the preview and submits it. The checker sees exactly what would be generated, exports it, and approves it (never their own
/// batch) or rejects it with a reason. Only an approved batch can generate accounts, and a partial failure keeps every success and lets
/// the failed families be retried.
class CollectionBatchScreen extends StatefulWidget {
  const CollectionBatchScreen({
    super.key,
    required this.api,
    required this.membership,
    required this.batchId,
    this.saveExport = saveExportToDocuments,
    this.pollInterval = const Duration(seconds: 2),
  });

  final SmartCollectApi api;
  final SchoolMembership membership;
  final String batchId;
  final SaveExport saveExport;
  final Duration pollInterval;

  @override
  State<CollectionBatchScreen> createState() => _CollectionBatchScreenState();
}

class _CollectionBatchScreenState extends State<CollectionBatchScreen> {
  final _search = TextEditingController();
  CollectionBatch? _batch;
  CollectionPolicy? _policy;
  List<BatchItem> _items = const [];
  Map<String, BucketCount> _buckets = const {};
  bool _hasMore = false;
  String? _bucket;
  String? _generation;
  bool _selectedOnly = false;
  bool _overriddenOnly = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _poll;
  bool _retryMode = false;
  final Set<String> _retryTicked = {};
  List<BatchEvent>? _events;

  SmartCollectApi get _api => widget.api;
  SchoolMembership get _m => widget.membership;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  // -- loading -------------------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = _batch == null;
      _error = null;
    });
    try {
      final batch = await _api.batch(_m, widget.batchId);
      _policy ??= (await _api.policy(_m)).policy;
      if (!mounted) return;
      _batch = batch;
      await _loadItems();
      _watchProgress();
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadItems({bool more = false}) async {
    final page = await _api.items(
      _m,
      widget.batchId,
      bucket: _bucket,
      selected: _selectedOnly ? true : null,
      overriddenOnly: _overriddenOnly,
      generation: _generation,
      query: _search.text,
      offset: more ? _items.length : 0,
    );
    if (!mounted) return;
    setState(() {
      _items = more ? [..._items, ...page.items] : page.items;
      _hasMore = page.hasMore;
      _buckets = page.buckets;
    });
  }

  void _watchProgress() {
    _poll?.cancel();
    if (_batch?.isProcessing != true) return;
    _poll = Timer.periodic(widget.pollInterval, (_) async {
      try {
        final progress = await _api.progress(_m, widget.batchId);
        if (!mounted) return;
        if (progress.finished) {
          _poll?.cancel();
          await _load();
        } else {
          setState(() {});
        }
      } catch (_) {
        // The next tick asks again.
      }
    });
  }

  /// Run one change of the batch. A screen that was looking at an out-of-date batch is told, and reloaded.
  Future<void> _act(Future<CollectionBatch> Function() run, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final batch = await run();
      if (!mounted) return;
      _batch = batch;
      await _loadItems();
      _watchProgress();
      if (done != null && mounted) showBankMessage(context, done);
    } on ApiException catch (error) {
      if (!mounted) return;
      showBankMessage(context, error.message);
      if (error.isConflict || error.code == 'stale_preview' || error.code == 'batch_changed') await _load();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -- the maker's changes -----------------------------------------------------------------------------

  int get _version => _batch?.version ?? 0;

  Future<void> _select(BatchItem item, bool on) => _act(() => _api.setSelection(
        _m, widget.batchId,
        select: on ? [item.id] : const [],
        deselect: on ? const [] : [item.id],
        expectedVersion: _version,
      ));

  Future<void> _override(BatchItem item) async {
    final reason = await askForReason(
      context,
      title: 'Override eligibility',
      message: '${item.familyName} still owes ${formatMoneyMinor(item.previousArrearsMinor)} for an earlier term. Including them is your decision, and the reason is kept with your name. '
          'What they owe does not change.',
      action: 'Include this family',
    );
    if (reason == null) return;
    await _act(() => _api.overrideEligibility(_m, widget.batchId, item.id, reason: reason, expectedVersion: _version));
  }

  Future<void> _chooseBalances(BatchItem item) async {
    final ids = await chooseArrearsDialog(context, item);
    if (ids == null) return;
    await _act(() => _api.chooseArrears(_m, widget.batchId, item.id, receivableIds: ids, expectedVersion: _version));
  }

  Future<void> _addIdentity(BatchItem item) async {
    final api = _api;
    var onFile = false;
    try {
      onFile = (await api.payerIdentity(_m, item.familyId)).onFile;
    } catch (_) {}
    if (!mounted) return;
    final entered = await askPayerIdentity(context, familyName: item.familyName, hasOnFile: onFile);
    if (entered == null) return;
    try {
      await api.savePayerIdentity(_m, item.familyId, bvn: entered.$1, nin: entered.$2);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      return;
    }
    await _act(() => api.refreshPreview(_m, widget.batchId, expectedVersion: _version), done: 'Saved. The preview was refreshed.');
  }

  Future<void> _export(String type) async {
    try {
      final file = await _api.export(_m, widget.batchId, type: type);
      final path = await widget.saveExport(file);
      if (mounted) showBankMessage(context, 'Saved on this device: $path');
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Not yet')),
            FilledButton(key: const ValueKey('confirm-action'), onPressed: () => Navigator.of(dialog).pop(true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _submit() async {
    final b = _batch!;
    if (!await _confirm(
      'Submit for approval?',
      '${b.totals.selected} families, ${formatMoneyMinor(b.totals.collectionMinor)} to be collected. Someone else must approve it before any account is generated, '
          'and you will not be able to change it while it waits.',
      'Submit for Approval',
    )) {
      return;
    }
    await _act(() => _api.submit(_m, widget.batchId, expectedHash: b.snapshotHash, expectedVersion: b.version), done: 'Submitted for approval.');
  }

  // -- the checker's decision --------------------------------------------------------------------------

  Future<void> _approve() async {
    final b = _batch!;
    var manual = <String>[];
    try {
      final needing = await _api.items(_m, widget.batchId, bucket: 'manual_approval', selected: true, limit: 200);
      final waiting = [for (final i in needing.items) if (i.manualApprovedBy == null) i];
      if (waiting.isNotEmpty) {
        if (!mounted) return;
        final ticked = await askManualApprovals(context, waiting);
        if (ticked == null) return;
        manual = ticked;
      } else if (!await _confirm(
        'Approve this generation?',
        '${b.totals.selected} families, ${formatMoneyMinor(b.totals.collectionMinor)} to be collected, through ${b.providerName}. '
            'Approval is for exactly what you see now: if anything changes before it runs, it is withdrawn.',
        'Approve Generation',
      )) {
        return;
      }
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      return;
    }
    await _act(() => _api.approve(_m, widget.batchId, expectedHash: b.snapshotHash, manualApprovals: manual), done: 'Approved. The maker can now generate the accounts.');
  }

  Future<void> _reject() async {
    final reason = await askForReason(
      context,
      title: 'Reject this batch',
      message: 'It goes back to the person who prepared it, with your reason. Say what needs to change.',
      action: 'Reject',
      minWords: 3,
    );
    if (reason == null) return;
    await _act(() => _api.reject(_m, widget.batchId, reason: reason), done: 'Rejected and sent back to the maker.');
  }

  Future<void> _start() async {
    if (!await _confirm(
      'Generate Collection Accounts?',
      'This asks ${_batch!.providerName} to make an account for each selected family. It cannot be undone, but every account can be retired later.',
      'Generate Collection Accounts',
    )) {
      return;
    }
    await _act(() => _api.start(_m, widget.batchId));
  }

  Future<void> _cancel() async {
    final reason = await askForReason(context, title: 'Cancel this batch?', message: 'Nothing has been generated. It stays on record as cancelled.', action: 'Cancel batch', minWords: 0);
    if (reason == null) return;
    await _act(() => _api.cancel(_m, widget.batchId, reason: reason), done: 'Batch cancelled.');
  }

  // -- retrying what failed ----------------------------------------------------------------------------

  Future<void> _retry({List<String>? ids}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _api.retry(_m, widget.batchId, itemIds: ids);
      if (!mounted) return;
      _batch = result.batch;
      _retryMode = false;
      _retryTicked.clear();
      await _loadItems();
      _watchProgress();
      if (mounted) {
        showBankMessage(
          context,
          result.approvalNeeded
              ? 'Something changed since this batch was approved, so it needs a fresh approval before the failed families are retried.'
              : 'Retrying ${result.retried} ${result.retried == 1 ? 'family' : 'families'}.',
        );
      }
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _viewFailed() {
    setState(() {
      _generation = 'failed';
      _bucket = null;
      _selectedOnly = false;
    });
    _loadItems();
  }

  Future<void> _selectFailed() async {
    setState(() {
      _retryMode = true;
      _generation = 'failed';
      _bucket = null;
      _selectedOnly = false;
    });
    await _loadItems();
    if (mounted) setState(() => _retryTicked.addAll([for (final i in _items) if (i.hasFailed) i.id]));
  }

  Future<void> _showHistory() async {
    try {
      final events = await _api.events(_m, widget.batchId);
      if (mounted) setState(() => _events = events);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  // -- building ----------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    return Scaffold(
      appBar: AppBar(title: Text(batch?.displayTitle ?? 'Collection batch'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Reload')]),
      body: _loading && batch == null
          ? const Center(child: CircularProgressIndicator())
          : batch == null
              ? ErrorRetry(message: _error ?? 'This batch could not be loaded.', onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _body(batch)),
    );
  }

  Widget _body(CollectionBatch b) {
    final editable = b.can.edit;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(b),
        _totals(b),
        ..._notices(b),
        _actions(b),
        if (b.isProcessing || b.isFinished) _progress(b),
        _policyCard(b),
        _filters(b),
        for (final i in _items)
          BatchItemTile(
            item: i,
            editable: editable,
            canOverride: b.can.edit,
            retryMode: _retryMode,
            retryTicked: _retryTicked.contains(i.id),
            onRetryTick: (on) => setState(() => on ? _retryTicked.add(i.id) : _retryTicked.remove(i.id)),
            onSelect: (on) => _select(i, on),
            onOverride: () => _override(i),
            onClearOverride: () => _act(() => _api.clearOverride(_m, widget.batchId, i.id, expectedVersion: _version)),
            onChooseBalances: () => _chooseBalances(i),
            onAddIdentity: () => _addIdentity(i),
          ),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No families match.'))),
        if (_hasMore) Center(child: OutlinedButton(onPressed: () => _loadItems(more: true), child: const Text('Show more'))),
        const SizedBox(height: 8),
        _history(),
      ],
    );
  }

  Widget _header(CollectionBatch b) => BankSection(
        title: b.displayTitle,
        trailing: BatchStatusChip(b.status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line('Period', b.period),
            _line('Provider', '${b.providerName} (${environmentLabel(b.providerEnvironment)})'),
            _line('Prepared by', '${b.preparedBy?.name ?? 'Unknown'}${b.preparedAt == null ? '' : ' · ${dateTimeLabel(b.preparedAt)}'}'),
            if (b.submittedBy != null) _line('Submitted by', '${b.submittedBy!.name} · ${dateTimeLabel(b.submittedAt)}'),
            if (b.approvedBy != null) _line('Approved by', '${b.approvedBy!.name} · ${dateTimeLabel(b.approvedAt)}'),
            _line('Version', '${b.version}'),
            if (b.isRejected && b.rejectionReason.isNotEmpty)
              Container(
                key: const ValueKey('rejection-banner'),
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(8)),
                child: Text('Rejected${b.rejectedBy == null ? '' : ' by ${b.rejectedBy!.name}'}: ${b.rejectionReason}', style: const TextStyle(color: Color(0xFFB3261E))),
              ),
          ],
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFF5F6B7A)))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _totals(CollectionBatch b) => BankSection(
        title: 'What would be generated',
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _tile('Families in the batch', '${b.totals.families}'),
            _tile('Selected', '${b.totals.selected}', key: 'total-selected'),
            _tile('Previous balances', formatMoneyMinor(b.totals.previousArrearsMinor)),
            _tile('Due this period', formatMoneyMinor(b.totals.currentDueMinor)),
            _tile('To be collected', formatMoneyMinor(b.totals.collectionMinor), bold: true, key: 'total-collection'),
          ],
        ),
      );

  Widget _tile(String label, String value, {bool bold = false, String? key}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
          Text(value, key: key == null ? null : ValueKey(key), style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      );

  List<Widget> _notices(CollectionBatch b) => [
        if (!b.providerIsActive && !b.isFinished && b.status != 'cancelled')
          _notice('The school\'s active provider is no longer ${b.providerName}. Refresh the preview to prepare this batch for the current provider.', const Color(0xFFB3261E)),
        for (final problem in b.policyProblems) _notice(problem, const Color(0xFFB3261E)),
        if (b.isMaker && b.isPending) _notice('You prepared or changed this batch, so someone else must approve it.', const Color(0xFF3B5BA5)),
        if (b.isPending && !b.isMaker && !b.can.approve) _notice('This batch is waiting for someone who holds the approve duty.', const Color(0xFF3B5BA5)),
      ];

  Widget _notice(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Text(text, style: TextStyle(color: color)),
      );

  Widget _actions(CollectionBatch b) {
    final can = b.can;
    final buttons = <Widget>[
      if (can.edit) OutlinedButton.icon(key: const ValueKey('refresh-preview'), onPressed: _busy ? null : () => _act(() => _api.refreshPreview(_m, widget.batchId, expectedVersion: _version), done: 'Preview refreshed from the ledger.'), icon: const Icon(Icons.refresh), label: const Text('Refresh preview')),
      if (can.edit) OutlinedButton(key: const ValueKey('select-all-eligible'), onPressed: _busy ? null : () => _act(() => _api.setSelection(_m, widget.batchId, selectAllEligible: true, expectedVersion: _version)), child: const Text('Select all eligible')),
      if (can.edit) OutlinedButton(key: const ValueKey('deselect-all'), onPressed: _busy ? null : () => _act(() => _api.setSelection(_m, widget.batchId, deselectAll: true, expectedVersion: _version)), child: const Text('Deselect all')),
      OutlinedButton.icon(key: const ValueKey('export-pdf'), onPressed: _busy ? null : () => _export('pdf'), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Export PDF')),
      OutlinedButton.icon(key: const ValueKey('export-xlsx'), onPressed: _busy ? null : () => _export('xlsx'), icon: const Icon(Icons.table_chart_outlined), label: const Text('Export Excel')),
      if (can.submit) FilledButton(key: const ValueKey('submit-batch'), onPressed: _busy || b.totals.selected == 0 ? null : _submit, child: const Text('Submit for Approval')),
      if (can.approve) FilledButton(key: const ValueKey('approve-batch'), onPressed: _busy ? null : _approve, child: const Text('Approve Generation')),
      if (can.reject) OutlinedButton(key: const ValueKey('reject-batch'), onPressed: _busy ? null : _reject, child: const Text('Reject')),
      if (can.start) FilledButton(key: const ValueKey('start-batch'), onPressed: _busy ? null : _start, child: const Text('Generate Collection Accounts')),
      if (can.cancel) TextButton(key: const ValueKey('cancel-batch'), onPressed: _busy ? null : _cancel, child: const Text('Cancel batch')),
    ];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Wrap(spacing: 8, runSpacing: 8, children: buttons));
  }

  Widget _progress(CollectionBatch b) {
    final t = b.totals;
    if (b.isProcessing) {
      final pr = b.progress;
      return BankSection(
        title: 'Generating collection accounts',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(key: const ValueKey('generation-progress'), value: pr == null || pr.total == 0 ? null : pr.fraction),
            const SizedBox(height: 8),
            Text('${t.successful} generated · ${t.failed} failed · ${pr == null ? t.selected - t.successful - t.failed : pr.waiting + pr.generating} still to do'),
            const Text('The provider is asked for each family in turn. You can leave this screen: it carries on.', style: TextStyle(color: Color(0xFF5F6B7A))),
          ],
        ),
      );
    }
    final withErrors = b.status == 'partially_successful' || b.status == 'failed';
    return BankSection(
      title: withErrors ? 'Generation complete with errors' : 'Generation complete',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _tile('Successful', '${t.successful}', key: 'result-successful')),
              Expanded(child: _tile('Failed', '${t.failed}', key: 'result-failed')),
            ],
          ),
          if (withErrors) ...[
            const SizedBox(height: 8),
            const Text('Every account that was generated stays. Only the failed families are tried again.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(key: const ValueKey('view-failed'), onPressed: _viewFailed, child: const Text('View failed')),
                if (b.can.retry) FilledButton(key: const ValueKey('retry-all'), onPressed: _busy ? null : () => _retry(), child: const Text('Retry all failed')),
                if (b.can.retry) OutlinedButton(key: const ValueKey('select-failed'), onPressed: _selectFailed, child: const Text('Select failed families')),
                if (_retryMode && _retryTicked.isNotEmpty)
                  FilledButton(key: const ValueKey('retry-selected'), onPressed: _busy ? null : () => _retry(ids: _retryTicked.toList()), child: Text('Retry selected (${_retryTicked.length})')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _policyCard(CollectionBatch b) {
    final policy = _policy;
    if (policy == null || b.policy.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        key: const ValueKey('batch-policy'),
        title: const Text('Policy for this batch', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Where each setting comes from'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in b.policy.entries)
            if (policy.labels.containsKey(e.key) && e.value != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 150, child: Text(policy.label(e.key), style: const TextStyle(color: Color(0xFF5F6B7A)))),
                    Expanded(child: Text(e.key == 'grace_period_hours' ? hoursWords(e.value) : policy.optionLabel(e.key, e.value), style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(scopeLabel(b.policySources[e.key]?.scope ?? 'school'), style: const TextStyle(fontSize: 11, color: Color(0xFF3B5BA5))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _filters(CollectionBatch b) {
    final counts = _buckets.isNotEmpty ? _buckets : b.counts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: 'Find a family',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _loadItems),
          ),
          onSubmitted: (_) => _loadItems(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(key: const ValueKey('bucket-all'), label: const Text('All'), selected: _bucket == null && _generation == null && !_selectedOnly && !_overriddenOnly, onSelected: (_) => _setFilter()),
            for (final bucket in eligibilityBuckets)
              if (counts[bucket] != null)
                ChoiceChip(
                  key: ValueKey('bucket-$bucket'),
                  label: Text('${eligibilityWords(bucket)} (${counts[bucket]!.total})'),
                  selected: _bucket == bucket,
                  onSelected: (_) => _setFilter(bucket: bucket),
                ),
            FilterChip(key: const ValueKey('filter-selected'), label: const Text('Selected only'), selected: _selectedOnly, onSelected: (v) => _setFilter(selectedOnly: v)),
            FilterChip(key: const ValueKey('filter-overridden'), label: const Text('Overridden'), selected: _overriddenOnly, onSelected: (v) => _setFilter(overriddenOnly: v)),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _setFilter({String? bucket, bool selectedOnly = false, bool overriddenOnly = false}) {
    setState(() {
      _bucket = bucket;
      _generation = null;
      _selectedOnly = selectedOnly;
      _overriddenOnly = overriddenOnly;
    });
    _loadItems();
  }

  Widget _history() {
    final events = _events;
    return ExpansionTile(
      key: const ValueKey('batch-history'),
      title: const Text('History', style: TextStyle(fontWeight: FontWeight.w700)),
      onExpansionChanged: (open) {
        if (open && _events == null) _showHistory();
      },
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        if (events == null) const Padding(padding: EdgeInsets.all(8), child: Text('Loading…')),
        for (final e in events ?? const <BatchEvent>[])
          ListTile(
            dense: true,
            title: Text(batchEventLabel(e.kind)),
            subtitle: Text([
              if (e.actor != null) e.actor!.name,
              dateTimeLabel(e.at),
              if ((e.detail['reason'] ?? '').toString().isNotEmpty) 'Reason: ${e.detail['reason']}',
              if ((e.detail['why'] ?? '').toString().isNotEmpty) '${e.detail['why']}',
            ].join(' · ')),
          ),
      ],
    );
  }
}
