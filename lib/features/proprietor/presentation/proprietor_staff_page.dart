import 'package:flutter/material.dart';

import '../data/proprietor_staff_demo_data.dart';
import '../domain/proprietor_staff_models.dart';

class ProprietorStaffPage extends StatelessWidget {
  const ProprietorStaffPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;

  @override
  Widget build(BuildContext context) {
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
                    _KpiGrid(compact: compact),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _StaffCard(
                        title: 'Leadership & staffing overview',
                        subtitle: 'Section ownership and current staffing context.',
                        child: _LeadershipTable(),
                      ),
                      right: const _StaffCard(
                        title: 'People attention queue',
                        subtitle: 'Owner-level issues, not day-to-day supervision.',
                        child: _AttentionList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _StaffCard(
                        title: 'Staff mix',
                        subtitle: 'Current teaching-staff distribution.',
                        child: _StaffMix(),
                      ),
                      right: const _StaffCard(
                        title: 'HR privacy boundary',
                        subtitle: 'Leadership overview is not payroll access.',
                        child: _PrivacyBoundary(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Prototype people data · current term · $schoolName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
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
          'PROPRIETOR · PEOPLE & HR',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Staff & HR Overview',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Whole-school staffing, leadership, attendance, workload and employment-risk oversight for $schoolName without exposing unnecessary payroll detail.',
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
        FilledButton.icon(
          onPressed: () => onActionRequested('jobs'),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Assign a job'),
        ),
        OutlinedButton(
          onPressed: () => onActionRequested('overview'),
          child: const Text('Executive Overview'),
        ),
        FilledButton.icon(
          onPressed: () => onActionRequested('structure'),
          icon: const Icon(Icons.account_tree_outlined, size: 18),
          label: const Text('Manage Leadership'),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 18),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: title),
        const SizedBox(width: 24),
        Flexible(
          child: Align(
            alignment: Alignment.topRight,
            child: actions,
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = compact ? 1 : (width >= 1080 ? 5 : width >= 760 ? 3 : 2);
        final spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in proprietorStaffKpis)
              SizedBox(
                width: itemWidth,
                child: _KpiCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final OwnerStaffKpi item;

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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.note,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({
    required this.compact,
    required this.left,
    required this.right,
  });

  final bool compact;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          left,
          const SizedBox(height: 18),
          right,
        ],
      );
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

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _LeadershipTable extends StatelessWidget {
  const _LeadershipTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 720),
        child: Column(
          children: [
            const _LeadershipHeader(),
            const Divider(height: 1),
            for (final row in proprietorLeadershipRows) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(row.role, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    SizedBox(width: 150, child: Text(row.role)),
                    SizedBox(width: 160, child: Text(row.scope)),
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.team,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _SignalChip(row: row),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeadershipHeader extends StatelessWidget {
  const _LeadershipHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text('Leader', style: style)),
          SizedBox(width: 150, child: Text('Role', style: style)),
          SizedBox(width: 160, child: Text('Scope', style: style)),
          SizedBox(width: 120, child: Text('Team', style: style)),
          SizedBox(width: 100, child: Text('Signal', style: style)),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.row});

  final OwnerLeaderRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = row.needsReview
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foreground = row.needsReview
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        row.signal,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < proprietorPeopleAttention.length; i++) ...[
          _AttentionItem(item: proprietorPeopleAttention[i]),
          if (i != proprietorPeopleAttention.length - 1)
            const Divider(height: 24),
        ],
      ],
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({required this.item});

  final OwnerPeopleAttentionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.priority_high_rounded,
            color: theme.colorScheme.onTertiaryContainer,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(item.detail),
              const SizedBox(height: 5),
              Text(
                'Owner: ${item.owner}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffMix extends StatelessWidget {
  const _StaffMix();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final item in proprietorStaffMix)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.section,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.count}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total teaching staff',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$proprietorTeachingStaffTotal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacyBoundary extends StatelessWidget {
  const _PrivacyBoundary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'The proprietor may have authority to grant HR/finance access, but ordinary leadership views should not automatically expose staff bank details, salary deductions, loan balances or private medical information. Those remain need-to-know.',
            ),
          ),
        ],
      ),
    );
  }
}
