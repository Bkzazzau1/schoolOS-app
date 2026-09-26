import 'package:flutter/material.dart';

import '../domain/collection_models.dart';
import 'collection_words.dart';

const _choiceFields = <String>['account_mode', 'reuse_scope', 'settlement_action', 'arrears_policy', 'eligibility_policy'];
const _schoolOnly = <String>['provider_switch_policy', 'override_reason_policy'];
const _graceActions = {'grace_then_dormant', 'grace_then_close'};

/// The collection policy's settings as a form. Used to edit the school's default, to set an override for a session, term or family, and
/// to set a policy for one batch.
///
/// In override mode each setting has a "change this" box: ONLY the ticked settings are sent, and everything else keeps inheriting. A
/// wait ("wait, then close") asks for the school's own waiting period: none is assumed. Nothing here can name a provider: a family, term
/// or batch never chooses its own.
class PolicyFieldsForm extends StatefulWidget {
  const PolicyFieldsForm({
    super.key,
    required this.policy,
    required this.initial,
    required this.onChanged,
    this.overrideMode = false,
    this.includeSchoolOnly = false,
  });

  final CollectionPolicy policy;

  /// The values to start from: the school's default (or the policy already in force).
  final Map<String, dynamic> initial;

  /// The settings that were changed (override mode: the ticked ones; default mode: those that differ from [initial]).
  final void Function(Map<String, Object?> changed) onChanged;
  final bool overrideMode;
  final bool includeSchoolOnly;

  @override
  State<PolicyFieldsForm> createState() => _PolicyFieldsFormState();
}

class _PolicyFieldsFormState extends State<PolicyFieldsForm> {
  late final Map<String, Object?> _values = {
    for (final e in widget.initial.entries) e.key: e.value,
    if (widget.includeSchoolOnly) 'provider_switch_policy': widget.policy.providerSwitchPolicy,
    if (widget.includeSchoolOnly) 'override_reason_policy': widget.policy.overrideReasonPolicy,
  };
  final Set<String> _ticked = {};
  late final _graceHours = TextEditingController(text: _values['grace_period_hours']?.toString() ?? '');
  late final _reuseCount = TextEditingController(text: _values['reuse_count']?.toString() ?? '');

  @override
  void dispose() {
    _graceHours.dispose();
    _reuseCount.dispose();
    super.dispose();
  }

  bool _editable(String field) => !widget.overrideMode || _ticked.contains(field);

  void _set(String field, Object? value) {
    setState(() => _values[field] = value);
    _emit();
  }

  void _emit() {
    final out = <String, Object?>{};
    for (final field in [..._choiceFields, 'reuse_count', 'reuse_until', 'grace_period_hours', if (widget.includeSchoolOnly) ..._schoolOnly]) {
      final value = _values[field];
      final was = _schoolOnly.contains(field)
          ? (field == 'provider_switch_policy' ? widget.policy.providerSwitchPolicy : widget.policy.overrideReasonPolicy)
          : widget.initial[field];
      final chosen = widget.overrideMode ? _ticked.contains(field) : value != was;
      if (chosen && value != null) out[field] = value;
    }
    widget.onChanged(out);
  }

  void _tick(String field, bool on) {
    setState(() => on ? _ticked.add(field) : _ticked.remove(field));
    _emit();
  }

  Widget _wrap(String field, Widget child) {
    if (!widget.overrideMode) return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(key: ValueKey('change-$field'), value: _ticked.contains(field), onChanged: (v) => _tick(field, v == true)),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _choice(String field) {
    final options = widget.policy.options[field] ?? const <PolicyOption>[];
    final current = options.any((o) => o.value == _values[field]) ? _values[field] as String : null;
    return _wrap(
      field,
      DropdownButtonFormField<String>(
        key: ValueKey('field-$field'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: widget.policy.label(field), border: const OutlineInputBorder()),
        items: [for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis))],
        onChanged: _editable(field) ? (v) => _set(field, v) : null,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse('${_values['reuse_until'] ?? ''}') ?? now.add(const Duration(days: 365));
    final date = await showDatePicker(context: context, initialDate: current, firstDate: now, lastDate: now.add(const Duration(days: 3650)));
    if (date != null) _set('reuse_until', '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final scope = _values['reuse_scope'];
    final action = _values['settlement_action'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _choice('account_mode'),
        _choice('reuse_scope'),
        if (scope == 'selected_terms' || scope == 'multiple_sessions')
          _wrap(
            'reuse_count',
            TextField(
              key: const ValueKey('field-reuse_count'),
              controller: _reuseCount,
              enabled: _editable('reuse_count'),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: scope == 'selected_terms' ? 'How many terms' : 'How many sessions', border: const OutlineInputBorder()),
              onChanged: (v) => _set('reuse_count', int.tryParse(v.trim())),
            ),
          ),
        if (scope == 'until_date')
          _wrap(
            'reuse_until',
            OutlinedButton.icon(
              key: const ValueKey('field-reuse_until'),
              onPressed: _editable('reuse_until') ? _pickDate : null,
              icon: const Icon(Icons.event),
              label: Text(_values['reuse_until'] == null ? 'Choose the date' : 'Until ${_values['reuse_until']}'),
            ),
          ),
        _choice('settlement_action'),
        if (_graceActions.contains(action))
          _wrap(
            'grace_period_hours',
            TextField(
              key: const ValueKey('field-grace_period_hours'),
              controller: _graceHours,
              enabled: _editable('grace_period_hours'),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Waiting period (hours)',
                helperText: _values['grace_period_hours'] is int ? hoursWords(_values['grace_period_hours']) : 'Your school chooses how long. For example 48 is two days.',
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _set('grace_period_hours', int.tryParse(v.trim())),
            ),
          ),
        _choice('arrears_policy'),
        _choice('eligibility_policy'),
        if (widget.includeSchoolOnly) ...[
          _choiceOf('provider_switch_policy'),
          _choiceOf('override_reason_policy'),
        ],
      ],
    );
  }

  Widget _choiceOf(String field) {
    final options = widget.policy.options[field] ?? const <PolicyOption>[];
    final current = options.any((o) => o.value == _values[field]) ? _values[field] as String : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('field-$field'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: widget.policy.label(field), border: const OutlineInputBorder()),
        items: [for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => _set(field, v),
      ),
    );
  }
}
