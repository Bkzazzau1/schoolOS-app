import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/transfer_verify_network_api.dart';
import '../domain/network_models.dart';

/// Both sides of a school's TransferVerify conversations: cases it has
/// asked other schools about, and (owner only, since responding reveals
/// more about this school's own case than the candidate match already did)
/// cases other schools have asked this school about.
class TransferVerifyRequestsPage extends StatefulWidget {
  const TransferVerifyRequestsPage({super.key, required this.api, required this.membership});

  final TransferVerifyNetworkApi? api;
  final SchoolMembership membership;

  @override
  State<TransferVerifyRequestsPage> createState() => _TransferVerifyRequestsPageState();
}

class _TransferVerifyRequestsPageState extends State<TransferVerifyRequestsPage> {
  Future<(List<TransferVerificationRequestRecord>, List<TransferVerificationRequestRecord>)>? _future;
  String? _notice;

  bool get _isOwner => widget.membership.role == SchoolRole.proprietor;

  @override
  void initState() {
    super.initState();
    final api = widget.api;
    if (api != null) _future = _load(api);
  }

  Future<(List<TransferVerificationRequestRecord>, List<TransferVerificationRequestRecord>)> _load(
    TransferVerifyNetworkApi api,
  ) async {
    final sent = await api.requestsSent(widget.membership);
    final received = _isOwner ? await api.requestsReceived(widget.membership) : const <TransferVerificationRequestRecord>[];
    return (sent, received);
  }

  void _reload() {
    final api = widget.api;
    if (api == null) return;
    setState(() => _future = _load(api));
  }

  Future<void> _cancel(TransferVerificationRequestRecord item) async {
    final api = widget.api;
    if (api == null) return;
    try {
      await api.cancel(widget.membership, item.id);
      if (!mounted) return;
      setState(() => _notice = 'Request to ${item.sourceSchoolName} cancelled.');
      _reload();
    } catch (error) {
      if (mounted) setState(() => _notice = '$error');
    }
  }

  Future<void> _respond(TransferVerificationRequestRecord item, bool confirm) async {
    final api = widget.api;
    if (api == null) return;
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ResponseNoteDialog(confirm: confirm),
    );
    if (note == null) return;
    try {
      await api.respond(widget.membership, requestId: item.id, confirm: confirm, note: note);
      if (!mounted) return;
      setState(() => _notice = 'Responded to ${item.requestingSchoolName}.');
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
          Text('Verification Requests', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          const _Notice(
            text: 'Verification requests require a connected school server. This device is running in demo mode.',
          ),
        ],
      );
    }

    return FutureBuilder<(List<TransferVerificationRequestRecord>, List<TransferVerificationRequestRecord>)>(
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
                  Text('${snapshot.error ?? 'Could not load verification requests.'}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final (sent, received) = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            const SizedBox(height: 6),
            Text('Verification Requests', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              _Notice(text: _notice!),
            ],
            const SizedBox(height: 18),
            Text('Sent by your school', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (sent.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No requests sent yet.')))
            else
              for (final item in sent) ...[
                _RequestCard(
                  item: item,
                  schoolLabel: item.sourceSchoolName,
                  trailing: item.status == TransferVerificationStatus.pending
                      ? OutlinedButton(onPressed: () => _cancel(item), child: const Text('Cancel'))
                      : null,
                ),
                const SizedBox(height: 10),
              ],
            if (_isOwner) ...[
              const SizedBox(height: 20),
              Text('Received by your school', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (received.isEmpty)
                const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(18), child: Text('No requests received yet.')))
              else
                for (final item in received) ...[
                  _RequestCard(
                    item: item,
                    schoolLabel: item.requestingSchoolName,
                    trailing: item.status == TransferVerificationStatus.pending
                        ? Wrap(spacing: 8, children: [
                            OutlinedButton(onPressed: () => _respond(item, false), child: const Text('Reject')),
                            FilledButton(onPressed: () => _respond(item, true), child: const Text('Confirm')),
                          ])
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.schoolLabel, this.trailing});

  final TransferVerificationRequestRecord item;
  final String schoolLabel;
  final Widget? trailing;

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
                Expanded(child: Text(schoolLabel, style: const TextStyle(fontWeight: FontWeight.w800))),
                Chip(label: Text(item.status.label)),
              ],
            ),
            if (item.note.trim().isNotEmpty) Text(item.note),
            if (item.responseNote.trim().isNotEmpty) Text('Response: ${item.responseNote}'),
            if (trailing != null) ...[
              const SizedBox(height: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponseNoteDialog extends StatefulWidget {
  const _ResponseNoteDialog({required this.confirm});
  final bool confirm;

  @override
  State<_ResponseNoteDialog> createState() => _ResponseNoteDialogState();
}

class _ResponseNoteDialogState extends State<_ResponseNoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.confirm ? 'Confirm this case' : 'Reject this case'),
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
        FilledButton(onPressed: () => Navigator.of(context).pop(_note.text), child: Text(widget.confirm ? 'Confirm' : 'Reject')),
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
