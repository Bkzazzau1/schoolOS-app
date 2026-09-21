import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_aging.dart';
import '../data/finance_billing.dart';
import '../data/finance_ledger_repository.dart';
import '../domain/finance_ledger_models.dart';

/// Reminders to families who owe. Each is firmer than the last, a family is not reminded again within a few days, and the
/// words never guess why fees are unpaid. The app queues them; the school server sends them.
class FinanceRemindersPage extends StatefulWidget {
  const FinanceRemindersPage({super.key, required this.ledger, required this.schoolName, this.onChanged});

  final FinanceLedgerRepository ledger;
  final String schoolName;
  final VoidCallback? onChanged;

  @override
  State<FinanceRemindersPage> createState() => _FinanceRemindersPageState();
}

class _FinanceRemindersPageState extends State<FinanceRemindersPage> with SyncRefresh<FinanceRemindersPage> {
  AgingReport? _report;
  List<FeeReminder> _reminders = const [];
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
      final report = await widget.ledger.aging();
      final reminders = await widget.ledger.reminders();
      if (!mounted) return;
      setState(() {
        _report = report;
        _reminders = reminders;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _queue(StudentAccount account) async {
    final mine = _reminders.where((r) => r.studentId == account.student.id).length;
    final level = (mine + 1).clamp(1, 3);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${reminderLevelNames[level]} · ${account.student.name}'),
        content: SelectableText(reminderMessage(
          level: level,
          guardian: account.student.primaryGuardian,
          student: account.student.name,
          balance: account.balance,
          term: financeCurrentTerm,
          school: widget.schoolName,
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('reminder-confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Queue reminder')),
        ],
      ),
    );
    if (ok != true) return;
    final result = await widget.ledger.queueReminder(account, schoolName: widget.schoolName);
    _say(result.message);
    if (result.success) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _queueAll() async {
    final count = await widget.ledger.queueAllReminders(schoolName: widget.schoolName);
    _say(count == 0 ? 'Nobody can be reminded right now.' : '$count reminders queued.');
    if (count > 0) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (report == null) {
      return Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final theme = Theme.of(context);
    FeeReminder? lastFor(String id) {
      for (final r in _reminders) {
        if (r.studentId == id) return r;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('FINANCE OFFICE · REMINDERS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Fee Reminders', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(report.overdue
            ? '${report.owing.length} accounts owe ${formatNaira(report.outstanding)} and are ${report.days} days overdue.'
            : 'Fees are not overdue yet, so no reminders can be queued.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('reminders-all'),
          onPressed: report.overdue && report.owing.isNotEmpty ? _queueAll : null,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Queue reminders for everyone who can be reminded'),
        ),
        const SizedBox(height: 4),
        Text(
          'Reminders are queued here and sent by the school server. Levels go from friendly to second to final notice, at least ${FinanceLedgerRepository.reminderGapDays} days apart.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text('Who owes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (report.owing.isEmpty) const Text('Nobody owes anything.'),
        for (final a in report.owing)
          Card(
            key: ValueKey('remind-${a.student.id}'),
            elevation: 0,
            child: ListTile(
              title: Text(a.student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${a.student.className} · owes ${formatNaira(a.balance)}\n'
                '${lastFor(a.student.id) == null ? 'Not reminded yet' : '${reminderLevelNames[lastFor(a.student.id)!.level]} queued ${lastFor(a.student.id)!.queuedAt.split('T').first}'}',
              ),
              isThreeLine: true,
              trailing: TextButton(
                key: ValueKey('remind-button-${a.student.id}'),
                onPressed: report.overdue ? () => _queue(a) : null,
                child: const Text('Remind'),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text('Queued reminders', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (_reminders.isEmpty) const Text('None yet.'),
        for (final r in _reminders.take(30))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${reminderLevelNames[r.level]} · ${r.studentName}'),
            subtitle: Text('${r.queuedAt.split('T').first} · owed ${formatNaira(r.balance)} · waiting to be sent'),
          ),
      ],
    );
  }
}
