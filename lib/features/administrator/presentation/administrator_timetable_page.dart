import 'package:flutter/material.dart';

import '../data/administrator_timetable_repository.dart';
import '../domain/administrator_academics_models.dart';
import '../domain/administrator_timetable_models.dart';

class AdministratorTimetablePage extends StatefulWidget {
  const AdministratorTimetablePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onChanged,
  });

  final String schoolName;
  final AdministratorTimetableRepository repository;
  final VoidCallback onChanged;

  @override
  State<AdministratorTimetablePage> createState() =>
      _AdministratorTimetablePageState();
}

class _AdministratorTimetablePageState
    extends State<AdministratorTimetablePage> {
  AdministratorTimetableSnapshot? _snapshot;
  String? _error;
  bool _busy = true;
  String _classFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_busy && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && snapshot == null) {
      return _StateMessage(
        title: 'Could not load timetable',
        detail: _error!,
        onRetry: _load,
      );
    }
    if (snapshot == null) return const SizedBox.shrink();

    final classOptions = <String, String>{};
    for (final item in snapshot.curriculum) {
      classOptions[item.classId] = item.className;
    }
    final visibleEntries = snapshot.entries.where((item) {
      return _classFilter == 'all' || item.classId == _classFilter;
    }).toList(growable: false);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _header(snapshot),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: _error!, onRetry: _load),
            ],
            const SizedBox(height: 16),
            _coverage(snapshot),
            const SizedBox(height: 16),
            _toolbar(snapshot, classOptions),
            const SizedBox(height: 16),
            if (snapshot.activeTerm == null)
              const _InfoCard(
                title: 'No active academic term',
                detail:
                    'Activate a term in Academic Structure before publishing a timetable. Timetable rows always belong to a canonical term.',
              )
            else if (snapshot.curriculum.isEmpty)
              const _InfoCard(
                title: 'No active curriculum requirements',
                detail:
                    'Configure Subjects & Curriculum first. Timetable rows cannot be created from free-text subjects or class-name guesses.',
              )
            else if (visibleEntries.isEmpty)
              const _InfoCard(
                title: 'No published timetable rows yet',
                detail:
                    'Create the first lesson from a canonical ClassSubject. A queued local row is not authoritative until server sync accepts it.',
              )
            else
              _schedule(snapshot, visibleEntries),
            const SizedBox(height: 16),
            _overrides(snapshot),
            const SizedBox(height: 16),
            const _AuthorityCard(),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }

  Widget _header(AdministratorTimetableSnapshot snapshot) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ADMINISTRATION · TIMETABLE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Timetable & Scheduling',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.schoolName} · ${snapshot.activeTerm?.name ?? 'No active term'}',
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: snapshot.activeTerm == null || snapshot.curriculum.isEmpty
                ? null
                : () => _showEntryDialog(snapshot),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add lesson'),
          ),
        ],
      );

  Widget _coverage(AdministratorTimetableSnapshot snapshot) {
    final active = snapshot.entries.where((item) => item.isActive).toList();
    final required = snapshot.curriculum.fold<int>(
      0,
      (sum, item) => sum + item.periodsPerWeek,
    );
    final covered = active.where((item) => item.teacherId.isNotEmpty).length;
    final clashes = active.where((item) => item.status == 'clash').length;
    final pending = snapshot.entries.where((item) => item.pendingSync).length +
        snapshot.overrides.where((item) => item.pendingSync).length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Kpi(label: 'Curriculum periods', value: '$required', note: 'Required per week'),
        _Kpi(label: 'Scheduled rows', value: '${active.length}', note: 'Active term'),
        _Kpi(label: 'Teacher-covered', value: '$covered', note: 'Derived from assignments'),
        _Kpi(label: 'Clashes', value: '$clashes', note: 'Teacher/room overlap'),
        _Kpi(label: 'Pending sync', value: '$pending', note: 'Queued ≠ accepted'),
      ],
    );
  }

  Widget _toolbar(
    AdministratorTimetableSnapshot snapshot,
    Map<String, String> classOptions,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Published weekly grid',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _classFilter,
                  decoration: const InputDecoration(
                    labelText: 'Class',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All classes'),
                    ),
                    for (final item in classOptions.entries)
                      DropdownMenuItem(
                        value: item.key,
                        child: Text(item.value),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _classFilter = value ?? 'all'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );

  Widget _schedule(
    AdministratorTimetableSnapshot snapshot,
    List<AdministratorTimetableEntry> entries,
  ) {
    final days = <int>[];
    for (final entry in entries) {
      if (!days.contains(entry.dayOfWeek)) days.add(entry.dayOfWeek);
    }
    days.sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _dayName(day),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in entries.where((item) => item.dayOfWeek == day))
                      _entryTile(snapshot, entry),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _entryTile(
    AdministratorTimetableSnapshot snapshot,
    AdministratorTimetableEntry entry,
  ) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.time} · Period ${entry.periodNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${entry.className} · ${entry.subject}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${entry.teacher.isEmpty ? 'Uncovered' : entry.teacher} · ${entry.room.isEmpty ? 'Room not assigned' : entry.room}',
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  children: [
                    Chip(label: Text(entry.status)),
                    if (entry.pendingSync)
                      const Chip(label: Text('Pending sync')),
                  ],
                ),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: () => _showEntryDialog(snapshot, entry: entry),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: () => _showOverrideDialog(snapshot, entry),
                  child: const Text('One-date change'),
                ),
                TextButton(
                  onPressed: () => _confirmDeactivate(entry),
                  child: const Text('Deactivate'),
                ),
              ],
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [info, const SizedBox(height: 6), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      );

  Widget _overrides(AdministratorTimetableSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Date-specific changes',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const Text(
                'Substitutions, cancellations and room changes preserve the recurring timetable.',
              ),
              const SizedBox(height: 10),
              if (snapshot.overrides.isEmpty)
                const Text('No timetable override is recorded yet.')
              else
                for (final item in snapshot.overrides)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.isCancelled
                          ? Icons.event_busy_outlined
                          : Icons.event_repeat_rounded,
                    ),
                    title: Text(
                      '${item.lessonDate} · ${item.status}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      [
                        if (item.teacher.isNotEmpty) item.teacher,
                        if (item.room.isNotEmpty) item.room,
                        if (item.note.isNotEmpty) item.note,
                      ].join(' · '),
                    ),
                    trailing: item.pendingSync
                        ? const Chip(label: Text('Pending sync'))
                        : null,
                  ),
            ],
          ),
        ),
      );

  Future<void> _showEntryDialog(
    AdministratorTimetableSnapshot snapshot, {
    AdministratorTimetableEntry? entry,
  }) async {
    final requirements = snapshot.curriculum;
    AdministratorClassSubject selected = requirements.firstWhere(
      (item) => item.id == entry?.classSubjectId,
      orElse: () => requirements.first,
    );
    var day = entry?.dayOfWeek ?? DateTime.monday;
    var period = entry?.periodNumber ?? 1;
    final start = TextEditingController(text: entry?.startTime ?? '08:00');
    final end = TextEditingController(text: entry?.endTime ?? '08:40');
    final room = TextEditingController(text: entry?.room ?? '');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry == null ? 'Add timetable lesson' : 'Edit timetable lesson'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<AdministratorClassSubject>(
                    initialValue: selected,
                    decoration: const InputDecoration(labelText: 'Class curriculum subject'),
                    items: [
                      for (final item in requirements)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.className} · ${item.subject} · ${item.periodsPerWeek}/week',
                          ),
                        ),
                    ],
                    onChanged: entry == null
                        ? (value) {
                            if (value != null) {
                              setDialogState(() => selected = value);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: [
                      for (var value = 1; value <= 7; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_dayName(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => day = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: period,
                    decoration: const InputDecoration(labelText: 'Period number'),
                    items: [
                      for (var value = 1; value <= 15; value++)
                        DropdownMenuItem(value: value, child: Text('Period $value')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => period = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: start,
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                            hintText: '08:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: end,
                          decoration: const InputDecoration(
                            labelText: 'End time',
                            hintText: '08:40',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: room,
                    decoration: const InputDecoration(
                      labelText: 'Room / venue',
                      hintText: 'Optional',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Teacher is not chosen here. SchoolOS derives teacher authority from the active Teaching Assignment for this ClassSubject.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Queue save'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(
      () => widget.repository.saveEntry(
        id: entry?.id,
        termId: snapshot.activeTerm!.id,
        classSubject: selected,
        dayOfWeek: day,
        periodNumber: period,
        startTime: start.text.trim(),
        endTime: end.text.trim(),
        room: room.text,
      ),
      'Timetable lesson queued. It becomes canonical only after server validation.',
    );
  }

  Future<void> _showOverrideDialog(
    AdministratorTimetableSnapshot snapshot,
    AdministratorTimetableEntry entry,
  ) async {
    final date = TextEditingController();
    final room = TextEditingController();
    final note = TextEditingController();
    var mode = 'room';
    String substituteTeacherId = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${entry.className} · ${entry.subject}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Lesson date',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    decoration: const InputDecoration(labelText: 'Change type'),
                    items: const [
                      DropdownMenuItem(value: 'room', child: Text('Room change / note')),
                      DropdownMenuItem(value: 'substitution', child: Text('Substitute teacher')),
                      DropdownMenuItem(value: 'cancel', child: Text('Cancel this lesson')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => mode = value);
                    },
                  ),
                  if (mode == 'substitution') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: substituteTeacherId.isEmpty ? null : substituteTeacherId,
                      decoration: const InputDecoration(labelText: 'Substitute Teacher membership'),
                      items: [
                        for (final teacher in snapshot.teachers)
                          DropdownMenuItem(
                            value: teacher.membershipId,
                            child: Text('${teacher.name} · ${teacher.section}'),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => substituteTeacherId = value ?? ''),
                    ),
                  ],
                  if (mode == 'room') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: room,
                      decoration: const InputDecoration(labelText: 'Replacement room'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Operational note'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: mode == 'substitution' && substituteTeacherId.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Queue change'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    await _run(
      () => widget.repository.saveOverride(
        entry: entry,
        lessonDate: date.text.trim(),
        substituteTeacherId: mode == 'substitution' ? substituteTeacherId : '',
        room: mode == 'room' ? room.text : '',
        note: note.text,
        isCancelled: mode == 'cancel',
      ),
      'Date-specific timetable change queued for server validation.',
    );
  }

  Future<void> _confirmDeactivate(AdministratorTimetableEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate timetable row?'),
        content: Text(
          '${entry.className} · ${entry.subject} · ${entry.day} ${entry.time}\n\nHistorical term records remain preserved. This change is queued until the server accepts it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => widget.repository.deactivateEntry(entry),
      'Timetable deactivation queued for server validation.',
    );
  }

  String _dayName(int day) => const {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
      }[day] ?? 'Day';
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                Text(note, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(detail),
            ],
          ),
        ),
      );
}

class _AuthorityCard extends StatelessWidget {
  const _AuthorityCard();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Authority boundary: the timetable references the canonical active term and ClassSubject. Base lessons never accept a free-text teacher; Teacher authority comes from the active TeachingAssignment. Date-specific substitution requires a linked Teacher membership. Queued offline changes are not canonical until the server accepts them.',
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListTile(
        tileColor: Theme.of(context).colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(message),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
