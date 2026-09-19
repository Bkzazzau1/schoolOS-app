import 'package:flutter/material.dart';

import '../data/finance_office_dashboard_demo_data.dart';
import '../domain/finance_office_dashboard_models.dart';

class FinanceOfficeDashboardPage extends StatelessWidget {
  const FinanceOfficeDashboardPage({
    super.key,
    required this.schoolName,
    required this.onNavigate,
  });

  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(schoolName: schoolName, onNavigate: onNavigate),
              const SizedBox(height: 20),
              const _KpiGrid(),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 940) {
                    return Column(
                      children: [
                        _RecentCollections(onNavigate: onNavigate),
                        const SizedBox(height: 16),
                        const _AttentionQueue(),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _RecentCollections(onNavigate: onNavigate),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(flex: 4, child: _AttentionQueue()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 820) {
                    return const Column(
                      children: [
                        _CollectionTrend(),
                        SizedBox(height: 16),
                        _OperationalPosition(),
                      ],
                    );
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _CollectionTrend()),
                      SizedBox(width: 16),
                      Expanded(child: _OperationalPosition()),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const _AccessBoundary(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.onNavigate});

  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCE OFFICE · DAILY CONTROL',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finance Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Collections, reconciliation, outstanding balances, expenses, financing and reporting in one workspace.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              schoolName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Finance Center is a separate SchoolOS web surface; the native Finance Office keeps its own role boundary.',
                  ),
                ),
              ),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Open Finance Center'),
            ),
            FilledButton.icon(
              onPressed: () => onNavigate('reconciliation'),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Reconcile payments'),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 16), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            const SizedBox(width: 18),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1250
            ? 5
            : width >= 900
                ? 3
                : width >= 560
                    ? 2
                    : 1;
        final itemWidth = (width - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in financeOfficeKpis)
              SizedBox(width: itemWidth, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final FinanceKpi item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(item.hint, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecentCollections extends StatelessWidget {
  const _RecentCollections({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent collection activity',
      subtitle: 'Latest student-account and bank reconciliation events.',
      trailing: TextButton(
        onPressed: () => onNavigate('reconciliation'),
        child: const Text('Open reconciliation'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 670) {
            return Column(
              children: [
                for (final row in financeRecentCollections)
                  _CollectionTile(row: row),
              ],
            );
          }
          return Column(
            children: [
              const _CollectionRow(
                cells: ['Reference', 'Student/account', 'Channel', 'Amount', 'Status'],
                header: true,
              ),
              for (final row in financeRecentCollections)
                _CollectionRow(
                  cells: [
                    row.reference,
                    row.account,
                    row.channel,
                    row.amount,
                    row.status,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({required this.cells, this.header = false});

  final List<String> cells;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: header ? FontWeight.w800 : FontWeight.w500,
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 1 || i == 2 ? 3 : 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  cells[i],
                  style: style?.copyWith(
                    fontWeight: !header && (i == 0 || i == 3)
                        ? FontWeight.w800
                        : style.fontWeight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.row});

  final FinanceCollectionActivity row;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(row.reference, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${row.account}\n${row.channel}'),
      isThreeLine: true,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(row.amount, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(row.status),
        ],
      ),
    );
  }
}

class _AttentionQueue extends StatelessWidget {
  const _AttentionQueue();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Finance attention queue',
      subtitle: 'Items requiring human review.',
      child: Column(
        children: [
          for (final item in financeAttentionQueue) _AttentionTile(item: item),
        ],
      ),
    );
  }
}

class _OperationalPosition extends StatelessWidget {
  const _OperationalPosition();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Today’s operational position',
      subtitle: 'Quick finance-office summary.',
      child: Column(
        children: [
          for (final item in financeOperationalPosition)
            _AttentionTile(item: item),
        ],
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.item});

  final FinanceAttentionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(item.detail),
                if (item.caption != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTrend extends StatelessWidget {
  const _CollectionTrend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      title: 'Collection trend',
      subtitle: 'Current-term cumulative collection rate.',
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final point in financeCollectionTrend)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${point.rate}%', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 5),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: point.rate / 100,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(point.week, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccessBoundary extends StatelessWidget {
  const _AccessBoundary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finance access boundary', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(financeOfficeScopeBoundary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
    final theme = Theme.of(context);
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
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
