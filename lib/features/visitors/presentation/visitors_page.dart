import 'package:flutter/material.dart';

import '../data/visitor_policy_copy.dart';
import '../data/visitor_repository.dart';
import '../domain/visitor_models.dart';

class VisitorsPage extends StatefulWidget {
  const VisitorsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onVisitorsChanged,
  });

  final String schoolName;
  final VisitorRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onVisitorsChanged;

  @override
  State<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends State<VisitorsPage> {
  final _searchController = TextEditingController();
  VisitorSnapshot? _snapshot;
  VisitStatus? _statusFilter;
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

  Future<void> _toggleReview(VisitorRecord visit) async {
    final result = await widget.repository.toggleRecordReview(visit.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onVisitorsChanged?.call();
      await _load();
    }
  }

  Future<void> _logVisitor() async {
    final visitor = TextEditingController();
    final organization = TextEditingController();
    final purpose = TextEditingController();
    final host = TextEditingController();
    final area = TextEditingController();
    final arrival = TextEditingController();
    final pass = TextEditingController();
    final note = TextEditingController();
    var status = VisitStatus.expected;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log a visitor'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: visitor, decoration: const InputDecoration(labelText: 'Visitor name')),
                  const SizedBox(height: 12),
                  TextField(controller: organization, decoration: const InputDecoration(labelText: 'Organization')),
                  const SizedBox(height: 12),
                  TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose')),
                  const SizedBox(height: 12),
                  TextField(controller: host, decoration: const InputDecoration(labelText: 'Host')),
                  const SizedBox(height: 12),
                  TextField(controller: area, decoration: const InputDecoration(labelText: 'Permitted area')),
                  const SizedBox(height: 12),
                  TextField(controller: arrival, decoration: const InputDecoration(labelText: 'Arrival time')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VisitStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in VisitStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: pass, decoration: const InputDecoration(labelText: 'Pass / badge reference')),
                  const SizedBox(height: 12),
                  TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log visitor')),
          ],
        ),
      ),
    );
    final values = (
      visitor: visitor.text,
      organization: organization.text,
      purpose: purpose.text,
      host: host.text,
      area: area.text,
      arrival: arrival.text,
      status: status,
      pass: pass.text,
      note: note.text,
    );
    visitor.dispose();
    organization.dispose();
    purpose.dispose();
    host.dispose();
    area.dispose();
    arrival.dispose();
    pass.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.create(
      visitor: values.visitor,
      organization: values.organization,
      purpose: values.purpose,
      host: values.host,
      area: values.area,
      arrival: values.arrival,
      status: values.status,
      pass: values.pass,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onVisitorsChanged?.call();
      await _load();
    }
  }

  Future<void> _editVisitor(VisitorRecord visit) async {
    final organization = TextEditingController(text: visit.organization);
    final purpose = TextEditingController(text: visit.purpose);
    final host = TextEditingController(text: visit.host);
    final area = TextEditingController(text: visit.area);
    final arrival = TextEditingController(text: visit.arrival);
    final departure = TextEditingController(text: visit.departure);
    final pass = TextEditingController(text: visit.pass);
    final note = TextEditingController(text: visit.note);
    var status = visit.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${visit.visitor}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: organization, decoration: const InputDecoration(labelText: 'Organization')),
                  const SizedBox(height: 12),
                  TextField(controller: purpose, decoration: const InputDecoration(labelText: 'Purpose')),
                  const SizedBox(height: 12),
                  TextField(controller: host, decoration: const InputDecoration(labelText: 'Host')),
                  const SizedBox(height: 12),
                  TextField(controller: area, decoration: const InputDecoration(labelText: 'Permitted area')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: arrival, decoration: const InputDecoration(labelText: 'Arrival'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: departure, decoration: const InputDecoration(labelText: 'Departure'))),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<VisitStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in VisitStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: pass, decoration: const InputDecoration(labelText: 'Pass / badge reference')),
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
      organization: organization.text,
      purpose: purpose.text,
      host: host.text,
      area: area.text,
      arrival: arrival.text,
      departure: departure.text,
      status: status,
      pass: pass.text,
      note: note.text,
    );
    organization.dispose();
    purpose.dispose();
    host.dispose();
    area.dispose();
    arrival.dispose();
    departure.dispose();
    pass.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.edit(
      id: visit.id,
      organization: values.organization,
      purpose: values.purpose,
      host: values.host,
      area: values.area,
      arrival: values.arrival,
      departure: values.departure,
      status: values.status,
      pass: values.pass,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onVisitorsChanged?.call();
      await _load();
    }
  }

  List<VisitorRecord> get _visibleVisits {
    final visits = _snapshot?.visits ?? const <VisitorRecord>[];
    return visits
        .where(
          (visit) => visit.matches(_searchController.text, _statusFilter),
        )
        .toList(growable: false);
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
              Text('Could not load visitor management: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = visitorStats(snapshot.visits);
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
                        'Visitor Management',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Front-office access and host accountability',
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
              'Track expected visitors, purpose, host, permitted area, pass and checkout status. Visitor history is a restricted operational record, not a school-community directory.',
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
              _VisitorRegister(
                visits: _visibleVisits,
                hasAnyVisits: snapshot.visits.isNotEmpty,
                permissions: snapshot.permissions,
                searchController: _searchController,
                statusFilter: _statusFilter,
                onQueryChanged: (_) => setState(() {}),
                onStatusChanged: (value) => setState(() => _statusFilter = value),
                onToggleReview: _toggleReview,
                onAdd: _logVisitor,
                onEdit: _editVisitor,
              ),
              const SizedBox(height: 16),
              const _AccessSidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _VisitorRegister(
                      visits: _visibleVisits,
                      hasAnyVisits: snapshot.visits.isNotEmpty,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      onQueryChanged: (_) => setState(() {}),
                      onStatusChanged: (value) => setState(() => _statusFilter = value),
                      onToggleReview: _toggleReview,
                      onAdd: _logVisitor,
                      onEdit: _editVisitor,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _AccessSidebar()),
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

  final VisitorStat stat;

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

class _VisitorRegister extends StatelessWidget {
  const _VisitorRegister({
    required this.visits,
    required this.hasAnyVisits,
    required this.permissions,
    required this.searchController,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onToggleReview,
    required this.onAdd,
    required this.onEdit,
  });

  final List<VisitorRecord> visits;
  final bool hasAnyVisits;
  final VisitorPermissions permissions;
  final TextEditingController searchController;
  final VisitStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<VisitStatus?> onStatusChanged;
  final ValueChanged<VisitorRecord> onToggleReview;
  final VoidCallback onAdd;
  final ValueChanged<VisitorRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    'Front-office visitor register',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (permissions.canCreate)
                  OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Log visitor')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Visitors should have a clear host, purpose and permitted area before wider campus access.',
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
                    hintText: 'Search visitor, purpose or host...',
                    border: OutlineInputBorder(),
                  ),
                );
                final filter = DropdownButtonFormField<VisitStatus?>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<VisitStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    for (final status in VisitStatus.values)
                      DropdownMenuItem<VisitStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: onStatusChanged,
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
            if (visits.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    hasAnyVisits
                        ? 'No visitor records match these filters.'
                        : 'No visitors logged yet. Log the first one above.',
                  ),
                ),
              )
            else
              for (final visit in visits) ...[
                _VisitorCard(
                  visit: visit,
                  canReview: permissions.canReviewRecords,
                  canManageAll: permissions.canManageAll,
                  onToggleReview: () => onToggleReview(visit),
                  onEdit: () => onEdit(visit),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({
    required this.visit,
    required this.canReview,
    required this.canManageAll,
    required this.onToggleReview,
    required this.onEdit,
  });

  final VisitorRecord visit;
  final bool canReview;
  final bool canManageAll;
  final VoidCallback onToggleReview;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Pill(visit.status.label),
              _Pill(visit.pass),
              _Pill(visit.area),
              if (visit.frontDeskReviewed) const _Pill('Reviewed'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            visit.visitor,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('${visit.organization} · ${visit.purpose}'),
          const SizedBox(height: 4),
          Text(
            'Host: ${visit.host} · Arrival ${visit.arrival} · Departure ${visit.departure}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 7),
          Text(
            visit.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (canReview || canManageAll) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canReview)
                  OutlinedButton.icon(
                    onPressed: onToggleReview,
                    icon: Icon(
                      visit.frontDeskReviewed
                          ? Icons.restart_alt_rounded
                          : Icons.fact_check_outlined,
                      size: 18,
                    ),
                    label: Text(
                      visit.frontDeskReviewed
                          ? 'Reopen front-desk review'
                          : 'Mark record reviewed',
                    ),
                  ),
                if (canManageAll)
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
              ],
            ),
          ],
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

class _AccessSidebar extends StatelessWidget {
  const _AccessSidebar();

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
                  'ACCESS RULES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in visitorAccessRules.entries) ...[
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
                  'PICKUP NOTE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  visitorPickupBoundary,
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
