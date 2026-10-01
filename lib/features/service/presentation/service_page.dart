import 'package:flutter/material.dart';

import '../data/service_policy_copy.dart';
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

  Future<void> _addProject() async {
    final title = TextEditingController();
    final type = TextEditingController();
    final audience = TextEditingController();
    final coordinator = TextEditingController();
    final date = TextEditingController();
    final beneficiary = TextEditingController();
    final note = TextEditingController();
    var status = ServiceProjectStatus.planned;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add service project'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Project title')),
                  const SizedBox(height: 12),
                  TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (e.g. Service, Peer support)')),
                  const SizedBox(height: 12),
                  TextField(controller: audience, decoration: const InputDecoration(labelText: 'Audience')),
                  const SizedBox(height: 12),
                  TextField(controller: coordinator, decoration: const InputDecoration(labelText: 'Coordinator')),
                  const SizedBox(height: 12),
                  TextField(controller: date, decoration: const InputDecoration(labelText: 'Date')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ServiceProjectStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in ServiceProjectStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: beneficiary, decoration: const InputDecoration(labelText: 'Beneficiary')),
                  const SizedBox(height: 12),
                  TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add project')),
          ],
        ),
      ),
    );
    final values = (
      title: title.text,
      type: type.text,
      audience: audience.text,
      coordinator: coordinator.text,
      date: date.text,
      status: status,
      beneficiary: beneficiary.text,
      note: note.text,
    );
    title.dispose();
    type.dispose();
    audience.dispose();
    coordinator.dispose();
    date.dispose();
    beneficiary.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.create(
      title: values.title,
      type: values.type,
      audience: values.audience,
      coordinator: values.coordinator,
      date: values.date,
      status: values.status,
      beneficiary: values.beneficiary,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onServiceChanged?.call();
      await _load();
    }
  }

  Future<void> _editProject(ServiceProject project) async {
    final type = TextEditingController(text: project.type);
    final audience = TextEditingController(text: project.audience);
    final coordinator = TextEditingController(text: project.coordinator);
    final date = TextEditingController(text: project.date);
    final participants = TextEditingController(text: '${project.participants}');
    final hours = TextEditingController(text: '${project.hours}');
    final beneficiary = TextEditingController(text: project.beneficiary);
    final note = TextEditingController(text: project.note);
    var status = project.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${project.title}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: type, decoration: const InputDecoration(labelText: 'Type')),
                  const SizedBox(height: 12),
                  TextField(controller: audience, decoration: const InputDecoration(labelText: 'Audience')),
                  const SizedBox(height: 12),
                  TextField(controller: coordinator, decoration: const InputDecoration(labelText: 'Coordinator')),
                  const SizedBox(height: 12),
                  TextField(controller: date, decoration: const InputDecoration(labelText: 'Date')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: participants, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Participants'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Hours'))),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ServiceProjectStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in ServiceProjectStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: beneficiary, decoration: const InputDecoration(labelText: 'Beneficiary')),
                  const SizedBox(height: 12),
                  TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final values = (
      type: type.text,
      audience: audience.text,
      coordinator: coordinator.text,
      date: date.text,
      participants: int.tryParse(participants.text) ?? project.participants,
      hours: int.tryParse(hours.text) ?? project.hours,
      status: status,
      beneficiary: beneficiary.text,
      note: note.text,
    );
    type.dispose();
    audience.dispose();
    coordinator.dispose();
    date.dispose();
    participants.dispose();
    hours.dispose();
    beneficiary.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.edit(
      id: project.id,
      type: values.type,
      audience: values.audience,
      coordinator: values.coordinator,
      date: values.date,
      participants: values.participants,
      hours: values.hours,
      status: values.status,
      beneficiary: values.beneficiary,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
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
                hasAnyProjects: snapshot.projects.isNotEmpty,
                permissions: snapshot.permissions,
                searchController: _searchController,
                selectedStatus: _status,
                onQueryChanged: (_) => setState(() {}),
                onStatusChanged: (value) => setState(() => _status = value),
                onToggleVerification: _toggleVerification,
                onAdd: _addProject,
                onEdit: _editProject,
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
                      hasAnyProjects: snapshot.projects.isNotEmpty,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      selectedStatus: _status,
                      onQueryChanged: (_) => setState(() {}),
                      onStatusChanged: (value) => setState(() => _status = value),
                      onToggleVerification: _toggleVerification,
                      onAdd: _addProject,
                      onEdit: _editProject,
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
    required this.hasAnyProjects,
    required this.permissions,
    required this.searchController,
    required this.selectedStatus,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onToggleVerification,
    required this.onAdd,
    required this.onEdit,
  });

  final List<ServiceProject> projects;
  final bool hasAnyProjects;
  final ServicePermissions permissions;
  final TextEditingController searchController;
  final ServiceProjectStatus? selectedStatus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ServiceProjectStatus?> onStatusChanged;
  final ValueChanged<ServiceProject> onToggleVerification;
  final VoidCallback onAdd;
  final ValueChanged<ServiceProject> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Service projects',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (permissions.canCreate)
                  OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add project')),
              ],
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
                    initialValue: selectedStatus,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    hasAnyProjects
                        ? 'No service projects match these filters.'
                        : 'No service projects yet. Add the first one above.',
                  ),
                ),
              )
            else
              for (final project in projects) ...[
                _ProjectTile(
                  project: project,
                  canVerify: permissions.canVerifyRecords,
                  canManageAll: permissions.canManageAll,
                  onToggleVerification: () => onToggleVerification(project),
                  onEdit: () => onEdit(project),
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
    required this.canManageAll,
    required this.onToggleVerification,
    required this.onEdit,
  });

  final ServiceProject project;
  final bool canVerify;
  final bool canManageAll;
  final VoidCallback onToggleVerification;
  final VoidCallback onEdit;

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
              if (canVerify || canManageAll) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canVerify)
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
                    if (canManageAll)
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                  ],
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
