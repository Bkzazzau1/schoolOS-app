import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../data/smart_collect_api.dart';
import '../domain/collection_models.dart';
import 'collection_words.dart';
import 'policy_fields_form.dart';

/// Put an override on a session, a term or a family. Only the settings that are ticked change; everything else keeps inheriting from the
/// layer beneath. It can expire, it is audited, and it is never edited or deleted: replacing or removing it keeps the old one as history.
Future<bool?> showOverrideDialog(
  BuildContext context, {
  required SmartCollectApi api,
  required FamilyFeesApi? familyApi,
  required SchoolMembership membership,
  required CollectionPolicy policy,
  required Periods periods,
  String scope = 'family',
  FamilyRow? family,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OverrideDialog(api: api, familyApi: familyApi, membership: membership, policy: policy, periods: periods, scope: scope, family: family),
    );

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({
    required this.api,
    required this.familyApi,
    required this.membership,
    required this.policy,
    required this.periods,
    required this.scope,
    required this.family,
  });

  final SmartCollectApi api;
  final FamilyFeesApi? familyApi;
  final SchoolMembership membership;
  final CollectionPolicy policy;
  final Periods periods;
  final String scope;
  final FamilyRow? family;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  final _reason = TextEditingController();
  final _search = TextEditingController();
  late String _scope = widget.scope;
  String? _sessionId;
  String? _termId;
  FamilyRow? _family;
  List<FamilyRow> _hits = const [];
  Map<String, Object?> _changed = const {};
  String _expiry = 'until_removed';
  DateTime? _expiresOn;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _family = widget.family;
    _sessionId = widget.periods.currentSessionId ?? (widget.periods.sessions.isEmpty ? null : widget.periods.sessions.first.id);
    _termId = widget.periods.currentTermId;
  }

  @override
  void dispose() {
    _reason.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final api = widget.familyApi;
    if (api == null) return;
    try {
      final page = await api.families(widget.membership, query: _search.text, limit: 8);
      if (mounted) setState(() => _hits = page.families);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: _expiresOn ?? now.add(const Duration(days: 30)), firstDate: now, lastDate: now.add(const Duration(days: 1825)));
    if (date != null) setState(() => _expiresOn = date);
  }

  Future<void> _save() async {
    if (_changed.isEmpty) return setState(() => _error = 'Tick at least one setting to change.');
    final target = switch (_scope) {
      'session' => _sessionId,
      'term' => _termId,
      _ => _family?.id,
    };
    if (target == null) return setState(() => _error = 'Choose what this override is for.');
    if (_expiry == 'at_date' && _expiresOn == null) return setState(() => _error = 'Choose the date it lasts until.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.setOverride(
        widget.membership,
        scope: _scope,
        sessionId: _scope == 'session' ? _sessionId : null,
        termId: _scope == 'term' ? _termId : null,
        familyId: _scope == 'family' ? _family?.id : null,
        values: _changed,
        reason: _reason.text,
        expiryKind: _expiry,
        expiresOn: _expiry == 'at_date' && _expiresOn != null ? '${_expiresOn!.year.toString().padLeft(4, '0')}-${_expiresOn!.month.toString().padLeft(2, '0')}-${_expiresOn!.day.toString().padLeft(2, '0')}' : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final terms = [
      for (final s in widget.periods.sessions)
        for (final t in s.terms) (t.id, '${s.name} · ${t.name}'),
    ];
    return AlertDialog(
      title: const Text('Add an override'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Only the settings you tick change. Everything else keeps using the layer beneath it. A family, term or session can never choose its own provider.'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'family', label: Text('Family')),
                  ButtonSegment(value: 'term', label: Text('Term')),
                  ButtonSegment(value: 'session', label: Text('Session')),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              const SizedBox(height: 12),
              if (_scope == 'session')
                DropdownButtonFormField<String>(
                  key: const ValueKey('override-session'),
                  initialValue: widget.periods.sessions.any((s) => s.id == _sessionId) ? _sessionId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Session', border: OutlineInputBorder()),
                  items: [for (final s in widget.periods.sessions) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => setState(() => _sessionId = v),
                ),
              if (_scope == 'term')
                DropdownButtonFormField<String>(
                  key: const ValueKey('override-term'),
                  initialValue: terms.any((t) => t.$1 == _termId) ? _termId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                  items: [for (final t in terms) DropdownMenuItem(value: t.$1, child: Text(t.$2))],
                  onChanged: (v) => setState(() => _termId = v),
                ),
              if (_scope == 'family') ...[
                if (_family != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.family_restroom),
                    title: Text(_family!.displayName),
                    subtitle: Text(_family!.code),
                    trailing: widget.family == null ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _family = null)) : null,
                  )
                else ...[
                  TextField(
                    key: const ValueKey('override-family-search'),
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Find the family',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _find),
                    ),
                    onSubmitted: (_) => _find(),
                  ),
                  for (final f in _hits)
                    ListTile(dense: true, title: Text(f.displayName), subtitle: Text(f.code), onTap: () => setState(() => _family = f)),
                ],
              ],
              const SizedBox(height: 12),
              PolicyFieldsForm(policy: widget.policy, initial: widget.policy.values, overrideMode: true, onChanged: (changed) => _changed = changed),
              TextField(controller: _reason, maxLength: 300, decoration: const InputDecoration(labelText: 'Why (the school may require a reason)', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const ValueKey('override-expiry'),
                initialValue: _expiry,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'How long it lasts', border: OutlineInputBorder()),
                items: [for (final o in widget.policy.options['expiry_kind'] ?? const <PolicyOption>[]) DropdownMenuItem(value: o.value, child: Text(o.label))],
                onChanged: (v) => setState(() => _expiry = v ?? _expiry),
              ),
              if (_expiry == 'at_date')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event), label: Text(_expiresOn == null ? 'Choose the date' : dateLabel(_expiresOn))),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('save-override'), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save override')),
      ],
    );
  }
}
