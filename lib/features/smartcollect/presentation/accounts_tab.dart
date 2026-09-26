import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'batch_dialogs.dart';
import 'collection_words.dart';
import 'family_merge_dialog.dart';
import 'override_dialog.dart';

/// Every family and the collection account it pays into. A family has ONE live account at the school, whatever its number of children;
/// closed and replaced accounts stay on record. Accounts are made by a collection batch (see the Collection tab): nothing here makes
/// one, and no account is typed in by hand.
class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key, required this.api, required this.familyApi, required this.membership, this.onChanged});

  final SmartCollectApi api;
  final FamilyFeesApi familyApi;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  final _search = TextEditingController();
  List<FamilyRow> _rows = const [];
  bool _hasMore = false;
  bool _canDecide = false;
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
    setState(() {
      _error = null;
      more ? _loadingMore = true : _loading = true;
    });
    try {
      final page = await widget.familyApi.families(widget.membership, query: _search.text, accounts: _filter, offset: more ? _rows.length : 0);
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

  Future<void> _merge(FamilyRow family) async {
    final done = await showMergeDialog(context, api: widget.familyApi, membership: widget.membership, family: family);
    if (done == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  /// Pause, reinstate, mark ready or retire one account. Pausing and retiring need a reason; retiring asks the provider to close it.
  Future<void> _accountAction(FamilyPayAccount account, String action) async {
    String? reason;
    if (action == 'suspend' || action == 'close') {
      reason = await askForReason(
        context,
        title: action == 'suspend' ? 'Pause this account?' : 'Retire this account?',
        message: action == 'suspend'
            ? 'The family will be told to contact the Finance Office before paying it. You can reinstate it later.'
            : 'The provider is asked to close it. It stays on record, and a payment the provider confirms into it is still credited to the family.',
        action: action == 'suspend' ? 'Pause account' : 'Retire account',
      );
      if (reason == null) return;
    }
    setState(() => _busy = account.id);
    try {
      await widget.familyApi.accountAction(widget.membership, account.id, action, reason: reason);
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _open(FamilyRow family) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FamilySheet(api: widget.api, familyApi: widget.familyApi, membership: widget.membership, family: family),
    );
    if (changed == true) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) return ErrorRetry(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Each family pays into ONE collection account, however many children it has. Accounts are made by a collection batch. '
            'Open a family to see its account history, its payer details and its policy.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('family-search'),
            controller: _search,
            decoration: InputDecoration(labelText: 'Search family, child or code', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _load)),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final (key, label) in const [(null, 'All'), ('with', 'With an account'), ('without', 'Without an account')])
                ChoiceChip(
                  key: ValueKey('accounts-filter-${key ?? 'all'}'),
                  label: Text(label),
                  selected: _filter == key,
                  onSelected: (_) {
                    setState(() => _filter = key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_rows.isEmpty) const BankSection(title: 'No families here', child: Text('No family matches.')),
          for (final f in _rows)
            _FamilyCard(
              family: f,
              canDecide: _canDecide,
              busyId: _busy,
              onOpen: () => _open(f),
              onMerge: () => _merge(f),
              onAccountAction: _accountAction,
            ),
          if (_hasMore) Center(child: OutlinedButton(onPressed: _loadingMore ? null : () => _load(more: true), child: Text(_loadingMore ? 'Loading…' : 'Show more families'))),
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
    required this.onOpen,
    required this.onMerge,
    required this.onAccountAction,
  });

  final FamilyRow family;
  final bool canDecide;
  final String? busyId;
  final VoidCallback onOpen;
  final VoidCallback onMerge;
  final Future<void> Function(FamilyPayAccount account, String action) onAccountAction;

  @override
  Widget build(BuildContext context) {
    final live = family.liveAccounts;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('family-${family.id}'),
        onTap: onOpen,
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
                        Text(family.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(
                          '${family.code} · ${family.students.isEmpty ? 'no children in it' : family.students.map((s) => s.name).join(', ')}',
                          style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (family.isMerged)
                    const StatusChip(label: 'Merged into another family', color: Color(0xFF5F6B7A))
                  else if (!family.isActive)
                    const StatusChip(label: 'Closed', color: Color(0xFF5F6B7A))
                  else if (canDecide)
                    PopupMenuButton<String>(
                      key: ValueKey('family-menu-${family.id}'),
                      tooltip: 'Family actions',
                      onSelected: (_) => onMerge(),
                      itemBuilder: (_) => const [PopupMenuItem(value: 'merge', child: Text('Merge into another family…'))],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (family.isActive && live.isEmpty)
                const Text('No collection account yet. One is made when the family is in an approved collection batch.', style: TextStyle(color: Color(0xFF5F6B7A))),
              for (final account in live) _AccountLine(account: account, busy: busyId == account.id, onAction: (action) => onAccountAction(account, action)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.account, required this.busy, required this.onAction});

  final FamilyPayAccount account;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final number = account.accountNumber.isEmpty ? 'not shown' : account.accountNumber;
    return Padding(
      key: ValueKey('account-${account.id}'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    StatusChip(label: accountStatusLabel(account.status), color: accountStatusColor(account.status)),
                    if (account.isTest) const SandboxTag(),
                  ],
                ),
                Text('${account.numberLabel}: $number'),
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
                if (!account.isPaused && account.status != 'closing') const PopupMenuItem(value: 'suspend', child: Text('Pause…')),
                if (account.status != 'closing') const PopupMenuItem(value: 'close', child: Text('Retire…')),
              ],
            ),
        ],
      ),
    );
  }
}

