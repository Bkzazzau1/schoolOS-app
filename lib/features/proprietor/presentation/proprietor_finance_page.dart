import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/owner_finance_overview.dart';
import '../data/proprietor_finance_demo_data.dart';
import '../domain/proprietor_finance_models.dart';

/// The owner's money page. Scholarships, discounts and payroll are worked out from the school's real records;
/// fees billed, collections, aging and the store are sample figures until the Finance role holds real data.
class ProprietorFinancePage extends StatefulWidget {
  const ProprietorFinancePage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
    required this.repository,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;
  final OwnerFinanceOverviewRepository repository;

  @override
  State<ProprietorFinancePage> createState() => _ProprietorFinancePageState();
}

class _ProprietorFinancePageState extends State<ProprietorFinancePage> with SyncRefresh<ProprietorFinancePage> {
  OwnerFinanceOverview? _overview;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final overview = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String get schoolName => widget.schoolName;
  ValueChanged<String> get onActionRequested => widget.onActionRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overview = _overview;
    if (overview == null) {
      return Center(
        child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('The finance overview could not be loaded.'))
            : const CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final contentWidth = constraints.maxWidth >= 1460 ? 1280.0 : 1160.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 28,
            24,
            compact ? 18 : 28,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: schoolName,
                      compact: compact,
                      onActionRequested: onActionRequested,
                    ),
                    const SizedBox(height: 20),
                    _KpiGrid(compact: compact, kpis: overview.kpis),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: _FinanceCard(
                        title: 'Waiting on you',
                        subtitle: 'Scholarships, discounts and payroll that need a decision.',
                        child: overview.attention.isEmpty
                            ? const Text('Nothing is waiting on you.')
                            : _FinanceList(items: overview.attention),
                      ),
                      right: _FinanceCard(
                        title: 'Recent decisions',
                        subtitle: 'The last scholarships and discounts you decided.',
                        child: overview.decidedRecently.isEmpty
                            ? const Text('No decisions yet.')
                            : _FinanceList(items: overview.decidedRecently),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SampleBanner(),
                    const SizedBox(height: 12),
                    _TwoColumn(
                      compact: compact,
                      left: _FinanceCard(
                        title: 'Revenue bridge',
                        subtitle: 'How gross school fees become real collectible revenue.',
                        child: _FinanceList(items: proprietorRevenueBridge),
                      ),
                      right: _FinanceCard(
                        title: 'Owner attention',
                        subtitle: 'Exceptions that materially affect cash collection.',
                        child: _FinanceList(items: proprietorFinanceAttention),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SectionCollectionCard(),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _FinanceCard(
                        title: 'Outstanding fee aging',
                        subtitle: 'How long open receivables have remained unpaid after approved concessions.',
                        child: _AgingList(),
                      ),
                      right: _FinanceCard(
                        title: 'Collection arrangements',
                        subtitle: 'Outstanding does not always mean unplanned debt.',
                        child: _FinanceList(items: proprietorCollectionArrangements),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: _FinanceCard(
                        title: 'School Store revenue',
                        subtitle: 'Books, uniforms and other sundry sales are tracked separately from tuition.',
                        child: _FinanceList(items: proprietorStoreRevenue),
                      ),
                      right: _FinanceCard(
                        title: 'Store control',
                        subtitle: 'Payment confirmation must reconcile with physical issue of goods.',
                        child: _FinanceList(items: proprietorStoreControl),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _FinanceCard(
                        title: 'Term collection trend',
                        subtitle: 'Net collectible realized by week.',
                        child: _CollectionTrend(),
                      ),
                      right: _FinanceCard(
                        title: 'Expense & cash watch',
                        subtitle: 'Proprietor-level operating context.',
                        child: _FinanceList(items: proprietorExpenseWatch),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: _FinanceCard(
                        title: 'Owner quick access',
                        subtitle: 'Go directly to the finance control point that needs attention.',
                        child: _QuickActions(onActionRequested: onActionRequested),
                      ),
                      right: const _FinanceCard(
                        title: 'Finance governance',
                        subtitle: 'Owner visibility without exposing unnecessary banking secrets.',
                        child: _GovernanceCallout(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Scholarships, discounts and payroll are from your records. Everything under "Sample figures" is not real yet · $schoolName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.compact,
    required this.onActionRequested,
  });

  final String schoolName;
  final bool compact;
  final ValueChanged<String> onActionRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · REVENUE ASSURANCE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'School Finance & Revenue Assurance',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'See what $schoolName billed, what concessions reduced, what has been collected, what remains overdue, what the store is selling, and what the school is spending.',
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => onActionRequested('overview'),
          child: const Text('Executive Overview'),
        ),
        OutlinedButton(
          onPressed: () => onActionRequested('collections'),
          child: const Text('Smart Collections'),
        ),
        OutlinedButton(
          onPressed: () => onActionRequested('approvals'),
          child: const Text('Concession Approvals'),
        ),
        FilledButton(
          onPressed: () => onActionRequested('finance-office'),
          child: const Text('Open Finance Office'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 18), actions],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: title),
        const SizedBox(width: 24),
        Flexible(child: Align(alignment: Alignment.topRight, child: actions)),
      ],
    );
  }
}

class _SampleBanner extends StatelessWidget {
  const _SampleBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Sample figures: fees billed, collections, aging, the store and expenses below are examples. They become '
            'real when the Finance role records them.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.compact, required this.kpis});

