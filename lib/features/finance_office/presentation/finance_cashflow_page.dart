import 'package:flutter/material.dart';

import '../data/finance_cashflow_repository.dart';
import '../domain/finance_cashflow_models.dart';
import '../domain/finance_concessions_models.dart' show financeMoney;

class FinanceCashflowPage extends StatefulWidget {
  const FinanceCashflowPage({super.key, required this.repository, this.onChanged});

  final FinanceCashflowRepository repository;
  final VoidCallback? onChanged;

  @override
  State<FinanceCashflowPage> createState() => _FinanceCashflowPageState();
}

class _FinanceCashflowPageState extends State<FinanceCashflowPage> {
  List<CashflowEntry> _entries = const [];
  bool _canApprove = false;
  bool _loading = true;
  String? _error;
  String? _notice;
  bool _showForm = false;
  String _filter = 'All';

  static const _filters = <String>['All', 'Income', 'Expense', 'Pending approval', 'Approved', 'Declined'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.repository.entries();
      final canApprove = await widget.repository.canApprove();
      if (!mounted) return;
      setState(() { _entries = entries; _canApprove = canApprove; _loading = false; _error = null; });
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _loading = false; });
    }
  }

  List<CashflowEntry> get _shown {
    if (_filter == 'All') return _entries;
    return _entries.where((e) => cashflowTypeLabel(e.type) == _filter || cashflowStatusLabel(e.status) == _filter).toList(growable: false);
  }

  Future<void> _submit(DateTime date, String description, CashflowType type, String category, int amount) async {
    final result = await widget.repository.recordEntry(date: date, description: description, type: type, category: category, amount: amount);
    if (!mounted) return;
    setState(() { _notice = result.message; if (result.success) _showForm = false; });
    if (result.success) { widget.onChanged?.call(); await _load(); }
  }

  Future<void> _decide(CashflowEntry entry, bool approve) async {
    String note = '';
    if (!approve) {
      final typed = await _askReason(context);
      if (typed == null) return;
      note = typed;
    }
    final result = await widget.repository.decide(entry, approve: approve, note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) { widget.onChanged?.call(); await _load(); }
  }

  Future<String?> _askReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this expense'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim().isEmpty ? null : controller.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text('Could not load the cash flow ledger. $_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }
    final theme = Theme.of(context);
    final income = _entries.where((e) => e.type == CashflowType.income && e.status == CashflowStatus.posted);
    final expense = _entries.where((e) => e.type == CashflowType.expense && e.status == CashflowStatus.approved);
    final pending = _entries.where((e) => e.isPending);
    final shown = _shown;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('FINANCE OFFICE · EXPENSES & INCOME', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Expenses & Income', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("The school's own money, outside the fee ledger - a donation, a facility rental, paying for repairs. Income posts right away; an expense needs a billing authority's approval first."),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _Kpi('Income (posted)', financeMoney(income.fold(0, (s, e) => s + e.amount))),
          _Kpi('Expenses (approved)', financeMoney(expense.fold(0, (s, e) => s + e.amount))),
          _Kpi('Pending approval', '${pending.length}'),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _filter,
              decoration: const InputDecoration(labelText: 'Filter'),
              items: [for (final f in _filters) DropdownMenuItem(value: f, child: Text(f))],
              onChanged: (v) { if (v != null) setState(() => _filter = v); },
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('cashbook-add-entry'),
            onPressed: () => setState(() { _showForm = !_showForm; _notice = null; }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record entry'),
          ),
        ]),
        if (_notice != null) ...[const SizedBox(height: 10), _Notice(text: _notice!)],
        if (_showForm) ...[const SizedBox(height: 14), _EntryForm(onSubmit: _submit)],
        const SizedBox(height: 18),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No entries match this filter.')),
        for (final entry in shown)
          Card(
            key: ValueKey('cashbook-entry-${entry.id}'),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(entry.description, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${entry.date} · ${cashflowTypeLabel(entry.type)} · ${entry.category}'
                            '${entry.decisionNote != null ? '\n${entry.decisionNote}' : ''}'),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Text(financeMoney(entry.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Chip(label: Text(cashflowStatusLabel(entry.status))),
                  if (entry.isPending && _canApprove) ...[
                    TextButton(key: ValueKey('cashbook-decline-${entry.id}'), onPressed: () => _decide(entry, false), child: const Text('Decline')),
                    FilledButton(key: ValueKey('cashbook-approve-${entry.id}'), onPressed: () => _decide(entry, true), child: const Text('Approve')),
                  ],
                ]),
              ]),
            ),
          ),
      ],
    );
  }
}

class _EntryForm extends StatefulWidget {
  const _EntryForm({required this.onSubmit});
  final Future<void> Function(DateTime date, String description, CashflowType type, String category, int amount) onSubmit;

  @override
  State<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<_EntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  CashflowType _type = CashflowType.expense;
  String _category = cashflowCategories.first;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Record income or an expense', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<CashflowType>(
                    key: const ValueKey('cashbook-type'),
                    isExpanded: true,
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [for (final t in CashflowType.values) DropdownMenuItem(value: t, child: Text(cashflowTypeLabel(t)))],
                    onChanged: (v) { if (v != null) setState(() => _type = v); },
                  ),
                ),
                SizedBox(width: 260, child: TextFormField(key: const ValueKey('cashbook-description'), controller: _description, decoration: const InputDecoration(labelText: 'Description'), validator: _required)),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('cashbook-category'),
                    isExpanded: true,
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [for (final c in cashflowCategories) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) { if (v != null) setState(() => _category = v); },
                  ),
                ),
                SizedBox(width: 180, child: TextFormField(key: const ValueKey('cashbook-amount'), controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₦)'), validator: _positive)),
                OutlinedButton.icon(
                  key: const ValueKey('cashbook-date'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
                ),
              ]),
              const SizedBox(height: 14),
              FilledButton(
                key: const ValueKey('cashbook-submit'),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSubmit(_date, _description.text, _type, _category, int.parse(_amount.text));
                },
                child: Text(_type == CashflowType.income ? 'Post income' : 'Send for approval'),
              ),
            ]),
          ),
        ),
      );

  static String? _required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;
  static String? _positive(String? v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount above zero' : null;
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 210,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ]),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}
