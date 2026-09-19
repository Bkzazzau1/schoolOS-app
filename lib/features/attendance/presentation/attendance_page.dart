import 'package:flutter/material.dart';

import '../../../shared/layout/app_breakpoints.dart';
import '../data/attendance_repository.dart';
import '../domain/attendance_models.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    required this.repository,
    required this.onSaved,
  });

  final AttendanceRepository repository;
  final VoidCallback onSaved;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AttendanceClass _selectedClass = AttendanceRepository.foundationClasses.first;
  final DateTime _attendanceDate = DateTime.now();
  List<AttendanceEntry> _entries = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() => _loading = true);

    final students = await widget.repository.loadRoster(_selectedClass.id);
    final savedStatuses = await widget.repository.loadSavedAttendance(
      schoolClass: _selectedClass,
      date: _attendanceDate,
    );

    if (!mounted) return;
    setState(() {
      _entries = students
          .map(
            (student) => AttendanceEntry(
              student: student,
              status: savedStatuses?[student.id] ?? AttendanceStatus.present,
            ),
          )
          .toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _saveAttendance() async {
    if (_saving || _entries.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.repository.saveAttendance(
        schoolClass: _selectedClass,
        date: _attendanceDate,
        entries: _entries,
      );
      widget.onSaved();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved offline and queued for sync.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setAll(AttendanceStatus status) {
    setState(() {
      _entries = _entries
          .map((entry) => entry.copyWith(status: status))
          .toList(growable: false);
    });
  }

  void _updateStatus(int index, AttendanceStatus status) {
    final updated = List<AttendanceEntry>.of(_entries);
    updated[index] = updated[index].copyWith(status: status);
    setState(() => _entries = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = _entries
        .where((entry) => entry.status == AttendanceStatus.present)
        .length;
    final absent = _entries
        .where((entry) => entry.status == AttendanceStatus.absent)
        .length;
    final late = _entries
        .where((entry) => entry.status == AttendanceStatus.late)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = AppBreakpoints.isPhone(constraints.maxWidth);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Offline-first · ${_formatDate(_attendanceDate)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveAttendance,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save offline'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: phone ? double.infinity : 260,
                      child: DropdownButtonFormField<AttendanceClass>(
                        initialValue: _selectedClass,
                        decoration: const InputDecoration(
                          labelText: 'Class',
                          prefixIcon: Icon(Icons.class_outlined),
                        ),
                        items: [
                          for (final schoolClass
                              in AttendanceRepository.foundationClasses)
                            DropdownMenuItem(
                              value: schoolClass,
                              child: Text(schoolClass.name),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null || value.id == _selectedClass.id) {
                            return;
                          }
                          _selectedClass = value;
                          _loadRoster();
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _entries.isEmpty
                          ? null
                          : () => _setAll(AttendanceStatus.present),
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Mark all present'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AttendanceMetric(label: 'Students', value: '${_entries.length}'),
                _AttendanceMetric(label: 'Present', value: '$present'),
                _AttendanceMetric(label: 'Absent', value: '$absent'),
                _AttendanceMetric(label: 'Late', value: '$late'),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_entries.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No students are cached for this class yet.'),
                ),
              )
            else
              for (var index = 0; index < _entries.length; index++) ...[
                _StudentAttendanceCard(
                  entry: _entries[index],
                  compact: phone,
                  onChanged: (status) => _updateStatus(index, status),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),
            Text(
              'Saving does not require internet. The encrypted local record is updated first, then the change is placed in the SchoolOS sync outbox.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.entry,
    required this.compact,
    required this.onChanged,
  });

  final AttendanceEntry entry;
  final bool compact;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final studentInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.student.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          entry.student.admissionNumber,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    final statusPicker = DropdownButton<AttendanceStatus>(
      value: entry.status,
      underline: const SizedBox.shrink(),
      items: [
        for (final status in AttendanceStatus.values)
          DropdownMenuItem(
            value: status,
            child: Text(status.label),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  studentInfo,
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: statusPicker,
                  ),
                ],
              )
            : Row(
                children: [
                  CircleAvatar(
                    child: Text(entry.student.name.characters.first),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: studentInfo),
                  statusPicker,
                ],
              ),
      ),
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        child: Text(value),
      ),
      label: Text(label),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
