import 'package:flutter/material.dart';

import '../data/finance_reports_demo_data.dart';
import '../domain/finance_reports_models.dart';

class FinanceReportsPage extends StatefulWidget {
  const FinanceReportsPage({super.key});

  @override
  State<FinanceReportsPage> createState() => _FinanceReportsPageState();
}

class _FinanceReportsPageState extends State<FinanceReportsPage> {
  String? _notice;

  void _exportCurrentView() {
    setState(() => _notice = financeReportsExportBoundary);
  }

  void _generateReportPack() {
    setState(() {
      _notice =
          'Report-pack preview includes ${financeReportLibrary.length} core finance reports. $financeReportsReadOnlyBoundary';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(
          onExport: _exportCurrentView,
          onGenerate: _generateReportPack,
        ),
        if (_notice != null) ...[
          const SizedBox(height: 12),
          _Notice(text: _notice!),
        ],
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        const _ReportGrid(),
        const SizedBox(height: 16),
        const _ReportingBoundaries(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onExport, required this.onGenerate});

  final VoidCallback onExport;
  final VoidCallback onGenerate;

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
                'FINANCE OFFICE · REPORTING',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Finance Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Auditable operational and management reporting for authorized finance and owner review.',
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
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Export current view'),
            ),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Generate report pack'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
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
            for (final item in financeReportKpis)
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
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

class _ReportGrid extends StatelessWidget {
  const _ReportGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return const Column(
            children: [
              _ReportLibraryCard(),
              SizedBox(height: 16),
              _ManagementSnapshotCard(),
            ],
          );
        }
        return const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _ReportLibraryCard()),
            SizedBox(width: 16),
            Expanded(flex: 2, child: _ManagementSnapshotCard()),
          ],
        );
      },
    );
  }
}

class _ReportLibraryCard extends StatelessWidget {
  const _ReportLibraryCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Report library',
      subtitle: 'Core finance outputs available to the Finance Office.',
      child: Column(
        children: [
          for (var i = 0; i < financeReportLibrary.length; i++) ...[
            _ReportRow(report: financeReportLibrary[i]),
            if (i != financeReportLibrary.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final FinanceReportDefinition report;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.description_outlined, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(report.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(report.detail),
              const SizedBox(height: 4),
              Text(report.period, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManagementSnapshotCard extends StatelessWidget {
  const _ManagementSnapshotCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Management snapshot',
      subtitle: 'Current term.',
      child: Column(
        children: [
          for (var i = 0; i < financeManagementSnapshots.length; i++) ...[
            _SnapshotRow(snapshot: financeManagementSnapshots[i]),
            if (i != financeManagementSnapshots.length - 1)
              const Divider(height: 22),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(financeReportsMinimumNecessaryBoundary),
          ),
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.snapshot});

  final FinanceManagementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final watch = snapshot.status == 'Watch';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(snapshot.section, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${snapshot.collectionRate}% fee collection'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Chip(
          avatar: Icon(
            watch ? Icons.visibility_outlined : Icons.check_circle_outline,
            size: 17,
          ),
          label: Text(snapshot.status),
        ),
      ],
    );
  }
}

class _ReportingBoundaries extends StatelessWidget {
  const _ReportingBoundaries();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: 'Reporting & evidence boundary',
      subtitle: 'Reports summarize finance evidence without gaining transaction authority.',
      child: const Column(
        children: [
          _BoundaryLine(icon: Icons.lock_outline, text: financeReportsMinimumNecessaryBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.visibility_outlined, text: financeReportsReadOnlyBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.hub_outlined, text: financeReportsSourceBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.percent_outlined, text: financeReportsSectionRateBoundary),
          SizedBox(height: 10),
          _BoundaryLine(icon: Icons.file_download_outlined, text: financeReportsExportBoundary),
        ],
      ),
    );
  }
}

class _BoundaryLine extends StatelessWidget {
  const _BoundaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
