import 'package:flutter/material.dart';

import '../data/finance_family_accounts_demo_data.dart';
import '../domain/finance_family_accounts_models.dart';

class FinanceFamilyAccountsPage extends StatefulWidget {
  const FinanceFamilyAccountsPage({super.key});

  @override
  State<FinanceFamilyAccountsPage> createState() => _FinanceFamilyAccountsPageState();
}

class _FinanceFamilyAccountsPageState extends State<FinanceFamilyAccountsPage> {
  FinanceFamilyAccount _selected = financeFamilyAccounts.first;

  void _prototypeAction() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Detailed Finance Center is not simulated here. Account mutations require a governed workflow.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onOpenFinanceCenter: _prototypeAction),
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        _BoundaryCallout(text: financeFamilyAccountBoundary),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final register = _FamilyRegister(
              selected: _selected,
              onSelected: (account) => setState(() => _selected = account),
            );
            final detail = _FamilyAccountDetail(account: _selected);
            if (constraints.maxWidth < 960) {
              return Column(
                children: [register, const SizedBox(height: 16), detail],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: register),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: detail),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _BoundaryCallout(text: financeFamilyAllocationBoundary),
        const SizedBox(height: 10),
        _BoundaryCallout(text: financeFamilyAcademicBoundary),
        const SizedBox(height: 10),
        _BoundaryCallout(text: financeFamilyPrototypeBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onOpenFinanceCenter});

  final VoidCallback onOpenFinanceCenter;

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
                'FINANCE OFFICE · STUDENT & FAMILY ACCOUNTS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Student & Family Accounts',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One parent or guardian account can serve multiple enrolled children while each child keeps a separate fee ledger.',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onOpenFinanceCenter,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open detailed Finance Center'),
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
            for (final item in financeAccountsKpis)
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

class _FamilyRegister extends StatelessWidget {
  const _FamilyRegister({required this.selected, required this.onSelected});

  final FinanceFamilyAccount selected;
  final ValueChanged<FinanceFamilyAccount> onSelected;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Family account register',
      subtitle: 'One collection account per responsible payer, with linked child fee ledgers.',
      child: Column(
        children: [
          for (final account in financeFamilyAccounts)
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.guardian,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Chip(
                              label: Text(financeFamilyAccountStatusLabel(account.status)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${account.childCount} ${account.childCount == 1 ? 'child' : 'children'} · ${account.id}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              account.accountNumber,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(account.provider),
                            Text(
                              '${financeFamilyMoney(account.balance)} balance',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          account.children.map((child) => child.student).join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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

class _FamilyAccountDetail extends StatelessWidget {
  const _FamilyAccountDetail({required this.account});

  final FinanceFamilyAccount account;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: account.guardian,
      subtitle: '${account.id} · ${account.childCount} linked ${account.childCount == 1 ? 'child' : 'children'}',
      trailing: Chip(label: Text(financeFamilyAccountStatusLabel(account.status))),
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
                const Text(
                  '2026/2027 · TERM 1 FAMILY COLLECTION ACCOUNT',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  account.accountNumber,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
              _MoneyCell(label: 'Family billed', value: account.billed),
              _MoneyCell(label: 'Family paid', value: account.paid),
              _MoneyCell(label: 'Family balance', value: account.balance),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Linked child fee ledgers',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final child in account.children) _ChildLedgerTile(child: child),
        ],
      ),
    );
  }
}

class _ChildLedgerTile extends StatelessWidget {
  const _ChildLedgerTile({required this.child});

  final FinanceChildFeeLedger child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.student, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('${child.className} · ${child.id}'),
            ],
          );
          final amounts = Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Billed ${financeFamilyMoney(child.billed)}'),
              Text('Paid ${financeFamilyMoney(child.paid)}'),
              Text(
                'Balance ${financeFamilyMoney(child.balance)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          );
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 8), amounts],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: identity),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: amounts),
            ],
          );
        },
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
      width: 160,
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
          Text(
            financeFamilyMoney(value),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
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
        padding: const EdgeInsets.all(16),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
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

class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}
