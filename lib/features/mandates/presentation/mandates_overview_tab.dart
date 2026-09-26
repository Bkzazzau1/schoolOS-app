import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_widgets.dart';

/// Mandates & Direct Debit at a glance. There is no "Active Provider" badge: both providers may operate at once, each with its own mandates.
class MandatesOverviewTab extends StatefulWidget {
  const MandatesOverviewTab({super.key, required this.api, required this.membership, required this.onOpenTab});

  final MandatesApi api;
  final SchoolMembership membership;

  /// Opens one of the hub's tabs (1 Providers, 2 Mandates, 3 Debit Batches, 4 Transactions).
  final void Function(int tab) onOpenTab;

  @override
  State<MandatesOverviewTab> createState() => _MandatesOverviewTabState();
}

class _MandatesOverviewTabState extends State<MandatesOverviewTab> {
  MandatesOverview? _overview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final overview = await widget.api.overview(widget.membership);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _overview;
    if (o == null) return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'A mandate is a payer\'s authority for the school to collect approved school fees from their bank account. The provider executes each '
            'debit; SchoolOS never holds the money. What a family owes always comes from the fee ledger, never from a mandate.',
          ),
          const SizedBox(height: 12),
          BankSection(
            title: 'Providers',
            trailing: TextButton(onPressed: () => widget.onOpenTab(1), child: const Text('Manage')),
            child: o.providers.isEmpty
                ? const Text('No provider is connected yet.')
                : Column(children: [
                    for (final c in o.providers)
                      ListTile(
                        key: ValueKey('overview-${c.provider}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.providerName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${connectionStatusLabel(c.status)} - ${mandateEnvironmentLabel(c.environment)} - ${c.activeMandates} mandates active'),
                        trailing: ConnectionStatusChip(c.status),
                      ),
                  ]),
          ),
          BankSection(
            title: 'Mandates',
            trailing: TextButton(onPressed: () => widget.onOpenTab(2), child: const Text('Open')),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              CountTile(tileKey: const ValueKey('ov-active'), label: 'Active (debit ready)', value: '${o.active}'),
              CountTile(tileKey: const ValueKey('ov-waiting'), label: 'Waiting for the payer', value: '${o.waitingForPayer}', warn: o.waitingForPayer > 0),
              CountTile(tileKey: const ValueKey('ov-setting-up'), label: 'Being set up by the provider', value: '${o.settingUp}'),
              CountTile(tileKey: const ValueKey('ov-failed'), label: 'Failed', value: '${o.failedMandates}', warn: o.failedMandates > 0),
            ]),
          ),
          BankSection(
            title: 'Debit batches',
            trailing: TextButton(onPressed: () => widget.onOpenTab(3), child: const Text('Open')),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              CountTile(tileKey: const ValueKey('ov-approval'), label: 'Waiting for approval', value: '${o.waitingForApproval}', warn: o.waitingForApproval > 0),
              CountTile(tileKey: const ValueKey('ov-debiting'), label: 'Debiting now', value: '${o.debiting}'),
              CountTile(tileKey: const ValueKey('ov-batch-failures'), label: 'Completed with failures', value: '${o.batchesWithFailures}', warn: o.batchesWithFailures > 0),
            ]),
          ),
          BankSection(
            title: 'Debits',
            trailing: TextButton(onPressed: () => widget.onOpenTab(4), child: const Text('Open')),
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              CountTile(tileKey: const ValueKey('ov-collected'), label: '${o.debitCount} confirmed debits', value: formatMoneyMinor(o.collectedMinor)),
              CountTile(tileKey: const ValueKey('ov-unknown'), label: 'Outcome not known yet', value: '${o.unknownDebits}', warn: o.unknownDebits > 0),
              CountTile(tileKey: const ValueKey('ov-failed-debits'), label: 'Failed debits', value: '${o.failedDebits}', warn: o.failedDebits > 0),
            ]),
          ),
        ],
      ),
    );
  }
}
