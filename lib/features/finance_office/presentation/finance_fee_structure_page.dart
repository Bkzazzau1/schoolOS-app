import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_billing.dart';
import '../data/finance_ledger_repository.dart';
import '../domain/finance_ledger_models.dart';
import 'finance_fee_dialogs.dart';

/// What each section is charged for a term. Changing it re-bills every student in that section.
class FinanceFeeStructurePage extends StatefulWidget {
  const FinanceFeeStructurePage({super.key, required this.ledger, this.onChanged});

  final FinanceLedgerRepository ledger;
  final VoidCallback? onChanged;

  @override
  State<FinanceFeeStructurePage> createState() => _FinanceFeeStructurePageState();
}

class _FinanceFeeStructurePageState extends State<FinanceFeeStructurePage> with SyncRefresh<FinanceFeeStructurePage> {
  String _term = financeCurrentTerm;
  List<FeeStructure> _structures = const [];
  List<StudentAccount> _accounts = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final structures = await widget.ledger.structures(_term);
      final accounts = await widget.ledger.accounts(_term);
      if (!mounted) return;
      setState(() {
        _structures = structures;
        _accounts = accounts;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit(FeeStructure structure) async {
    final items = await askFeeItems(context, section: structure.section, term: _term, items: structure.items);
    if (items == null) return;
    final result = await widget.ledger.saveStructure(term: _term, section: structure.section, items: items);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    final theme = Theme.of(context);
    final totals = totalsOf(_accounts);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · BILLING POLICY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Fee Structure', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('What each section is charged for the term. Changing a section re-bills every student in it. Scholarships and discounts reduce what a family owes; they are not debt.'),
        const SizedBox(height: 14),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('fee-term'),
            initialValue: _term,
            decoration: const InputDecoration(labelText: 'Term'),
            items: [for (final t in financeTerms) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _term = v;
                _loading = true;
              });
              _load();
            },
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Billing population', '${_accounts.length}', 'Students on the register'),
            _Kpi('Gross fees', formatNaira(totals.gross), 'Before scholarships and discounts'),
            _Kpi('Net collectible', formatNaira(totals.net), 'What families owe this term'),
            _Kpi('Collected', formatNaira(totals.paid), '${totals.collectedPercent}% of net'),
          ],
        ),
        const SizedBox(height: 18),
        for (final s in _structures) ...[
          Card(
            key: ValueKey('structure-${s.section}'),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.section} · ${_accounts.where((a) => a.section == s.section).length} students',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('edit-${s.section}'),
                        onPressed: () => _edit(s),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit fees'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final i in s.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [Expanded(child: Text(i.name)), Text(formatNaira(i.amount))]),
                    ),
                  const Divider(height: 22),
                  Row(
                    children: [
                      const Expanded(child: Text('Total per student', style: TextStyle(fontWeight: FontWeight.w900))),
                      Text(formatNaira(s.total), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Optional charges (transport, meals, boarding, books) are not billed yet. They will be added as their own charges, never merged into tuition silently.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
