import 'package:flutter/material.dart';

import '../data/finance_debt_aging_demo_data.dart';
import '../domain/finance_debt_aging_models.dart';

class FinanceDebtAgingPage extends StatefulWidget {
  const FinanceDebtAgingPage({super.key});

  @override
  State<FinanceDebtAgingPage> createState() => _FinanceDebtAgingPageState();
}

class _FinanceDebtAgingPageState extends State<FinanceDebtAgingPage> {
  String _bucket = 'All';

  List<FinanceFamilyReceivable> get _visible =>
      financeFilterReceivables(financeFamilyReceivables, _bucket);

  void _prototypeAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is a prototype action until its governed workflow is connected.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(
          bucket: _bucket,
          onBucketChanged: (value) => setState(() => _bucket = value),
          onExport: () => _prototypeAction('Export aging'),
        ),
        const SizedBox(height: 18),
        const _KpiWrap(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final aging = const _AgingCard();
            final quality = const _ArrangementQualityCard();
            if (constraints.maxWidth < 900) {
              return const Column(children: [aging, SizedBox(height: 18), quality]);
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: aging),
                SizedBox(width: 18),
                Expanded(child: quality),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _ReceivablesCard(rows: _visible),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = _ActionsCard(onAction: _prototypeAction);
            const principle = _PrincipleCard();
            if (constraints.maxWidth < 850) {
              return Column(children: [actions, const SizedBox(height: 18), principle]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: actions),
                const SizedBox(width: 18),
                const Expanded(child: principle),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _BoundaryCallout(text: financeAgingAccountingBoundary),
        const SizedBox(height: 10),
        _BoundaryCallout(text: financeAgingPrototypeBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bucket, required this.onBucketChanged, required this.onExport});
  final String bucket;
  final ValueChanged<String> onBucketChanged;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FINANCE OFFICE · RECEIVABLES', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 6),
        Text('Outstanding Fees & Aging', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text('Separate current balances, scheduled collections, structured financing and genuinely overdue debt before taking action.'),
      ],
    );
    final controls = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<String>(
            initialValue: bucket,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, labelText: 'Aging bucket'),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: '0–30 days', child: Text('0–30 days')),
              DropdownMenuItem(value: '31–60 days', child: Text('31–60 days')),
              DropdownMenuItem(value: '61–90 days', child: Text('61–90 days')),
              DropdownMenuItem(value: '90+ days', child: Text('90+ days')),
            ],
            onChanged: (value) {
              if (value != null) onBucketChanged(value);
            },
          ),
        ),
        FilledButton(onPressed: onExport, child: const Text('Export aging')),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 14), controls]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: heading), const SizedBox(width: 18), controls]);
      },
    );
  }
}

class _KpiWrap extends StatelessWidget {
  const _KpiWrap();

  @override
  Widget build(BuildContext context) {
    const cards = <Widget>[
      _Kpi('Total open receivables', '₦18.7m', 'After scholarships & discounts'),
      _Kpi('0–30 days', '₦8.2m', 'Current / newly due'),
      _Kpi('31–60 days', '₦5.4m', 'Follow-up window'),
      _Kpi('61–90 days', '₦3.1m', 'Structured review'),
      _Kpi('90+ days', '₦2.0m', 'Priority owner visibility'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 1180 ? (width - 48) / 5 : width >= 720 ? (width - 24) / 3 : width;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final card in cards) SizedBox(width: itemWidth, child: card)]);
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
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _AgingCard extends StatelessWidget {
  const _AgingCard();

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Receivable aging',
        subtitle: 'Age alone does not tell the whole story—collection arrangements matter.',
        child: Column(
          children: [
            for (final item in financeAgingSummaries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  SizedBox(width: 88, child: Text(item.bucket.label, style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                  Expanded(child: LinearProgressIndicator(value: item.progressPercent / 100, minHeight: 10, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(width: 10),
                  SizedBox(width: 72, child: Text(_millions(item.amount), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
                ]),
              ),
          ],
        ),
      );
}

class _ArrangementQualityCard extends StatelessWidget {
  const _ArrangementQualityCard();

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Arrangement quality',
        subtitle: 'How much of the outstanding balance already has a recovery path.',
        child: Column(
          children: [
            for (final item in financeArrangementQuality)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${_millions(item.amount)} · ${item.label}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${item.description}\n${item.guidance}'),
              ),
          ],
        ),
      );
}

class _ReceivablesCard extends StatelessWidget {
  const _ReceivablesCard({required this.rows});
  final List<FinanceFamilyReceivable> rows;

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Family receivables queue',
        subtitle: 'Operational view for respectful collection follow-up.',
        child: rows.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No family receivables match this aging bucket.')))
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 880) {
                    return Column(children: [for (final row in rows) _ReceivableTile(row: row)]);
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Family')),
                        DataColumn(label: Text('Children')),
                        DataColumn(label: Text('Balance')),
                        DataColumn(label: Text('Age')),
                        DataColumn(label: Text('Arrangement')),
                        DataColumn(label: Text('Next action')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(cells: [
                            DataCell(Text(row.family, style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(row.children)),
                            DataCell(Text(financeAgingMoney(row.balance), style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(row.age.label)),
                            DataCell(Text(row.plan)),
                            DataCell(Text(row.nextAction)),
                            DataCell(_StatusChip(status: row.status)),
                          ]),
                      ],
                    ),
                  );
                },
              ),
      );
}

class _ReceivableTile extends StatelessWidget {
  const _ReceivableTile({required this.row});
  final FinanceFamilyReceivable row;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(row.family, style: const TextStyle(fontWeight: FontWeight.w900))), const SizedBox(width: 8), _StatusChip(status: row.status)]),
          const SizedBox(height: 4),
          Text(row.children),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [
            Text(financeAgingMoney(row.balance), style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(row.age.label),
            Text(row.plan),
            Text(row.nextAction),
          ]),
        ]),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final FinanceReceivableStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      FinanceReceivableStatus.action => scheme.errorContainer,
      FinanceReceivableStatus.watch => scheme.tertiaryContainer,
      _ => scheme.secondaryContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(status.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.onAction});
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Collection actions',
        subtitle: 'Actions depend on arrangement, not labels about the family.',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final action in financeAgingActions) OutlinedButton(onPressed: () => onAction(action), child: Text(action))],
        ),
      );
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard();

  @override
  Widget build(BuildContext context) => const _CardShell(
        title: 'SchoolOS principle',
        subtitle: 'Finance facts stay separate from treatment of the child.',
        child: _BoundaryCallout(text: financeAgingAcademicBoundary),
      );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}

String _millions(int amount) => '₦${(amount / 1000000).toStringAsFixed(1)}m';
