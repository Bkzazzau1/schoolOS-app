import 'package:flutter/material.dart';

import '../data/finance_fee_structure_demo_data.dart';
import '../domain/finance_fee_structure_models.dart';

class FinanceFeeStructurePage extends StatefulWidget {
  const FinanceFeeStructurePage({super.key});

  @override
  State<FinanceFeeStructurePage> createState() => _FinanceFeeStructurePageState();
}

class _FinanceFeeStructurePageState extends State<FinanceFeeStructurePage> {
  String _term = financeFeeTerms.first;
  String? _notice;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            term: _term,
            onTermChanged: (value) => setState(() => _term = value),
            onSaveDraft: () => setState(
              () => _notice = 'Draft fee structure saved locally in this UI prototype.',
            ),
          ),
          const SizedBox(height: 18),
          _KpiWrap(term: _term),
          if (_notice != null) ...[
            const SizedBox(height: 16),
            _Notice(text: _notice!),
          ],
          const SizedBox(height: 18),
          const _CoreChargesCard(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final optional = const _OptionalChargesCard();
              final sequence = const _BillingSequenceCard();
              if (narrow) {
                return const Column(
                  children: [
                    _OptionalChargesCard(),
                    SizedBox(height: 18),
                    _BillingSequenceCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: optional),
                  const SizedBox(width: 18),
                  Expanded(child: sequence),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const _AccountingCallout(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.term,
    required this.onTermChanged,
    required this.onSaveDraft,
  });

  final String term;
  final ValueChanged<String> onTermChanged;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCE OFFICE · BILLING POLICY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fee Structure',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Define transparent section-level charges before student accounts, discounts, scholarships and collection limits are calculated.',
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                value: term,
                decoration: const InputDecoration(labelText: 'Term'),
                items: [
                  for (final item in financeFeeTerms)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) onTermChanged(value);
                },
              ),
            ),
            FilledButton.icon(
              onPressed: onSaveDraft,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save draft'),
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
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiWrap extends StatelessWidget {
  const _KpiWrap({required this.term});

  final String term;

  @override
  Widget build(BuildContext context) {
    final activeTerm = term.split(' · ').last;
    final cards = <Widget>[
      _Kpi(label: 'Active term', value: activeTerm, hint: '2026/2027 session'),
      _Kpi(label: 'Early Years base fee', value: financeMoney(117500), hint: 'Before optional services'),
      _Kpi(label: 'Primary base fee', value: financeMoney(145000), hint: 'Before optional services'),
      _Kpi(label: 'Secondary base fee', value: financeMoney(185000), hint: 'Before optional services'),
      const _Kpi(label: 'Billing population', value: '648', hint: 'Active pupils/students'),
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
  const _Kpi({required this.label, required this.value, required this.hint});
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _CoreChargesCard extends StatelessWidget {
  const _CoreChargesCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Core term charges by section',
      subtitle: 'Every component remains visible instead of hiding all charges inside one number.',
      trailing: const Chip(label: Text('Draft policy')),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return Column(children: [for (final row in financeFeeSections) _SectionTile(row: row)]);
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Section')),
                DataColumn(label: Text('Students')),
                DataColumn(label: Text('Tuition')),
                DataColumn(label: Text('Development')),
                DataColumn(label: Text('Activities')),
                DataColumn(label: Text('Technology')),
                DataColumn(label: Text('Base total')),
              ],
              rows: [
                for (final row in financeFeeSections)
                  DataRow(cells: [
                    DataCell(Text(row.section, style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text('${row.students}')),
                    DataCell(Text(financeMoney(row.tuition))),
                    DataCell(Text(financeMoney(row.development))),
                    DataCell(Text(financeMoney(row.activities))),
                    DataCell(Text(financeMoney(row.technology))),
                    DataCell(Text(financeMoney(row.total), style: const TextStyle(fontWeight: FontWeight.w900))),
                  ]),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.row});
  final FinanceFeeSection row;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(row.section, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${row.students} students · Base ${financeMoney(row.total)}'),
      children: [
        _line('Tuition', financeMoney(row.tuition)),
        _line('Development', financeMoney(row.development)),
        _line('Activities', financeMoney(row.activities)),
        _line('Technology', financeMoney(row.technology)),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label)), Text(value)]),
      );
}

class _OptionalChargesCard extends StatelessWidget {
  const _OptionalChargesCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Optional / service charges',
      subtitle: 'Added only where the child is actually enrolled in the service.',
      child: Column(
        children: [
          for (final item in financeOptionalCharges)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.charge, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${item.mode} · ${item.rule}'),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 155),
                child: Text(item.amount, textAlign: TextAlign.end),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillingSequenceCard extends StatelessWidget {
  const _BillingSequenceCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Billing sequence',
      subtitle: 'How SchoolOS should derive the amount each child can actually be asked to pay.',
      child: Column(
        children: [
          for (final step in financeBillingSequence)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${step.number}')),
              title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(step.detail),
            ),
        ],
      ),
    );
  }
}

class _AccountingCallout extends StatelessWidget {
  const _AccountingCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Important accounting distinction: ', style: TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: financeFeeAccountingDistinction),
          ],
        ),
      ),
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
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