/// A family's account history, payer details and policy. Retiring an account asks the provider to close it; it stays on record.
class _FamilySheet extends StatefulWidget {
  const _FamilySheet({required this.api, required this.familyApi, required this.membership, required this.family});

  final SmartCollectApi api;
  final FamilyFeesApi familyApi;
  final SchoolMembership membership;
  final FamilyRow family;

  @override
  State<_FamilySheet> createState() => _FamilySheetState();
}

class _FamilySheetState extends State<_FamilySheet> {
  List<FamilyAccountRecord>? _accounts;
  PayerIdentityStatus? _identity;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.familyAccounts(widget.membership, widget.family.id),
        widget.api.payerIdentity(widget.membership, widget.family.id).then<PayerIdentityStatus?>((v) => v).catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<FamilyAccountRecord>;
        _identity = results[1] as PayerIdentityStatus?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _retire(FamilyAccountRecord account) async {
    final reason = await askForReason(
      context,
      title: 'Retire this account?',
      message: 'The provider is asked to close ${account.accountNumber}. It stays on record, and a payment the provider confirms into it is still credited to the family.',
      action: 'Retire account',
    );
    if (reason == null) return;
    try {
      await widget.api.closeAccount(widget.membership, account.id, reason: reason);
      _changed = true;
      await _load();
      if (mounted) showBankMessage(context, 'The account is being closed.');
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<void> _identityDialog() async {
    final entered = await askPayerIdentity(context, familyName: widget.family.displayName, hasOnFile: _identity?.onFile ?? false);
    if (entered == null) return;
    try {
      await widget.api.savePayerIdentity(widget.membership, widget.family.id, bvn: entered.$1, nin: entered.$2);
      await _load();
      if (mounted) showBankMessage(context, 'Saved. It is kept encrypted and is never shown.');
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Future<void> _policyOverride() async {
    try {
      final policy = (await widget.api.policy(widget.membership)).policy;
      final periods = await widget.api.periods(widget.membership);
      if (!mounted) return;
      final saved = await showOverrideDialog(
        context,
        api: widget.api,
        familyApi: widget.familyApi,
        membership: widget.membership,
        policy: policy,
        periods: periods,
        family: widget.family,
      );
      if (saved == true) {
        _changed = true;
        if (mounted) showBankMessage(context, 'Override saved for ${widget.family.displayName}.');
      }
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.family.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.of(context).pop(_changed), icon: const Icon(Icons.close)),
              ],
            ),
            Text('${widget.family.code} · ${widget.family.students.map((s) => s.name).join(', ')}', style: const TextStyle(color: Color(0xFF5F6B7A))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(key: const ValueKey('family-identity'), onPressed: _identityDialog, icon: const Icon(Icons.badge_outlined), label: Text(_identity?.onFile == true ? 'Payer identity: on file' : 'Add payer BVN or NIN')),
                OutlinedButton.icon(key: const ValueKey('family-policy'), onPressed: _policyOverride, icon: const Icon(Icons.tune), label: const Text('Policy for this family')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Account history', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
            if (accounts == null && _error == null) const Center(child: CircularProgressIndicator()),
            if (accounts != null && accounts.isEmpty) const Text('This family has never had a collection account.'),
            for (final a in accounts ?? const <FamilyAccountRecord>[]) _AccountRecordCard(account: a, onRetire: a.isLive && a.status != 'closing' ? () => _retire(a) : null),
          ],
        ),
      ),
    );
  }
}

class _AccountRecordCard extends StatelessWidget {
  const _AccountRecordCard({required this.account, required this.onRetire});

  final FamilyAccountRecord account;
  final VoidCallback? onRetire;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final lines = <String>[
      if (a.bankName.isNotEmpty) a.bankName,
      '${a.mode == 'dynamic' ? 'Dynamic' : 'Static'} account',
      if (a.collectionTargetMinor != null) 'Asked to collect ${formatMoneyMinor(a.collectionTargetMinor!)}',
      if (a.validUntil != null) 'Valid until ${dateLabel(a.validUntil)}',
      if (a.graceUntil != null) 'Waiting until ${dateTimeLabel(a.graceUntil)}',
      if (a.batchTitle != null) 'Made by ${a.batchTitle!.isEmpty ? 'a collection batch' : a.batchTitle}',
      if (a.isLegacy) 'Recorded by hand (before Smart Money Collection)',
      if (a.closedAt != null) 'Closed ${dateLabel(a.closedAt)}${a.closeReason.isEmpty ? '' : ': ${a.closeReason}'}',
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('${a.provider.isEmpty ? 'Provider' : a.provider[0].toUpperCase() + a.provider.substring(1)} · ${a.numberLabel}: ${a.accountNumber.isEmpty ? 'not shown' : a.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w700))),
                StatusChip(label: accountStatusLabel(a.status), color: accountStatusColor(a.status)),
              ],
            ),
            for (final l in lines) Text(l, style: const TextStyle(color: Color(0xFF5F6B7A))),
            if (onRetire != null) Align(alignment: Alignment.centerRight, child: TextButton(key: ValueKey('retire-${a.id}'), onPressed: onRetire, child: const Text('Retire account'))),
          ],
        ),
      ),
    );
  }
}
