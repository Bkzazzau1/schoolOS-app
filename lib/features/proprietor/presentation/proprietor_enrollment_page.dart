import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/enrollment_brief_exporter.dart';
import '../data/owner_enrollment.dart';

/// The owner's enrollment view, counted from the school's real applicants and student register. Retention and trends need
/// history from earlier terms, so they are not shown.
class ProprietorEnrollmentPage extends StatefulWidget {
  const ProprietorEnrollmentPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
    required this.repository,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;
  final OwnerEnrollmentRepository repository;

  @override
  State<ProprietorEnrollmentPage> createState() => _ProprietorEnrollmentPageState();
}

class _ProprietorEnrollmentPageState extends State<ProprietorEnrollmentPage> with SyncRefresh<ProprietorEnrollmentPage> {
  final EnrollmentBriefExporter _exporter = const EnrollmentBriefExporter();
  OwnerEnrollment? _data;
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
      final data = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _exportBrief(OwnerEnrollment data) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _exporter.export(schoolName: widget.schoolName, enrollment: data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrollment brief saved on this device: $path'), duration: const Duration(seconds: 5)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export the enrollment brief: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(
        child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('Enrollment could not be loaded.'))
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
                      'PROPRIETOR · ENROLLMENT & ADMISSIONS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Enrollment & Admissions', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Applications, offers and students at ${widget.schoolName}, counted from the school register and the admissions pipeline.',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: () => widget.onActionRequested('overview'), child: const Text('Executive Overview')),
                        FilledButton.icon(
                          onPressed: _exporting ? null : () => _exportBrief(data),
                          icon: _exporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_outlined, size: 18),
                          label: Text(_exporting ? 'Creating…' : 'Export enrollment brief'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final k in data.kpis)
                          SizedBox(
                            width: 210,
                            child: Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(k.label, style: theme.textTheme.labelMedium),
                                    const SizedBox(height: 8),
                                    Text(k.value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Text(k.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Card(
                      title: 'Admissions pipeline by section',
                      subtitle: 'Demand and conversion across the school.',
                      child: data.empty
                          ? const Text('No students or applications yet. The Administrator registers students and takes applications.')
                          : _PipelineTable(sections: data.sections),
                    ),
                    const SizedBox(height: 18),
                    _Card(
                      title: 'Worth a look',
                      subtitle: 'Where the owner may want to ask a question. Capacity limits are not configured yet.',
                      child: data.watch.isEmpty
                          ? const Text('Nothing stands out.')
                          : Column(
                              children: [
                                for (final w in data.watch) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(w.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(w.detail),
                                        const SizedBox(height: 4),
                                        Text(w.action, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                  if (w != data.watch.last) const Divider(height: 24),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    _Card(
                      title: 'Not available yet',
                      subtitle: 'These need history that is not recorded.',
                      child: const Text(
                        'Retention and the enrollment trend need students recorded across earlier terms. They will appear once terms are closed and kept.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Admissions should support eligibility, capacity and documented school policy. SchoolOS should not make opaque '
                        'admissions decisions from family income, ethnicity, religion, disability, health history or other sensitive traits.',
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
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

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.child});

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
            Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PipelineTable extends StatelessWidget {
  const _PipelineTable({required this.sections});

  final List<EnrollmentSectionRow> sections;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Section')),
          DataColumn(label: Text('Students'), numeric: true),
          DataColumn(label: Text('Applications'), numeric: true),
          DataColumn(label: Text('Offers'), numeric: true),
          DataColumn(label: Text('Accepted'), numeric: true),
          DataColumn(label: Text('Registered'), numeric: true),
        ],
        rows: [
          for (final row in sections)
            DataRow(
              cells: [
                DataCell(Text(row.section, style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text('${row.activeStudents}')),
                DataCell(Text('${row.applications}')),
                DataCell(Text('${row.offers}')),
                DataCell(Text('${row.accepted}')),
                DataCell(Text('${row.registered}')),
              ],
            ),
        ],
      ),
    );
  }
}
