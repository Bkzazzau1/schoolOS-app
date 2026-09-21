import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/owner_attention_repository.dart';
import '../data/proprietor_overview_demo_data.dart';
import '../domain/proprietor_overview_models.dart';

class ProprietorOverviewPage extends StatefulWidget {
  const ProprietorOverviewPage({
    super.key,
    required this.schoolName,
    this.onModuleRequested,
    this.attention,
  });

  /// What is waiting on the owner, from the school's real records. Without it the sample list is shown.
  final OwnerAttentionRepository? attention;
  final String schoolName;
  final ValueChanged<String>? onModuleRequested;

  @override
  State<ProprietorOverviewPage> createState() => _ProprietorOverviewPageState();
}

class _ProprietorOverviewPageState extends State<ProprietorOverviewPage> with SyncRefresh<ProprietorOverviewPage> {
  int _selectedSectionIndex = 2;
  List<ProprietorAttentionItem>? _attention;
  List<ProprietorLeadershipItem>? _leadership;

  @override
  void initState() {
    super.initState();
    _loadAttention();
  }

  @override
  void onSynced() => _loadAttention();

  Future<void> _loadAttention() async {
    final repository = widget.attention;
    if (repository == null) return;
    try {
      final loaded = await repository.load();
      if (!mounted) return;
      setState(() {
        _attention = loaded.items;
        _leadership = loaded.leadership;
      });
    } catch (_) {
      // Keep whatever was shown; the queue is a convenience.
    }
  }

  ProprietorSectionPerformance get _selectedSection =>
      ProprietorOverviewDemoData.sections[_selectedSectionIndex];

  void _openModule(String moduleKey) {
    final callback = widget.onModuleRequested;
    if (callback != null) {
      callback(moduleKey);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_moduleTitle(moduleKey)} is the next proprietor module to be ported.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final desktop = width >= 1120;
        final tablet = width >= 720;
        final horizontalPadding = desktop ? 32.0 : tablet ? 24.0 : 16.0;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                40,
              ),
              sliver: SliverList.list(
                children: [
                  _OverviewHeader(
                    schoolName: widget.schoolName,
                    compact: !tablet,
                    onReports: () => _openModule('reports'),
                    onAi: () => _openModule('ai'),
                  ),
                  const SizedBox(height: 20),
                  _ExecutiveAiBrief(
                    attendancePercent:
                        ProprietorOverviewDemoData.weightedAttendance,
                    onAskAi: () => _openModule('ai'),
                    onReport: () => _openModule('reports'),
                  ),
                  const SizedBox(height: 18),
                  if (widget.attention != null) const _SampleNote(),
                  _KpiGrid(
                    items: ProprietorOverviewDemoData.kpis,
                    width: width,
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    leftFlex: 3,
                    rightFlex: 2,
                    left: _SectionPerformanceCard(
                      selectedIndex: _selectedSectionIndex,
                      selectedSection: _selectedSection,
                      onSelected: (index) {
                        setState(() => _selectedSectionIndex = index);
                      },
                      onReports: () => _openModule('reports'),
                    ),
                    right: _AttentionQueueCard(items: _attention, onOpen: _openModule),
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    left: _FinanceSummaryCard(
                      onOpen: () => _openModule('finance'),
                    ),
                    right: _EnrollmentSummaryCard(
                      onOpen: () => _openModule('enrollment'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    leftFlex: 3,
                    rightFlex: 2,
                    left: _LeadershipOversightCard(
                      items: _leadership,
                      onOpen: () => _openModule('structure'),
                    ),
                    right: _QuickAccessCard(onOpen: _openModule),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.schoolName,
    required this.compact,
    required this.onReports,
    required this.onAi,
  });

  final String schoolName;
  final bool compact;
  final VoidCallback onReports;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · WHOLE SCHOOL',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Executive Overview',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$schoolName · A decision-focused view of finance, enrollment, people, performance and school operations.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onReports,
          icon: const Icon(Icons.assessment_outlined, size: 18),
          label: const Text('Executive reports'),
        ),
        FilledButton.icon(
          onPressed: onAi,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Ask Proprietor AI'),
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: title),
        const SizedBox(width: 24),
        actions,
      ],
    );
  }
}

class _ExecutiveAiBrief extends StatelessWidget {
  const _ExecutiveAiBrief({
    required this.attendancePercent,
    required this.onAskAi,
    required this.onReport,
  });

