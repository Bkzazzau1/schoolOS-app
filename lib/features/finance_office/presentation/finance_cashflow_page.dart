import 'package:flutter/material.dart';

import '../data/finance_cashflow_demo_data.dart';
import '../domain/finance_cashflow_models.dart';

class FinanceCashflowPage extends StatefulWidget {
  const FinanceCashflowPage({super.key});

  @override
  State<FinanceCashflowPage> createState() => _FinanceCashflowPageState();
}

class _FinanceCashflowPageState extends State<FinanceCashflowPage> {
  String? _notice;

  void _newIncome() {
    setState(() => _notice = financeIncomeEntryBoundary);
  }

  void _newExpense() {
    setState(() => _notice = financeExpenseRequestBoundary);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onIncome: _newIncome, onExpense: _newExpense),
        const SizedBox(height: 12),
        const _SampleDataBanner(
          text: 'This screen shows sample income and expense entries, not real ones. Finance AI already treats expenses, other income and cashflow as not recorded yet; this screen is not yet connected to a real ledger either.',
        ),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          _Notice(text: _notice!),
        ],
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        const _MainGrid(),
        const SizedBox(height: 16),
        const _PostingBoundary(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onIncome, required this.onExpense});

  final VoidCallback onIncome;
  final VoidCallback onExpense;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINANCE OFFICE · CASHFLOW',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Income & Expenses',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Operational income, approved expenses, categories and cashflow monitoring.',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onIncome,
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('New income entry'),
            ),
            FilledButton.icon(
              onPressed: onExpense,
              icon: const Icon(Icons.request_quote_outlined),
              label: const Text('New expense request'),
            ),
          ],
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
            for (final item in financeCashflowKpis)
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

class _MainGrid extends StatelessWidget {
  const _MainGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return const Column(
            children: [
              _LedgerCard(),
              SizedBox(height: 16),
              _ControlsCard(),
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _LedgerCard()),
            SizedBox(width: 16),
            Expanded(child: _ControlsCard()),
          ],
        );
      },
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Cashflow ledger',
      subtitle: 'Recent posted operational entries.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              children: [
                for (final entry in financeCashflowEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MobileEntry(entry: entry),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date / Description')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final entry in financeCashflowEntries)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 245,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.description,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(entry.date, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(financeCashflowTypeLabel(entry.type))),
                      DataCell(Text(entry.category)),
                      DataCell(
                        Text(
                          financeCashflowMoney(entry.amount),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      DataCell(_StatusPill(status: entry.status)),
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

class _MobileEntry extends StatelessWidget {
  const _MobileEntry({required this.entry});
  final FinanceCashflowEntry entry;

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
                child: Text(
                  entry.description,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(status: entry.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.date, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(financeCashflowTypeLabel(entry.type))),
              Chip(label: Text(entry.category)),
              Chip(label: Text(financeCashflowMoney(entry.amount))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final FinanceCashflowStatus status;

  @override
  Widget build(BuildContext context) {
    final posted = status == FinanceCashflowStatus.posted;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: posted ? scheme.primaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        financeCashflowStatusLabel(status),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Expense controls',
      subtitle: 'Finance workflow guardrails.',
      child: Column(
        children: [
          for (var i = 0; i < financeExpenseControls.length; i++) ...[
            _ControlRow(control: financeExpenseControls[i]),
            if (i != financeExpenseControls.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.control});
  final FinanceExpenseControl control;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.verified_user_outlined, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(control.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(control.detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _SampleDataBanner extends StatelessWidget {
  const _SampleDataBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.science_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _PostingBoundary extends StatelessWidget {
  const _PostingBoundary();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Posting & audit boundary',
      subtitle: 'Keep authorization, cash movement and accounting history distinct.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _BoundaryLine(icon: Icons.account_balance_wallet_outlined, text: financeIncomeEntryBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.approval_outlined, text: financeExpenseRequestBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.attach_file_outlined, text: financeExpenseEvidenceBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.history_rounded, text: financeCashflowCorrectionBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.science_outlined, text: financeCashflowPrototypeBoundary),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
