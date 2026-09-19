import 'package:flutter/material.dart';

import '../data/activity_demo_data.dart';
import '../data/activity_repository.dart';
import '../domain/activity_models.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    required this.onActivitiesChanged,
  });

  final String schoolName;
  final ActivityRepository repository;
  final VoidCallback onBack;
  final VoidCallback onActivitiesChanged;

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final _searchController = TextEditingController();
  ActivitySnapshot? _snapshot;
  ActivityType? _typeFilter;
  String? _sectionFilter;
  String? _selectedId = 'ACT-003';
  String _notice = '';
  bool _loading = true;

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
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _loading = false;
      if (snapshot.activities.isNotEmpty &&
          !snapshot.activities.any((item) => item.id == _selectedId)) {
        _selectedId = snapshot.activities.first.id;
      }
    });
  }

  List<SchoolActivity> get _visible {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return snapshot.activities
        .where(
          (activity) => activity.matches(
            _searchController.text,
            _typeFilter,
            _sectionFilter,
          ),
        )
        .toList(growable: false);
  }

  SchoolActivity? get _selected {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.activities.isEmpty) return null;
    return snapshot.activities.firstWhere(
      (item) => item.id == _selectedId,
      orElse: () => snapshot.activities.first,
    );
  }

  Future<void> _addActivity() async {
    final result = await showDialog<_NewActivityDraft>(
      context: context,
      builder: (context) => const _AddActivityDialog(),
    );
    if (result == null) return;
    final action = await widget.repository.addActivity(
      name: result.name,
      type: result.type,
      section: result.section,
      coordinator: result.coordinator,
      schedule: result.schedule,
      venue: result.venue,
      note: result.note,
    );
    if (action.success) {
      widget.onActivitiesChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _notice = action.message);
  }

  Future<void> _takeAttendance(SchoolActivity activity) async {
    final controller = TextEditingController(text: '${activity.attendance}');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance · ${activity.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Recent attendance %',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Save attendance'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    final action = await widget.repository.updateAttendance(
      activityId: activity.id,
      attendance: value,
    );
    if (action.success) {
      widget.onActivitiesChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _notice = action.message);
  }

  void _showMembers(SchoolActivity activity) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${activity.name} · Members'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${activity.members} participation entries are currently registered.'),
              const SizedBox(height: 12),
              const Text(
                'The production register will list only members permitted by the active school, section and activity scope. This screen intentionally does not invent student identities.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final snapshot = _snapshot!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 22, compact ? 16 : 26, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: widget.schoolName,
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 16),
                    const _ScopeCard(),
                    const SizedBox(height: 16),
                    _Stats(compact: compact),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _directory(snapshot)),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: _sidebar(snapshot)),
                        ],
                      )
                    else ...[
                      _directory(snapshot),
                      const SizedBox(height: 16),
                      _sidebar(snapshot),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _directory(ActivitySnapshot snapshot) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 560,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Programme directory',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Sports, clubs, creative programmes and academic enrichment. Houses and excursions remain dedicated workflows.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: snapshot.permissions.canManageAll ? _addActivity : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add activity'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Filters(
              searchController: _searchController,
              typeFilter: _typeFilter,
              sectionFilter: _sectionFilter,
              onSearchChanged: (_) => setState(() {}),
              onTypeChanged: (value) => setState(() => _typeFilter = value),
              onSectionChanged: (value) => setState(() => _sectionFilter = value),
            ),
            if (_notice.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Notice(text: _notice),
            ],
            const SizedBox(height: 12),
            if (_visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No programmes match these filters.')),
              )
            else
              for (final item in _visible) ...[
                _ActivityRow(
                  activity: item,
                  selected: item.id == _selectedId,
                  onTap: () => setState(() => _selectedId = item.id),
                ),
                if (item != _visible.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _sidebar(ActivitySnapshot snapshot) {
    final selected = _selected;
    return Column(
      children: [
        if (selected != null)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECTED PROGRAMME',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(selected.note),
                  const SizedBox(height: 14),
                  _Detail('Coordinator', selected.coordinator),
                  _Detail('Schedule & venue', '${selected.schedule} · ${selected.venue}'),
                  _Detail(
                    'Participation',
                    '${selected.members} members · ${selected.attendance > 0 ? '${selected.attendance}% recent attendance' : 'Attendance not taken yet'}',
                  ),
                  _Detail('Guardian consent', selected.consent),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: snapshot.permissions.canTakeAttendance
                            ? () => _takeAttendance(selected)
                            : null,
                        child: const Text('Take attendance'),
                      ),
                      OutlinedButton(
                        onPressed: () => _showMembers(selected),
                        child: const Text('Members'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Co-curricular timetable',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                const Text('School time is more than academic periods.'),
                const SizedBox(height: 12),
                for (final entry in activityTimetable.entries)
                  _Detail(entry.key, entry.value),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Notice(text: activityParticipationRule),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.onBack});

  final String schoolName;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCHOOL LIFE · ${schoolName.toUpperCase()}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Activities, Clubs & Sports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('School Life'),
        ),
      ],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'SchoolOS schedules and documents co-curricular programmes clearly while keeping participation separate from academic attainment. Houses and trips use their own dedicated workflows.',
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final notes = const {
      'Active programmes': 'Clubs, sports, creative + enrichment',
      'Participation entries': 'Not a unique-student count',
      'Programme types': 'Sport, club, creative, enrichment',
      'Upcoming sessions': 'Representative schedule',
      'Dedicated workflows': 'Houses + excursions separate',
    };
    final cards = activityStats.entries
        .map(
          (entry) => _StatCard(
            label: entry.key,
            value: entry.value,
            note: notes[entry.key]!,
          ),
        )
        .toList(growable: false);
    if (compact) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i != cards.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in cards) SizedBox(width: 220, child: card),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.typeFilter,
    required this.sectionFilter,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onSectionChanged,
  });

  final TextEditingController searchController;
  final ActivityType? typeFilter;
  final String? sectionFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ActivityType?> onTypeChanged;
  final ValueChanged<String?> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Search activity, coordinator or section',
            ),
          ),
        ),
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<ActivityType?>(
            initialValue: typeFilter,
            decoration: const InputDecoration(labelText: 'Programme type'),
            items: [
              const DropdownMenuItem<ActivityType?>(value: null, child: Text('All types')),
              for (final type in ActivityType.values)
                DropdownMenuItem<ActivityType?>(value: type, child: Text(type.label)),
            ],
            onChanged: onTypeChanged,
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            initialValue: sectionFilter,
            decoration: const InputDecoration(labelText: 'Section'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('All sections')),
              DropdownMenuItem<String?>(value: 'Early Years', child: Text('Early Years')),
              DropdownMenuItem<String?>(value: 'Primary', child: Text('Primary')),
              DropdownMenuItem<String?>(value: 'Secondary', child: Text('Secondary')),
              DropdownMenuItem<String?>(value: 'Whole school', child: Text('Whole school')),
            ],
            onChanged: onSectionChanged,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.selected, required this.onTap});
  final SchoolActivity activity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(activity.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        Chip(label: Text(activity.type.label)),
                        Chip(label: Text(activity.section)),
                        Chip(label: Text('${activity.members} members')),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(activity.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(activity.note),
                    const SizedBox(height: 8),
                    Text('${activity.schedule} · ${activity.venue} · ${activity.coordinator}', style: theme.textTheme.bodySmall),
                    if (activity.attendance > 0) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: activity.attendance / 100),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Chip(label: Text(activity.status)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text),
    );
  }
}

