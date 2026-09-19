import 'package:flutter/material.dart';

import '../data/executive_report_pack_exporter.dart';
import '../data/proprietor_reports_demo_data.dart';
import '../domain/proprietor_reports_models.dart';

class ProprietorReportsPage extends StatefulWidget {
  const ProprietorReportsPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;

  @override
  State<ProprietorReportsPage> createState() => _ProprietorReportsPageState();
}

class _ProprietorReportsPageState extends State<ProprietorReportsPage> {
  final ExecutiveReportPackExporter _exporter =
      const ExecutiveReportPackExporter();
  bool _exporting = false;

  Future<void> _createPack() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _exporter.export(schoolName: widget.schoolName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Executive report pack saved offline to $path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create report pack: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openReport(OwnerExecutiveReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Coverage', value: report.coverage),
              _DetailRow(label: 'Updated', value: report.updated),
              _DetailRow(label: 'Status', value: report.status),
              const SizedBox(height: 14),
              Text(
                'This is the proprietor-level report brief. Detailed source records remain inside their respective operational modules and permissions.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                      onCreatePack: _createPack,
                    ),
                    const SizedBox(height: 20),
                    _KpiGrid(compact: compact),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: _ModuleCard(
                        title: 'Available reports',
                        subtitle:
                            'Designed for decision review rather than raw operational data dumps.',
                        child: _ReportsList(onOpen: _openReport),
                      ),
                      right: const _ModuleCard(
                        title: 'Board / owner pack',
                        subtitle:
                            'Suggested contents for a formal monthly review.',
                        child: _ReportPackList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TwoColumn(
                      compact: compact,
                      left: const _ModuleCard(
                        title: 'Report cadence',
                        subtitle: 'Prototype scheduling concept.',
                        child: _CadenceSummary(),
                      ),
                      right: const _ModuleCard(
                        title: 'Reporting principle',
                        subtitle: 'Evidence first.',
                        child: _ReportingPrinciple(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Prototype executive reporting data · ${widget.schoolName}',
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
    required this.onCreatePack,
  });

  final String schoolName;
  final bool compact;
  final bool exporting;
  final VoidCallback onOverview;
  final VoidCallback onCreatePack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROPRIETOR · EXECUTIVE REPORTING',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Executive Reports',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Board-ready summaries and owner-level evidence across finance, enrollment, people, academics and operations at $schoolName.',
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
          onPressed: exporting ? null : onCreatePack,
          icon: exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(exporting ? 'Creating…' : 'Create report pack'),
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
        final spacing = 12.0;
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in proprietorReportKpis)
              SizedBox(width: itemWidth, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final OwnerReportKpi item;

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
            Text(
              item.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
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

class _ReportsList extends StatelessWidget {
  const _ReportsList({required this.onOpen});

  final ValueChanged<OwnerExecutiveReport> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < proprietorExecutiveReports.length; i++) ...[
          _ReportRow(report: proprietorExecutiveReports[i], onOpen: onOpen),
          if (i != proprietorExecutiveReports.length - 1)
            const Divider(height: 22),
        ],
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.onOpen});

  final OwnerExecutiveReport report;
  final ValueChanged<OwnerExecutiveReport> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                report.coverage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(report.updated, style: theme.textTheme.labelSmall),
                  _StatusPill(label: report.status),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () => onOpen(report),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

class _ReportPackList extends StatelessWidget {
  const _ReportPackList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < proprietorReportPackSections.length; i++) ...[
          _PackSection(item: proprietorReportPackSections[i]),
          if (i != proprietorReportPackSections.length - 1)
            const Divider(height: 24),
        ],
      ],
    );
  }
}

class _PackSection extends StatelessWidget {
  const _PackSection({required this.item});

  final OwnerReportPackSection item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text('${item.number}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                item.description,
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

class _CadenceSummary extends StatelessWidget {
  const _CadenceSummary();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        if (narrow) {
          return Column(
            children: [
              for (final item in proprietorReportCadence) ...[
                _CadenceItem(item: item),
                if (item != proprietorReportCadence.last)
                  const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in proprietorReportCadence)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _CadenceItem(item: item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CadenceItem extends StatelessWidget {
  const _CadenceItem({required this.item});

  final OwnerReportCadence item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.frequency, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(
          item.reportType,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.purpose,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReportingPrinciple extends StatelessWidget {
  const _ReportingPrinciple();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        proprietorReportingPrinciple,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
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
              style: theme.textTheme.bodySmall?.copyWith(
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
