import 'package:flutter/material.dart';

import '../data/finance_reminders_demo_data.dart';
import '../domain/finance_reminders_models.dart';

class FinanceRemindersPage extends StatefulWidget {
  const FinanceRemindersPage({super.key});

  @override
  State<FinanceRemindersPage> createState() => _FinanceRemindersPageState();
}

class _FinanceRemindersPageState extends State<FinanceRemindersPage> {
  late List<FinanceReminderRow> _rows;
  String _filter = 'All';
  late String _selectedId;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _rows = List<FinanceReminderRow>.from(financeReminderSeed);
    _selectedId = _rows.first.id;
  }

  List<FinanceReminderRow> get _visible => _filter == 'All'
      ? _rows
      : _rows.where((row) => row.status.label == _filter).toList();

  FinanceReminderRow get _current => _rows.firstWhere(
        (row) => row.id == _selectedId,
        orElse: () => _rows.first,
      );

  void _select(FinanceReminderRow row) {
    setState(() {
      _selectedId = row.id;
      _notice = null;
    });
  }

  void _sendNow() {
    final current = _current;
    setState(() {
      _rows = [
        for (final row in _rows)
          if (row.id == current.id)
            row.copyWith(status: FinanceReminderStatus.sent)
          else
            row,
      ];
      _notice = 'Reminder for ${current.student} marked sent locally.';
    });
  }

  void _skip() {
    final current = _current;
    setState(() {
      _rows = [
        for (final row in _rows)
          if (row.id == current.id)
            row.copyWith(status: FinanceReminderStatus.skipped)
          else
            row,
      ];
      _notice = 'Reminder for ${current.student} suppressed locally.';
    });
  }

  void _prototypeNotice(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is still a website prototype action.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onPrototype: _prototypeNotice),
        const SizedBox(height: 18),
        const _KpiWrap(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 920;
            final queue = _ReminderQueueCard(
              rows: _visible,
              selectedId: _selectedId,
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
              onSelected: _select,
            );
            final detail = _ReminderDetailCard(
              row: current,
              notice: _notice,
              onSendNow: _sendNow,
              onSkip: _skip,
              onOpenFamily: () => _prototypeNotice('Open family account'),
            );
            if (narrow) {
              return Column(
                children: [queue, const SizedBox(height: 18), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: queue),
                const SizedBox(width: 18),
                Expanded(child: detail),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return const Column(
                children: [
                  _EscalationCard(),
                  SizedBox(height: 18),
                  _SuppressionCard(),
                ],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _EscalationCard()),
                SizedBox(width: 18),
                Expanded(child: _SuppressionCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const _HistoryCard(),
        const SizedBox(height: 14),
        const _BoundaryCallout(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPrototype});
  final ValueChanged<String> onPrototype;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCE OFFICE · SCHOOL FEE REMINDERS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fee Reminder Center',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send the right reminder based on the family’s actual balance, payment arrangement, mandate status and next expected payment.',
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () => onPrototype('Reminder rules'),
              child: const Text('Reminder rules'),
            ),
            FilledButton.icon(
              onPressed: () => onPrototype('Create campaign'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create campaign'),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: title),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiWrap extends StatelessWidget {
  const _KpiWrap();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      _Kpi('Due in 7 days', '$financeReminderDueIn7Days', 'Families with upcoming obligations'),
      _Kpi('Mandate-backed', '$financeReminderMandateBacked', 'Use softer scheduled-debit wording'),
      _Kpi('Payment-plan families', '$financeReminderPaymentPlanFamilies', 'Remind only agreed instalment'),
      _Kpi('No arrangement', '$financeReminderNoArrangement', 'Needs finance follow-up'),
      _Kpi('Suppressed today', '$financeReminderSuppressedToday', 'Financing, recent payment or manual pause'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 1180
            ? (width - 48) / 5
            : width >= 720
                ? (width - 24) / 3
                : width;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: itemWidth, child: card)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.hint);
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReminderQueueCard extends StatelessWidget {
  const _ReminderQueueCard({
    required this.rows,
    required this.selectedId,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelected,
  });

  final List<FinanceReminderRow> rows;
  final String selectedId;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<FinanceReminderRow> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Reminder queue',
      subtitle: 'Collection-aware messages, not blanket debt notifications.',
      trailing: SizedBox(
        width: 155,
        child: DropdownButtonFormField<String>(
          initialValue: filter,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true, labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
            DropdownMenuItem(value: 'Sent', child: Text('Sent')),
            DropdownMenuItem(value: 'Skipped', child: Text('Skipped')),
            DropdownMenuItem(value: 'Needs review', child: Text('Needs review')),
          ],
          onChanged: (value) {
            if (value != null) onFilterChanged(value);
          },
        ),
      ),
      child: rows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No reminders match this status.')),
            )
          : Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: row.id == selectedId
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onSelected(row),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row.student, style: const TextStyle(fontWeight: FontWeight.w900)),
                                        Text('${row.className} · ${row.guardian}'),
                                        Text(row.arrangement, style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _StatusChip(status: row.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('${financeReminderMoney(row.balance)} outstanding', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ReminderDetailCard extends StatelessWidget {
  const _ReminderDetailCard({
    required this.row,
    required this.notice,
    required this.onSendNow,
    required this.onSkip,
    required this.onOpenFamily,
  });

  final FinanceReminderRow row;
  final String? notice;
  final VoidCallback onSendNow;
  final VoidCallback onSkip;
  final VoidCallback onOpenFamily;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: row.student,
      subtitle: '${row.guardian} · ${row.className}',
      trailing: _StatusChip(status: row.status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Outstanding school-fee balance'),
                const SizedBox(height: 4),
                Text(financeReminderMoney(row.balance), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(row.arrangement),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FactGrid(row: row),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MESSAGE PREVIEW', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(financeReminderPreview(row)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(onPressed: onSendNow, child: const Text('Send now')),
              OutlinedButton(onPressed: onSkip, child: const Text('Suppress reminder')),
              TextButton(onPressed: onOpenFamily, child: const Text('Open family account')),
            ],
          ),
          if (notice != null) ...[
            const SizedBox(height: 10),
            _Notice(text: notice!),
          ],
          const SizedBox(height: 10),
          Text(financeReminderDeliveryBoundary, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.row});
  final FinanceReminderRow row;

  @override
  Widget build(BuildContext context) {
    final amount = row.nextAmount > 0 ? financeReminderMoney(row.nextAmount) : 'Handled by active workflow';
    final facts = [
      ('Next expected payment', amount),
      ('Expected date', row.nextDate),
      ('Channels', row.channels),
      ('Why this reminder?', row.reason),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 560 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final fact in facts)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fact.$1, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(fact.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EscalationCard extends StatelessWidget {
  const _EscalationCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Reminder escalation',
      subtitle: 'Suggested timing around an agreed due date.',
      child: Column(
        children: [
          for (var i = 0; i < financeReminderStages.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(financeReminderStages[i].when, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(financeReminderStages[i].message),
            ),
        ],
      ),
    );
  }
}

class _SuppressionCard extends StatelessWidget {
  const _SuppressionCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Smart suppression rules',
      subtitle: 'Prevent noisy or misleading reminders.',
      child: Column(
        children: [
          for (final rule in financeReminderSuppressionRules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${rule.detail}\n${rule.hint}'),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Communication history',
      subtitle: 'Finance can see what was sent, when, through which channel and why.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: [
                for (final item in financeReminderHistory)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.when, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${item.recipient}\n${item.summary}'),
                    trailing: Text(item.status, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('When')),
                DataColumn(label: Text('Recipient / channel')),
                DataColumn(label: Text('Message context')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final item in financeReminderHistory)
                  DataRow(cells: [
                    DataCell(Text(item.when, style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(item.recipient)),
                    DataCell(Text(item.summary)),
                    DataCell(Text(item.status)),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(financeReminderAcademicBoundary, style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Text(financeReminderPrototypeBoundary),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final FinanceReminderStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status.label));
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.subtitle, required this.child, this.trailing});
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: trailing!),
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
