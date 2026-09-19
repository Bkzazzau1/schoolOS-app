import 'package:flutter/material.dart';

import '../data/proprietor_campus_demo_data.dart';
import '../domain/proprietor_campus_models.dart';

class ProprietorCampusesPage extends StatelessWidget {
  const ProprietorCampusesPage({
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
                      onOverview: () => onActionRequested('overview'),
                      onStructure: () => onActionRequested('structure'),
                    ),
                    const SizedBox(height: 20),
                    _KpiGrid(compact: compact),
                    const SizedBox(height: 18),
                    _CampusGrid(compact: compact),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _ModuleCard(
                        title: 'Expansion checklist',
                        subtitle: 'Owner controls before a new campus is marked active.',
                        child: _ExpansionChecklist(),
                      ),
                      right: const _ModuleCard(
                        title: 'Campus isolation principle',
                        subtitle: 'Multi-campus must not mean unrestricted access.',
                        child: _IsolationCallout(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Prototype campus data · owner comparison · $schoolName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    required this.onOverview,
    required this.onStructure,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onOverview;
  final VoidCallback onStructure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · CAMPUS / BRANCH OVERSIGHT',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Campus Comparison',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Compare branches, capacity, finance and operating readiness across $schoolName without mixing campus-level authority.',
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
        OutlinedButton(onPressed: onOverview, child: const Text('Executive Overview')),
        FilledButton.icon(
          onPressed: onStructure,
          icon: const Icon(Icons.account_tree_rounded, size: 18),
          label: const Text('Manage Structure'),
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

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = compact ? 1 : (width >= 1080 ? 5 : 3);
        const spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in proprietorCampusKpis)
              SizedBox(width: itemWidth, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final OwnerCampusKpi item;

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
            Text(item.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(item.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(item.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CampusGrid extends StatelessWidget {
  const _CampusGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < proprietorCampuses.length; i++) ...[
            _CampusCard(campus: proprietorCampuses[i]),
            if (i != proprietorCampuses.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < proprietorCampuses.length; i++) ...[
          Expanded(child: _CampusCard(campus: proprietorCampuses[i])),
          if (i != proprietorCampuses.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _CampusCard extends StatelessWidget {
  const _CampusCard({required this.campus});

  final OwnerCampusSummary campus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = !campus.isActive;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: planned ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${campus.statusLabel.toUpperCase()} CAMPUS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: planned ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(campus.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(campus.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            _CampusMetrics(campus: campus),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: planned ? theme.colorScheme.surfaceContainerLow : theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(campus.readinessNote, style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusMetrics extends StatelessWidget {
  const _CampusMetrics({required this.campus});

  final OwnerCampusSummary campus;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('Students', '${campus.students}'),
      ('Staff', '${campus.staff}'),
      ('Attendance', campus.isActive ? '${campus.attendancePercent}%' : '—'),
      ('Fees', campus.isActive ? '${campus.feeCollectionPercent}%' : '—'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 2 : 4;
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries)
              SizedBox(width: width, child: _Metric(label: entry.$1, value: entry.$2)),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 5),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
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
    if (compact) return Column(children: [left, const SizedBox(height: 14), right]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.title, required this.subtitle, required this.child});

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
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ExpansionChecklist extends StatelessWidget {
  const _ExpansionChecklist();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < proprietorCampusExpansionChecklist.length; i++) ...[
          _ChecklistItem(item: proprietorCampusExpansionChecklist[i]),
          if (i != proprietorCampusExpansionChecklist.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.item});

  final OwnerCampusChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.checklist_rounded, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(item.detail, style: theme.textTheme.bodySmall?.copyWith(height: 1.45, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _IsolationCallout extends StatelessWidget {
  const _IsolationCallout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              proprietorCampusIsolationPrinciple,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
