import 'package:flutter/material.dart';

import '../data/teacher_attendance_demo_data.dart';
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
  final _queryController = TextEditingController();
  String _selectedLessonId = teacherAttendanceLessons.first.id;
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
    _queryController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

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
              if (_notice != null) ...[
                _Notice(message: _notice!, success: _noticeSuccess),
                const SizedBox(height: 12),
              ],
              _Hero(
                onMarkAllPresent: () => _apply(
                  () => widget.repository.markAllPresent(
                    lessonId: _selectedLessonId,
                  ),
                ),
                onBack: () => widget.onNavigate('timetable'),
              ),
              const SizedBox(height: 16),
              FutureBuilder<TeacherAttendanceSnapshot>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _ErrorCard(onRetry: _reload);
                  }
                  if (snapshot.requireData.registers.isEmpty) {
                    return const Card(
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No assigned attendance registers are available.'),
                      ),
                    );
                  }

                  final data = snapshot.requireData;
                  final selected = data.registers.firstWhere(
                    (register) => register.lesson.id == _selectedLessonId,
                    orElse: () => data.registers.first,
                  );
                  final visibleEntries = selected.entries.where((entry) {
                    final q = _query.trim().toLowerCase();
                    if (q.isEmpty) return true;
                    return '${entry.code} ${entry.studentId}'.toLowerCase().contains(q);
                  }).toList(growable: false);

                  return _AttendanceContent(
                    snapshot: data,
                    register: selected,
                    visibleEntries: visibleEntries,
                    onLessonChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedLessonId = value);
                    },
                    onStatusChanged: (studentId, status) => _apply(
                      () => widget.repository.setStatus(
                        lessonId: selected.lesson.id,
                        studentId: studentId,
                        status: status,
                      ),
                    ),
                    onNoteChanged: (studentId, note) => _apply(
                      () => widget.repository.setNote(
                        lessonId: selected.lesson.id,
                        studentId: studentId,
                        note: note,
                      ),
                    ),
                    onSubmit: () => _apply(
                      () => widget.repository.submit(
                        lessonId: selected.lesson.id,
                      ),
                    ),
                    onStudents: () => widget.onNavigate('students'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
              'Attendance',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Text('Scheduled class attendance · Offline capable'),
          ],
        ),
        SizedBox(
          width: 330,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search student ID...',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
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

class _Hero extends StatelessWidget {
  const _Hero({required this.onMarkAllPresent, required this.onBack});

  final VoidCallback onMarkAllPresent;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    teacherAttendanceDateLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Take class attendance',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Attendance is tied to a scheduled lesson and applies only to the teacher's assigned class.",
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onMarkAllPresent,
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Mark all present'),
                ),
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Back to timetable'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceContent extends StatelessWidget {
  const _AttendanceContent({
    required this.snapshot,
    required this.register,
    required this.visibleEntries,
    required this.onLessonChanged,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onSubmit,
    required this.onStudents,
  });

  final TeacherAttendanceSnapshot snapshot;
  final TeacherAttendanceRegister register;
  final List<TeacherAttendanceStudentEntry> visibleEntries;
  final ValueChanged<String?> onLessonChanged;
  final void Function(String studentId, TeacherAttendanceStatus status)
      onStatusChanged;
  final void Function(String studentId, String note) onNoteChanged;
  final VoidCallback onSubmit;
  final VoidCallback onStudents;

  bool get locked =>
      register.submissionState == TeacherAttendanceSubmissionState.submitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LessonBar(
          registers: snapshot.registers,
          selectedId: register.lesson.id,
          onChanged: onLessonChanged,
        ),
        const SizedBox(height: 14),
        _StatusSummary(register: register),
        const SizedBox(height: 14),
        _RegisterPanel(
          register: register,
          visibleEntries: visibleEntries,
          locked: locked,
          onStatusChanged: onStatusChanged,
          onNoteChanged: onNoteChanged,
          onSubmit: onSubmit,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HistoryPanel(),
                  const SizedBox(height: 16),
                  _InsightsPanel(onStudents: onStudents),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _HistoryPanel()),
                const SizedBox(width: 16),
                Expanded(child: _InsightsPanel(onStudents: onStudents)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _BoundaryPanel(),
      ],
    );
  }
}

class _LessonBar extends StatelessWidget {
  const _LessonBar({
    required this.registers,
    required this.selectedId,
    required this.onChanged,
  });

