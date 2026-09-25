import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/transfer_verify_network_api.dart';
import '../domain/dispute_models.dart';

/// The source school's own side of disputes and clearance - owner only,
/// the same authority tier as publishing: reviewing a dispute or issuing a
/// clearance reveals more about this school's own case than a candidate
/// match ever did.
class TransferVerifyDisputesPage extends StatefulWidget {
  const TransferVerifyDisputesPage({super.key, required this.api, required this.membership});

  final TransferVerifyNetworkApi? api;
  final SchoolMembership membership;

  @override
  State<TransferVerifyDisputesPage> createState() => _TransferVerifyDisputesPageState();
}

class _TransferVerifyDisputesPageState extends State<TransferVerifyDisputesPage> {
  Future<(List<TransferVerifyDispute>, List<TransferVerifyClearance>)>? _future;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final api = widget.api;
    if (api != null) _future = _load(api);
  }

  Future<(List<TransferVerifyDispute>, List<TransferVerifyClearance>)> _load(TransferVerifyNetworkApi api) async {
    final disputes = await api.disputesReceived(widget.membership);
    final clearances = await api.clearancesForSchool(widget.membership);
    return (disputes, clearances);
  }

  void _reload() {
    final api = widget.api;
    if (api == null) return;
    setState(() => _future = _load(api));
  }

  Future<void> _review(TransferVerifyDispute dispute, bool accept) async {
    final api = widget.api;
    if (api == null) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewNoteDialog(accept: accept),
    );
    if (note == null) return;
    try {
      await api.reviewDispute(widget.membership, disputeId: dispute.id, accept: accept, note: note);
      if (!mounted) return;
      setState(() => _notice = accept ? 'Dispute accepted.' : 'Dispute rejected.');
      _reload();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    }
  }

  Future<void> _revoke(TransferVerifyClearance clearance) async {
    final api = widget.api;
    if (api == null) return;
    try {
      await api.revokeClearance(widget.membership, clearance.id);
      if (!mounted) return;
      setState(() => _notice = 'Clearance revoked.');
      _reload();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.api == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
          const SizedBox(height: 6),
          Text('Disputes & Clearance', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const _Notice(text: 'Disputes and clearance require a connected school server. This device is running in demo mode.'),
        ],
      );
    }

    return FutureBuilder<(List<TransferVerifyDispute>, List<TransferVerifyClearance>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  Text('${snapshot.error ?? 'Could not load disputes and clearance.'}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final (disputes, clearances) = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            const SizedBox(height: 6),
            Text('Disputes & Clearance', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              _Notice(text: _notice!),
            ],
            const SizedBox(height: 18),
            Text('Disputes on your published cases', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (disputes.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No disputes have been opened.')))
            else
              for (final dispute in disputes) ...[
                _DisputeCard(dispute: dispute, onAccept: () => _review(dispute, true), onReject: () => _review(dispute, false)),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 20),
            Text('Clearances issued', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Issue a clearance from a resolved, published case in the list above.'),
            const SizedBox(height: 8),
            if (clearances.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No clearances issued yet.')))
            else
              for (final clearance in clearances) ...[
                _ClearanceCard(clearance: clearance, onRevoke: clearance.status == TransferClearanceStatus.active ? () => _revoke(clearance) : null),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.dispute, required this.onAccept, required this.onReject});

  final TransferVerifyDispute dispute;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(dispute.reason.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800))),
                Chip(label: Text(dispute.status.label)),
              ],
            ),
            if (dispute.explanation.trim().isNotEmpty) Text(dispute.explanation),
            if (dispute.resolutionNote.trim().isNotEmpty) Text('Review note: ${dispute.resolutionNote}'),
            if (dispute.status == TransferDisputeStatus.opened) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: onReject, child: const Text('Reject')),
                FilledButton(onPressed: onAccept, child: const Text('Accept')),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClearanceCard extends StatelessWidget {
  const _ClearanceCard({required this.clearance, this.onRevoke});

  final TransferVerifyClearance clearance;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text('Token: ${clearance.verificationToken}', style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        subtitle: Text('Issued ${_date(clearance.issuedAt)}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(label: Text(clearance.status.label)),
            if (onRevoke != null) OutlinedButton(onPressed: onRevoke, child: const Text('Revoke')),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _ReviewNoteDialog extends StatefulWidget {
  const _ReviewNoteDialog({required this.accept});
  final bool accept;

  @override
  State<_ReviewNoteDialog> createState() => _ReviewNoteDialogState();
}

class _ReviewNoteDialogState extends State<_ReviewNoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.accept ? 'Accept this dispute' : 'Reject this dispute'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Factual detail only.'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_note.text), child: Text(widget.accept ? 'Accept' : 'Reject')),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}