  final int attendancePercent;
  final VoidCallback onAskAi;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.48),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final score = Container(
              width: compact ? double.infinity : 132,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment:
                    compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text('School health', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    '87',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('/100 · Stable', style: theme.textTheme.bodySmall),
                ],
              ),
            );

            final brief = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: const Text(
                    'AI',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Executive AI Brief',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'Current term',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'School-wide operations are stable with $attendancePercent% attendance and 94% fee collection. Current owner priorities are Secondary attendance, outstanding fees, two curriculum pacing gaps and one Primary staffing assignment.',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: onAskAi,
                            icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                            label: const Text('Ask School AI'),
                          ),
                          TextButton.icon(
                            onPressed: onReport,
                            icon: const Icon(Icons.description_outlined, size: 17),
                            label: const Text('Open executive report'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  brief,
                  const SizedBox(height: 16),
                  score,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: brief),
                const SizedBox(width: 20),
                score,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items, required this.width});

  final List<ProprietorKpi> items;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = width >= 1180 ? 3 : width >= 700 ? 2 : 1;
    const spacing = 12.0;
    final cardWidth = columns == 1
        ? double.infinity
        : (width - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final item in items)
          SizedBox(
            width: cardWidth,
            child: _KpiCard(item: item),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final ProprietorKpi item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _kpiColor(theme, item.tone);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.trend,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
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

class _SectionPerformanceCard extends StatelessWidget {
  const _SectionPerformanceCard({
    required this.selectedIndex,
    required this.selectedSection,
    required this.onSelected,
    required this.onReports,
  });

  final int selectedIndex;
  final ProprietorSectionPerformance selectedSection;
  final ValueChanged<int> onSelected;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OwnerCard(
      title: 'Section Performance',
      subtitle: 'Compare each school section without collapsing everything into one score.',
      trailing: TextButton(
        onPressed: onReports,
        child: const Text('View reports'),
      ),
      child: Column(
        children: [
          for (var index = 0;
              index < ProprietorOverviewDemoData.sections.length;
              index++) ...[
            _SectionRow(
              section: ProprietorOverviewDemoData.sections[index],
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
            if (index != ProprietorOverviewDemoData.sections.length - 1)
              const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final items = [
                  _DetailMetric(
                    label: 'Selected section',
                    value: selectedSection.name,
                    note:
                        '${selectedSection.leader} · ${selectedSection.leaderRole}',
                  ),
                  _DetailMetric(
                    label: 'Students',
                    value: '${selectedSection.students}',
                  ),
                  _DetailMetric(
                    label: 'Staff',
                    value: '${selectedSection.staff}',
                  ),
                  _DetailMetric(
                    label: 'Status',
                    value: selectedSection.statusLabel,
                  ),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        items[i],
                        if (i != items.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: items[0]),
                    for (final item in items.skip(1)) ...[
                      const SizedBox(width: 12),
                      Expanded(child: item),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final ProprietorSectionPerformance section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionIdentity(section: section),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _InlineMetric(label: 'Students', value: '${section.students}'),
                        _InlineMetric(
                          label: 'Attendance',
                          value: '${section.attendancePercent}%',
                        ),
                        _InlineMetric(
                          label: 'Academic',
                          value: '${section.academicPercent}%',
                        ),
                        _InlineMetric(
                          label: 'Fees',
                          value: '${section.feeCollectionPercent}%',
                        ),
                        _HealthBadge(status: section.status),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: _SectionIdentity(section: section)),
                  Expanded(
                    child: Text(
                      '${section.students}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: _MiniProgress(value: section.attendancePercent),
                  ),
                  Expanded(
                    child: _MiniProgress(value: section.academicPercent),
                  ),
                  Expanded(
                    child: _MiniProgress(value: section.feeCollectionPercent),
                  ),
                  const SizedBox(width: 8),
                  _HealthBadge(status: section.status),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AttentionQueueCard extends StatelessWidget {
  const _AttentionQueueCard({required this.items, required this.onOpen});

  /// Null while loading, or when there is no real data (then the sample list is shown).
  final List<ProprietorAttentionItem>? items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final real = items;
    final list = real ?? ProprietorOverviewDemoData.attention;
    return _OwnerCard(
      title: 'Owner Attention Queue',
      subtitle: real == null
          ? 'Sample items. Your own appear here as work arrives.'
          : 'Waiting on you, from the school records.',
      trailing: CircleAvatar(radius: 16, child: Text('${list.length}')),
      child: Column(
        children: [
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing is waiting on you.'),
            ),
          for (var index = 0; index < list.length; index++) ...[
            _AttentionItem(
              item: list[index],
              onTap: real == null || list[index].moduleKey == null ? null : () => onOpen(list[index].moduleKey!),
            ),
            if (index != list.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({required this.item, this.onTap});

  final ProprietorAttentionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = switch (item.tone) {
      ProprietorAttentionTone.high => theme.colorScheme.error,
      ProprietorAttentionTone.medium => theme.colorScheme.tertiary,
      ProprietorAttentionTone.info => theme.colorScheme.primary,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: accent.withValues(alpha: 0.12),
            foregroundColor: accent,
            child: const Icon(Icons.priority_high_rounded, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.detail, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  'Owner: ${item.owner}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OwnerCard(
      title: 'Finance & Cash Collection',
      subtitle: 'Owner-level collection and exposure summary.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Owner Finance')),
      child: Column(
        children: [
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FinanceMetric(label: 'Invoiced', value: '₦62.8m'),
              _FinanceMetric(label: 'Collected', value: '₦59.1m'),
              _FinanceMetric(label: 'Outstanding', value: '₦3.7m'),
              _FinanceMetric(label: 'Financing', value: '₦150k'),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collection trend',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '94.1%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final value in ProprietorOverviewDemoData.collectionTrend)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: '$value%',
                        child: FractionallySizedBox(
                          heightFactor: value / 100,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
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

class _EnrollmentSummaryCard extends StatelessWidget {
  const _EnrollmentSummaryCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OwnerCard(
      title: 'Enrollment & Retention',
      subtitle: 'Whole-school enrollment movement.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Enrollment')),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current enrollment', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 5),
                    Text(
                      '648',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '+29 net students this session',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 8,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '96%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text('retention'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FinanceMetric(label: 'Early Years', value: '84'),
              _FinanceMetric(label: 'Primary', value: '286'),
              _FinanceMetric(label: 'Secondary', value: '278'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeadershipOversightCard extends StatelessWidget {
  const _LeadershipOversightCard({required this.items, required this.onOpen});

  /// Null when there is no real data (then the sample list is shown).
  final List<ProprietorLeadershipItem>? items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final list = items ?? ProprietorOverviewDemoData.leadership;
    return _OwnerCard(
      title: 'Leadership Oversight',
      subtitle: 'Current section leadership and owner-level signal.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Manage structure')),
      child: Column(
        children: [
          if (list.isEmpty) const Text('No leadership appointed yet.'),
          for (var index = 0; index < list.length; index++) ...[
            _LeadershipRow(item: list[index]),
            if (index != list.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _LeadershipRow extends StatelessWidget {
  const _LeadershipRow({required this.item});

  final ProprietorLeadershipItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = item.signal == ProprietorLeadershipSignal.review;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          child: Text(
            item.name
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part[0])
                .join(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text('${item.role} · ${item.scope}', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Chip(
          avatar: Icon(
            review ? Icons.visibility_outlined : Icons.check_circle_outline,
            size: 16,
          ),
          label: Text(item.signalLabel),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _OwnerCard(
      title: 'Owner Quick Access',
      subtitle: 'Move directly to executive modules.',
      child: Column(
        children: [
          for (var index = 0;
              index < ProprietorOverviewDemoData.quickAccess.length;
              index++) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onOpen(
                  ProprietorOverviewDemoData.quickAccess[index].moduleKey,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ProprietorOverviewDemoData.quickAccess[index].title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              ProprietorOverviewDemoData
                                  .quickAccess[index].description,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            if (index != ProprietorOverviewDemoData.quickAccess.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.width,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final double width;
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    if (width < 900) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 18),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}

class _SectionIdentity extends StatelessWidget {
  const _SectionIdentity({required this.section});

  final ProprietorSectionPerformance section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.name,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          '${section.leaderRole} · ${section.leader}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('$value%', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 5,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.status});

  final ProprietorHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watch = status == ProprietorHealthStatus.watch;
    final accent = watch ? theme.colorScheme.tertiary : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        watch ? 'Watch' : 'Healthy',
        style: theme.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(note!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _FinanceMetric extends StatelessWidget {
  const _FinanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Color _kpiColor(ThemeData theme, ProprietorKpiTone tone) {
  return switch (tone) {
    ProprietorKpiTone.green => theme.colorScheme.primary,
    ProprietorKpiTone.amber => theme.colorScheme.tertiary,
    ProprietorKpiTone.blue => theme.colorScheme.secondary,
    ProprietorKpiTone.purple => theme.colorScheme.secondary,
  };
}

String _moduleTitle(String moduleKey) {
  return switch (moduleKey) {
    'finance' => 'Owner Finance',
    'enrollment' => 'Enrollment & Admissions',
    'staff' => 'Staff & HR',
    'reports' => 'Executive Reports',
    'campuses' => 'Campus Comparison',
    'ai' => 'Proprietor AI',
    'structure' => 'Structure & Leadership',
    'appearance' => 'School Appearance',
    _ => 'Proprietor module',
  };
}

/// Says which parts of the overview are still sample figures.
class _SampleNote extends StatelessWidget {
  const _SampleNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The Owner Attention Queue and Leadership are from your school records. The figures on fees, attendance, '
              'results and enrolment below are sample figures until those modules hold real data.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
