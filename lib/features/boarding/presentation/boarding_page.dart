import 'package:flutter/material.dart';

import '../data/boarding_policy_copy.dart';
import '../data/boarding_repository.dart';
import '../domain/boarding_models.dart';

class BoardingPage extends StatefulWidget {
  const BoardingPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onBoardingChanged,
  });

  final String schoolName;
  final BoardingRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onBoardingChanged;

  @override
  State<BoardingPage> createState() => _BoardingPageState();
}

class _BoardingPageState extends State<BoardingPage> {
  final _searchController = TextEditingController();
  BoardingSnapshot? _snapshot;
  bool _previewEnabled = true;
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

  Future<void> _toggleReview(BoardingDorm dorm) async {
    final result = await widget.repository.toggleHandoverReview(dorm.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onBoardingChanged?.call();
      await _load();
    }
  }

  Future<void> _addDorm() async {
    final name = TextEditingController();
    final houseParent = TextEditingController();
    final capacity = TextEditingController(text: '0');
    final note = TextEditingController();
    var status = DormStatus.normal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add dormitory'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Dormitory name')),
                  const SizedBox(height: 12),
                  TextField(controller: houseParent, decoration: const InputDecoration(labelText: 'House parent')),
                  const SizedBox(height: 12),
                  TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DormStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in DormStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add dormitory')),
          ],
        ),
      ),
    );
    final values = (name: name.text, houseParent: houseParent.text, capacity: int.tryParse(capacity.text) ?? 0, status: status, note: note.text);
    name.dispose();
    houseParent.dispose();
    capacity.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.create(
      name: values.name,
      houseParent: values.houseParent,
      capacity: values.capacity,
      status: values.status,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onBoardingChanged?.call();
      await _load();
    }
  }

  Future<void> _editDorm(BoardingDorm dorm) async {
    final houseParent = TextEditingController(text: dorm.houseParent);
    final capacity = TextEditingController(text: '${dorm.capacity}');
    final occupied = TextEditingController(text: '${dorm.occupied}');
    final onCampus = TextEditingController(text: '${dorm.onCampus}');
    final approvedLeave = TextEditingController(text: '${dorm.approvedLeave}');
    final maintenance = TextEditingController(text: '${dorm.maintenance}');
    final note = TextEditingController(text: dorm.note);
    var status = dorm.status;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${dorm.name}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: houseParent, decoration: const InputDecoration(labelText: 'House parent')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: occupied, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Occupied'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: onCampus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'On campus'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: approvedLeave, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Approved leave'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: maintenance, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maintenance items')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DormStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in DormStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
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
      houseParent: houseParent.text,
      capacity: int.tryParse(capacity.text) ?? dorm.capacity,
      occupied: int.tryParse(occupied.text) ?? dorm.occupied,
      onCampus: int.tryParse(onCampus.text) ?? dorm.onCampus,
      approvedLeave: int.tryParse(approvedLeave.text) ?? dorm.approvedLeave,
      maintenance: int.tryParse(maintenance.text) ?? dorm.maintenance,
      status: status,
      note: note.text,
    );
    houseParent.dispose();
    capacity.dispose();
    occupied.dispose();
    onCampus.dispose();
    approvedLeave.dispose();
    maintenance.dispose();
    note.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.edit(
      name: dorm.name,
      houseParent: values.houseParent,
      capacity: values.capacity,
      occupied: values.occupied,
      onCampus: values.onCampus,
      approvedLeave: values.approvedLeave,
      maintenance: values.maintenance,
      status: values.status,
      note: values.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onBoardingChanged?.call();
      await _load();
    }
  }

  List<BoardingDorm> get _visibleDorms {
    final dorms = _snapshot?.dorms ?? const <BoardingDorm>[];
    return dorms
        .where((dorm) => dorm.matches(_searchController.text))
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
              Text('Could not load boarding: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = boardingStats(
      snapshot.dorms,
      previewEnabled: _previewEnabled,
    );
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
                        'Boarding & Hostel',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Optional school module',
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
              'View dormitories and resident lists. The preview toggle affects this view only.',
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
              _DormitoryOverview(
                dorms: _visibleDorms,
                hasAnyDorms: snapshot.dorms.isNotEmpty,
                permissions: snapshot.permissions,
                searchController: _searchController,
                previewEnabled: _previewEnabled,
                onQueryChanged: (_) => setState(() {}),
                onPreviewChanged: () => setState(
                  () => _previewEnabled = !_previewEnabled,
                ),
                onToggleReview: _toggleReview,
                onAdd: _addDorm,
                onEdit: _editDorm,
              ),

            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DormitoryOverview(
                      dorms: _visibleDorms,
                      hasAnyDorms: snapshot.dorms.isNotEmpty,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      previewEnabled: _previewEnabled,
                      onQueryChanged: (_) => setState(() {}),
                      onPreviewChanged: () => setState(
                        () => _previewEnabled = !_previewEnabled,
                      ),
                      onToggleReview: _toggleReview,
                      onAdd: _addDorm,
                      onEdit: _editDorm,
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

  final BoardingStat stat;

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

class _DormitoryOverview extends StatelessWidget {
  const _DormitoryOverview({
    required this.dorms,
    required this.hasAnyDorms,
    required this.permissions,
    required this.searchController,
    required this.previewEnabled,
    required this.onQueryChanged,
    required this.onPreviewChanged,
    required this.onToggleReview,
    required this.onAdd,
    required this.onEdit,
  });

  final List<BoardingDorm> dorms;
  final bool hasAnyDorms;
  final BoardingPermissions permissions;
  final TextEditingController searchController;
  final bool previewEnabled;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPreviewChanged;
  final ValueChanged<BoardingDorm> onToggleReview;
  final VoidCallback onAdd;
  final ValueChanged<BoardingDorm> onEdit;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dormitory overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Operational accountability without continuous or invasive monitoring of students.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (permissions.canManageAll)
                  OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add dormitory')),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onPreviewChanged,
                  child: Text(
                    previewEnabled
                        ? 'Preview disabled state'
                        : 'Restore enabled preview',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!previewEnabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disabled-state preview only',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(boardingDisabledPreviewNote),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: searchController,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search dorm or house parent...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              if (dorms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      hasAnyDorms
                          ? 'No dormitories match this search.'
                          : 'No dormitories yet. Add the first one above.',
                    ),
                  ),
                )
              else
                for (final dorm in dorms) ...[
                  _DormCard(
                    dorm: dorm,
                    canReview: permissions.canReviewHandover,
                    canManageAll: permissions.canManageAll,
                    onToggleReview: () => onToggleReview(dorm),
                    onEdit: () => onEdit(dorm),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DormCard extends StatelessWidget {
  const _DormCard({
    required this.dorm,
    required this.canReview,
    required this.canManageAll,
    required this.onToggleReview,
    required this.onEdit,
  });

  final BoardingDorm dorm;
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
              _Pill(dorm.status.label),
              _Pill('${dorm.occupied}/${dorm.capacity} occupied'),
              _Pill('${dorm.approvedLeave} on leave'),
              if (dorm.handoverReviewed) const _Pill('Reviewed'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            dorm.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('House parent: ${dorm.houseParent}'),
          const SizedBox(height: 7),
          Text(
            dorm.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dorm.onCampus} on campus · ${dorm.maintenance} maintenance items',
            style: theme.textTheme.bodySmall,
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
                      dorm.handoverReviewed
                          ? Icons.restart_alt_rounded
                          : Icons.fact_check_outlined,
                      size: 18,
                    ),
                    label: Text(
                      dorm.handoverReviewed
                          ? 'Reopen review'
                          : 'Mark handover reviewed',
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
