import 'package:flutter/material.dart';

import '../data/service_demo_data.dart';
import '../data/service_repository.dart';
import '../domain/service_models.dart';

class ServicePage extends StatefulWidget {
  const ServicePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onServiceChanged,
  });

  final String schoolName;
  final ServiceRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onServiceChanged;

  @override
  State<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends State<ServicePage> {
  final _searchController = TextEditingController();
  ServiceSnapshot? _snapshot;
  ServiceProjectStatus? _status;
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

  Future<void> _toggleVerification(ServiceProject project) async {
    final result = await widget.repository.toggleVerification(project.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onServiceChanged?.call();
      await _load();
    }
  }

  List<ServiceProject> get _visibleProjects {
    final projects = _snapshot?.projects ?? const <ServiceProject>[];
    return projects.where((project) {
      final statusMatch = _status == null || project.status == _status;
      return statusMatch && project.matches(_searchController.text);
    }).toList(growable: false);
  }

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
              Text('Could not load service projects: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = serviceStats(snapshot.projects);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
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
                        'Community Service & Volunteering',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Participation, contribution and supervised service',
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
              'Plan school and community projects, coordinators, participants and service hours while keeping volunteering separate from exam grades and compulsory punishment.',
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
              _ProjectRegister(
                projects: _visibleProjects,
                permissions: snapshot.permissions,
                searchController: _searchController,
                selectedStatus: _status,
                onQueryChanged: (_) => setState(() {}),
                onStatusChanged: (value) => setState(() => _status = value),
                onToggleVerification: _toggleVerification,
              ),
              const SizedBox(height: 16),
              const _PrinciplesSidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _ProjectRegister(
                      projects: _visibleProjects,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      selectedStatus: _status,
                      onQueryChanged: (_) => setState(() {}),
                      onStatusChanged: (value) => setState(() => _status = value),
                      onToggleVerification: _toggleVerification,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _PrinciplesSidebar()),
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

  final ServiceStat stat;

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

class _ProjectRegister extends StatelessWidget {
  const _ProjectRegister({
    required this.projects,
    required this.permissions,
    required this.searchController,
    required this.selectedStatus,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onToggleVerification,
  });

  final List<ServiceProject> projects;
  final ServicePermissions permissions;
  final TextEditingController searchController;
  final ServiceProjectStatus? selectedStatus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ServiceProjectStatus?> onStatusChanged;
  final ValueChanged<ServiceProject> onToggleVerification;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service projects',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recognize contribution without converting volunteering into academic attainment.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 330,
                  child: TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      labelText: 'Search project, audience or coordinator',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<ServiceProjectStatus?>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      const DropdownMenuItem<ServiceProjectStatus?>(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      for (final status in ServiceProjectStatus.values)
                        DropdownMenuItem<ServiceProjectStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No service projects match these filters.')),
              )
            else
              for (final project in projects) ...[
                _ProjectTile(
                  project: project,
                  canVerify: permissions.canVerifyRecords,
                  onToggleVerification: () => onToggleVerification(project),
                ),
                if (project != projects.last) const Divider(height: 26),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.canVerify,
    required this.onToggleVerification,
  });

  final ServiceProject project;
  final bool canVerify;
  final VoidCallback onToggleVerification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.volunteer_activism_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(project.type)),
                  Chip(label: Text(project.audience)),
                  Chip(label: Text(project.status.label)),
                  if (project.verified)
                    const Chip(
                      avatar: Icon(Icons.verified_outlined, size: 17),
                      label: Text('Verified'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                project.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${project.date} · ${project.coordinator} · ${project.participants} participants',
              ),
              const SizedBox(height: 5),
              Text(project.note),
              const SizedBox(height: 6),
              Text(
                'Beneficiary: ${project.beneficiary} · ${project.isContributionBased ? 'Contribution-based activity' : '${project.hours} recorded hours'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (canVerify) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onToggleVerification,
                  icon: Icon(
                    project.verified
                        ? Icons.restart_alt_rounded
                        : Icons.verified_outlined,
                  ),
                  label: Text(
                    project.verified
                        ? 'Reopen verification'
                        : 'Verify record',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrinciplesSidebar extends StatelessWidget {
  const _PrinciplesSidebar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SERVICE PRINCIPLES',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                for (final entry in servicePrinciples.entries) ...[
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(entry.value),
                  if (entry.key != servicePrinciples.keys.last)
                    const Divider(height: 22),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTED MODULES',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8),
                Text(serviceConnectedModules),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
