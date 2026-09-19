import 'package:flutter/material.dart';

import '../data/teaching_model_demo_data.dart';
import '../data/teaching_model_repository.dart';
import '../domain/teaching_model_models.dart';

class TeachingModelsPage extends StatefulWidget {
  const TeachingModelsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onTeachingModelsChanged,
  });

  final String schoolName;
  final TeachingModelRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onTeachingModelsChanged;

  @override
  State<TeachingModelsPage> createState() => _TeachingModelsPageState();
}

class _TeachingModelsPageState extends State<TeachingModelsPage> {
  TeachingModelSnapshot? _snapshot;
  String? _section;
  TeachingModelType _selectedModel = TeachingModelType.hybrid;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _updateModel(
    TeachingClassConfig configuration,
    TeachingModelType model,
  ) async {
    final result = await widget.repository.updateModel(
      configurationId: configuration.id,
      model: model,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success && configuration.model != model) {
      widget.onTeachingModelsChanged?.call();
      await _load();
    }
  }

  List<TeachingClassConfig> get _visibleRows {
    final rows = _snapshot?.configurations ?? const <TeachingClassConfig>[];
    if (_section == null) return rows;
    return rows.where((row) => row.section == _section).toList(growable: false);
  }

  TeachingModelInfo get _selectedInfo => teachingModelInfo.firstWhere(
        (item) => item.model == _selectedModel,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text('Could not load teaching models: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = teachingModelStats(snapshot.configurations);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            22,
            compact ? 16 : 28,
            40,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to School Life',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flexible Teaching Models',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Class teacher · Subject teacher · Hybrid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'SchoolOS must fit the school’s real structure. Nursery and Primary can use one teacher for a class, while specialists or subject teachers are added only where the school actually uses them.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final stat in stats)
                  SizedBox(
                    width: compact ? 160 : 205,
                    child: _StatCard(stat: stat),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            if (compact) ...[
              _StructureCard(
                rows: _visibleRows,
                permissions: snapshot.permissions,
                section: _section,
                selectedModel: _selectedModel,
                selectedInfo: _selectedInfo,
                onSectionChanged: (value) => setState(() => _section = value),
                onModelInfoChanged: (value) =>
                    setState(() => _selectedModel = value),
                onRowModelChanged: _updateModel,
              ),
              const SizedBox(height: 16),
              const _TeachingSidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _StructureCard(
                      rows: _visibleRows,
                      permissions: snapshot.permissions,
                      section: _section,
                      selectedModel: _selectedModel,
                      selectedInfo: _selectedInfo,
                      onSectionChanged: (value) =>
                          setState(() => _section = value),
                      onModelInfoChanged: (value) =>
                          setState(() => _selectedModel = value),
                      onRowModelChanged: _updateModel,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _TeachingSidebar()),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final TeachingModelStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(
              stat.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              stat.detail,
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

class _StructureCard extends StatelessWidget {
  const _StructureCard({
    required this.rows,
    required this.permissions,
    required this.section,
    required this.selectedModel,
    required this.selectedInfo,
    required this.onSectionChanged,
    required this.onModelInfoChanged,
    required this.onRowModelChanged,
  });

  final List<TeachingClassConfig> rows;
  final TeachingModelPermissions permissions;
  final String? section;
  final TeachingModelType selectedModel;
  final TeachingModelInfo selectedInfo;
  final ValueChanged<String?> onSectionChanged;
  final ValueChanged<TeachingModelType> onModelInfoChanged;
  final void Function(TeachingClassConfig, TeachingModelType) onRowModelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teaching structure',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Each section has a normal model, but individual classes may override it.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final info in teachingModelInfo)
                  ChoiceChip(
                    selected: selectedModel == info.model,
                    label: Text(info.model.label),
                    onSelected: (_) => onModelInfoChanged(info.model),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedInfo.model.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(selectedInfo.summary),
                  const SizedBox(height: 4),
                  Text('Best fit: ${selectedInfo.bestFit}'),
                  const SizedBox(height: 8),
                  const Text(teachingAssignmentBoundary),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                initialValue: section,
                decoration: const InputDecoration(labelText: 'Section'),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All sections'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Early Years',
                    child: Text('Early Years'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Primary',
                    child: Text('Primary'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Secondary',
                    child: Text('Secondary'),
                  ),
                ],
                onChanged: onSectionChanged,
              ),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No classes match this section.')),
              )
            else
              for (final row in rows) ...[
                _TeachingRow(
                  configuration: row,
                  canConfigure: permissions.canConfigureAllSections,
                  onModelChanged: (model) => onRowModelChanged(row, model),
                ),
                if (row != rows.last) const Divider(height: 28),
              ],
          ],
        ),
      ),
    );
  }
}

class _TeachingRow extends StatelessWidget {
  const _TeachingRow({
    required this.configuration,
    required this.canConfigure,
    required this.onModelChanged,
  });

  final TeachingClassConfig configuration;
  final bool canConfigure;
  final ValueChanged<TeachingModelType> onModelChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            Chip(label: Text(configuration.section)),
            Chip(label: Text(configuration.id)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          configuration.className,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(configuration.note),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<TeachingModelType>(
                key: ValueKey('${configuration.id}-${configuration.model.name}'),
                initialValue: configuration.model,
                decoration: const InputDecoration(labelText: 'Teaching model'),
                items: [
                  for (final model in TeachingModelType.values)
                    DropdownMenuItem(
                      value: model,
                      child: Text(model.label),
                    ),
                ],
                onChanged: canConfigure
                    ? (value) {
                        if (value != null) onModelChanged(value);
                      }
                    : null,
              ),
            ),
            SizedBox(
              width: 250,
              child: _DetailBlock(
                label: 'Lead / tutor',
                value: configuration.leadTeacher,
                detail: 'Primary class / pastoral responsibility',
              ),
            ),
            SizedBox(
              width: 280,
              child: _DetailBlock(
                label: 'Specialist coverage',
                value: configuration.specialistCoverage,
                detail: 'Configured extras only',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TeachingSidebar extends StatelessWidget {
  const _TeachingSidebar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _PolicyCard(
          title: 'How assignment changes',
          subtitle: 'Different models need different UI behavior.',
          entries: {
            'Class Teacher': teachingClassTeacherRule,
            'Subject Teacher': teachingSubjectTeacherRule,
            'Hybrid': teachingHybridRule,
          },
        ),
        SizedBox(height: 14),
        _PolicyCard(
          title: 'Early Years structure',
          subtitle: teachingEarlyYearsBoundary,
          entries: {
            'Room / Group Lead':
                'Owns group planning, routines, observations and family coordination.',
            'Assistant educators':
                'Support the room without pretending every activity is a separate subject.',
            'Specialists':
                'Music, movement, creative or language sessions can be added where the school uses them.',
          },
        ),
        SizedBox(height: 14),
        _PolicyCard(
          title: 'Primary structure',
          subtitle: 'Designed for the “one class, one teacher” reality.',
          entries: {
            'Core-subject ownership':
                'The class teacher can own English, Mathematics, Basic Science and other configured subjects.',
            'Specialist exceptions':
                'ICT, PE, French, Arabic, Music or other subjects can override the default teacher.',
            'Class-level override':
                'A school can use Class Teacher in P1–P3 and Hybrid in P4–P6 if desired.',
          },
        ),
      ],
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  final String title;
  final String subtitle;
  final Map<String, String> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 12),
            for (final entry in entries.entries) ...[
              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(entry.value),
              if (entry.key != entries.keys.last) const Divider(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}
