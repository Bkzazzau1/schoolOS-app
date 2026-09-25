import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/transfer_verify_network_api.dart';
import '../domain/dispute_models.dart';

/// A guardian's own read-only view of any published TransferVerify case
/// this school has against their child, with a "dispute this" action -
/// mirrors apps.transferverify.disputes.case_status_for_guardian exactly.
/// Never shows another school's internal notes, only this school's own.
class TransferVerifyMyCasePage extends StatefulWidget {
  const TransferVerifyMyCasePage({super.key, required this.api, required this.membership});

  final TransferVerifyNetworkApi? api;
  final SchoolMembership membership;

  @override
  State<TransferVerifyMyCasePage> createState() => _TransferVerifyMyCasePageState();
}

class _TransferVerifyMyCasePageState extends State<TransferVerifyMyCasePage> {
  Future<List<TransferVerifyCaseStatus>>? _future;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final api = widget.api;
    if (api != null) _future = api.myCaseStatus(widget.membership);
  }

  void _reload() {
    final api = widget.api;
    if (api == null) return;
    setState(() => _future = api.myCaseStatus(widget.membership));
  }

  Future<void> _dispute(TransferVerifyCaseStatus item) async {
    final api = widget.api;
    if (api == null) return;
    final result = await showDialog<_DisputeFormResult>(
      context: context,
      builder: (_) => const _DisputeDialog(),
    );
    if (result == null) return;
    try {
      await api.openDispute(
        widget.membership,
        transferAlertId: item.transferAlertId,
        reason: result.reason,
        explanation: result.explanation,
      );
      if (!mounted) return;
      setState(() => _notice = 'Dispute sent. The school will review it.');
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
          Text('TransferVerify Case', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const _Notice(text: 'This requires a connected school server. This device is running in demo mode.'),
        ],
      );
    }

    return FutureBuilder<List<TransferVerifyCaseStatus>>(
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
                  Text('${snapshot.error ?? 'Could not load case status.'}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final cases = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            const SizedBox(height: 6),
            Text('TransferVerify Case', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Any TransferVerify case this school has published concerning your child, and its current status.'),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              _Notice(text: _notice!),
            ],
            const SizedBox(height: 16),
            if (cases.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No TransferVerify case exists for your child at this school.')))
            else
              for (final item in cases) ...[
                _CaseCard(item: item, onDispute: () => _dispute(item)),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.onDispute});

  final TransferVerifyCaseStatus item;
  final VoidCallback onDispute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w800))),
                Chip(label: Text(item.state.replaceAll('_', ' '))),
              ],
            ),
            const SizedBox(height: 6),
            Text('Status: ${item.status.replaceAll('_', ' ')}'),
            if (item.reason.trim().isNotEmpty) Text('Reason given: ${item.reason.replaceAll('_', ' ')}'),
            const SizedBox(height: 8),
            if (item.hasActiveClearance)
              Chip(avatar: const Icon(Icons.verified_outlined, size: 16), label: const Text('Cleared by this school'), backgroundColor: theme.colorScheme.primaryContainer)
            else if (item.hasOpenDispute)
              const Chip(label: Text('Your dispute is under review'))
            else
              OutlinedButton(onPressed: onDispute, child: const Text('Dispute this case')),
          ],
        ),
      ),
    );
  }
}

class _DisputeFormResult {
  const _DisputeFormResult(this.reason, this.explanation);
  final TransferDisputeReason reason;
  final String explanation;
}

class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog();

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  TransferDisputeReason? _reason;
  final _explanation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Choose a reason.');
      return;
    }
    Navigator.of(context).pop(_DisputeFormResult(reason, _explanation.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dispute this case'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<TransferDisputeReason>(
              isExpanded: true,
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [for (final r in TransferDisputeReason.all) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (value) => setState(() => _reason = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _explanation,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Explanation (optional)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Send dispute')),
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
