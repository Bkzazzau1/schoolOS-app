import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';
import 'family_account_dialogs.dart';

/// Where each family pays. A family has ONE payment account per bank, shared by all its children; the finance side
/// sets it up (asks the school's bank to issue it, or records the account the bank gave) and it then appears to the
/// parent. What an account looks like depends on the bank, so nothing here assumes a format.
///
/// These are the school's own accounts: SchoolOS does not receive or hold the money.
class FamilyAccountsTab extends StatefulWidget {
  const FamilyAccountsTab({
    super.key,
    required this.familyApi,
    required this.bankApi,
    required this.membership,
    this.onChanged,
  });

  final FamilyFeesApi familyApi;
  final BankConnectApi bankApi;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<FamilyAccountsTab> createState() => _FamilyAccountsTabState();
}

class _FamilyAccountsTabState extends State<FamilyAccountsTab> {
  final _search = TextEditingController();
  List<FamilyRow> _rows = const [];
  bool _hasMore = false;
  bool _canDecide = false;
  String _query = '';
  String? _filter;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _busy;

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

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await widget.familyApi.families(
        widget.membership,
        query: _query,
        accounts: _filter,
        offset: more ? _rows.length : 0,
      );
      if (!mounted) return;
      setState(() {
        _rows = more ? [..._rows, ...page.families] : page.families;
        _hasMore = page.hasMore;
        _canDecide = page.canDecideBilling;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _changed() {
    widget.onChanged?.call();
    _load();
  }

  Future<void> _setUp(FamilyRow family) async {
    final List<AccountProvider> providers;
    final List<BankConnection> connections;
    setState(() => _busy = family.id);
    try {
      final results = await Future.wait([
        widget.familyApi.providers(widget.membership),
        widget.bankApi.connections(widget.membership),
      ]);
      providers = results[0] as List<AccountProvider>;
      connections = (results[1] as ConnectionsInfo).connections;
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      return;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    if (!mounted) return;
    final done = await showSetUpAccountDialog(
      context,
      api: widget.familyApi,
      membership: widget.membership,
      family: family,
      providers: providers,
      connections: connections,
    );
    if (done == true) _changed();
  }

  Future<void> _issueAll() async {
    try {
      final results = await Future.wait([
        widget.familyApi.providers(widget.membership),
        widget.bankApi.connections(widget.membership),
      ]);
      if (!mounted) return;
      final done = await showIssueAllDialog(
        context,
        api: widget.familyApi,
        membership: widget.membership,
        providers: results[0] as List<AccountProvider>,
        connections: (results[1] as ConnectionsInfo).connections,
      );
      if (done == true) _changed();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<void> _merge(FamilyRow family) async {
    final done = await showMergeDialog(context, api: widget.familyApi, membership: widget.membership, family: family);
    if (done == true) _changed();
  }

  Future<void> _accountAction(FamilyPayAccount account, String action) async {
    String? reason;
    if (action == 'suspend' || action == 'close') {
      reason = await askForReason(
        context,
        title: action == 'suspend' ? 'Pause this account?' : 'Close this account for good?',
        message: action == 'suspend'
            ? 'The family will be told to contact the Finance Office before paying it. You can reinstate it later.'
            : 'A closed account no longer identifies the family, and its number is not offered to parents. This cannot be undone.',
        action: action == 'suspend' ? 'Pause account' : 'Close account',
      );
      if (reason == null) return;
    }
    setState(() => _busy = account.id);
    try {
      await widget.familyApi.accountAction(widget.membership, account.id, action, reason: reason);
      if (mounted) _changed();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _filterTo(String? filter) {
    setState(() => _filter = filter);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty && _error == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) return ErrorRetry(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Each family pays into one account for all its children, at each bank the school uses. Set it up here and it appears '
            'to the parent. These are the school\'s own accounts: SchoolOS does not receive or hold the money.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  key: const ValueKey('family-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Search family, child or code',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _query = '';
                              _load();
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    _query = value;
                    _load();
                  },
                ),
              ),
              for (final (label, value) in const [('All', null), ('No account yet', 'without'), ('Has an account', 'with')])
                ChoiceChip(
                  key: ValueKey('family-filter-$label'),
                  label: Text(label),
                  selected: _filter == value,
                  onSelected: (_) => _filterTo(value),
                ),
              OutlinedButton.icon(
                key: const ValueKey('issue-all'),
                onPressed: _issueAll,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Issue for every family without one'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
          if (_rows.isEmpty && !_loading)
            const Padding(padding: EdgeInsets.all(16), child: Text('No family matches. Families appear here once students are placed in one.')),
          for (final family in _rows)
            _FamilyCard(
              family: family,
              canDecide: _canDecide,
              busyId: _busy,
              onSetUp: () => _setUp(family),
              onMerge: () => _merge(family),
              onAccountAction: _accountAction,
            ),
          if (_hasMore)
            Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(onPressed: () => _load(more: true), child: const Text('Show more families')),
            ),
        ],
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.canDecide,
    required this.busyId,
    required this.onSetUp,
    required this.onMerge,
    required this.onAccountAction,
  });

  final FamilyRow family;
  final bool canDecide;
  final String? busyId;
  final VoidCallback onSetUp;
  final VoidCallback onMerge;
  final Future<void> Function(FamilyPayAccount account, String action) onAccountAction;

  @override
  Widget build(BuildContext context) {
    final live = family.liveAccounts;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12);
    return Card(
      key: ValueKey('family-${family.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(family.displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${family.code} · ${family.students.isEmpty ? 'no children in it' : family.students.map((s) => s.name).join(', ')}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                if (family.isMerged)
                  const StatusChip(label: 'Merged into another family', color: Color(0xFF5F6B7A))
                else if (!family.isActive)
                  const StatusChip(label: 'Closed', color: Color(0xFF5F6B7A))
                else if (busyId == family.id)
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  PopupMenuButton<String>(
                    key: ValueKey('family-menu-${family.id}'),
                    tooltip: 'Family actions',
                    onSelected: (value) => value == 'add' ? onSetUp() : onMerge(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'add', child: Text(live.isEmpty ? 'Set up payment account' : 'Add an account at another bank')),
                      if (canDecide) const PopupMenuItem(value: 'merge', child: Text('Merge into another family…')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (family.isActive && live.isEmpty)
              Row(
                children: [
                  const Expanded(child: Text('No payment account yet: this family has nowhere to pay.', style: TextStyle(color: Color(0xFF8A6D00)))),
                  FilledButton.tonal(key: ValueKey('setup-${family.id}'), onPressed: busyId == family.id ? null : onSetUp, child: const Text('Set up')),
                ],
              ),
            for (final account in live)
              _AccountLine(account: account, busy: busyId == account.id, onAction: (action) => onAccountAction(account, action)),
          ],
        ),
      ),
    );
  }
}

Color _accountColor(String status) => switch (status) {
      'active' => const Color(0xFF1B7F3B),
      'dormant' => const Color(0xFF5F6B7A),
      'provisioning' => const Color(0xFF8A6D00),
      _ => const Color(0xFFB3261E),
    };

String _accountStatusLabel(String status) => switch (status) {
      'active' => 'Ready',
      'dormant' => 'Resting',
      'provisioning' => 'Being set up',
      'suspended' => 'Paused',
      _ => status,
    };

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.account, required this.busy, required this.onAction});

  final FamilyPayAccount account;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final number = account.accountNumber.isEmpty ? 'no number yet' : account.accountNumber;
    return Padding(
      key: ValueKey('account-${account.id}'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2, right: 8), child: Icon(Icons.account_balance_outlined, size: 18)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(account.bankLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                    StatusChip(label: _accountStatusLabel(account.status), color: _accountColor(account.status)),
                    if (account.isTest) const SandboxTag(),
                  ],
                ),
                SelectableText('${account.numberLabel}: $number'),
                if (account.accountName.isNotEmpty) Text('Account name: ${account.accountName}'),
                for (final d in account.details) Text('${d.label}: ${d.value}'),
              ],
            ),
          ),
          if (busy)
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            PopupMenuButton<String>(
              key: ValueKey('account-menu-${account.id}'),
              tooltip: 'Account actions',
              onSelected: onAction,
              itemBuilder: (_) => [
                if (account.isSettingUp) const PopupMenuItem(value: 'mark-provisioned', child: Text('Mark as ready')),
                if (account.isPaused) const PopupMenuItem(value: 'reinstate', child: Text('Reinstate')),
                if (!account.isPaused) const PopupMenuItem(value: 'suspend', child: Text('Pause…')),
                const PopupMenuItem(value: 'close', child: Text('Close…')),
              ],
            ),
        ],
      ),
    );
  }
}
