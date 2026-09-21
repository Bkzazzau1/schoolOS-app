import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/executive_report_pack_exporter.dart';
import '../data/owner_reports.dart';

/// The owner's reports, built from the school's real records. A report the school has no data for yet is listed as
/// not available, with the reason, instead of showing made-up figures.
class ProprietorReportsPage extends StatefulWidget {
  const ProprietorReportsPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
    required this.repository,
    this.exporter = const ExecutiveReportPackExporter(),
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;
  final OwnerReportsRepository repository;
  final ExecutiveReportPackExporter exporter;

  @override
  State<ProprietorReportsPage> createState() => _ProprietorReportsPageState();
}

class _ProprietorReportsPageState extends State<ProprietorReportsPage> with SyncRefresh<ProprietorReportsPage> {
  OwnerReports? _reports;
  bool _failed = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load();

  Future<void> _load() async {
    try {
      final reports = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _createPack(OwnerReports reports) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await widget.exporter.export(schoolName: widget.schoolName, reports: reports);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executive report pack saved on this device: $path'), duration: const Duration(seconds: 5)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the report pack: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _open(ReportDoc doc) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _ReportSheet(doc: doc),
      );

  @override
  Widget build(BuildContext context) {
    final reports = _reports;
    if (reports == null) {
      return Center(
        child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('The reports could not be built.'))
            : const CircularProgressIndicator(),
      );
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final contentWidth = constraints.maxWidth >= 1460 ? 1280.0 : 1160.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 28, 24, compact ? 18 : 28, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
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
                    Text('Executive Reports', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Reports for ${widget.schoolName}, built from what has been recorded. Ones the school has no data for yet '
                      'say so.',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => widget.onActionRequested('overview'),
                          child: const Text('Executive Overview'),
                        ),
                        FilledButton.icon(
                          onPressed: _exporting ? null : () => _createPack(reports),
                          icon: _exporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.inventory_2_outlined, size: 18),
                          label: Text(_exporting ? 'Creating…' : 'Create report pack'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Kpi(label: 'Reports ready', value: '${reports.available.length}', note: 'Built from your records'),
                        _Kpi(
                          label: 'Not available yet',
                          value: '${reports.unavailable.length}',
                          note: 'Waiting on other roles\' data',
                        ),
                        _Kpi(label: 'Built', value: _day(reports.generatedOn), note: 'Refreshed when records change'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reports', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            for (final doc in reports.docs) ...[
                              _ReportRow(doc: doc, onOpen: _open),
                              if (doc != reports.docs.last) const Divider(height: 22),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(reportingPrinciple, style: theme.textTheme.bodyMedium?.copyWith(height: 1.55)),
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

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.doc, required this.onOpen});

  final ReportDoc doc;
  final ValueChanged<ReportDoc> onOpen;

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
              Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(doc.coverage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(
                doc.available ? 'Ready' : 'Not available yet · ${doc.unavailableReason}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: doc.available ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(onPressed: () => onOpen(doc), child: const Text('Open')),
      ],
    );
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.doc});

  final ReportDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          shrinkWrap: true,
          children: [
            Text(doc.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(doc.coverage, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            if (!doc.available)
              Text('Not available yet: ${doc.unavailableReason}', style: theme.textTheme.bodyLarge),
            for (final section in doc.sections) ...[
              const SizedBox(height: 10),
              Text(section.heading, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final line in section.lines)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line, style: theme.textTheme.bodyMedium)),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }
}
