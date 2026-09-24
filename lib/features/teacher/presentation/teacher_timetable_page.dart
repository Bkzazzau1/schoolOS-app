import 'package:flutter/material.dart';

import '../data/teacher_timetable_demo_data.dart'
    show teacherTimetableAuthorityBoundary;
import '../data/teacher_timetable_repository.dart';
import '../domain/teacher_timetable_models.dart';

class TeacherTimetablePage extends StatefulWidget {
  const TeacherTimetablePage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherTimetableRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherTimetablePage> createState() => _TeacherTimetablePageState();
}

class _TeacherTimetablePageState extends State<TeacherTimetablePage> {
  late Future<TeacherTimetableSnapshot> _future;
  final _queryController = TextEditingController();
  bool _dayView = false;
  String _selectedDay = 'Monday';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.load());
  }

  Future<void> _run(Future<TeacherTimetableActionResult> future) async {
    final result = await future;
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) await _reload();
  }

  List<TeacherTimetableKpi> _kpis(List<TeacherTimetableLesson> lessons) {
    final live = lessons
        .where((lesson) => lesson.status != TeacherTimetableLessonStatus.cancelled)
        .toList(growable: false);
    final substitutions = live
        .where((lesson) =>
            lesson.status == TeacherTimetableLessonStatus.substitution)
        .length;
    final clashes = live
        .where((lesson) => lesson.status == TeacherTimetableLessonStatus.clash)
        .length;
    final classes = live
        .map((lesson) => lesson.classId.isEmpty ? lesson.className : lesson.classId)
        .toSet()
        .length;
    return [
      TeacherTimetableKpi(
        label: 'Lessons this week',
        value: '${live.length}',
        hint: 'Across $classes assigned class${classes == 1 ? '' : 'es'}',
      ),
      TeacherTimetableKpi(
        label: 'Substitutions',
        value: '$substitutions',
        hint: 'Date-specific cover this week',
      ),
      TeacherTimetableKpi(
        label: 'Schedule clashes',
        value: '$clashes',
        hint: clashes == 0 ? 'No conflict published' : 'Needs school review',
      ),
      TeacherTimetableKpi(
        label: 'Assigned classes',
        value: '$classes',
        hint: 'Canonical timetable scope',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherTimetableSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StateMessage(
            icon: Icons.error_outline,
            title: 'Could not open timetable',
            detail: '${snapshot.error}',
            actionLabel: 'Retry',
            onAction: _reload,
          );
        }
        final data = snapshot.requireData;
        if (!data.days.contains(_selectedDay) && data.days.isNotEmpty) {
          _selectedDay = data.days.first;
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    controller: _queryController,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 16),
                  _Hero(
                    termLabel: data.termLabel,
                    weekLabel: data.weekLabel,
                    canonical: data.canonical,
                    onSync: () => _run(widget.repository.queueSyncRequest()),
                    onPrint: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Print is a device document action. It does not change timetable authority.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in _kpis(data.lessons))
                        SizedBox(
                          width: compact ? double.infinity : 210,
                          child: _KpiCard(item: item),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Toolbar(
                    dayView: _dayView,
                    selectedDay: _selectedDay,
                    days: data.days,
                    weekLabel: data.weekLabel,
                    onViewChanged: (value) => setState(() => _dayView = value),
                    onDayChanged: (day) => setState(() => _selectedDay = day),
                  ),
                  const SizedBox(height: 16),
                  if (data.canonical && data.lessons.isEmpty)
                    const _StateMessage(
                      icon: Icons.calendar_month_outlined,
                      title: 'No published timetable entries',
                      detail:
                          'Your server-authorized Teacher membership has no active-term timetable lessons yet. SchoolOS will not substitute demo lessons for a connected school.',
                    )
                  else
                    ..._visibleDays(data).map(
                      (day) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DayCard(
                          day: day.$1,
                          date: day.$2,
                          lessons: day.$3,
                          onNavigate: widget.onNavigate,
                          onOpen: (lesson) => ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                '${lesson.className} · ${lesson.subject} opened from the canonical timetable.',
                              ),
                            ),
                          ),
                          onReportIssue: (lesson) =>
                              _run(widget.repository.reportIssue(lesson)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  _bottomPanels(compact, data.notices),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        teacherTimetableAuthorityBoundary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<(String, String, List<TeacherTimetableLesson>)> _visibleDays(
    TeacherTimetableSnapshot snapshot,
  ) {
    final dayNames = _dayView ? <String>[_selectedDay] : snapshot.days;
    return dayNames.map((day) {
      final source = snapshot.lessons
          .where((lesson) => lesson.day == day)
          .toList(growable: false);
      final filtered = source
          .where((lesson) => lesson.matches(_query))
          .toList(growable: false);
      final date = source.isEmpty ? '' : source.first.date;
      return (day, date, filtered);
    }).toList(growable: false);
  }

  Widget _bottomPanels(
    bool compact,
    List<TeacherTimetableNotice> notices,
  ) {
    final noticesPanel = _Panel(
      title: 'Schedule notices',
      subtitle: 'Canonical changes affecting this teaching week',
      child: notices.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No substitution, cancellation or room-change notice this week.',
              ),
            )
          : Column(
              children: [
                for (final notice in notices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      notice.warning
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline_rounded,
                    ),
                    title: Text(
                      notice.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(notice.detail),
                  ),
              ],
            ),
    );
    final actions = _Panel(
      title: 'Quick actions',
      subtitle: 'Actions do not rewrite the school timetable locally',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => widget.onNavigate('attendance'),
            child: const Text('Take attendance'),
          ),
          OutlinedButton(
            onPressed: () => widget.onNavigate('lesson-plans'),
            child: const Text('Open lesson plans'),
          ),
          OutlinedButton(
            onPressed: () => widget.onNavigate('classes'),
            child: const Text('Open my classes'),
          ),
          OutlinedButton(
            onPressed: () => _run(widget.repository.requestChange()),
            child: const Text('Request timetable change'),
          ),
        ],
      ),
    );
    if (compact) {
      return Column(
        children: [noticesPanel, const SizedBox(height: 16), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: noticesPanel),
        const SizedBox(width: 16),
        Expanded(child: actions),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TEACHER WORKSPACE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'My Timetable',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(
            width: 360,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search class, subject, room...',
                isDense: true,
              ),
            ),
          ),
        ],
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.termLabel,
    required this.weekLabel,
    required this.canonical,
    required this.onSync,
    required this.onPrint,
  });

  final String termLabel;
  final String weekLabel;
  final bool canonical;
  final VoidCallback onSync;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$termLabel · $weekLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Your teaching schedule',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      canonical
                          ? 'Server-published lessons from your active Teacher membership and canonical Teaching Assignments.'
                          : 'Demo timetable data for local product preview.',
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(label: Text(canonical ? 'Canonical' : 'Demo')),
                  FilledButton.tonalIcon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync timetable'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final TeacherTimetableKpi item;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label),
              const SizedBox(height: 5),
              Text(
                item.value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(item.hint),
            ],
          ),
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.dayView,
    required this.selectedDay,
    required this.days,
    required this.weekLabel,
    required this.onViewChanged,
    required this.onDayChanged,
  });

  final bool dayView;
  final String selectedDay;
  final List<String> days;
  final String weekLabel;
  final ValueChanged<bool> onViewChanged;
  final ValueChanged<String> onDayChanged;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Week')),
                  ButtonSegment(value: true, label: Text('Day')),
                ],
                selected: {dayView},
                onSelectionChanged: (selection) =>
                    onViewChanged(selection.first),
              ),
              if (dayView && days.isNotEmpty)
                DropdownButton<String>(
                  value: selectedDay,
                  items: [
                    for (final day in days)
                      DropdownMenuItem(value: day, child: Text(day)),
                  ],
                  onChanged: (value) {
                    if (value != null) onDayChanged(value);
                  },
                ),
              Text(
                weekLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.date,
    required this.lessons,
    required this.onNavigate,
    required this.onOpen,
    required this.onReportIssue,
  });

  final String day;
  final String date;
  final List<TeacherTimetableLesson> lessons;
  final ValueChanged<String> onNavigate;
  final ValueChanged<TeacherTimetableLesson> onOpen;
  final ValueChanged<TeacherTimetableLesson> onReportIssue;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date.isEmpty ? day : '$day · $date',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Text('${lessons.length} lesson${lessons.length == 1 ? '' : 's'}'),
                ],
              ),
              const SizedBox(height: 10),
              if (lessons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No lessons match this view.'),
                )
              else
                for (var index = 0; index < lessons.length; index++) ...[
                  _LessonRow(
                    lesson: lessons[index],
                    fallbackPeriod: index + 1,
                    onNavigate: onNavigate,
                    onOpen: onOpen,
                    onReportIssue: onReportIssue,
                  ),
                  if (index != lessons.length - 1) const Divider(height: 20),
                ],
            ],
          ),
        ),
      );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.fallbackPeriod,
    required this.onNavigate,
    required this.onOpen,
    required this.onReportIssue,
  });

  final TeacherTimetableLesson lesson;
  final int fallbackPeriod;
  final ValueChanged<String> onNavigate;
  final ValueChanged<TeacherTimetableLesson> onOpen;
  final ValueChanged<TeacherTimetableLesson> onReportIssue;

  String get _statusLabel => switch (lesson.status) {
        TeacherTimetableLessonStatus.scheduled => 'Scheduled',
        TeacherTimetableLessonStatus.substitution => 'Substitution',
        TeacherTimetableLessonStatus.uncovered => 'Uncovered',
        TeacherTimetableLessonStatus.clash => 'Clash',
        TeacherTimetableLessonStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final period =
              lesson.periodNumber > 0 ? lesson.periodNumber : fallbackPeriod;
          final cancelled =
              lesson.status == TeacherTimetableLessonStatus.cancelled;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.time, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('Period $period'),
              const SizedBox(height: 6),
              Text(
                '${lesson.subject} · ${lesson.className}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                lesson.room.isEmpty
                    ? 'Room not assigned'
                    : 'Room ${lesson.room}',
              ),
              if (lesson.topic.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Planned topic · ${lesson.topic}'),
              ],
              if ((lesson.note ?? '').isNotEmpty)
                Text(
                  lesson.note!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 8),
              Chip(label: Text(_statusLabel)),
            ],
          );
          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TextButton(
                onPressed: cancelled ? null : () => onNavigate('attendance'),
                child: const Text('Take attendance'),
              ),
              TextButton(
                onPressed: cancelled ? null : () => onOpen(lesson),
                child: const Text('Open'),
              ),
              TextButton(
                onPressed: () => onReportIssue(lesson),
                child: const Text('Report issue'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 6), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 3),
              Text(subtitle),
              const SizedBox(height: 10),
              child,
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 38),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(detail, textAlign: TextAlign.center),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 14),
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      );
}
