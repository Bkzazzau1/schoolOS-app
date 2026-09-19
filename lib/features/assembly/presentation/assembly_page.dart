import 'package:flutter/material.dart';

import '../data/assembly_demo_data.dart';
import '../data/assembly_repository.dart';
import '../domain/assembly_models.dart';

class AssemblyPage extends StatefulWidget {
  const AssemblyPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
  });

  final String schoolName;
  final AssemblyRepository repository;
  final VoidCallback onBack;

  @override
  State<AssemblyPage> createState() => _AssemblyPageState();
}

class _AssemblyPageState extends State<AssemblyPage> {
  final _searchController = TextEditingController();
  AssemblySnapshot? _snapshot;
  AssemblySessionType? _typeFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<AssemblySession> get _visibleSessions {
    final sessions = _snapshot?.sessions ?? const <AssemblySession>[];
    return sessions
        .where(
          (session) => session.matches(
            _searchController.text,
            _typeFilter,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text('Could not load assembly activities: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = assemblyStats(snapshot.sessions);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
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
                        'Assembly & Faith Activities',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Configurable school culture calendar',
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
            Text(
              'Plan whole-school and section assemblies, civic programmes, wellbeing gatherings and optional faith/religious activities without assuming every school follows the same model.',
              style: theme.textTheme.bodyMedium,
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
              _SessionList(
                sessions: _visibleSessions,
                searchController: _searchController,
                typeFilter: _typeFilter,
                onQueryChanged: (_) => setState(() {}),
                onTypeChanged: (value) => setState(() => _typeFilter = value),
              ),
              const SizedBox(height: 16),
              _ConfigurationSidebar(
                canConfigureSchoolWide:
                    snapshot.permissions.canConfigureSchoolWide,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _SessionList(
                      sessions: _visibleSessions,
                      searchController: _searchController,
                      typeFilter: _typeFilter,
                      onQueryChanged: (_) => setState(() {}),
                      onTypeChanged: (value) =>
                          setState(() => _typeFilter = value),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 3,
                    child: _ConfigurationSidebar(
                      canConfigureSchoolWide:
                          snapshot.permissions.canConfigureSchoolWide,
                    ),
                  ),
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

  final AssemblyStat stat;

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

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.searchController,
    required this.typeFilter,
    required this.onQueryChanged,
    required this.onTypeChanged,
  });

  final List<AssemblySession> sessions;
  final TextEditingController searchController;
  final AssemblySessionType? typeFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AssemblySessionType?> onTypeChanged;

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
              'Weekly gatherings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate schedule, audience and participation rules for each school culture activity.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 560;
                final search = TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search session, audience or lead...',
                    border: OutlineInputBorder(),
                  ),
                );
                final filter = DropdownButtonFormField<AssemblySessionType?>(
                  initialValue: typeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<AssemblySessionType?>(
                      value: null,
                      child: Text('All types'),
                    ),
                    for (final type in AssemblySessionType.values)
                      DropdownMenuItem<AssemblySessionType?>(
                        value: type,
                        child: Text(type.label),
                      ),
                  ],
                  onChanged: onTypeChanged,
                );
                if (stacked) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      filter,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 10),
                    Expanded(child: filter),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No sessions match these filters.')),
              )
            else
              for (final session in sessions) ...[
                _SessionCard(session: session),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final AssemblySession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: const Icon(Icons.groups_2_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Pill(session.type.label),
                    _Pill(session.audience),
                    _Pill(session.day),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  session.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${session.time} · ${session.venue} · Lead: ${session.lead}'),
                const SizedBox(height: 7),
                Text(
                  session.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Participation: ${session.participation}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

class _ConfigurationSidebar extends StatelessWidget {
  const _ConfigurationSidebar({required this.canConfigureSchoolWide});

  final bool canConfigureSchoolWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONFIGURATION PRINCIPLE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in assemblyConfigurationPrinciples.entries) ...[
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(entry.value, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OWNER AUTHORITY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canConfigureSchoolWide
                      ? 'This membership has school-wide configuration authority, but the website does not yet expose an editor here. The native app therefore preserves the current read/filter workflow instead of inventing one.'
                      : 'This membership can view only the assembly data made available to its scope.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
