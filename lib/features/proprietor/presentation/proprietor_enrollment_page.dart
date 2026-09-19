import 'package:flutter/material.dart';

import '../data/enrollment_brief_exporter.dart';
import '../data/proprietor_enrollment_demo_data.dart';
import '../domain/proprietor_enrollment_models.dart';

class ProprietorEnrollmentPage extends StatefulWidget {
  const ProprietorEnrollmentPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;

  @override
  State<ProprietorEnrollmentPage> createState() =>
      _ProprietorEnrollmentPageState();
}

class _ProprietorEnrollmentPageState extends State<ProprietorEnrollmentPage> {
  final EnrollmentBriefExporter _exporter = const EnrollmentBriefExporter();
  bool _exporting = false;

  Future<void> _exportBrief() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _exporter.export(schoolName: widget.schoolName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrollment brief saved offline to $path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export enrollment brief: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
                      schoolName: widget.schoolName,
                      compact: compact,
                      exporting: _exporting,
                      onOverview: () => widget.onActionRequested('overview'),
                      onExport: _exportBrief,
                    ),
                    const SizedBox(height: 20),
                    _KpiGrid(compact: compact),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _ModuleCard(
                        title: 'Admissions pipeline by section',
                        subtitle: 'Demand and conversion across the school.',
                        child: _PipelineTable(),
                      ),
                      right: const _ModuleCard(
                        title: 'Capacity watch',
                        subtitle: 'Where owner decisions may be needed.',
                        child: _CapacityWatch(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _ModuleCard(
                        title: 'Enrollment trend',
                        subtitle:
                            'Seven checkpoints across the current planning window.',
                        child: _EnrollmentTrend(),
                      ),
                      right: const _ModuleCard(
                        title: 'Enrollment governance',
                        subtitle: 'Owner policy boundary.',
                        child: _GovernanceCallout(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Prototype enrollment data · current admission cycle · ${widget.schoolName}',
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
    required this.exporting,
    required this.onOverview,
    required this.onExport,
  });

  final String schoolName;
  final bool compact;
  final bool exporting;
  final VoidCallback onOverview;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · ENROLLMENT & ADMISSIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enrollment & Admissions',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Owner-level visibility into demand, admissions conversion, retention and section capacity across $schoolName.',
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
          onPressed: onOverview,
          child: const Text('Executive Overview'),
        ),
        FilledButton.icon(
          onPressed: exporting ? null : onExport,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(exporting ? 'Exporting…' : 'Export enrollment brief'),
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
            for (final item in proprietorEnrollmentKpis)
              SizedBox(width: itemWidth, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final OwnerEnrollmentKpi item;

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
            const SizedBox(height: 10),
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(item.note, style: theme.textTheme.bodySmall),
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
        children: [left, const SizedBox(height: 18), right],
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

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
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
            const SizedBox(height: 5),
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

class _PipelineTable extends StatelessWidget {
  const _PipelineTable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (final row in proprietorEnrollmentPipeline) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.section,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _MiniMetric(label: 'Applications', value: '${row.applications}'),
                          _MiniMetric(label: 'Offers', value: '${row.offers}'),
                          _MiniMetric(label: 'Accepted', value: '${row.accepted}'),
                          _MiniMetric(
                            label: 'Retention',
                            value: '${row.retentionPercent}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Section')),
              DataColumn(label: Text('Applications'), numeric: true),
              DataColumn(label: Text('Offers'), numeric: true),
              DataColumn(label: Text('Accepted'), numeric: true),
              DataColumn(label: Text('Retention'), numeric: true),
            ],
            rows: [
              for (final row in proprietorEnrollmentPipeline)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        row.section,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(Text('${row.applications}')),
                    DataCell(Text('${row.offers}')),
                    DataCell(Text('${row.accepted}')),
                    DataCell(Text('${row.retentionPercent}%')),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _CapacityWatch extends StatelessWidget {
  const _CapacityWatch();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < proprietorCapacityWatch.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proprietorCapacityWatch[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(proprietorCapacityWatch[i].detail),
                    const SizedBox(height: 4),
                    Text(
                      proprietorCapacityWatch[i].action,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i != proprietorCapacityWatch.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
        ],
      ],
    );
  }
}

class _EnrollmentTrend extends StatelessWidget {
  const _EnrollmentTrend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minValue = proprietorEnrollmentTrend.reduce((a, b) => a < b ? a : b);
    final maxValue = proprietorEnrollmentTrend.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).clamp(1, 9999);

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < proprietorEnrollmentTrend.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${proprietorEnrollmentTrend[i]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 42 +
                          ((proprietorEnrollmentTrend[i] - minValue) / range) *
                              116,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('P${i + 1}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GovernanceCallout extends StatelessWidget {
  const _GovernanceCallout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.policy_outlined,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Admissions should support eligibility, capacity and documented school policy. '
              'SchoolOS should not make opaque admissions decisions from family income, ethnicity, religion, disability, health history or other sensitive traits.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
