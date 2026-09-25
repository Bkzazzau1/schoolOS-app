import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/transfer_verify_network_api.dart';
import '../domain/network_models.dart';

/// The admission draft's own TransferVerify step (§41 of the brief: embedded
/// here, never a standalone search page). Phone-only for now - clearly
/// labeled as a weaker, candidate-only signal until biometric matching ships
/// in a later phase; it never confirms identity by itself.
class TransferVerifyIdentityCheckCard extends StatefulWidget {
  const TransferVerifyIdentityCheckCard({
    super.key,
    required this.membership,
    required this.api,
    required this.guardianPhoneController,
  });

  final SchoolMembership membership;

  /// Null on demo data, or whenever there is no connected school server.
  final TransferVerifyNetworkApi? api;
  final TextEditingController guardianPhoneController;

  @override
  State<TransferVerifyIdentityCheckCard> createState() => _TransferVerifyIdentityCheckCardState();
}

class _TransferVerifyIdentityCheckCardState extends State<TransferVerifyIdentityCheckCard> {
  bool _checking = false;
  String? _error;
  List<TransferVerifyCandidateMatch>? _results;
  final _requested = <String>{};

  Future<void> _check() async {
    final api = widget.api;
    if (api == null) return;
    final phone = widget.guardianPhoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter the guardian phone number above first.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final results = await api.matchByPhone(widget.membership, phone);
      if (!mounted) return;
      setState(() {
        _results = results;
        _checking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _checking = false;
      });
    }
  }

  Future<void> _ask(TransferVerifyCandidateMatch candidate) async {
    final api = widget.api;
    if (api == null) return;
    try {
      await api.sendRequest(
        widget.membership,
        transferAlertId: candidate.transferAlertId,
        note: 'Identity check during admission.',
      );
      if (!mounted) return;
      setState(() => _requested.add(candidate.transferAlertId));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TransferVerify identity check', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text(
              'Optional. Checks whether a school in your association network has an unresolved case against this '
              'guardian phone. Phone alone is only ever a candidate signal, never confirmation on its own.',
            ),
            const SizedBox(height: 14),
            if (widget.api == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                child: const Text('This check requires a connected school server. This device is running in demo mode.'),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: _checking ? null : _check,
                icon: _checking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
                label: const Text('Check TransferVerify'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              if (_results != null) ...[
                const SizedBox(height: 14),
                if (_results!.isEmpty)
                  const Text('No matches found for this phone number.')
                else
                  for (final candidate in _results!) ...[
                    _CandidateTile(
                      candidate: candidate,
                      requested: _requested.contains(candidate.transferAlertId),
                      onAsk: () => _ask(candidate),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.requested, required this.onAsk});

  final TransferVerifyCandidateMatch candidate;
  final bool requested;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(candidate.sourceSchoolName, style: const TextStyle(fontWeight: FontWeight.w800))),
              const Chip(label: Text('Candidate match · phone only'), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 6),
          Text('Status: ${candidate.status.replaceAll('_', ' ')}'),
          if (candidate.reason.trim().isNotEmpty) Text('Reason: ${candidate.reason.replaceAll('_', ' ')}'),
          const SizedBox(height: 10),
          requested
              ? const Text('Verification request sent - waiting for the source school to respond.')
              : OutlinedButton(onPressed: onAsk, child: Text('Ask ${candidate.sourceSchoolName} to verify')),
        ],
      ),
    );
  }
}
