import 'package:flutter/material.dart';

import '../data/principal_timetable_demo_data.dart';
import '../data/principal_timetable_repository.dart';
import '../domain/principal_timetable_models.dart';

class PrincipalTimetablePage extends StatefulWidget {
  const PrincipalTimetablePage({super.key, required this.repository, required this.onNavigate, this.onMutationQueued});

  final PrincipalTimetableRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalTimetablePage> createState() => _PrincipalTimetablePageState();
}

class _PrincipalTimetablePageState extends State<PrincipalTimetablePage> {
  PrincipalTimetableSnapshot? _snapshot;
  String? _error;
  String _day = 'Monday';
  String _view = 'Day';
  String _query = '';
  String _statusFilter = 'All statuses';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<PrincipalTimetableLesson> _visible(PrincipalTimetableSnapshot snapshot) {
    final query = _query.trim().toLowerCase();
    return snapshot.lessons.where((lesson) {
      final matchesDay = _view == 'Week' || lesson.day == _day;
      final matchesStatus = _statusFilter == 'All statuses' || lesson.status.label == _statusFilter;
      final haystack = '${lesson.className} ${lesson.subject} ${lesson.teacher} ${lesson.room}'.toLowerCase();
      return matchesDay && matchesStatus && (query.isEmpty || haystack.contains(query));
    }).toList(growable: false);
  }

  Future<void> _toggleException(PrincipalTimetableLesson lesson, bool handled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.setExceptionHandled(lessonId: lesson.id, handled: handled);
    if (!mounted) return;
    await _load();
    widget.onMutationQueued?.call();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 8),
        const Text('Could not load timetable.', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]));
    }
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    final visible = _visible(snapshot);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        _TimetableOverview(
          lessons: visible,
          day: _day,
          view: _view,
          statusFilter: _statusFilter,
          onDayChanged: (value) => setState(() => _day = value),
          onViewChanged: (value) => setState(() => _view = value),
          onStatusChanged: (value) => setState(() => _statusFilter = value),
          onQueryChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final exceptions = _Exceptions(
            snapshot: snapshot,
            saving: _saving,
            onToggle: _toggleException,
          );
          final ai = _AiInsight(onNavigate: widget.onNavigate);
          if (constraints.maxWidth >= 900) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: exceptions),
              const SizedBox(width: 16),
              Expanded(child: ai),
            ]);
          }
          return Column(children: [exceptions, const SizedBox(height: 16), ai]);
        }),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final loads = _TeacherLoads(rows: snapshot.teacherLoads);
          final rooms = _RoomUse(rows: snapshot.roomUse);
          if (constraints.maxWidth >= 900) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: loads),
              const SizedBox(width: 16),
              Expanded(child: rooms),
            ]);
          }
          return Column(children: [loads, const SizedBox(height: 16), rooms]);
        }),
        const SizedBox(height: 12),
        const _Boundary(text: principalTimetableAuthorityBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalTimetableExceptionBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalTimetableAuditBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalTimetableAiBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 16,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PRINCIPAL · TIMETABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            SizedBox(height: 4),
            Text('School Timetable', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
            SizedBox(height: 4),
            Text('Monitor lessons, teacher load, rooms, substitutions and scheduling exceptions.'),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('teachers'), child: const Text('Teachers')),
            OutlinedButton(onPressed: () => onNavigate('attendance'), child: const Text('Attendance')),
          ]),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalTimetableSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        const _Kpi(label: 'Lessons this week', value: '186', note: 'Across current campus'),
        const _Kpi(label: 'Today', value: '38', note: 'Scheduled lessons'),
        _Kpi(label: 'Substitutions', value: '${snapshot.substitutionCount}', note: 'Requires awareness'),
        _Kpi(label: 'Uncovered', value: '${snapshot.uncoveredCount}', note: 'Needs assignment'),
        _Kpi(label: 'Clashes', value: '${snapshot.clashCount}', note: 'Needs correction'),
      ]);
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(width: 185, child: Card(elevation: 0, child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(note, style: Theme.of(context).textTheme.bodySmall),
    ]),
  )));
}

