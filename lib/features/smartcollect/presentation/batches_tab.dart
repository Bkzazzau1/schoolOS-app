import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'collection_batch_screen.dart';
import 'collection_words.dart';
import 'new_batch_page.dart';

/// Collection batches. A maker sees their drafts, rejected batches (with the reason) and what is waiting; a checker sees the batches
/// waiting for their approval. Opening one shows exactly what would be generated.
class BatchesTab extends StatefulWidget {
  const BatchesTab({super.key, required this.api, required this.membership, this.onChanged, this.saveExport = saveExportToDocuments});

  final SmartCollectApi api;
  final SchoolMembership membership;
  final VoidCallback? onChanged;
  final SaveExport saveExport;

  @override
  State<BatchesTab> createState() => _BatchesTabState();
}

class _BatchesTabState extends State<BatchesTab> {
  List<CollectionBatch> _batches = const [];
  CollectionDashboard? _dashboard;
  String _filter = 'all';
  String? _error;
  bool _loading = true;

  static const _filters = <(String, String)>[
    ('all', 'All'),
    ('awaiting', 'Waiting for me to approve'),
    ('draft', 'Drafts'),
    ('rejected', 'Rejected'),
    ('pending_approval', 'Waiting for approval'),
    ('processing', 'Generating'),
    ('failed', 'With failures'),
    ('completed', 'Completed'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await widget.api.dashboard(widget.membership);
      final batches = await switch (_filter) {
        'all' => widget.api.batches(widget.membership),
        'awaiting' => widget.api.batches(widget.membership, awaiting: true),
        'failed' => widget.api.batches(widget.membership, status: 'partially_successful,failed'),
        final status => widget.api.batches(widget.membership, status: status),
      };
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _batches = batches;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CollectionBatchScreen(api: widget.api, membership: widget.membership, batchId: id, saveExport: widget.saveExport)),
    );
    widget.onChanged?.call();
    await _load();
  }

  Future<void> _new() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => NewBatchPage(api: widget.api, membership: widget.membership)));
    if (id == null || !mounted) return;
    await _open(id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _dashboard == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _dashboard == null) return ErrorRetry(message: _error!, onRetry: _load);
    final can = _dashboard!.permissions;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'A collection batch makes a collection account for each family you select. One person prepares it, a different person approves it, '
                  'and only then are accounts generated.',
                ),
              ),
              if (can.canPrepare) FilledButton.icon(key: const ValueKey('new-batch'), onPressed: _new, icon: const Icon(Icons.add), label: const Text('New batch')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (key, label) in _filters)
                if (key != 'awaiting' || can.canApprove)
                  ChoiceChip(
                    key: ValueKey('batch-filter-$key'),
                    label: Text(label),
                    selected: _filter == key,
                    onSelected: (_) {
                      setState(() => _filter = key);
                      _load();
                    },
                  ),
            ],
          ),
          const SizedBox(height: 12),
          if (_batches.isEmpty)
            const BankSection(title: 'No batches here', child: Text('Nothing matches this filter yet.')),
          for (final b in _batches) _BatchCard(batch: b, onOpen: () => _open(b.id)),
        ],
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.onOpen});

  final CollectionBatch batch;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: ValueKey('batch-${b.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(b.displayTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                  BatchStatusChip(b.status),
                ],
              ),
              Text('${b.period} · ${b.providerName} (${environmentLabel(b.providerEnvironment)})', style: const TextStyle(color: Color(0xFF5F6B7A))),
              const SizedBox(height: 6),
              Text('${b.totals.selected} of ${b.totals.families} families · ${formatMoneyMinor(b.totals.collectionMinor)} to be collected'),
              if (b.isFinished) Text('${b.totals.successful} generated · ${b.totals.failed} failed', style: TextStyle(color: b.totals.failed > 0 ? const Color(0xFFB3261E) : const Color(0xFF1B7F3B))),
              if (b.isRejected && b.rejectionReason.isNotEmpty) Text('Rejected: ${b.rejectionReason}', style: const TextStyle(color: Color(0xFFB3261E))),
              Text('Prepared by ${b.preparedBy?.name ?? 'unknown'} · ${whenLabel(b.preparedAt)}', style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