  final bool compact;
  final List<OwnerFinanceKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = compact ? 1 : (width >= 1080 ? 4 : width >= 760 ? 2 : 2);
        final spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in kpis)
              SizedBox(width: itemWidth, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final OwnerFinanceKpi item;

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
            Text(item.label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              item.note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.compact, required this.left, required this.right});

  final bool compact;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(children: [left, const SizedBox(height: 18), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 18),
        Expanded(child: right),
      ],
    );
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _FinanceList extends StatelessWidget {
  const _FinanceList({required this.items});

  final List<OwnerFinanceListItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _FinanceListRow(item: items[i]),
          if (i != items.length - 1) Divider(color: theme.colorScheme.outlineVariant),
        ],
      ],
    );
  }
}

class _FinanceListRow extends StatelessWidget {
  const _FinanceListRow({required this.item});

  final OwnerFinanceListItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = item.isWarning ? theme.colorScheme.error : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(item.detail, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                const SizedBox(height: 5),
                Text(
                  item.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCollectionCard extends StatelessWidget {
  const _SectionCollectionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collection by school section', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Gross charges, concessions, net collectible and realized collections.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 860),
                child: DataTable(
                  headingRowHeight: 46,
                  dataRowMinHeight: 54,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('Section')),
                    DataColumn(label: Text('Gross fees')),
                    DataColumn(label: Text('Concessions')),
                    DataColumn(label: Text('Net collectible')),
                    DataColumn(label: Text('Collected')),
                    DataColumn(label: Text('Rate')),
                  ],
                  rows: [
                    for (final row in proprietorFinanceSections)
                      DataRow(
                        cells: [
                          DataCell(Text(row.section, style: const TextStyle(fontWeight: FontWeight.w800))),
                          DataCell(Text(row.grossFees)),
                          DataCell(Text(row.concessions)),
                          DataCell(Text(row.netCollectible)),
                          DataCell(Text(row.collected)),
                          DataCell(_RateBadge(rate: row.rate)),
                        ],
                      ),
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

class _RateBadge extends StatelessWidget {
  const _RateBadge({required this.rate});

  final int rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = rate < 85;
    final color = warning ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$rate%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
    );
  }
}

class _AgingList extends StatelessWidget {
  const _AgingList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < proprietorFinanceAging.length; i++) ...[
          Builder(builder: (context) {
            final item = proprietorFinanceAging[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item.band} · ${item.amount}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(item.status),
                        const SizedBox(height: 4),
                        Text(
                          'See Finance Office aging queue for arrangement-level detail',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (i != proprietorFinanceAging.length - 1) Divider(color: theme.colorScheme.outlineVariant),
        ],
      ],
    );
  }
}

class _CollectionTrend extends StatelessWidget {
  const _CollectionTrend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < proprietorTermCollectionTrend.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${proprietorTermCollectionTrend[i]}%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: proprietorTermCollectionTrend[i] / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('W${i + 1}', style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onActionRequested});

  final ValueChanged<String> onActionRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < proprietorFinanceQuickActions.length; i++) ...[
          Builder(builder: (context) {
            final action = proprietorFinanceQuickActions[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onActionRequested(action.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(action.description),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            );
          }),
          if (i != proprietorFinanceQuickActions.length - 1) Divider(color: theme.colorScheme.outlineVariant),
        ],
      ],
    );
  }
}

class _GovernanceCallout extends StatelessWidget {
  const _GovernanceCallout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.policy_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'The proprietor should see school-wide revenue, store sales, concessions, receivables, mandate performance, expenses and exceptions. Debit credentials, sensitive bank authorization data and private repayment notes stay restricted to authorized finance workflows.',
              style: TextStyle(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
