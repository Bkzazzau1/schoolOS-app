import 'package:flutter/material.dart';

import '../data/principal_timetable_repository.dart';
import '../domain/principal_timetable_models.dart';

class PrincipalTimetablePage extends StatefulWidget {
  const PrincipalTimetablePage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });

  final PrincipalTimetableRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalTimetablePage> createState() => _PrincipalTimetablePageState();
}

class _PrincipalTimetablePageState extends State<PrincipalTimetablePage> {
  PrincipalTimetableSnapshot? _snapshot;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'Could not load timetable',
        detail: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(snapshot: snapshot, onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        if (snapshot.lessons.isEmpty)
          const _StateCard(
            icon: Icons.calendar_month_outlined,
            title: 'No Secondary timetable has been published',
            detail:
                'The canonical active term contains no timetable entries visible to the Principal yet. SchoolOS does not fabricate a period grid from weekly teaching-assignment counts.',
          )
        else
          _ScheduleGrid(lessons: snapshot.lessons),
        const SizedBox(height: 16),
        _Exceptions(snapshot: snapshot, onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 850) {
              return Column(
                children: [
                  _TeacherLoads(rows: snapshot.teacherLoads),
                  const SizedBox(height: 16),
                  _RoomUse(rows: snapshot.roomUse),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _TeacherLoads(rows: snapshot.teacherLoads)),
                const SizedBox(width: 16),
                Expanded(child: _RoomUse(rows: snapshot.roomUse)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _Boundary(text: principalTimetableAuthorityBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalTimetableAiBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.onNavigate});

  final PrincipalTimetableSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRINCIPAL · TIMETABLE',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                'School Timetable',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.termName.isEmpty ? 'Active term' : snapshot.termName} · ${snapshot.weekLabel}',
              ),
              const SizedBox(height: 3),
              const Text(
                'Canonical Secondary lessons, teacher coverage, room usage and schedule exceptions.',
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('dashboard'),
                child: const Text('Dashboard'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('teachers'),
                child: const Text('Teachers'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('assignments'),
                child: const Text('Teaching assignments'),
              ),
            ],
          ),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});

  final PrincipalTimetableSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final liveLessons = snapshot.lessons
        .where((row) => row.status != PrincipalTimetableStatus.cancelled)
        .length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Kpi(
          label: 'Lessons this week',
          value: '$liveLessons',
          note: 'Published Secondary periods',
        ),
        _Kpi(
          label: 'Substitutions',
          value: '${snapshot.substitutionCount}',
          note: 'Date-specific teacher cover',
        ),
        _Kpi(
          label: 'Uncovered',
          value: '${snapshot.uncoveredCount}',
          note: 'No active Teacher assignment',
        ),
        _Kpi(
          label: 'Clashes',
          value: '${snapshot.clashCount}',
          note: 'Teacher or room overlap',
        ),
        _Kpi(
          label: 'Cancelled',
          value: '${snapshot.cancelledCount}',
          note: 'This week only',
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
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
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(note, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({required this.lessons});

  final List<PrincipalTimetableLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final days = <String>[];
    for (final lesson in lessons) {
      if (!days.contains(lesson.day)) days.add(lesson.day);
    }
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Published lesson grid',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const SizedBox(height: 3),
            const Text(
              'Read-only Principal view. Schedule creation and correction remain with Administration.',
            ),
            const SizedBox(height: 14),
            for (final day in days) ...[
              Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              for (final lesson in lessons.where((row) => row.day == day))
                _LessonTile(lesson: lesson),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final PrincipalTimetableLesson lesson;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lesson.time}${lesson.periodNumber > 0 ? ' · Period ${lesson.periodNumber}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${lesson.className} · ${lesson.subject}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${lesson.teacher.isEmpty ? 'No active teacher' : lesson.teacher} · ${lesson.room.isEmpty ? 'Room not assigned' : lesson.room}',
                ),
                if ((lesson.note ?? '').isNotEmpty) Text(lesson.note!),
              ],
            );
            final chip = Chip(label: Text(lesson.status.label));
            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 6), chip],
              );
            }
            return Row(
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                chip,
              ],
            );
          },
        ),
      );
}

class _Exceptions extends StatelessWidget {
  const _Exceptions({required this.snapshot, required this.onNavigate});

  final PrincipalTimetableSnapshot snapshot;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final rows = snapshot.exceptions;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule exceptions',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      Text('Uncovered periods, clashes, substitutions and cancellations.'),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onNavigate('assignments'),
                  child: const Text('Teaching assignments'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('No timetable exception is published for this week.')
            else
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(
                    '${row.day} · ${row.time} · ${row.className}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${row.subject} · ${row.teacher.isEmpty ? 'No teacher' : row.teacher}${row.room.isEmpty ? '' : ' · ${row.room}'}',
                  ),
                  trailing: Chip(label: Text(row.status.label)),
                ),
            const SizedBox(height: 8),
            const Text(principalTimetableExceptionBoundary),
          ],
        ),
      ),
    );
  }
}

class _TeacherLoads extends StatelessWidget {
  const _TeacherLoads({required this.rows});

  final List<PrincipalTeacherLoad> rows;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teacher workload',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Text('Weekly curriculum periods from canonical Teaching Assignments.'),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Text('No Secondary teaching staff are assigned yet.'),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${row.lessons} periods/week · target ${row.target}'),
                  trailing: Chip(label: Text(row.status)),
                ),
            ],
          ),
        ),
      );
}

class _RoomUse extends StatelessWidget {
  const _RoomUse({required this.rows});

  final List<PrincipalRoomUtilization> rows;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Room schedule share',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Text('Share of published room-assigned weekly periods.'),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Text('No room has been attached to the published timetable yet.'),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.room,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${row.lessons} weekly period${row.lessons == 1 ? '' : 's'}'),
                  trailing: Text(
                    '${row.utilization}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(detail),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}