  final List<TeacherAttendanceRegister> registers;
  final String selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = registers.firstWhere(
      (item) => item.lesson.id == selectedId,
      orElse: () => registers.first,
    );
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 22,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 390,
              child: DropdownButtonFormField<String>(
                initialValue: current.lesson.id,
                decoration: const InputDecoration(labelText: 'Scheduled lesson'),
                items: [
                  for (final item in registers)
                    DropdownMenuItem(
                      value: item.lesson.id,
                      child: Text(item.lesson.label),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
            _Meta(label: 'Room', value: current.lesson.room),
            _Meta(label: 'Topic', value: current.lesson.topic),
            _Meta(label: 'Students', value: '${current.entries.length}'),
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
        width: 145,
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

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.register});
  final TeacherAttendanceRegister register;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Present',
        register.count(TeacherAttendanceStatus.present),
        '${register.presentPercent}% of class',
      ),
      (
        'Absent',
        register.count(TeacherAttendanceStatus.absent),
        'Requires review',
      ),
      (
        'Late',
        register.count(TeacherAttendanceStatus.late),
        'Arrival recorded',
      ),
      (
        'Excused',
        register.count(TeacherAttendanceStatus.excused),
        'Approved reason',
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 205,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 4),
                    Text(
                      '${item.$2}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    Text(item.$3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RegisterPanel extends StatelessWidget {
  const _RegisterPanel({
    required this.register,
    required this.visibleEntries,
    required this.locked,
    required this.onStatusChanged,
    required this.onNoteChanged,
    required this.onSubmit,
  });

  final TeacherAttendanceRegister register;
  final List<TeacherAttendanceStudentEntry> visibleEntries;
  final bool locked;
  final void Function(String studentId, TeacherAttendanceStatus status)
      onStatusChanged;
  final void Function(String studentId, String note) onNoteChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${register.lesson.className} attendance register',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    Text(
                      locked
                          ? 'Submitted registers are locked here; later changes require an audited correction.'
                          : 'Select one status per student. Changes remain editable until submission.',
                    ),
                  ],
                ),
                Chip(label: Text('${visibleEntries.length} shown')),
              ],
            ),
            const SizedBox(height: 14),
            if (register.pendingSync)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Local changes are pending synchronization.'),
                    ),
                  ],
                ),
              ),
            if (visibleEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No student IDs match this search.'),
              )
            else
              Column(
                children: [
                  for (final entry in visibleEntries)
                    _StudentAttendanceRow(
                      entry: entry,
                      locked: locked,
                      onStatusChanged: (status) =>
                          onStatusChanged(entry.studentId, status),
                      onNoteChanged: (note) => onNoteChanged(entry.studentId, note),
                    ),
                ],
              ),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${register.reviewCount} entries need review',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'Repeated absence and lateness can be surfaced to authorized school staff after synchronization.',
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: locked ? null : onSubmit,
                  icon: Icon(locked ? Icons.lock_outline : Icons.cloud_upload_outlined),
                  label: Text(
                    locked
                        ? register.pendingSync
                            ? 'Submitted · sync pending'
                            : 'Attendance submitted'
                        : 'Submit attendance',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceRow extends StatelessWidget {
  const _StudentAttendanceRow({
    required this.entry,
    required this.locked,
    required this.onStatusChanged,
    required this.onNoteChanged,
  });

  final TeacherAttendanceStudentEntry entry;
  final bool locked;
  final ValueChanged<TeacherAttendanceStatus> onStatusChanged;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CircleAvatar(
                    child: Text(entry.id.toString().padLeft(2, '0')),
                  ),
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.code, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('Demo record · ${entry.studentId}'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.attendanceRate}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: entry.attendanceRate / 100),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final status in TeacherAttendanceStatus.values)
                        _StatusButton(
                          status: status,
                          selected: entry.status == status,
                          enabled: !locked,
                          onPressed: () => onStatusChanged(status),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: ValueKey('${entry.studentId}-${entry.note}-$locked'),
                initialValue: entry.note,
                enabled: !locked,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  isDense: true,
                ),
                onFieldSubmitted: onNoteChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final TeacherAttendanceStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = teacherAttendanceStatusLabel(status);
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 42,
        child: selected
            ? FilledButton(
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(42, 38),
                ),
                child: Text(label.substring(0, 1)),
              )
            : OutlinedButton(
                onPressed: enabled ? onPressed : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(42, 38),
                ),
                child: Text(label.substring(0, 1)),
              ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Recent attendance history', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 10),
            for (final item in teacherAttendanceHistory)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.className} · ${item.subject}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.day} · ${item.presentSummary}'),
                trailing: Text(item.rate, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.onStudents});
  final VoidCallback onStudents;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Attendance insights', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('!')),
              title: Text('One attendance pattern needs review', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('A demo record shows repeated absence across recent lessons.'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onStudents, child: const Text('Open students')),
            ),
            const Divider(),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.trending_up_rounded)),
              title: Text('Class attendance improving', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('The selected class is above its recent attendance average.'),
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance evidence rules', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 8),
            const Text(teacherAttendanceDraftBoundary),
            const SizedBox(height: 8),
            const Text(teacherAttendanceSyncBoundary),
            const SizedBox(height: 8),
            const Text(teacherAttendanceInsightBoundary),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.offline_bolt_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Attendance completion: $teacherAttendanceCompletion% · offline entry remains available.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Attendance data could not be loaded.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
