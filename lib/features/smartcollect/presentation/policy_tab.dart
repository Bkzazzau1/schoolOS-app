import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_models.dart' show CollectionPermissions;
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'collection_words.dart';
import 'override_dialog.dart';
import 'policy_fields_form.dart';

/// The school's collection policy: the default, and the layers over it (session, term, batch, family), nearest wins. Every setting says
/// whether it is using the school default or an override, and every override says why and for how long.
class PolicyTab extends StatefulWidget {
  const PolicyTab({super.key, required this.api, required this.membership, this.familyApi, this.onChanged});

  final SmartCollectApi api;
  final FamilyFeesApi? familyApi;
  final SchoolMembership membership;
  final VoidCallback? onChanged;

  @override
  State<PolicyTab> createState() => _PolicyTabState();
}

class _PolicyTabState extends State<PolicyTab> {
  PolicyInfo? _info;
  List<PolicyOverride> _overrides = const [];
  Periods? _periods;
  String? _error;
  bool _loading = true;
  String _scope = 'all';

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
      final results = await Future.wait([
        widget.api.policy(widget.membership),
        widget.api.overrides(widget.membership),
        widget.api.periods(widget.membership),
      ]);
      if (!mounted) return;
      setState(() {
        _info = results[0] as PolicyInfo;
        _overrides = results[1] as List<PolicyOverride>;
        _periods = results[2] as Periods;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed() {
    widget.onChanged?.call();
    _load();
  }

  Future<void> _editDefault() async {
    final info = _info;
    if (info == null) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DefaultDialog(api: widget.api, membership: widget.membership, policy: info.policy),
    );
    if (saved == true) _changed();
  }

  Future<void> _add() async {
    final info = _info;
    final periods = _periods;
    if (info == null || periods == null) return;
    final saved = await showOverrideDialog(
      context,
      api: widget.api,
      familyApi: widget.familyApi,
      membership: widget.membership,
      policy: info.policy,
      periods: periods,
    );
    if (saved == true) _changed();
  }

  Future<void> _remove(PolicyOverride o) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove the override for ${o.targetLabel}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('It goes back to using the layer beneath. The override stays on record.'),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Why (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    try {
      await widget.api.removeOverride(widget.membership, o.id, reason: text);
      _changed();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _info == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _info == null) return ErrorRetry(message: _error!, onRetry: _load);
    final info = _info!;
    final policy = info.policy;
    final can = info.permissions.canManagePolicy;
    final shown = [for (final o in _overrides) if (_scope == 'all' || o.scope == _scope) o];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'How family collection accounts behave. This is the school\'s default; a session, term, batch or family can override only the '
            'settings it changes, and the nearest layer wins: family, then batch, then term, then session, then this default.',
          ),
          const SizedBox(height: 12),
          BankSection(
            title: 'School default policy',
            trailing: can ? TextButton.icon(key: const ValueKey('edit-default-policy'), onPressed: _editDefault, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in _summary(policy)) _row(line.$1, line.$2),
                for (final p in policy.problems) Text(p, style: const TextStyle(color: Color(0xFFB3261E))),
              ],
            ),
          ),
          BankSection(
            title: 'Overrides',
            trailing: can ? FilledButton.icon(key: const ValueKey('add-override'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in const ['all', 'session', 'term', 'family'])
                      ChoiceChip(label: Text(s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1)), selected: _scope == s, onSelected: (_) => setState(() => _scope = s)),
                  ],
                ),
                const SizedBox(height: 8),
                if (shown.isEmpty) const Text('No overrides. Everything is using the school default.'),
                for (final o in shown) _OverrideTile(entry: o, policy: policy, canRemove: can, onRemove: () => _remove(o)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<(String, String)> _summary(CollectionPolicy p) {
    final v = p.values;
    final scope = p.optionLabel('reuse_scope', v['reuse_scope']);
    final reuse = switch (v['reuse_scope']) {
      'selected_terms' => '$scope (${v['reuse_count'] ?? '?'})',
      'multiple_sessions' => '$scope (${v['reuse_count'] ?? '?'})',
      'until_date' => '$scope (${v['reuse_until'] ?? '?'})',
      _ => scope,
    };
    final wait = const {'grace_then_dormant', 'grace_then_close'}.contains(v['settlement_action']) ? ' after ${hoursWords(v['grace_period_hours'])}' : '';
    return [
      (p.label('account_mode'), p.optionLabel('account_mode', v['account_mode'])),
      (p.label('reuse_scope'), reuse),
      (p.label('settlement_action'), '${p.optionLabel('settlement_action', v['settlement_action'])}$wait'),
      (p.label('arrears_policy'), p.optionLabel('arrears_policy', v['arrears_policy'])),
      (p.label('eligibility_policy'), p.optionLabel('eligibility_policy', v['eligibility_policy'])),
      (p.label('provider_switch_policy'), p.optionLabel('provider_switch_policy', p.providerSwitchPolicy)),
      (p.label('override_reason_policy'), p.optionLabel('override_reason_policy', p.overrideReasonPolicy)),
    ];
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 170, child: Text(label, style: const TextStyle(color: Color(0xFF5F6B7A)))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _OverrideTile extends StatelessWidget {
  const _OverrideTile({required this.entry, required this.policy, required this.canRemove, required this.onRemove});

  final PolicyOverride entry;
  final CollectionPolicy policy;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final o = entry;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(o.targetLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
                StatusChip(label: scopeLabel(o.scope), color: const Color(0xFF3B5BA5)),
              ],
            ),
            const SizedBox(height: 4),
            for (final e in o.values.entries)
              Text('${policy.label(e.key)}: ${e.key == 'grace_period_hours' ? hoursWords(e.value) : policy.optionLabel(e.key, e.value)}'),
            if (o.reason.isNotEmpty) Text('Why: ${o.reason}', style: const TextStyle(color: Color(0xFF5F6B7A))),
            Text(expiryWords(o.expiryKind, on: o.expiresOn, term: o.expiryTerm, session: o.expirySession), style: const TextStyle(color: Color(0xFF5F6B7A))),
            if (canRemove) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onRemove, child: const Text('Remove'))),
          ],
        ),
      ),
    );
  }
}

class _DefaultDialog extends StatefulWidget {
  const _DefaultDialog({required this.api, required this.membership, required this.policy});

  final SmartCollectApi api;
  final SchoolMembership membership;
  final CollectionPolicy policy;

  @override
  State<_DefaultDialog> createState() => _DefaultDialogState();
}

class _DefaultDialogState extends State<_DefaultDialog> {
  Map<String, Object?> _changed = const {};
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_changed.isEmpty) return Navigator.of(context).pop(false);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.updatePolicy(widget.membership, _changed);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('School default policy'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PolicyFieldsForm(policy: widget.policy, initial: widget.policy.values, includeSchoolOnly: true, onChanged: (c) => _changed = c),
                if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('save-default-policy'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
        ],
      );
}

/// Kept so other screens can say what the person may do without importing the bank models.
typedef PolicyPermissions = CollectionPermissions;
