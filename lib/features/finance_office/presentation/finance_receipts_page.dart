import 'package:flutter/material.dart';

import '../data/finance_receipts_demo_data.dart';
import '../domain/finance_receipts_models.dart';

class FinanceReceiptsPage extends StatefulWidget {
  const FinanceReceiptsPage({super.key});

  @override
  State<FinanceReceiptsPage> createState() => _FinanceReceiptsPageState();
}

class _FinanceReceiptsPageState extends State<FinanceReceiptsPage> {
  FinanceReceipt _selected = financeReceipts.first;

  void _documentAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action is a non-financial prototype document action until native print/export integration is connected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(
          onExport: () => _documentAction('Export register'),
          onPrint: () => _documentAction('Print selected'),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final register = _ReceiptRegister(
              selected: _selected,
              onSelected: (receipt) => setState(() => _selected = receipt),
            );
            final preview = _ReceiptPreview(receipt: _selected);
            if (constraints.maxWidth < 930) {
              return Column(
                children: [
                  register,
                  const SizedBox(height: 18),
                  preview,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: register),
                const SizedBox(width: 18),
                Expanded(flex: 6, child: preview),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _BoundaryCallout(text: financeReceiptIssuanceBoundary),
        const SizedBox(height: 10),
        _BoundaryCallout(text: financeReceiptMutationBoundary),
        const SizedBox(height: 10),
        _BoundaryCallout(text: financeReceiptPrototypeBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onExport, required this.onPrint});

  final VoidCallback onExport;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLLECTION RECORDS · RECEIPTS',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Receipts Register',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Every confirmed term-account credit creates a traceable receipt for Finance and the linked parent.',
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton(
          onPressed: onExport,
          child: const Text('Export register'),
        ),
        FilledButton(
          onPressed: onPrint,
          child: const Text('Print selected'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 14),
              actions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _ReceiptRegister extends StatelessWidget {
  const _ReceiptRegister({
    required this.selected,
    required this.onSelected,
  });

  final FinanceReceipt selected;
  final ValueChanged<FinanceReceipt> onSelected;

  @override
  Widget build(BuildContext context) => _CardShell(
        title: 'Recent receipts',
        subtitle: 'Confirmed collections posted to student ledgers.',
        child: Column(
          children: [
            for (final receipt in financeReceipts)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _ReceiptListButton(
                  receipt: receipt,
                  selected: selected.number == receipt.number,
                  onTap: () => onSelected(receipt),
                ),
              ),
          ],
        ),
      );
}

class _ReceiptListButton extends StatelessWidget {
  const _ReceiptListButton({
    required this.receipt,
    required this.selected,
    required this.onTap,
  });

  final FinanceReceipt receipt;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      receipt.student,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    financeReceiptMoney(receipt.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${receipt.className} · ${receipt.date}'),
              const SizedBox(height: 5),
              Text(
                receipt.number,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.receipt});

  final FinanceReceipt receipt;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReceiptBrand(),
              const Divider(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: Text('Receipt No.')),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        receipt.number,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      _ConfirmedChip(status: receipt.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailGrid(receipt: receipt),
              const SizedBox(height: 18),
              _BalanceSummary(receipt: receipt),
              const SizedBox(height: 18),
              Text(
                'System-generated SchoolOS prototype receipt · linked automatically to the student fee ledger.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _ReceiptBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(child: Text('S')),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  financeReceiptSchoolName,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                SizedBox(height: 2),
                Text(financeReceiptCampusLine),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'PAYMENT RECEIPT',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      );
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.receipt});

  final FinanceReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final details = <(String, String)>[
      ('Student', receipt.student),
      ('Admission No.', receipt.admissionNumber),
      ('Class', receipt.className),
      ('Term', financeReceiptTerm),
      ('Amount paid', financeReceiptMoney(receipt.amount)),
      ('Payment method', receipt.method),
      ('Transaction ref', receipt.transactionReference),
      ('Payment date', receipt.date),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 620
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final detail in details)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.$1,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail.$2,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.receipt});

  final FinanceReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Previous balance', financeReceiptMoney(receipt.previousBalance)),
      ('Payment received', '- ${financeReceiptMoney(receipt.amount)}'),
      ('New balance', financeReceiptMoney(receipt.newBalance)),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.$1)),
                        Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$1),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$2,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                if (i < items.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ConfirmedChip extends StatelessWidget {
  const _ConfirmedChip({required this.status});

  final FinanceReceiptStatus status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          status.label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );
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
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
              const SizedBox(height: 14),
              child,
            ],
          ),
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text),
      );
}
