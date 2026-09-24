import 'package:flutter/material.dart';

import '../data/teacher_attendance_repository.dart';
import '../domain/teacher_attendance_models.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherAttendanceRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  late Future<TeacherAttendanceSnapshot> _future;
  final _searchController = TextEditingController();
  String _selectedLessonId = '';
  String _query = '';
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  Future<void> _apply(
    Future<TeacherAttendanceActionResult> Function() action,
  ) async {
    final result = await action();
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      _future = widget.repository.load();
    });
    if (result.success) widget.onMutationQueued();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAttendanceSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorState(onRetry: _reload);
        }

        final data = snapshot.requireData;
        if (data.registers.isEmpty) {
          return _EmptyState(
            canonical: data.canonical,
            onTimetable: () => widget.onNavigate('timetable'),
          );
        }
        final selected = data.registers.firstWhere(
          (item) => item.lesson.id == _selectedLessonId,
          orElse: () => data.registers.first,
        );
        final visibleEntries = selected.entries.where((entry) {
          final q = _query.trim().toLowerCase();
          if (q.isEmpty) return true;
          return '${entry.code} ${entry.studentId}'.toLowerCase().contains(q);
        }).toList(growable: false);
        final locked =
            selected.submissionState == TeacherAttendanceSubmissionState.submitted;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Header(
              canonical: data.canonical,
              dateLabel: data.dateLabel,
              onTimetable: () => widget.onNavigate('timetable'),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              _Notice(message: _notice!, success: _noticeSuccess),
            ],
            const SizedBox(height: 16),
            _OccurrenceSelector(
              registers: data.registers,
              selected: selected,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedLessonId = value;
                  _query = '';
                  _searchController.clear();
                });
              },
              onTopicChanged: locked
                  ? null
                  : (topicId) => _apply(
                        () => widget.repository.setTopic(
                          lessonId: selected.lesson.id,
                          topicId: topicId ?? '',
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            _Summary(register: selected),
            const SizedBox(height: 14),
            _RegisterHeader(
              register: selected,
              locked: locked,
              searchController: _searchController,
              onSearch: (value) => setState(() => _query = value),
              onMarkAllPresent: locked
                  ? null
                  : () => _apply(
                        () => widget.repository.markAllPresent(
                          lessonId: selected.lesson.id,
                        ),
                      ),
            ),
            const SizedBox(height: 10),
            for (final entry in visibleEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StudentRow(
                  entry: entry,
                  locked: locked,
                  onStatusChanged: (status) => _apply(
                    () => widget.repository.setStatus(
                      lessonId: selected.lesson.id,
                      studentId: entry.studentId,
                      status: status,
                    ),
                  ),
                  onNote: () => _editNote(selected.lesson.id, entry),
                ),
              ),
            if (visibleEntries.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No eligible student matches this search.'),
                ),
              ),
            const SizedBox(height: 8),
            _SubmissionPanel(
              register: selected,
              locked: locked,
              onSubmit: locked
                  ? null
                  : () => _apply(
                        () => widget.repository.submit(
                          lessonId: selected.lesson.id,
                        ),
                      ),
            ),
            const SizedBox(height: 14),
            const _BoundaryPanel(),
          ],
        );
      },
    );
  }

  Future<void> _editNote(
    String lessonId,
    TeacherAttendanceStudentEntry entry,
  ) async {
    final controller = TextEditingController(text: entry.note);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Attendance note · ${entry.code}'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Optional factual attendance note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save note'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _apply(
      () => widget.repository.setNote(
        lessonId: lessonId,
        studentId: entry.studentId,
        note: value,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.canonical,
    required this.dateLabel,
    required this.onTimetable,
  });

  final bool canonical;
  final String dateLabel;
  final VoidCallback onTimetable;

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
              Text(
                canonical ? 'TEACHER · SUBJECT ATTENDANCE' : 'TEACHER · DEMO ATTENDANCE',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Lesson attendance',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                canonical
                    ? '$dateLabel · Real timetable occurrences · Offline capable'
                    : '$dateLabel · Standalone demo data',
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: onTimetable,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('My timetable'),
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: success ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(success ? Icons.check_circle_outline : Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _OccurrenceSelector extends StatelessWidget {
  const _OccurrenceSelector({
    required this.registers,
    required this.selected,
    required this.onChanged,
    required this.onTopicChanged,
  });

  final List<TeacherAttendanceRegister> registers;
  final TeacherAttendanceRegister selected;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String?>? onTopicChanged;

  @override
  Widget build(BuildContext context) {
    final lesson = selected.lesson;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 470,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selected.lesson.id,
                    decoration: const InputDecoration(
                      labelText: 'Real lesson occurrence',
                    ),
                    items: [
                      for (final register in registers)
                        DropdownMenuItem(
                          value: register.lesson.id,
                          child: Text(register.lesson.label),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
                _Meta(label: 'Time', value: lesson.time),
                _Meta(label: 'Room', value: lesson.room.isEmpty ? 'Not assigned' : lesson.room),
                _Meta(
                  label: 'Students',
                  value: '${selected.entries.length} eligible',
                ),
              ],
            ),
            if (lesson.topicOptions.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 520,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: lesson.topicId.isEmpty ? '' : lesson.topicId,
                  decoration: const InputDecoration(
                    labelText: 'Curriculum topic taught (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('No topic linked')),
                    for (final topic in lesson.topicOptions)
                      DropdownMenuItem(value: topic.id, child: Text(topic.title)),
                  ],
                  onChanged: onTopicChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.register});

  final TeacherAttendanceRegister register;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Unmarked', register.count(TeacherAttendanceStatus.unmarked)),
      ('Present', register.count(TeacherAttendanceStatus.present)),
      ('Absent', register.count(TeacherAttendanceStatus.absent)),
      ('Late', register.count(TeacherAttendanceStatus.late)),
      ('Excused', register.count(TeacherAttendanceStatus.excused)),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in rows)
          SizedBox(
            width: 160,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 3),
                    Text(
                      '${item.$2}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({
    required this.register,
    required this.locked,
    required this.searchController,
    required this.onSearch,
    required this.onMarkAllPresent,
  });

  final TeacherAttendanceRegister register;
  final bool locked;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback? onMarkAllPresent;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${register.lesson.className} · ${register.lesson.subject}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    locked
                        ? 'Submitted and locked · ${register.submittedAt ?? 'server acknowledgement pending'}'
                        : 'Every eligible student must receive an explicit status before submission.',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearch,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search student name or ID',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onMarkAllPresent,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Mark all present'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.entry,
    required this.locked,
    required this.onStatusChanged,
    required this.onNote,
  });

  final TeacherAttendanceStudentEntry entry;
  final bool locked;
  final ValueChanged<TeacherAttendanceStatus> onStatusChanged;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                entry.code.trim().isEmpty ? '?' : entry.code.trim().substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.code, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(entry.studentId),
                  if (entry.note.isNotEmpty)
                    Text(
                      entry.note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<TeacherAttendanceStatus>(
                initialValue: entry.status,
                decoration: const InputDecoration(isDense: true, labelText: 'Status'),
                items: [
                  for (final status in TeacherAttendanceStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(teacherAttendanceStatusLabel(status)),
                    ),
                ],
                onChanged: locked
                    ? null
                    : (value) {
                        if (value != null) onStatusChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Attendance note',
              onPressed: locked ? null : onNote,
              icon: const Icon(Icons.note_alt_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionPanel extends StatelessWidget {
  const _SubmissionPanel({
    required this.register,
    required this.locked,
    required this.onSubmit,
  });

  final TeacherAttendanceRegister register;
  final bool locked;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = !locked && register.unmarkedCount == 0 && register.entries.isNotEmpty;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? 'Attendance submitted' : 'Ready to submit?',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                Text(
                  locked
                      ? 'This occurrence is locked. A later change must use an audited correction workflow.'
                      : register.unmarkedCount == 0
                          ? 'All ${register.entries.length} eligible students have an explicit status.'
                          : '${register.unmarkedCount} student(s) are still unmarked.',
                ),
                if (register.pendingSync)
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Text('Local change queued · server acknowledgement pending'),
                  ),
              ],
            ),
            FilledButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Submit attendance'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryPanel extends StatelessWidget {
  const _BoundaryPanel();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Subject attendance is tied to a real timetable occurrence and the canonical subject-eligible roster. A local draft is not server acknowledgement. Submitted records are historical evidence; attendance alone must not change grades, discipline or progression.',
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canonical, required this.onTimetable});

  final bool canonical;
  final VoidCallback onTimetable;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fact_check_outlined, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'No lesson occurrence is ready for attendance',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canonical
                        ? 'Attendance appears only for your real active-term timetable occurrences up to today. Future and cancelled lessons are not opened as registers.'
                        : 'No standalone demo attendance data is available.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onTimetable,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Open timetable'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 8),
            const Text(
              'Could not load lesson attendance.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}
