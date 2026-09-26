import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../domain/bank_labels.dart';
import '../domain/bank_models.dart';
import 'bank_widgets.dart';

/// Ask for the words a decision needs on record, and nothing is done until they are given.
Future<String?> askForReason(BuildContext context, {required String title, required String message, required String action}) =>
    showDialog<String>(context: context, builder: (_) => _ReasonDialog(title: title, message: message, action: action));

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.action});

  final String title;
  final String message;
  final String action;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reason'),
              controller: _reason,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Reason (kept on record)'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('reason-confirm'),
            onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
            child: Text(widget.action),
          ),
        ],
      );
}

AccountProvider? _providerOf(List<AccountProvider> providers, String code) {
  for (final p in providers) {
    if (p.code == code) return p;
  }
  return null;
}

// -- setting up one family's account -----------------------------------------------------------------------------

Future<bool?> showSetUpAccountDialog(
  BuildContext context, {
  required FamilyFeesApi api,
  required SchoolMembership membership,
  required FamilyRow family,
  required List<AccountProvider> providers,
  required List<BankConnection> connections,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _SetUpDialog(api: api, membership: membership, family: family, providers: providers, connections: connections),
    );

class _Fact {
  _Fact(String label, {this.fixed = false}) : label = TextEditingController(text: label);

  final TextEditingController label;
  final TextEditingController value = TextEditingController();
  final bool fixed;

  void dispose() {
    label.dispose();
    value.dispose();
  }
}

class _SetUpDialog extends StatefulWidget {
  const _SetUpDialog({
    required this.api,
    required this.membership,
    required this.family,
    required this.providers,
    required this.connections,
  });

  final FamilyFeesApi api;
  final SchoolMembership membership;
  final FamilyRow family;
  final List<AccountProvider> providers;
  final List<BankConnection> connections;

  @override
  State<_SetUpDialog> createState() => _SetUpDialogState();
}

class _SetUpDialogState extends State<_SetUpDialog> {
  static const _other = 'other';

  late final List<BankConnection> _connected = [for (final c in widget.connections) if (c.isConnected) c];
  bool _issue = false;
  BankConnection? _issueVia;
  String _providerCode = _other;
  BankConnection? _link;
  final _bank = TextEditingController();
  final _name = TextEditingController();
  final _number = TextEditingController();
  final List<_Fact> _facts = [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _issueVia = _connected.isEmpty ? null : _connected.first;
    _issue = _issueVia != null && _canIssue(_issueVia!);
    _pickProvider(widget.providers.isEmpty ? _other : widget.providers.first.code);
  }

  @override
  void dispose() {
    _bank.dispose();
    _name.dispose();
    _number.dispose();
    for (final f in _facts) {
      f.dispose();
    }
    super.dispose();
  }

  bool _canIssue(BankConnection c) => _providerOf(widget.providers, c.provider)?.canIssue ?? false;

  AccountShape get _shape => _providerOf(widget.providers, _providerCode)?.shape ?? AccountShape.generic;

  void _pickProvider(String code) {
    _providerCode = code;
    final provider = _providerOf(widget.providers, code);
    _bank.text = provider?.displayName ?? '';
    for (final f in _facts) {
      f.dispose();
    }
    _facts
      ..clear()
      ..addAll([for (final label in _shape.detailLabels) _Fact(label, fixed: true)]);
    final matches = [for (final c in _connected) if (c.provider == code) c];
    _link = matches.isEmpty ? null : matches.first;
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() {
    if (_issue) {
      return _run(() => widget.api.issueAccount(widget.membership, widget.family.id, _issueVia!.id));
    }
    final details = [
      for (final f in _facts)
        if (f.label.text.trim().isNotEmpty && f.value.text.trim().isNotEmpty) PayDetail(label: f.label.text.trim(), value: f.value.text.trim()),
    ];
    return _run(
      () => widget.api.recordAccount(
        widget.membership,
        widget.family.id,
        provider: _providerCode,
        bankName: _bank.text,
        accountName: _name.text,
        accountNumber: _number.text,
        details: details,
        connectionId: _link?.id,
      ),
    );
  }

  bool get _ready => _issue ? _issueVia != null && _canIssue(_issueVia!) : _number.text.trim().isNotEmpty && _bank.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Payment account for ${widget.family.displayName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One account for the whole family, however many children it has. The parent sees it as soon as it is ready.',
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                key: const ValueKey('setup-method'),
                segments: const [
                  ButtonSegment(value: true, label: Text('Ask the bank to issue it')),
                  ButtonSegment(value: false, label: Text('Record what the bank gave')),
                ],
                selected: {_issue},
                onSelectionChanged: (s) => setState(() => _issue = s.first),
              ),
              const SizedBox(height: 12),
              if (_issue) ..._issueForm() else ..._recordForm(),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, key: const ValueKey('setup-error'), style: const TextStyle(color: Color(0xFFB3261E)))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('setup-confirm'),
          onPressed: _busy || !_ready ? null : _submit,
          child: Text(_busy ? 'Working…' : (_issue ? 'Issue account' : 'Save account')),
        ),
      ],
    );
  }

  List<Widget> _issueForm() {
    if (_connected.isEmpty) {
      return const [Text('No bank account is connected yet. Connect one under Bank accounts, or record the account the bank gave this family.')];
    }
    final via = _issueVia!;
    final provider = _providerOf(widget.providers, via.provider);
    return [
      DropdownButtonFormField<BankConnection>(
        key: const ValueKey('issue-via'),
        initialValue: via,
        decoration: const InputDecoration(labelText: 'Under which of the school\'s bank accounts'),
        items: [for (final c in _connected) DropdownMenuItem(value: c, child: Text('${c.title} · ${c.bankTitle}'))],
        onChanged: (c) => setState(() => _issueVia = c),
      ),
      const SizedBox(height: 10),
      Text(
        _canIssue(via)
            ? 'SchoolOS will ask ${provider?.displayName ?? via.providerName} to issue an account for this family.'
            : '${provider?.displayName ?? via.providerName} cannot issue accounts for families yet: SchoolOS has not been given its verified '
                'documentation. Record the account the bank gave this family instead.',
        key: const ValueKey('issue-note'),
        style: TextStyle(color: _canIssue(via) ? null : const Color(0xFF8A6D00)),
      ),
    ];
  }

  List<Widget> _recordForm() {
    final shape = _shape;
    final matches = [for (final c in _connected) if (c.provider == _providerCode) c];
    return [
      DropdownButtonFormField<String>(
        key: const ValueKey('record-provider'),
        initialValue: _providerCode,
        decoration: const InputDecoration(labelText: 'Bank or provider'),
        items: [
          for (final p in widget.providers) DropdownMenuItem(value: p.code, child: Text(p.displayName)),
          const DropdownMenuItem(value: _other, child: Text('Another bank')),
        ],
        onChanged: (code) => setState(() => _pickProvider(code ?? _other)),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('record-bank'),
        controller: _bank,
        decoration: const InputDecoration(labelText: 'Bank name (as the family will see it)'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('record-number'),
        controller: _number,
        decoration: InputDecoration(
          labelText: shape.numberLabel,
          helperText: shape.numberExample.isEmpty ? 'Exactly as the bank gave it' : 'For example ${shape.numberExample}',
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      TextField(key: const ValueKey('record-name'), controller: _name, decoration: const InputDecoration(labelText: 'Account name (optional)')),
      ...[
        const SizedBox(height: 14),
        const Text('Anything else the payer must quote', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final (i, fact) in _facts.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('fact-label-$i'),
                    controller: fact.label,
                    readOnly: fact.fixed,
                    decoration: const InputDecoration(labelText: 'Label', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(key: ValueKey('fact-value-$i'), controller: fact.value, decoration: const InputDecoration(labelText: 'Value', isDense: true))),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _facts.removeAt(i).dispose()),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('add-fact'),
            onPressed: _facts.length >= 6 ? null : () => setState(() => _facts.add(_Fact(''))),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a fact (payment reference, sort code…)'),
          ),
        ),
      ],
      if (shape.payerNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Shown to the payer: ${shape.payerNote}')),
      if (matches.isNotEmpty) ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<BankConnection?>(
          key: const ValueKey('record-link'),
          initialValue: _link,
          decoration: const InputDecoration(labelText: 'Payments into it are read from'),
          items: [
            for (final c in matches) DropdownMenuItem<BankConnection?>(value: c, child: Text('${c.title} · ${c.bankTitle}')),
            const DropdownMenuItem<BankConnection?>(value: null, child: Text('Not linked to a connected account')),
          ],
          onChanged: (c) => setState(() => _link = c),
        ),
      ],
      const SizedBox(height: 8),
      Text(
        'SchoolOS credits this family automatically only when the school\'s connected bank reports which account a payment was made into. '
        'Any other payment waits in Review for a person.',
        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ];
  }
}

// -- issuing for everyone --------------------------------------------------------------------------------------

Future<bool?> showIssueAllDialog(
  BuildContext context, {
  required FamilyFeesApi api,
  required SchoolMembership membership,
  required List<AccountProvider> providers,
  required List<BankConnection> connections,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _IssueAllDialog(api: api, membership: membership, providers: providers, connections: connections),
    );

class _IssueAllDialog extends StatefulWidget {
  const _IssueAllDialog({required this.api, required this.membership, required this.providers, required this.connections});

  final FamilyFeesApi api;
  final SchoolMembership membership;
  final List<AccountProvider> providers;
  final List<BankConnection> connections;

  @override
  State<_IssueAllDialog> createState() => _IssueAllDialogState();
}

class _IssueAllDialogState extends State<_IssueAllDialog> {
  late final List<BankConnection> _connected = [for (final c in widget.connections) if (c.isConnected) c];
  BankConnection? _via;
  IssueReport? _report;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _via = _connected.isEmpty ? null : _connected.first;
  }

  bool get _can => _via != null && (_providerOf(widget.providers, _via!.provider)?.canIssue ?? false);

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = await widget.api.issueMissing(widget.membership, _via!.id);
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return AlertDialog(
      title: const Text('Issue accounts for every family'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (report != null) ...[
                Text(
                  report.issued == 0 ? 'No account was issued.' : 'Issued ${report.issued} account${report.issued == 1 ? '' : 's'}.',
                  key: const ValueKey('issue-all-result'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (report.failed.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('${report.failed.length} could not be issued:'),
                  for (final f in report.failed) Text('• ${f.familyName}: ${f.message}'),
                ],
              ] else if (_connected.isEmpty)
                const Text('No bank account is connected yet. Connect one under Bank accounts first.')
              else ...[
                const Text('Every active family that has no account at this bank is given one. A family that already has one is left alone.'),
                const SizedBox(height: 12),
                DropdownButtonFormField<BankConnection>(
                  key: const ValueKey('issue-all-via'),
                  initialValue: _via,
                  decoration: const InputDecoration(labelText: 'Under which of the school\'s bank accounts'),
                  items: [for (final c in _connected) DropdownMenuItem(value: c, child: Text('${c.title} · ${c.bankTitle}'))],
                  onChanged: (c) => setState(() => _via = c),
                ),
                if (!_can)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'This bank cannot issue accounts for families yet: SchoolOS has not been given its verified documentation. '
                      'Record each family\'s account by hand instead.',
                      key: ValueKey('issue-all-cannot'),
                      style: TextStyle(color: Color(0xFF8A6D00)),
                    ),
                  ),
              ],
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
            ],
          ),
        ),
      ),
      actions: [
        if (report != null)
          FilledButton(onPressed: () => Navigator.of(context).pop(report.issued > 0), child: const Text('Done'))
        else ...[
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('issue-all-confirm'), onPressed: _busy || !_can ? null : _run, child: Text(_busy ? 'Working…' : 'Issue accounts')),
        ],
      ],
    );
  }
}

// -- merging two families ---------------------------------------------------------------------------------------

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
          'Accounts at ${p.accountsKept.join(', ')} stay where they are (a family holds one per bank) and keep crediting the merged family, '
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
