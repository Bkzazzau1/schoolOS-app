import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/owner_enrollment.dart';
import '../data/owner_finance_overview.dart';
import '../data/owner_reports.dart';
import '../data/proprietor_overview_demo_data.dart';
import '../domain/concession_request.dart' show formatNaira;
import '../domain/proprietor_overview_models.dart';

class ProprietorOverviewPage extends StatefulWidget {
  const ProprietorOverviewPage({
    super.key,
    required this.schoolName,
    this.onModuleRequested,
    this.reports,
  });

  /// The school's real records - staff, finance, enrollment and what is waiting on the owner. Every
  /// figure on this page comes from here; without it, the page shows an honest empty state rather
  /// than a sample.
  final OwnerReportsRepository? reports;
  final String schoolName;
  final ValueChanged<String>? onModuleRequested;

  @override
  State<ProprietorOverviewPage> createState() => _ProprietorOverviewPageState();
}

class _ProprietorOverviewPageState extends State<ProprietorOverviewPage> with SyncRefresh<ProprietorOverviewPage> {
  int _selectedSectionIndex = 2;
  OwnerReports? _reports;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    final repository = widget.reports;
    if (repository == null) return;
    try {
      final loaded = await repository.load();
      if (!mounted) return;
      setState(() => _reports = loaded);
    } catch (_) {
      // Keep whatever was shown; the overview is a convenience.
    }
  }

  static const _sectionOrder = ['Early Years', 'Primary', 'Secondary'];

  String get _selectedSectionName => _sectionOrder[_selectedSectionIndex];

  EnrollmentSectionRow? get _selectedSection {
    final sections = _reports?.enrollment?.sections;
    if (sections == null) return null;
    for (final row in sections) {
      if (row.section == _selectedSectionName) return row;
    }
    return null;
  }

  OwnerFeeSection? get _selectedFeeSection {
    final sections = _reports?.finance.fees?.sections;
    if (sections == null) return null;
    for (final row in sections) {
      if (row.section == _selectedSectionName) return row;
    }
    return null;
  }

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
                  _ExecutiveBrief(
                    reports: _reports,
                    onAskAi: () => _openModule('ai'),
                    onReport: () => _openModule('reports'),
                  ),
                  const SizedBox(height: 18),
                  _KpiGrid(items: _kpisFrom(_reports), width: width),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    leftFlex: 3,
                    rightFlex: 2,
                    left: _SectionPerformanceCard(
                      selectedIndex: _selectedSectionIndex,
                      selectedSection: _selectedSection,
                      selectedFeeSection: _selectedFeeSection,
                      sectionNames: _sectionOrder,
                      onSelected: (index) {
                        setState(() => _selectedSectionIndex = index);
                      },
                      onReports: () => _openModule('reports'),
                    ),
                    right: _AttentionQueueCard(items: _reports?.attention.items, onOpen: _openModule),
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    left: _FinanceSummaryCard(
                      fees: _reports?.finance.fees,
                      onOpen: () => _openModule('finance'),
                    ),
                    right: _EnrollmentSummaryCard(
                      enrollment: _reports?.enrollment,
                      onOpen: () => _openModule('enrollment'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResponsivePair(
                    width: width,
                    leftFlex: 3,
                    rightFlex: 2,
                    left: _LeadershipOversightCard(
                      items: _reports?.attention.leadership,
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

/// A one-line, real-facts summary - never a generated score or narrative. Ask Proprietor AI itself
/// (owner_reports.dart/proprietor_ai_service.dart) is where an actual AI-composed brief belongs;
/// this card only ever states what [reports] really contains.
class _ExecutiveBrief extends StatelessWidget {
  const _ExecutiveBrief({
    required this.reports,
    required this.onAskAi,
    required this.onReport,
  });

  final OwnerReports? reports;
  final VoidCallback onAskAi;
  final VoidCallback onReport;

  String get _summary {
    final r = reports;
    if (r == null) return 'Connect your school records to see a real executive summary here.';
    final waiting = r.attention.items.length;
    final parts = <String>[
      waiting == 0 ? 'Nothing is waiting on you.' : '$waiting item${waiting == 1 ? '' : 's'} waiting on you.',
    ];
    final collected = r.finance.fees?.totals.collectedPercent;
    if (collected != null) parts.add('$collected% of this term\'s fees collected.');
    final attendanceKpi = r.staff.kpis.where((k) => k.label == 'Staff attendance').toList();
    if (attendanceKpi.isNotEmpty && attendanceKpi.first.value != 'Not recorded') {
      parts.add('Staff attendance ${attendanceKpi.first.value}.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.48),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: const Icon(Icons.summarize_outlined, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Summary',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(_summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onAskAi,
                        icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                        label: const Text('Ask Proprietor AI'),
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
                if (item.trend.isNotEmpty)
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

/// Real enrollment counts, and real fee-collection per section when the ledger is connected -
/// never a fabricated attendance/academic/status figure with no source behind it.
class _SectionPerformanceCard extends StatelessWidget {
  const _SectionPerformanceCard({
    required this.selectedIndex,
    required this.selectedSection,
    required this.selectedFeeSection,
    required this.sectionNames,
    required this.onSelected,
    required this.onReports,
  });

  final int selectedIndex;
  final EnrollmentSectionRow? selectedSection;
  final OwnerFeeSection? selectedFeeSection;
  final List<String> sectionNames;
  final ValueChanged<int> onSelected;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = selectedSection;
    final fees = selectedFeeSection;

    return _OwnerCard(
      title: 'Section Performance',
      subtitle: 'Real student counts and fee collection per school section.',
      trailing: TextButton(
        onPressed: onReports,
        child: const Text('View reports'),
      ),
      child: Column(
        children: [
          for (var index = 0; index < sectionNames.length; index++) ...[
            _SectionRow(
              name: sectionNames[index],
              students: index == selectedIndex ? section?.activeStudents : null,
              feeCollectionPercent: index == selectedIndex ? fees?.rate : null,
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
            if (index != sectionNames.length - 1) const SizedBox(height: 8),
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
                    value: sectionNames[selectedIndex],
                  ),
                  _DetailMetric(
                    label: 'Active students',
                    value: section == null ? 'Not available yet' : '${section.activeStudents}',
                  ),
                  _DetailMetric(
                    label: 'Fee collection',
                    value: fees == null ? 'Not available yet' : '${fees.rate}%',
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
    required this.name,
    required this.students,
    required this.feeCollectionPercent,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int? students;
  final int? feeCollectionPercent;
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
                    Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _InlineMetric(label: 'Students', value: students == null ? '—' : '$students'),
                        _InlineMetric(
                          label: 'Fees',
                          value: feeCollectionPercent == null ? 'Not available yet' : '$feeCollectionPercent%',
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: Text(
                      students == null ? '—' : '$students',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: feeCollectionPercent == null
                        ? Text('Not available yet', style: theme.textTheme.bodySmall, textAlign: TextAlign.center)
                        : _MiniProgress(value: feeCollectionPercent!),
                  ),
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

  /// Null while loading, or when there is no real data yet.
  final List<ProprietorAttentionItem>? items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = items ?? const <ProprietorAttentionItem>[];
    return _OwnerCard(
      title: 'Owner Attention Queue',
      subtitle: 'Waiting on you, from the school records.',
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
              onTap: list[index].moduleKey == null ? null : () => onOpen(list[index].moduleKey!),
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
  const _FinanceSummaryCard({required this.fees, required this.onOpen});

  /// Null when the Finance Office's ledger has not been read yet.
  final OwnerFeeSummary? fees;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = fees?.totals;
    return _OwnerCard(
      title: 'Finance & Cash Collection',
      subtitle: 'Owner-level collection and exposure summary.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Owner Finance')),
      child: totals == null
          ? const Text('Not available yet. Connect the Finance Office ledger to see real figures here.')
          : Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _FinanceMetric(label: 'Billed', value: formatNaira(totals.net)),
                    _FinanceMetric(label: 'Collected', value: formatNaira(totals.paid)),
                    _FinanceMetric(label: 'Outstanding', value: formatNaira(totals.balance)),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Collection rate',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${totals.collectedPercent}%',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EnrollmentSummaryCard extends StatelessWidget {
  const _EnrollmentSummaryCard({required this.enrollment, required this.onOpen});

  /// Null while loading or when the register could not be read.
  final OwnerEnrollment? enrollment;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = enrollment;

    return _OwnerCard(
      title: 'Enrollment',
      subtitle: 'Whole-school enrollment, from the real student register.',
      trailing: TextButton(onPressed: onOpen, child: const Text('Enrollment')),
      child: data == null
          ? const Text('Not available yet.')
          : Column(
              children: [
                Text('Current enrollment', style: theme.textTheme.labelLarge),
                const SizedBox(height: 5),
                Text(
                  '${data.activeStudents}',
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'On the school register',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final section in data.sections)
                      _FinanceMetric(label: section.section, value: '${section.activeStudents}'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LeadershipOversightCard extends StatelessWidget {
  const _LeadershipOversightCard({required this.items, required this.onOpen});

  /// Null while loading, or when there is no real data yet.
  final List<ProprietorLeadershipItem>? items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final list = items ?? const <ProprietorLeadershipItem>[];
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
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

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

/// The KPI grid's real figures, from the same records Finance/Enrollment/Staff & HR already show -
/// never a trend badge, since no history is recorded to compute one from.
List<ProprietorKpi> _kpisFrom(OwnerReports? reports) {
  if (reports == null) {
    return const [
      ProprietorKpi(label: 'Active students', value: '—', note: 'Not available yet', trend: '', tone: ProprietorKpiTone.blue),
    ];
  }
  final collected = reports.finance.fees?.totals.collectedPercent;
  final balance = reports.finance.fees?.totals.balance;
  final staffAttendance = reports.staff.kpis.firstWhere((k) => k.label == 'Staff attendance');
  final teaching = reports.staff.kpis.firstWhere((k) => k.label == 'Teaching staff');
  return [
    ProprietorKpi(
      label: 'Active students',
      value: '${reports.enrollment?.activeStudents ?? '—'}',
      note: 'On the school register',
      trend: '',
      tone: ProprietorKpiTone.green,
    ),
    ProprietorKpi(
      label: 'Teaching staff',
      value: teaching.value,
      note: teaching.note,
      trend: '',
      tone: ProprietorKpiTone.blue,
    ),
    ProprietorKpi(
      label: 'Fee collection',
      value: collected == null ? 'Not available yet' : '$collected%',
      note: collected == null ? 'Connect the Finance Office ledger' : 'Of this term\'s billed fees',
      trend: '',
      tone: ProprietorKpiTone.green,
    ),
    ProprietorKpi(
      label: 'Outstanding fees',
      value: balance == null ? 'Not available yet' : formatNaira(balance),
      note: balance == null ? 'Connect the Finance Office ledger' : 'Across the whole school',
      trend: '',
      tone: ProprietorKpiTone.amber,
    ),
    ProprietorKpi(
      label: 'Staff attendance',
      value: staffAttendance.value,
      note: staffAttendance.note,
      trend: '',
      tone: ProprietorKpiTone.purple,
    ),
  ];
}
