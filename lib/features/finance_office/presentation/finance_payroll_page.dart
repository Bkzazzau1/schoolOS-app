import 'package:flutter/material.dart';

import '../data/finance_payroll_demo_data.dart';
import '../domain/finance_payroll_models.dart';

class FinancePayrollPage extends StatefulWidget {
  const FinancePayrollPage({super.key});

  @override
  State<FinancePayrollPage> createState() => _FinancePayrollPageState();
}

class _FinancePayrollPageState extends State<FinancePayrollPage> {
  String? _notice;

  void _prepareBatch() {
    final ready = financePayrollRows.where((row) => row.isReady).toList();
    final held = financePayrollRows.where((row) => row.needsAttendanceReview).toList();
    final readyValue = ready.fold<int>(0, (sum, row) => sum + row.net);
    setState(() {
      _notice =
          'Payment batch preview prepared from ${ready.length} ready sample records (${financePayrollMoney(readyValue)}). ${held.length} attendance-review record remains held. No salary has been marked Paid and no money has been sent.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onPrepare: _prepareBatch),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          _Notice(text: _notice!),
        ],
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        const _PayrollRegister(),
        const SizedBox(height: 16),
        const _RulesGrid(),
        const SizedBox(height: 16),
        const _AuditBoundary(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPrepare});

  final VoidCallback onPrepare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINANCE OFFICE · PAYROLL HANDOFF',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Payroll Processing',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Receive HR-approved payroll figures plus a reviewed attendance summary, confirm payment batches and preserve payroll audit records.',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onPrepare,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Prepare payment batch'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis();

  @override
  Widget build(BuildContext context) {
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
          children: [
            for (final item in financePayrollKpis)
              SizedBox(
                width: itemWidth,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label),
                        const SizedBox(height: 6),
                        Text(
                          item.value,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(item.hint, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PayrollRegister extends StatelessWidget {
  const _PayrollRegister();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Payroll handoff register',
      subtitle:
          'Finance receives verified attendance context; HR/leadership retains responsibility for employment and pay decisions.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 860) {
            return Column(
              children: [
                for (final row in financePayrollRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MobilePayrollRow(row: row),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 64,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('Staff')),
                DataColumn(label: Text('Expected')),
                DataColumn(label: Text('Present')),
                DataColumn(label: Text('Leave')),
                DataColumn(label: Text('Unexplained')),
                DataColumn(label: Text('Gross')),
                DataColumn(label: Text('Deductions')),
                DataColumn(label: Text('Net')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final row in financePayrollRows)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.name,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(row.staffId, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text('${row.expectedDays}')),
                      DataCell(Text('${row.presentDays}')),
                      DataCell(Text('${row.leaveDays}')),
                      DataCell(Text('${row.unexplainedDays}')),
                      DataCell(Text(financePayrollMoney(row.gross))),
                      DataCell(Text(financePayrollMoney(row.deductions))),
                      DataCell(
                        Text(
                          financePayrollMoney(row.net),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      DataCell(_StatusPill(status: row.status)),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MobilePayrollRow extends StatelessWidget {
  const _MobilePayrollRow({required this.row});

  final FinancePayrollRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
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
                    Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(row.staffId, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: row.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Expected ${row.expectedDays}')),
              Chip(label: Text('Present ${row.presentDays}')),
              Chip(label: Text('Leave ${row.leaveDays}')),
              Chip(label: Text('Unexplained ${row.unexplainedDays}')),
            ],
          ),
          const SizedBox(height: 10),
          Text('Gross ${financePayrollMoney(row.gross)}'),
          Text('Deductions ${financePayrollMoney(row.deductions)}'),
          Text(
            'Net ${financePayrollMoney(row.net)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final FinancePayrollStatus status;

  @override
  Widget build(BuildContext context) {
    final ready = status == FinancePayrollStatus.ready;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ready ? scheme.primaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        financePayrollStatusLabel(status),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RulesGrid extends StatelessWidget {
  const _RulesGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = const [
          _RuleCard(
            title: 'Attendance handoff rule',
            subtitle: 'Attendance data supports payroll preparation, not automatic salary action.',
            text: financePayrollAttendanceRule,
            icon: Icons.fact_check_outlined,
          ),
          _RuleCard(
            title: 'Human review required',
            subtitle: 'Device records never decide pay by themselves.',
            text: financePayrollHumanReviewRule,
            icon: Icons.person_search_outlined,
          ),
        ];
        if (constraints.maxWidth < 900) {
          return const Column(
            children: [
              _RuleCard(
                title: 'Attendance handoff rule',
                subtitle: 'Attendance data supports payroll preparation, not automatic salary action.',
                text: financePayrollAttendanceRule,
                icon: Icons.fact_check_outlined,
              ),
              SizedBox(height: 16),
              _RuleCard(
                title: 'Human review required',
                subtitle: 'Device records never decide pay by themselves.',
                text: financePayrollHumanReviewRule,
                icon: Icons.person_search_outlined,
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i == 0) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.title,
    required this.subtitle,
    required this.text,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: title,
      subtitle: subtitle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _AuditBoundary extends StatelessWidget {
  const _AuditBoundary();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Payroll authority & settlement boundary',
      subtitle: 'Keep approved pay, batch preparation, settlement and employment authority separate.',
      child: const Column(
        children: [
          _BoundaryLine(icon: Icons.admin_panel_settings_outlined, text: financePayrollAuthorityBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.playlist_add_check_rounded, text: financePayrollBatchBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.account_balance_outlined, text: financePayrollSettlementBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.history_rounded, text: financePayrollCorrectionBoundary),
        ],
      ),
    );
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
