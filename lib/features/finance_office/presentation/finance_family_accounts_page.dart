import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_billing.dart';
import '../data/finance_ledger_repository.dart';
import '../domain/finance_ledger_models.dart';
import 'finance_fee_dialogs.dart';

/// Every student's account for the term: what is charged, what scholarships and discounts take off, what has been paid, and
/// what is still owed. Payments are recorded here.
class FinanceFamilyAccountsPage extends StatefulWidget {
  const FinanceFamilyAccountsPage({super.key, required this.ledger, this.onChanged});

  final FinanceLedgerRepository ledger;
  final VoidCallback? onChanged;

  @override
  State<FinanceFamilyAccountsPage> createState() => _FinanceFamilyAccountsPageState();
}

class _FinanceFamilyAccountsPageState extends State<FinanceFamilyAccountsPage> with SyncRefresh<FinanceFamilyAccountsPage> {
  List<StudentAccount> _accounts = const [];
  String _search = '';
  AccountStatus? _filter;
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
      final accounts = await widget.ledger.accounts();
      if (!mounted) return;
      setState(() {
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

  List<StudentAccount> get _shown {
    final q = _search.trim().toLowerCase();
    return [
      for (final a in _accounts)
        if ((_filter == null || a.status == _filter) &&
            (q.isEmpty || a.student.name.toLowerCase().contains(q) || a.student.className.toLowerCase().contains(q) || a.student.id.toLowerCase().contains(q)))
          a,
    ];
  }

  Future<void> _pay(StudentAccount account) async {
    final choice = await askPayment(context, student: account.student, balance: account.balance);
    if (choice == null) return;
    final result = await widget.ledger.recordPayment(
      student: account.student,
      amount: choice.amount,
      method: choice.method,
      reference: choice.reference,
      note: choice.note,
    );
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
    final shown = _shown;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · STUDENT ACCOUNTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Student Accounts', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Fees for $financeCurrentTerm. Record a payment against the child it is for; it gets a numbered receipt.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Kpi('Net collectible', formatNaira(totals.net), '${_accounts.length} students'),
            _Kpi('Collected', formatNaira(totals.paid), '${totals.collectedPercent}% of net'),
            _Kpi('Still owed', formatNaira(totals.balance), '${_accounts.where((a) => a.balance > 0).length} accounts'),
            _Kpi('Fully paid', '${_accounts.where((a) => a.status == AccountStatus.paid).length}', 'Accounts settled'),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                key: const ValueKey('accounts-search'),
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), labelText: 'Search name, class or ID', isDense: true),
              ),
            ),
            for (final entry in const [
              (null, 'All'),
              (AccountStatus.unpaid, 'Unpaid'),
              (AccountStatus.partPaid, 'Part paid'),
              (AccountStatus.paid, 'Paid'),
            ])
              ChoiceChip(
                key: ValueKey('accounts-filter-${entry.$2}'),
                label: Text(entry.$2),
                selected: _filter == entry.$1,
                onSelected: (_) => setState(() => _filter = entry.$1),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No student matches.')),
        for (final a in shown)
          Card(
            key: ValueKey('account-${a.student.id}'),
            elevation: 0,
            child: ListTile(
              title: Text(a.student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${a.student.className} · ${a.student.id}\n'
                'Net ${formatNaira(a.net)}${a.concession > 0 ? ' (after ${formatNaira(a.concession)} scholarship/discount)' : ''} · Paid ${formatNaira(a.paid)}',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(a.statusLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('Owes ${formatNaira(a.balance < 0 ? 0 : a.balance)}', style: theme.textTheme.bodySmall),
                ],
              ),
              onTap: () => _open(a),
            ),
          ),
      ],
    );
  }

  Future<void> _open(StudentAccount a) async {
    final pay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(a.student.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.student.className} · ${a.section} · $financeCurrentTerm'),
                const SizedBox(height: 10),
                _Line('Fees charged', formatNaira(a.gross)),
                _Line('Scholarships & discounts', '- ${formatNaira(a.gross - a.net)}'),
                _Line('Net to pay', formatNaira(a.net)),
                _Line('Paid', formatNaira(a.paid)),
                _Line('Still owed', formatNaira(a.balance < 0 ? 0 : a.balance), bold: true),
                const SizedBox(height: 12),
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.w900)),
                if (a.payments.isEmpty) const Text('None yet.'),
                for (final p in a.payments)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${p.receiptNumber} · ${p.receivedAt.split('T').first} · ${formatNaira(p.amount)} · ${p.method}${p.isVoided ? ' · VOIDED (${p.voidedReason})' : ''}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
          if (a.balance > 0 && a.status != AccountStatus.noFees)
            FilledButton(key: const ValueKey('account-pay'), onPressed: () => Navigator.pop(context, true), child: const Text('Record payment')),
        ],
      ),
    );
    if (pay == true && mounted) await _pay(a);
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      );
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
