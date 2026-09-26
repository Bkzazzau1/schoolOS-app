import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_detail_page.dart';
import 'mandate_widgets.dart';
import 'start_mandate_page.dart';

/// Every mandate at the school: family, payer, provider, bank and MASKED account, status, and whether it can be debited now.
class MandatesTab extends StatefulWidget {
  const MandatesTab({super.key, required this.api, required this.membership, this.onChanged});

  final MandatesApi api;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<MandatesTab> createState() => _MandatesTabState();
}

class _MandatesTabState extends State<MandatesTab> {
  static const _filters = <(String?, String)>[
    (null, 'All'),
    ('active', 'Active'),
    ('pending_activation', 'Pending activation'),
    ('pending_provider_setup', 'Pending provider setup'),
    ('pending_consent', 'Waiting for the payer'),
    ('failed', 'Failed'),
    ('suspended', 'Suspended'),
    ('cancelled', 'Cancelled'),
  ];

  MandatesPage? _page;
  String? _status;
  String? _provider;
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.mandates(widget.membership, status: _status, provider: _provider, search: _search.text);
      if (mounted) setState(() => _page = page);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    try {
      final connections = await widget.api.connections(widget.membership);
      if (!mounted) return;
      final made = await Navigator.of(context).push<Mandate>(
        MaterialPageRoute(builder: (_) => StartMandatePage(api: widget.api, membership: widget.membership, connections: connections.connections)),
      );
      if (made != null) {
        widget.onChanged?.call();
        await _load();
      }
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<void> _open(Mandate mandate, MandatePermissions permissions) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MandateDetailPage(api: widget.api, membership: widget.membership, mandateId: mandate.id, permissions: permissions)),
    );
    if (changed == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) {
      if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
      return const Center(child: CircularProgressIndicator());
    }
    final can = page.permissions.canManage;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('${page.counts.values.fold<int>(0, (a, b) => a + b)} mandates', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            if (can) FilledButton.icon(key: const ValueKey('start-mandate'), onPressed: _start, icon: const Icon(Icons.add), label: const Text('Start a mandate')),
          ]),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('mandate-search'),
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search by family',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final (key, label) in _filters)
              ChoiceChip(
                key: ValueKey('filter-${key ?? 'all'}'),
                label: Text(key == null ? label : '$label (${page.counts[key] ?? 0})'),
                selected: _status == key,
                onSelected: (_) {
                  setState(() => _status = key);
                  _load();
                },
              ),
            for (final provider in const [('remita', 'Remita'), ('lendsqr', 'Lendsqr')])
              FilterChip(
                key: ValueKey('provider-filter-${provider.$1}'),
                label: Text(provider.$2),
                selected: _provider == provider.$1,
                onSelected: (on) {
                  setState(() => _provider = on ? provider.$1 : null);
                  _load();
                },
              ),
          ]),
          const SizedBox(height: 12),
          if (_loading && page.mandates.isEmpty) const Center(child: CircularProgressIndicator()),
          if (!_loading && page.mandates.isEmpty)
            const BankSection(title: 'No mandates', child: Text('No mandate matches. A mandate is started for a payer, who then authorises it themselves.')),
          for (final m in page.mandates) _row(m, page.permissions),
        ],
      ),
    );
  }

  Widget _row(Mandate m, MandatePermissions permissions) => Card(
        key: ValueKey('mandate-${m.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () => _open(m, permissions),
          title: Text(m.familyName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m.payer.name} - ${m.providerName} - ${m.bankName.isEmpty ? m.bankCode : m.bankName} ${m.accountMask}'),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  MandateStatusChip(m.status),
                  StatusChip(label: m.debitReady ? 'Debit ready' : 'Not debit ready', color: m.debitReady ? const Color(0xFF1B7F3B) : const Color(0xFF5F6B7A)),
                  if (m.isPrimary) const StatusChip(label: 'Primary', color: Color(0xFF3B5BA5)),
                  if (m.isSandbox) const SandboxTag(),
                ]),
                if (m.createdAt != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Created ${shortDate(m.createdAt)}', style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12))),
              ],
            ),
          ),
        ),
      );
}
