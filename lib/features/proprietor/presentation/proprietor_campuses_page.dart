import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/owner_campuses.dart';

/// Compares the school's campuses using what is really recorded: sections, classes, staff and leadership. Students,
/// attendance and fees are shown as not recorded until the roles that hold them have data.
class ProprietorCampusesPage extends StatefulWidget {
  const ProprietorCampusesPage({
    super.key,
    required this.schoolName,
    required this.onActionRequested,
    required this.repository,
  });

  final String schoolName;
  final ValueChanged<String> onActionRequested;
  final OwnerCampusesRepository repository;

  @override
  State<ProprietorCampusesPage> createState() => _ProprietorCampusesPageState();
}

class _ProprietorCampusesPageState extends State<ProprietorCampusesPage> with SyncRefresh<ProprietorCampusesPage> {
  OwnerCampuses? _data;
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

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Center(
        child: _failed
            ? const Padding(padding: EdgeInsets.all(24), child: Text('The campuses could not be loaded.'))
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
                      'PROPRIETOR · CAMPUS COMPARISON',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Campus Comparison', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(
                      'Campuses of ${widget.schoolName}, grouped from the sections set up in Structure & Leadership.',
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
                          onPressed: () => widget.onActionRequested('structure'),
                          icon: const Icon(Icons.account_tree_outlined, size: 18),
                          label: const Text('Manage structure'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _Kpi('Campuses', '${data.campuses.length}', 'From your sections'),
                        _Kpi('Sections', '${data.sections}', '${data.classes} classes'),
                        _Kpi('Staff', '${data.staff}', data.unassignedStaff == 0
                            ? 'All placed in a section'
                            : '${data.unassignedStaff} not in any section'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (data.campuses.isEmpty)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'No sections are set up yet, so there are no campuses to compare. Set up the structure first.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    for (final campus in data.campuses) ...[
                      _CampusCard(campus: campus),
                      const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Students, attendance and fee collection by campus are not recorded yet. They will appear when the '
                      'roles that hold them have data.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 18),
                    _Note(
                      title: 'Before opening a new campus',
                      body: [for (final (title, detail) in campusExpansionChecklist) '$title: $detail'].join('\n'),
                    ),
                    const SizedBox(height: 14),
                    _Note(title: 'Campus isolation', body: campusIsolationPrinciple),
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

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note);

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
              const SizedBox(height: 6),
              Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampusCard extends StatelessWidget {
  const _CampusCard({required this.campus});

  final CampusView campus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <(String, String)>[
      ('Sections', '${campus.sections.length}'),
      ('Classes', '${campus.classes}'),
      ('Staff', '${campus.staff}'),
      ('Teachers', '${campus.teachers}'),
      ('Files to complete', '${campus.filesToComplete}'),
      ('Students', 'Not recorded'),
      ('Attendance', 'Not recorded'),
      ('Fees', 'Not recorded'),
    ];
    return Card(
      key: ValueKey('campus-${campus.name}'),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campus.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              campus.sections.map((s) => s.name).join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, value) in entries)
                  Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 5),
                        Text(
                          value,
                          style: value == 'Not recorded'
                              ? theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                              : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Leadership', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (campus.leaders.isEmpty) const Text('No section leaders appointed.'),
            for (final leader in campus.leaders) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(leader)),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
