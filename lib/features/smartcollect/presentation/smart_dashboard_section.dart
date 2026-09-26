import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'collection_words.dart';

/// Smart Money Collection at a glance, above the money figures: the active provider, the connected ones, a planned provider switch,
/// the account policy, the current period, how many families have accounts, and what is waiting on people (batches to approve,
/// rejected drafts, failed generations). Every number is the server's own.
class SmartDashboardSection extends StatefulWidget {
  const SmartDashboardSection({
    super.key,
    required this.api,
    required this.membership,
    required this.onOpenProviders,
    required this.onOpenBatches,
    required this.onOpenPolicy,
    required this.onOpenAccounts,
    required this.onOpenBatch,
  });

  final SmartCollectApi api;
  final SchoolMembership membership;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenBatches;
  final VoidCallback onOpenPolicy;
  final VoidCallback onOpenAccounts;
  final void Function(String batchId) onOpenBatch;

  @override
  State<SmartDashboardSection> createState() => _SmartDashboardSectionState();
}

class _SmartDashboardSectionState extends State<SmartDashboardSection> {
  CollectionDashboard? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.dashboard(widget.membership);
      if (mounted) {
        setState(() {
          _d = d;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return _error == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))));
    }
    final active = d.activeProvider;
    final sw = d.scheduledSwitch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BankSection(
          title: 'Smart Money Collection',
          trailing: TextButton(onPressed: widget.onOpenProviders, child: const Text('Providers')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active == null)
                const Text('No active collection provider. Connect the school\'s Paystack or Monnify account and make it active to start making family accounts.', style: TextStyle(color: Color(0xFFB3261E)))
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Active provider: ${active.providerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    StatusChip(label: environmentLabel(active.environment), color: active.isLive ? const Color(0xFF3B5BA5) : const Color(0xFF6B4FBB)),
                    StatusChip(label: webhookStatusLabel(active.webhookStatus), color: active.webhookActive ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00)),
                  ],
                ),
                Text('${d.connectedProviders.length} provider${d.connectedProviders.length == 1 ? '' : 's'} connected', style: const TextStyle(color: Color(0xFF5F6B7A))),
              ],
              if (sw != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  key: const ValueKey('switch-banner'),
                  onTap: widget.onOpenProviders,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: (sw.isReady ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      sw.isReady
                          ? 'Ready to switch from ${sw.currentName} to ${sw.targetName}. Nothing has changed: review and apply it in Providers.'
                          : 'Switch to ${sw.targetName} planned for ${dateTimeLabel(sw.scheduledFor)}. It waits for you when the day comes.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(_policyLine(d.policy), style: const TextStyle(color: Color(0xFF5F6B7A))),
              if (d.sessionName.isNotEmpty) Text('Current period: ${d.sessionName}${d.termName.isEmpty ? '' : ' · ${d.termName}'}', style: const TextStyle(color: Color(0xFF5F6B7A))),
            ],
          ),
        ),
        BankSection(
          title: 'Family accounts',
          trailing: TextButton(onPressed: widget.onOpenAccounts, child: const Text('Open')),
          child: Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _stat('Families', '${d.activeFamilies}'),
              _stat('With an account', '${d.familiesWithLiveAccount}', key: 'stat-with-account'),
              _stat('Without one', '${d.familiesWithoutAccount}', key: 'stat-without-account'),
              for (final e in d.accountsByStatus.entries.where((e) => e.key != 'closed' && e.key != 'failed')) _stat(accountStatusLabel(e.key), '${e.value}'),
            ],
          ),
        ),
        BankSection(
          title: 'Collection batches',
          trailing: TextButton(onPressed: widget.onOpenBatches, child: const Text('Open')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _stat('Drafts', '${d.drafts}'),
                  _stat('Rejected', '${d.rejected}'),
                  _stat('Waiting for approval', '${d.pendingApproval}', key: 'stat-pending'),
                  _stat('Generating', '${d.processing}'),
                  _stat('Failed families', '${d.failedFamilies}', key: 'stat-failed'),
                ],
              ),
              if (d.pendingApprovals.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Waiting for your approval', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final b in d.pendingApprovals)
                  ListTile(
                    key: ValueKey('pending-${b.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.displayTitle),
                    subtitle: Text('${b.totals.selected} families · ${formatMoneyMinor(b.totals.collectionMinor)} · prepared by ${b.preparedBy?.name ?? 'unknown'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpenBatch(b.id),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _policyLine(CollectionPolicy p) {
    final v = p.values;
    return 'Default policy: ${p.optionLabel('account_mode', v['account_mode'])} accounts · ${p.optionLabel('settlement_action', v['settlement_action'])} · '
        'earlier balances: ${p.optionLabel('arrears_policy', v['arrears_policy'])}';
  }

  Widget _stat(String label, String value, {String? key}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
          Text(value, key: key == null ? null : ValueKey(key), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      );
}
