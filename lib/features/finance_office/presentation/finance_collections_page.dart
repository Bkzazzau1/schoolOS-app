import 'package:flutter/material.dart';

import '../data/finance_collections_demo_data.dart';
import '../domain/finance_collections_models.dart';

class FinanceCollectionsPage extends StatefulWidget {
  const FinanceCollectionsPage({super.key});

  @override
  State<FinanceCollectionsPage> createState() => _FinanceCollectionsPageState();
}

class _FinanceCollectionsPageState extends State<FinanceCollectionsPage> {
  FinanceTermAccount _selected = financeTermAccounts.first;
  late final TextEditingController _limitController;
  String _reason = financeCollectionLimitReasons.first;
  String _validity = financeCollectionValidityOptions.first;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(text: '${_selected.limit}');
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _choose(FinanceTermAccount account) {
    setState(() {
      _selected = account;
      _limitController.text = '${account.limit}';
      _notice = null;
    });
  }

  void _prototypeAction(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action exists on the SchoolOS website prototype, but no persisted provider-backed workflow is defined yet.',
        ),
      ),
    );
  }

  void _authorizePrototypeLimit() {
    final amount = int.tryParse(_limitController.text) ?? 0;
    setState(() {
      _notice =
          'Prototype limit reviewed for ${_selected.guardian} family account (${_selected.student} ledger): ${financeCollectionMoney(amount)}. This does not claim a bank-side ceiling changed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final totals = financeCollectionsTotals(financeTermAccounts);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(
          onExport: () => _prototypeAction('Export collections'),
          onSpecialArrangement: () => _prototypeAction('New special arrangement'),
        ),
        const SizedBox(height: 16),
        _Kpis(totals: totals),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 940;
            final accounts = _TermAccountList(
              selected: _selected,
              onSelected: _choose,
            );
            final detail = _TermAccountDetail(account: _selected);
            if (compact) {
              return Column(
                children: [
                  accounts,
                  const SizedBox(height: 16),
                  detail,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: accounts),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: detail),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 840;
            final control = _LimitControl(
              account: _selected,
              limitController: _limitController,
              reason: _reason,
              validity: _validity,
              notice: _notice,
              onReasonChanged: (value) => setState(() => _reason = value),
              onValidityChanged: (value) => setState(() => _validity = value),
              onAuthorize: _authorizePrototypeLimit,
            );
            const status = _CollectionStatusCard();
            if (compact) {
              return Column(
                children: [control, const SizedBox(height: 16), status],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: control),
                const SizedBox(width: 16),
                const Expanded(child: status),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _LiveCollectionsFeed(),
        const SizedBox(height: 16),
        const _PrototypeBoundary(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onExport, required this.onSpecialArrangement});

  final VoidCallback onExport;
  final VoidCallback onSpecialArrangement;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REVENUE ASSURANCE · SMART COLLECTIONS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Collections Control Room',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Family collection accounts, separate child fee ledgers, flexible deposits, collection limits, live payment identification and automatic receipts.',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export collections'),
            ),
            FilledButton.icon(
              onPressed: onSpecialArrangement,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New special arrangement'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.totals});
  final FinanceCollectionsTotals totals;

  @override
  Widget build(BuildContext context) {
    final cards = <({String label, String value, String hint})>[
      (
        label: 'Gross term fees',
        value: financeCollectionMoney(totals.gross),
        hint: 'Selected child ledgers',
      ),
      (
        label: 'Scholarships & discounts',
        value: financeCollectionMoney(totals.concessions),
        hint: 'Removed before collection',
      ),
      (
        label: 'Collected',
        value: financeCollectionMoney(totals.collected),
        hint: 'Allocated across child ledgers',
      ),
      (
        label: 'Outstanding',
        value: financeCollectionMoney(totals.outstanding),
        hint: 'Net family obligations',
      ),
      (
        label: 'Family collection accounts',
        value: '${totals.activeAccounts}',
        hint: 'One per guardian · child ledgers linked',
      ),
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
          children: [
            for (final item in cards)
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
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

class _TermAccountList extends StatelessWidget {
  const _TermAccountList({required this.selected, required this.onSelected});

  final FinanceTermAccount selected;
  final ValueChanged<FinanceTermAccount> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Linked child fee ledgers',
      subtitle: 'Each child keeps a ledger; siblings under the same payer can share one family collection account.',
      child: Column(
        children: [
          for (final account in financeTermAccounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected.id == account.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(account),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        final identity = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.student, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text('${account.className} · ${account.id}'),
                            Text(account.guardian, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        );
                        final bank = Column(
                          crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(account.account, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                            Text('Family account · ${account.provider}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        );
                        final amount = Column(
                          crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Text(financeCollectionMoney(account.outstanding), style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text('child ledger outstanding', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              identity,
                              const SizedBox(height: 8),
                              bank,
                              const SizedBox(height: 8),
                              amount,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(flex: 4, child: identity),
                            const SizedBox(width: 10),
                            Expanded(flex: 3, child: bank),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: amount),
                          ],
                        );
                      },
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

class _TermAccountDetail extends StatelessWidget {
  const _TermAccountDetail({required this.account});
  final FinanceTermAccount account;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: account.student,
      subtitle: '${account.className} · child ledger under ${account.guardian}',
      trailing: Chip(label: Text(financeTermAccountStatusLabel(account.status))),
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
                const Text('2026/2027 · TERM 1 FAMILY COLLECTION ACCOUNT', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(
                  account.account,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text('${account.provider} · Account holder: ${account.guardian}'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MoneyCell(label: 'Gross fee', value: account.gross),
              _MoneyCell(label: 'Scholarship', value: account.scholarship),
              _MoneyCell(label: 'Discount', value: account.discount),
              _MoneyCell(label: 'Paid to this ledger', value: account.paid),
              _MoneyCell(label: 'Ledger outstanding', value: account.outstanding),
              _MoneyCell(label: 'Ledger collection ceiling', value: account.limit),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '$financeCollectionsFamilyAccountBoundary $financeCollectionsAllocationBoundary $financeCollectionsDepositBoundary $financeCollectionsCeilingBoundary',
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(financeCollectionMoney(value), style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LimitControl extends StatelessWidget {
  const _LimitControl({
    required this.account,
    required this.limitController,
    required this.reason,
    required this.validity,
    required this.notice,
    required this.onReasonChanged,
    required this.onValidityChanged,
    required this.onAuthorize,
  });

  final FinanceTermAccount account;
  final TextEditingController limitController;
  final String reason;
  final String validity;
  final String? notice;
  final ValueChanged<String> onReasonChanged;
  final ValueChanged<String> onValidityChanged;
  final VoidCallback onAuthorize;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Collection limit control',
      subtitle: 'Prototype review for the selected child ledger within its family account.',
      trailing: const Chip(label: Text('Audited change')),
      child: Column(
        children: [
          TextFormField(
            initialValue: account.account,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Family collection account'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Authorized receivable for selected ledger'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final item in financeCollectionLimitReasons)
                DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) {
              if (value != null) onReasonChanged(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: validity,
            decoration: const InputDecoration(labelText: 'Validity'),
            items: [
              for (final item in financeCollectionValidityOptions)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              if (value != null) onValidityChanged(value);
            },
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAuthorize,
              child: const Text('Authorize prototype limit'),
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(notice!, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollectionStatusCard extends StatelessWidget {
  const _CollectionStatusCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Collection status',
      subtitle: 'What finance staff need to resolve today.',
      child: Column(
        children: [
          for (final item in financeCollectionStatusItems)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chevron_right_rounded),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(item.detail),
            ),
        ],
      ),
    );
  }
}

class _LiveCollectionsFeed extends StatelessWidget {
  const _LiveCollectionsFeed();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Live collections feed',
      subtitle: 'Confirmed credits arriving through family accounts and allocated to identified child ledgers.',
      trailing: const Chip(label: Text('● Live prototype')),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 820) {
            return Column(
              children: [
                for (final event in financeCollectionFeed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event.student, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${event.time} · ${event.account}\n${event.reference}'),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(financeCollectionMoney(event.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text(financeCollectionStatusLabel(event.status)),
                      ],
                    ),
                  ),
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Time')),
                DataColumn(label: Text('Child ledger')),
                DataColumn(label: Text('Family account')),
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: [
                for (final event in financeCollectionFeed)
                  DataRow(
                    cells: [
                      DataCell(Text(event.time)),
                      DataCell(Text(event.student, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(event.account, style: const TextStyle(fontFamily: 'monospace'))),
                      DataCell(Text(event.reference, style: const TextStyle(fontFamily: 'monospace'))),
                      DataCell(Text(financeCollectionMoney(event.amount), style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(Text(financeCollectionStatusLabel(event.status))),
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

class _PrototypeBoundary extends StatelessWidget {
  const _PrototypeBoundary();

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
        '$financeCollectionsFamilyAccountBoundary $financeCollectionsAllocationBoundary $financeCollectionsPrototypeBoundary',
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
