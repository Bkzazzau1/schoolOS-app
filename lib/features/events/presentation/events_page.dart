import 'package:flutter/material.dart';

import '../data/event_demo_data.dart';
import '../data/event_repository.dart';
import '../domain/event_models.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    required this.onEventsChanged,
  });

  final String schoolName;
  final EventRepository repository;
  final VoidCallback onBack;
  final VoidCallback onEventsChanged;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _searchController = TextEditingController();
  EventSnapshot? _snapshot;
  SchoolEventType? _typeFilter;
  bool _loading = true;
  String _notice = '';

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
    });
  }

  List<SchoolEvent> get _visibleEvents {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return snapshot.events
        .where((event) => event.matches(_searchController.text, _typeFilter))
        .toList(growable: false);
  }

  Future<void> _addEvent() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.permissions.canManageAll) return;

    final title = TextEditingController();
    final audience = TextEditingController(text: 'Whole school');
    final date = TextEditingController();
    final time = TextEditingController();
    final venue = TextEditingController();
    final owner = TextEditingController(text: 'School Leadership');
    final note = TextEditingController();
    var type = SchoolEventType.schoolWide;
    var status = SchoolEventStatus.scheduled;

    final result = await showDialog<EventActionResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add school event'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Event title')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<SchoolEventType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Event type'),
                    items: [for (final item in SchoolEventType.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setLocalState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: audience, decoration: const InputDecoration(labelText: 'Audience')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: date, decoration: const InputDecoration(labelText: 'Date'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: time, decoration: const InputDecoration(labelText: 'Time'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: venue, decoration: const InputDecoration(labelText: 'Venue')),
                  const SizedBox(height: 10),
                  TextField(controller: owner, decoration: const InputDecoration(labelText: 'Owner / coordinator')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<SchoolEventStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final item in SchoolEventStatus.values) DropdownMenuItem(value: item, child: Text(item.label))],
                    onChanged: (value) {
                      if (value != null) setLocalState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Event note')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final saved = await widget.repository.addEvent(
                  title: title.text,
                  type: type,
                  audience: audience.text,
                  date: date.text,
                  time: time.text,
                  venue: venue.text,
                  owner: owner.text,
                  status: status,
                  note: note.text,
                );
                if (context.mounted) Navigator.of(context).pop(saved);
              },
              child: const Text('Save event'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    audience.dispose();
    date.dispose();
    time.dispose();
    venue.dispose();
    owner.dispose();
    note.dispose();
    if (result == null) return;
    if (result.success) {
      widget.onEventsChanged();
      await _load();
    }
    if (!mounted) return;
    setState(() => _notice = result.message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final snapshot = _snapshot!;
    final upcoming = snapshot.events.where((event) => event.isUpcoming).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final wide = constraints.maxWidth >= 1040;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 22, compact ? 16 : 26, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(schoolName: widget.schoolName, compact: compact, onBack: widget.onBack),
                    const SizedBox(height: 16),
                    const _ScopeCard(),
                    const SizedBox(height: 16),
                    _StatGrid(upcoming: upcoming, compact: compact),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildCalendar(snapshot)),
                          const SizedBox(width: 16),
                          const Expanded(flex: 3, child: _Sidebar()),
                        ],
                      )
                    else ...[
                      _buildCalendar(snapshot),
                      const SizedBox(height: 16),
                      const _Sidebar(),
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

  Widget _buildCalendar(EventSnapshot snapshot) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School calendar', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('Filter events by type and audience.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (snapshot.permissions.canManageAll)
                  FilledButton.icon(onPressed: _addEvent, icon: const Icon(Icons.add_rounded), label: const Text('Add event')),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 620;
                final search = TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search event, audience or owner...'),
                );
                final filter = DropdownButtonFormField<SchoolEventType?>(
                  initialValue: _typeFilter,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: [
                    const DropdownMenuItem<SchoolEventType?>(value: null, child: Text('All types')),
                    for (final type in SchoolEventType.values) DropdownMenuItem<SchoolEventType?>(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) => setState(() => _typeFilter = value),
                );
                return narrow
                    ? Column(children: [search, const SizedBox(height: 10), filter])
                    : Row(children: [Expanded(flex: 2, child: search), const SizedBox(width: 10), Expanded(child: filter)]);
              },
            ),
            if (_notice.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                child: Text(_notice),
              ),
            ],
            const SizedBox(height: 14),
            if (_visibleEvents.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No events match the current filters.')))
            else
              for (final event in _visibleEvents) ...[
                _EventCard(event: event),
                if (event != _visibleEvents.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.compact, required this.onBack});
  final String schoolName;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SCHOOL LIFE · ${schoolName.toUpperCase()}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Events & School Calendar', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('Academic + community calendar', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
    if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 12), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('School Life'))]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: text), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('School Life'))]);
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(18)),
      child: const Text('One shared calendar for school-wide events, section activities, parent meetings, sports, clubs and holidays. Academic timetable periods remain separate.'),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.upcoming, required this.compact});
  final int upcoming;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Upcoming events', '$upcoming', 'Across current calendar'),
      ('This month', '$eventThisMonthCount', 'September 2026'),
      ('Parent-facing', '$eventParentFacingCount', 'Conference, sports, family morning'),
      ('Registration open', '$eventRegistrationOpenCount', 'Inter-House Sports Day'),
      ('Calendar conflicts', '$eventCalendarConflicts', 'Current indicator'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = compact ? 1 : (constraints.maxWidth >= 1050 ? 5 : 3);
      final children = <Widget>[];
      for (var start = 0; start < items.length; start += columns) {
        final end = (start + columns).clamp(0, items.length);
        children.add(Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = start; i < end; i++) ...[
            Expanded(child: _StatCard(label: items[i].$1, value: items[i].$2, note: items[i].$3)),
            if (i != end - 1) const SizedBox(width: 10),
          ],
          for (var i = end; i < start + columns; i++) ...[
            const Expanded(child: SizedBox()),
            if (i != start + columns - 1) const SizedBox(width: 10),
          ],
        ]));
        if (end != items.length) children.add(const SizedBox(height: 10));
      }
      return Column(children: children);
    });
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surface, border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(note, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final SchoolEvent event;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (event.type) {
      SchoolEventType.sports => Icons.flag_outlined,
      SchoolEventType.academic => Icons.school_outlined,
      SchoolEventType.parents => Icons.family_restroom_outlined,
      SchoolEventType.club => Icons.groups_outlined,
      SchoolEventType.holiday => Icons.beach_access_outlined,
      SchoolEventType.schoolWide => Icons.event_outlined,
    };
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [Chip(label: Text(event.type.label)), Chip(label: Text(event.audience)), Chip(label: Text(event.status.label))]),
          const SizedBox(height: 5),
          Text(event.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${event.date} · ${event.time} · ${event.venue}'),
          const SizedBox(height: 6),
          Text(event.note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 6),
          Text(event.owner, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CALENDAR RULE', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Audience and authority matter', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text(eventAuthorityRule),
      ]))),
      const SizedBox(height: 12),
      Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('INTEGRATIONS LATER', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (final entry in eventFutureIntegrations.entries) ...[
          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(entry.value, style: theme.textTheme.bodySmall),
          if (entry != eventFutureIntegrations.entries.last) const Divider(height: 18),
        ],
      ]))),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)), child: const Text(eventAcademicBoundary)),
    ]);
  }
}
