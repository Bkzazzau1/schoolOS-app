import '../../../core/sync/sync_scope.dart';
import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_staff_models.dart';
import '../../finance_office/domain/finance_payroll_models.dart';
import '../../finance_office/presentation/payroll_batch_panel.dart';
import '../data/owner_payroll_repository.dart';
import '../data/payroll_batch_repository.dart';

class OwnerPayrollPage extends StatefulWidget {
  const OwnerPayrollPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final OwnerPayrollRepository repository;
  final VoidCallback onChanged;

  @override
  State<OwnerPayrollPage> createState() => _OwnerPayrollPageState();
}

class _OwnerPayrollPageState extends State<OwnerPayrollPage> {
  PayrollSnapshot? _snapshot;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _editSalary(AdministratorStaffRecord person) async {
    final current = _snapshot?.profiles[person.id];
    final gross = TextEditingController(
      text: current == null ? '' : '${current.gross}',
    );
    final deductions = TextEditingController(
      text: current == null ? '' : '${current.deductions}',
    );
    var onPayroll = current?.onPayroll ?? true;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Salary · ${person.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: gross,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly gross salary (₦)',
                  ),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Enter a number.' : null,
                ),
                TextFormField(
                  controller: deductions,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Approved deductions (₦)',
                  ),
                  validator: (v) {
                    final d = int.tryParse(v ?? '');
                    if (d == null) return 'Enter a number (0 if none).';
                    if (d > (int.tryParse(gross.text) ?? 0)) {
                      return 'Deductions cannot exceed gross.';
                    }
                    return null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('On payroll'),
                  value: onPayroll,
                  onChanged: (v) => setLocal(() => onPayroll = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final grossValue = int.tryParse(gross.text) ?? 0;
    final deductionValue = int.tryParse(deductions.text) ?? 0;
    gross.dispose();
    deductions.dispose();
    if (saved != true) return;
    await _run(
      () => widget.repository.saveSalary(
        person: person,
        gross: grossValue,
        deductions: deductionValue,
        onPayroll: onPayroll,
      ),
      'Salary saved on this device and queued for sync. History is kept.',
    );
  }

  Future<void> _editAuthorizer(AdministratorStaffRecord person) async {
    final existing = _snapshot?.authorizers
        .where((a) => a.id == person.id && a.isActive)
        .firstOrNull;
    final chosen = <String>{...?existing?.authorities};
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Payroll authority · ${person.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in payrollAuthorityLabels.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  value: chosen.contains(entry.key),
                  onChanged: (v) => setLocal(() {
                    v == true ? chosen.add(entry.key) : chosen.remove(entry.key);
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Grant'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    await _run(
      () => widget.repository.saveAuthorizer(
        person: person,
        authorities: chosen,
      ),
      'Authority recorded. Account access remains pending activation.',
    );
  }

  void _showInvoice(PayrollSnapshot snapshot) {
    final month = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final rows = snapshot.onPayroll.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payroll invoice · ${months[month.month - 1]} ${month.year}'),
        content: SizedBox(
          width: 560,
          child: rows.isEmpty
              ? const Text('No staff are on payroll yet.')
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in rows)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.name),
                          subtitle: Text(
                            'Gross ${financePayrollMoney(p.gross)} − '
                            'deductions ${financePayrollMoney(p.deductions)}',
                          ),
                          trailing: Text(
                            financePayrollMoney(p.net),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      const Divider(),
                      _totalRow('Total gross', snapshot.totalGross),
                      _totalRow('Total deductions', snapshot.totalDeductions),
                      _totalRow('Net payable', snapshot.totalNet, bold: true),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          financePayrollMoney(amount),
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Payroll & Salaries', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Set each staff member’s salary, put them on payroll, review the payroll invoice and choose who may prepare, approve or make payments.',
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Changes are saved on this device and queued for sync, with salary history kept. This page does not move money, and payroll authority is a recorded instruction, not an activated login. Paid status needs real bank or payment evidence.',
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (snapshot != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi('On payroll', '${snapshot.onPayroll.length}'),
                _kpi('Gross', financePayrollMoney(snapshot.totalGross)),
                _kpi('Deductions', financePayrollMoney(snapshot.totalDeductions)),
                _kpi('Net payable', financePayrollMoney(snapshot.totalNet)),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _showInvoice(snapshot),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View payroll invoice'),
              ),
            ),
            const SizedBox(height: 16),
            PayrollBatchPanel(
              repository: PayrollBatchRepository(confirm: ServerConfirmScope.maybeOf(context), 
                database: widget.repository.database,
                session: widget.repository.session,
              ),
              onChanged: widget.onChanged,
            ),
            const SizedBox(height: 24),
            Text('Staff salaries', style: theme.textTheme.titleLarge),
            for (final person in snapshot.staff)
              _salaryTile(snapshot, person),
            const SizedBox(height: 24),
            Text('Approvers and payment authority', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Assign someone to approve new staff proposals, or to prepare, approve and release payroll payments. Nobody can approve what they proposed or prepared themselves.',
            ),
            for (final a in snapshot.authorizers.where((a) => a.isActive))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(a.name),
                subtitle: Text(
                  a.authorities
                      .map((k) => payrollAuthorityLabels[k] ?? k)
                      .join(' · '),
                ),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => widget.repository.revokeAuthorizer(a.id),
                          'Authority revoked.',
                        ),
                  child: const Text('Revoke'),
                ),
              ),
            if (!snapshot.authorizers.any((a) => a.isActive))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No authorizers assigned yet.'),
              ),
            const SizedBox(height: 8),
            PopupMenuButton<AdministratorStaffRecord>(
              enabled: !_busy,
              onSelected: _editAuthorizer,
              itemBuilder: (context) => [
                for (final person in snapshot.staff)
                  PopupMenuItem(value: person, child: Text(person.name)),
              ],
              child: const IgnorePointer(
                child: FilledButton(
                  onPressed: null,
                  child: Text('Assign approval authority'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _salaryTile(PayrollSnapshot snapshot, AdministratorStaffRecord person) {
    final profile = snapshot.profiles[person.id];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(person.name),
      subtitle: Text(
        profile == null
            ? '${person.role} · No salary set'
            : '${person.role} · Gross ${financePayrollMoney(profile.gross)} · '
                  'Net ${financePayrollMoney(profile.net)} · '
                  '${profile.onPayroll ? 'On payroll' : 'Not on payroll'}',
      ),
      trailing: TextButton(
        onPressed: _busy ? null : () => _editSalary(person),
        child: Text(profile == null ? 'Set salary' : 'Edit'),
      ),
    );
  }

  Widget _kpi(String label, String value) => SizedBox(
    width: 200,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    ),
  );
}
