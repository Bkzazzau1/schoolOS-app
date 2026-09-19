import 'package:flutter/material.dart';

import '../data/finance_family_accounts_demo_data.dart';
import '../data/finance_reconciliation_demo_data.dart';
import '../domain/finance_family_accounts_models.dart';
import '../domain/finance_reconciliation_models.dart';

class FinanceReconciliationPage extends StatefulWidget {
  const FinanceReconciliationPage({super.key});

  @override
  State<FinanceReconciliationPage> createState() => _FinanceReconciliationPageState();
}

class _FinanceReconciliationPageState extends State<FinanceReconciliationPage> {
  FinanceReconciliationRow? _reviewing;
  FinanceFamilyAccount? _proposedFamily;
  FinanceChildFeeLedger? _proposedChild;
  String? _notice;

  void _prototypeImport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(financeReconciliationImportBoundary)),
    );
  }

  void _openReview(FinanceReconciliationRow row) {
    setState(() {
      _reviewing = row;
      _proposedFamily = null;
      _proposedChild = null;
      _notice = null;
    });
  }

  void _chooseFamily(FinanceFamilyAccount? family) {
    setState(() {
      _proposedFamily = family;
      _proposedChild = null;
      _notice = null;
    });
  }

  void _recordProposal() {
    if (_reviewing == null || _proposedFamily == null || _proposedChild == null) {
      setState(() {
        _notice = 'Select both a family account and a child fee ledger before recording a review proposal.';
      });
      return;
    }
    setState(() {
      _notice =
          'Review proposal recorded locally: ${_proposedFamily!.guardian} → ${_proposedChild!.student}. The transaction remains Review until the evidence is confirmed; no child balance or receipt changed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onImport: _prototypeImport),
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        _Queue(onReview: _openReview),
        if (_reviewing != null) ...[
          const SizedBox(height: 16),
          _ReviewPanel(
            row: _reviewing!,
            proposedFamily: _proposedFamily,
            proposedChild: _proposedChild,
            notice: _notice,
            onFamilyChanged: _chooseFamily,
            onChildChanged: (child) => setState(() {
              _proposedChild = child;
              _notice = null;
            }),
            onRecord: _recordProposal,
          ),
        ],
        const SizedBox(height: 16),
        const _Controls(),
        const SizedBox(height: 16),
        const _Boundaries(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onImport});
  final VoidCallback onImport;

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
                'FINANCE OFFICE · BANK CONTROL',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Payment Reconciliation',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Match incoming transfers and payment events to the correct family account and child fee ledger with an auditable review trail.',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Import bank statement'),
        ),
      ],
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
            for (final item in financeReconciliationKpis)
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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

class _Queue extends StatelessWidget {
  const _Queue({required this.onReview});
  final ValueChanged<FinanceReconciliationRow> onReview;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Reconciliation queue',
      subtitle: 'Never allocate an ambiguous transfer solely from name similarity.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return Column(
              children: [
                for (final row in financeReconciliationRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MobileRow(row: row, onReview: onReview),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Sender')),
                DataColumn(label: Text('Channel')),
                DataColumn(label: Text('Match')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final row in financeReconciliationRows)
                  DataRow(
                    cells: [
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.reference, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(financeReconciliationMoney(row.amount), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      )),
                      DataCell(Text(row.sender)),
                      DataCell(Text(row.channel)),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.matchLabel),
                          if (row.hasFamilyAllocation)
                            Text(
                              '${row.familyAccountNumber} · ${row.childLedgerId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      )),
                      DataCell(
                        row.needsReview
                            ? FilledButton.tonal(
                                onPressed: () => onReview(row),
                                child: const Text('Review & match'),
                              )
                            : Text(
                                financeReconciliationStatusLabel(row.status),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                      ),
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

class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.row, required this.onReview});
  final FinanceReconciliationRow row;
  final ValueChanged<FinanceReconciliationRow> onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.reference, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(financeReconciliationMoney(row.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${row.sender} · ${row.channel}'),
          const SizedBox(height: 4),
          Text('Match: ${row.matchLabel}'),
          if (row.hasFamilyAllocation)
            Text('Family ${row.familyAccountNumber} · Ledger ${row.childLedgerId}'),
          const SizedBox(height: 8),
          if (row.needsReview)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => onReview(row),
                child: const Text('Review & match'),
              ),
            )
          else
            Chip(label: Text(financeReconciliationStatusLabel(row.status))),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.row,
    required this.proposedFamily,
    required this.proposedChild,
    required this.notice,
    required this.onFamilyChanged,
    required this.onChildChanged,
    required this.onRecord,
  });

  final FinanceReconciliationRow row;
  final FinanceFamilyAccount? proposedFamily;
  final FinanceChildFeeLedger? proposedChild;
  final String? notice;
  final ValueChanged<FinanceFamilyAccount?> onFamilyChanged;
  final ValueChanged<FinanceChildFeeLedger?> onChildChanged;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Human review · ${row.reference}',
      subtitle: '${row.sender} · ${financeReconciliationMoney(row.amount)} · ${row.channel}',
      trailing: const Chip(label: Text('Still Review')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(financeReconciliationMatchBoundary),
          const SizedBox(height: 14),
          DropdownButtonFormField<FinanceFamilyAccount>(
            isExpanded: true,
            initialValue: proposedFamily,
            decoration: const InputDecoration(labelText: 'Proposed family account'),
            items: [
              for (final family in financeFamilyAccounts)
                DropdownMenuItem(
                  value: family,
                  child: Text(
                    '${family.guardian} · ${family.accountNumber}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onFamilyChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FinanceChildFeeLedger>(
            isExpanded: true,
            initialValue: proposedChild,
            decoration: const InputDecoration(labelText: 'Proposed child fee ledger'),
            items: [
              if (proposedFamily != null)
                for (final child in proposedFamily!.children)
                  DropdownMenuItem(
                    value: child,
                    child: Text('${child.student} · ${child.className} · ${child.id}'),
                  ),
            ],
            onChanged: proposedFamily == null ? null : onChildChanged,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRecord,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Record review proposal'),
          ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(notice!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final signals = _CardShell(
          title: 'Matching signals',
          subtitle: 'Evidence strength used during reconciliation.',
          child: Column(
            children: [
              for (final item in financeReconciliationSignals)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chevron_right_rounded),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.detail),
                ),
            ],
          ),
        );
        const reversal = _CardShell(
          title: 'Reversal control',
          subtitle: 'Append-only financial history.',
          child: Text(financeReconciliationReversalBoundary),
        );
        if (constraints.maxWidth < 820) {
          return Column(children: [signals, const SizedBox(height: 16), reversal]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: signals),
            const SizedBox(width: 16),
            const Expanded(child: reversal),
          ],
        );
      },
    );
  }
}

class _Boundaries extends StatelessWidget {
  const _Boundaries();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '$financeReconciliationFamilyBoundary\n\n$financeReconciliationPostingBoundary\n\n$financeReconciliationImportBoundary',
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

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
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
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