class _TimetableOverview extends StatelessWidget {
  const _TimetableOverview({
    required this.lessons,
    required this.day,
    required this.view,
    required this.statusFilter,
    required this.onDayChanged,
    required this.onViewChanged,
    required this.onStatusChanged,
    required this.onQueryChanged,
  });
  final List<PrincipalTimetableLesson> lessons;
  final String day;
  final String view;
  final String statusFilter;
  final ValueChanged<String> onDayChanged;
  final ValueChanged<String> onViewChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Timetable overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text('Filter the timetable by day, status, teacher, class or room.'),
            ])),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'Day', label: Text('Day')), ButtonSegment(value: 'Week', label: Text('Week'))],
              selected: {view},
              onSelectionChanged: (value) => onViewChanged(value.first),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: 170, child: DropdownButtonFormField<String>(
              initialValue: day,
              decoration: const InputDecoration(labelText: 'Day', border: OutlineInputBorder()),
              items: [for (final value in principalTimetableDays) DropdownMenuItem(value: value, child: Text(value))],
              onChanged: view == 'Week' ? null : (value) { if (value != null) onDayChanged(value); },
            )),
            SizedBox(width: 190, child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
              items: [for (final value in principalTimetableStatuses) DropdownMenuItem(value: value, child: Text(value))],
              onChanged: (value) { if (value != null) onStatusChanged(value); },
            )),
            SizedBox(width: 330, child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search class, subject, teacher or room...', border: OutlineInputBorder()),
              onChanged: onQueryChanged,
            )),
          ]),
          const SizedBox(height: 12),
          if (lessons.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No timetable lessons match these filters.')))
          else
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 850) {
                return Column(children: [for (final lesson in lessons) _LessonCard(lesson: lesson)]);
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(columns: const [
                  DataColumn(label: Text('Day')), DataColumn(label: Text('Time')), DataColumn(label: Text('Class')), DataColumn(label: Text('Subject')), DataColumn(label: Text('Teacher')), DataColumn(label: Text('Room')), DataColumn(label: Text('Status')),
                ], rows: [for (final lesson in lessons) DataRow(cells: [
                  DataCell(Text(lesson.day)), DataCell(Text(lesson.time, style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(Text(lesson.className)), DataCell(Text(lesson.subject)), DataCell(Text(lesson.teacher)), DataCell(Text(lesson.room)), DataCell(_StatusChip(status: lesson.status)),
                ])]),
              );
            }),
        ]),
      ));
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson});
  final PrincipalTimetableLesson lesson;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('${lesson.className} · ${lesson.subject}', style: const TextStyle(fontWeight: FontWeight.w900))), _StatusChip(status: lesson.status)]),
          const SizedBox(height: 5),
          Text('${lesson.day} · ${lesson.time} · ${lesson.teacher} · ${lesson.room}'),
        ]),
      );
}

class _Exceptions extends StatelessWidget {
  const _Exceptions({required this.snapshot, required this.saving, required this.onToggle});
  final PrincipalTimetableSnapshot snapshot;
  final bool saving;
  final void Function(PrincipalTimetableLesson lesson, bool handled) onToggle;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Schedule exceptions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final item in snapshot.exceptions) ...[
            Builder(builder: (context) {
              final handled = snapshot.isHandled(item.id);
              return Opacity(
                opacity: handled ? .62 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    _StatusChip(status: item.status),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${item.className} · ${item.subject}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${item.day} · ${item.time} · ${item.teacher} · ${item.room}'),
                    ])),
                    TextButton(onPressed: saving ? null : () => onToggle(item, !handled), child: Text(handled ? 'Reopen' : 'Mark handled')),
                  ]),
                ),
              );
            }),
          ],
        ]),
      ));
}

class _AiInsight extends StatelessWidget {
  const _AiInsight({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Principal AI schedule insight', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(principalTimetableAiInsight),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Principal AI')),
            OutlinedButton(onPressed: () => onNavigate('teachers'), child: const Text('Review teacher load')),
          ]),
        ]),
      ));
}

class _TeacherLoads extends StatelessWidget {
  const _TeacherLoads({required this.rows});
  final List<PrincipalTeacherLoad> rows;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Teacher workload', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final row in rows) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${row.lessons} lessons · target ${row.target}'),
            trailing: Chip(label: Text(row.status)),
          ),
        ]),
      ));
}

class _RoomUse extends StatelessWidget {
  const _RoomUse({required this.rows});
  final List<PrincipalRoomUtilization> rows;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Room utilization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final row in rows) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(row.room, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${row.utilization}%')]),
              Text('${row.lessons} lessons this week', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 5),
              LinearProgressIndicator(value: row.utilization / 100),
            ]),
          ),
        ]),
      ));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final PrincipalTimetableStatus status;
  @override
  Widget build(BuildContext context) => Chip(label: Text(status.label));
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_user_outlined, size: 20), const SizedBox(width: 10), Expanded(child: Text(text)),
        ]),
      ));
}
