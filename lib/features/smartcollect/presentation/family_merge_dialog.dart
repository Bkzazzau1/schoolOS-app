import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';

/// Two households that are really one can be folded together: one ledger and one place to pay. Needs billing authority, which the server
/// checks; it cannot be undone. Nothing is deleted: the merged family and its accounts stay on record.
Future<bool?> showMergeDialog(
  BuildContext context, {
  required FamilyFeesApi api,
  required SchoolMembership membership,
  required FamilyRow family,
}) =>
    showDialog<bool>(context: context, builder: (_) => _MergeDialog(api: api, membership: membership, family: family));

class _MergeDialog extends StatefulWidget {
  const _MergeDialog({required this.api, required this.membership, required this.family});

  final FamilyFeesApi api;
  final SchoolMembership membership;
  final FamilyRow family;

  @override
  State<_MergeDialog> createState() => _MergeDialogState();
}

class _MergeDialogState extends State<_MergeDialog> {
  final _search = TextEditingController();
  final _reason = TextEditingController();
  List<FamilyRow> _results = const [];
  FamilyRow? _target;
  MergePreview? _preview;
  bool _understood = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await widget.api.families(widget.membership, query: _search.text, limit: 10);
      if (mounted) {
        setState(() => _results = [for (final f in page.families) if (f.id != widget.family.id && f.isActive) f]);
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(FamilyRow target) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.api.mergePreview(widget.membership, widget.family.id, target.id);
      if (mounted) {
        setState(() {
          _target = target;
          _preview = preview;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.merge(widget.membership, widget.family.id, _target!.id, _reason.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return AlertDialog(
      title: Text('Merge ${widget.family.displayName}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview == null) ..._chooser() else ..._confirmation(preview),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const ValueKey('merge-error'), style: const TextStyle(color: Color(0xFFB3261E)))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        if (preview != null)
          FilledButton(
            key: const ValueKey('merge-confirm'),
            onPressed: _busy || !preview.canMerge || !_understood || _reason.text.trim().isEmpty ? null : _merge,
            child: Text(_busy ? 'Working…' : 'Merge families'),
          ),
      ],
    );
  }

  List<Widget> _chooser() => [
        const Text(
          'Two households that are really one can be folded together: one ledger and one place to pay. Choose the family to merge '
          'this one into.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('merge-search'),
                controller: _search,
                decoration: const InputDecoration(labelText: 'Search family, child or code', isDense: true),
                onSubmitted: (_) => _find(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(key: const ValueKey('merge-find'), onPressed: _busy ? null : _find, child: const Text('Search')),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        for (final f in _results)
          ListTile(
            key: ValueKey('merge-target-${f.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(f.displayName),
            subtitle: Text('${f.code} · ${f.students.map((s) => s.name).join(', ')}'),
            onTap: _busy ? null : () => _choose(f),
          ),
      ];

  List<Widget> _confirmation(MergePreview p) {
    String moves(String key, String noun) => '${p.moves[key] ?? 0} $noun';
    return [
      Text('${p.source.name} will be merged into ${p.into.name}.', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (p.problems.isNotEmpty)
        for (final problem in p.problems) Text(problem.message, key: const ValueKey('merge-problem'), style: const TextStyle(color: Color(0xFFB3261E))),
      Text('Children moving: ${p.source.students.isEmpty ? 'none' : p.source.students.join(', ')}'),
      Text('${moves('charges', 'charge(s)')}, ${moves('payments', 'recorded payment(s)')}, ${moves('statements', 'statement(s)')} move with them.'),
      Text('Owed now: ${formatMoneyMinor(p.source.outstandingMinor)} + ${formatMoneyMinor(p.into.outstandingMinor)}'
          '${p.source.creditMinor + p.into.creditMinor > 0 ? ' · Credit held: ${formatMoneyMinor(p.source.creditMinor + p.into.creditMinor)} (used against what is owed)' : ''}'),
      if (p.accountsMoved.isNotEmpty) Text('Accounts that move to ${p.into.name}: ${p.accountsMoved.join(', ')}.'),
      if (p.accountsKept.isNotEmpty)
        Text(
          'Accounts at ${p.accountsKept.join(', ')} stay where they are (a family holds one live account per school) and keep crediting the merged family, '
          'so no number a family was given stops working.',
        ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('merge-reason'),
        controller: _reason,
        maxLength: 300,
        decoration: const InputDecoration(labelText: 'Why are these one family? (kept on record)'),
        onChanged: (_) => setState(() {}),
      ),
      CheckboxListTile(
        key: const ValueKey('merge-understood'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _understood,
        onChanged: (v) => setState(() => _understood = v ?? false),
        title: const Text('I understand this cannot be undone.'),
      ),
    ];
  }
}