class _NewActivityDraft {
  const _NewActivityDraft({
    required this.name,
    required this.type,
    required this.section,
    required this.coordinator,
    required this.schedule,
    required this.venue,
    required this.note,
  });
  final String name;
  final ActivityType type;
  final String section;
  final String coordinator;
  final String schedule;
  final String venue;
  final String note;
}

class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _name = TextEditingController();
  final _coordinator = TextEditingController();
  final _schedule = TextEditingController();
  final _venue = TextEditingController();
  final _note = TextEditingController();
  ActivityType _type = ActivityType.club;
  String _section = 'Whole school';

  @override
  void dispose() {
    _name.dispose();
    _coordinator.dispose();
    _schedule.dispose();
    _venue.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add activity'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Activity name')),
              const SizedBox(height: 10),
              DropdownButtonFormField<ActivityType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Programme type'),
                items: [for (final type in ActivityType.values) DropdownMenuItem(value: type, child: Text(type.label))],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _section,
                decoration: const InputDecoration(labelText: 'Section'),
                items: const [
                  DropdownMenuItem(value: 'Whole school', child: Text('Whole school')),
                  DropdownMenuItem(value: 'Early Years', child: Text('Early Years')),
                  DropdownMenuItem(value: 'Primary', child: Text('Primary')),
                  DropdownMenuItem(value: 'Secondary', child: Text('Secondary')),
                  DropdownMenuItem(value: 'Primary + Secondary', child: Text('Primary + Secondary')),
                ],
                onChanged: (value) => setState(() => _section = value ?? _section),
              ),
              const SizedBox(height: 10),
              TextField(controller: _coordinator, decoration: const InputDecoration(labelText: 'Coordinator')),
              const SizedBox(height: 10),
              TextField(controller: _schedule, decoration: const InputDecoration(labelText: 'Schedule')),
              const SizedBox(height: 10),
              TextField(controller: _venue, decoration: const InputDecoration(labelText: 'Venue')),
              const SizedBox(height: 10),
              TextField(controller: _note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Programme note')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _NewActivityDraft(
              name: _name.text,
              type: _type,
              section: _section,
              coordinator: _coordinator.text,
              schedule: _schedule.text,
              venue: _venue.text,
              note: _note.text,
            ),
          ),
          child: const Text('Create activity'),
        ),
      ],
    );
  }
}
