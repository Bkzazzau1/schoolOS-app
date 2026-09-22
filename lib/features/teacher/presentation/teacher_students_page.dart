import 'package:flutter/material.dart';

import '../data/teacher_students_demo_data.dart';
import '../data/teacher_students_repository.dart';
import '../domain/teacher_students_models.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherStudentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  late Future<TeacherStudentsSnapshot> _future;
  final _noteController = TextEditingController();
  String _query = '';
  String _classFilter = 'All classes';
  String _riskFilter = 'All statuses';
  String _selectedId = teacherStudents.first.id;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<TeacherStudentSummary> _filtered(TeacherStudentsSnapshot snapshot) {
    return snapshot.students.where((student) {
      final classMatches =
          _classFilter == 'All classes' || student.className == _classFilter;
      final riskMatches = _riskFilter == 'All statuses' ||
          teacherStudentRiskLabel(student.risk) == _riskFilter;
      return student.matches(_query) && classMatches && riskMatches;
    }).toList(growable: false);
  }

  void _selectStudent(
    TeacherStudentsSnapshot snapshot,
    TeacherStudentSummary student,
  ) {
    setState(() {
      _selectedId = student.id;
      _notice = null;
      _noteController.text = snapshot.notes[student.id]?.text ?? '';
    });
  }

  Future<void> _saveNote() async {
    final result = await widget.repository.saveNote(
      studentId: _selectedId,
      text: _noteController.text,
    );
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.success) _future = widget.repository.load();
    });
    if (result.success) widget.onMutationQueued();
  }

  Future<void> _showProfile(
    TeacherStudentsSnapshot snapshot,
    TeacherStudentSummary student,
  ) async {
    final profile = snapshot.profiles[student.id];
    if (profile == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (context, controller) => _TeacherStudentProfileSheet(
          profile: profile,
          controller: controller,
          onNavigate: (key) {
            Navigator.of(context).pop();
            widget.onNavigate(key);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherStudentsSnapshot>(
      future: _future,
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (asyncSnapshot.hasError || !asyncSnapshot.hasData) {
          return _ErrorState(onRetry: () {
            setState(() => _future = widget.repository.load());
          });
        }

        final snapshot = asyncSnapshot.data!;
        final filtered = _filtered(snapshot);
        final selected = snapshot.students.firstWhere(
          (student) => student.id == _selectedId,
          orElse: () => filtered.isNotEmpty ? filtered.first : snapshot.students.first,
        );
        final selectedNote = snapshot.notes[selected.id];
        if (_selectedId != selected.id) {
          _selectedId = selected.id;
          _noteController.text = selectedNote?.text ?? '';
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Header(onNavigate: widget.onNavigate),
            const SizedBox(height: 18),
            _Kpis(),
            const SizedBox(height: 18),
            _DirectoryPanel(
              snapshot: snapshot,
              filtered: filtered,
              selected: selected,
              query: _query,
              classFilter: _classFilter,
              riskFilter: _riskFilter,
              noteController: _noteController,
              notice: _notice,
              noticeSuccess: _noticeSuccess,
              onQueryChanged: (value) => setState(() => _query = value),
              onClassChanged: (value) {
                if (value == null) return;
                setState(() => _classFilter = value);
              },
              onRiskChanged: (value) {
                if (value == null) return;
                setState(() => _riskFilter = value);
              },
              onSelected: (student) => _selectStudent(snapshot, student),
              onProfile: (student) => _showProfile(snapshot, student),
              onSaveNote: _saveNote,
              onNavigate: widget.onNavigate,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final cards = <Widget>[
                  _InfoCard(
                    title: 'Teacher AI student insight',
                    body: teacherStudentAiInsight,
                    actionLabel: 'Ask Teacher AI',
                    onAction: () => widget.onNavigate('ai'),
                  ),
                  const _InfoCard(
                    title: 'Privacy boundary',
                    body: teacherStudentsPrivacyBoundary,
                  ),
                ];
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      cards[0],
                      const SizedBox(height: 12),
                      cards[1],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  teacherStudentsEvidenceBoundary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('classes'),
                child: const Text('My Classes'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('assessments'),
                child: const Text('Assessments'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('messages'),
                child: const Text('Message'),
              ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEACHER PORTAL · ASSIGNED STUDENTS ONLY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Students',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Academic, attendance and intervention view limited to your assigned classes.',
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: copy), actions],
          );
        },
      );
}

class _Kpis extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 620
              ? constraints.maxWidth
              : constraints.maxWidth < 980
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final kpi in teacherStudentKpis)
                SizedBox(
                  width: width,
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kpi.$1),
                          const SizedBox(height: 6),
                          Text(
                            kpi.$2,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(kpi.$3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _DirectoryPanel extends StatelessWidget {
  const _DirectoryPanel({
    required this.snapshot,
    required this.filtered,
    required this.selected,
    required this.query,
    required this.classFilter,
    required this.riskFilter,
    required this.noteController,
    required this.notice,
    required this.noticeSuccess,
    required this.onQueryChanged,
    required this.onClassChanged,
    required this.onRiskChanged,
    required this.onSelected,
    required this.onProfile,
    required this.onSaveNote,
    required this.onNavigate,
  });

  final TeacherStudentsSnapshot snapshot;
  final List<TeacherStudentSummary> filtered;
  final TeacherStudentSummary selected;
  final String query;
  final String classFilter;
  final String riskFilter;
  final TextEditingController noteController;
  final String? notice;
  final bool noticeSuccess;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onRiskChanged;
  final ValueChanged<TeacherStudentSummary> onSelected;
  final ValueChanged<TeacherStudentSummary> onProfile;
  final VoidCallback onSaveNote;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My student roster',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Only students linked to your current teaching assignments are visible. Open a full profile for deeper teacher-visible context.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search student or ID...',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: onQueryChanged,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                    isExpanded: true,
                      initialValue: classFilter,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        'All classes',
                        'JSS 2A',
                        'JSS 2B',
                        'JSS 3A',
                        'SS 1A',
                      ]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(growable: false),
                      onChanged: onClassChanged,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                    isExpanded: true,
                      initialValue: riskFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        'All statuses',
                        'Strong',
                        'Stable',
                        'Watch',
                        'At risk',
                      ]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(growable: false),
                      onChanged: onRiskChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final roster = _Roster(
                    students: filtered,
                    selectedId: selected.id,
                    onSelected: onSelected,
                    onProfile: onProfile,
                  );
                  final profile = _SelectedStudentCard(
                    student: selected,
                    noteController: noteController,
                    savedNote: snapshot.notes[selected.id],
                    notice: notice,
                    noticeSuccess: noticeSuccess,
                    onProfile: () => onProfile(selected),
                    onSaveNote: onSaveNote,
                    onNavigate: onNavigate,
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(
                      children: [roster, const SizedBox(height: 14), profile],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: roster),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: profile),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _Roster extends StatelessWidget {
  const _Roster({
    required this.students,
    required this.selectedId,
    required this.onSelected,
    required this.onProfile,
  });

  final List<TeacherStudentSummary> students;
  final String selectedId;
  final ValueChanged<TeacherStudentSummary> onSelected;
  final ValueChanged<TeacherStudentSummary> onProfile;

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No assigned students match these filters.')),
      );
    }
    return Column(
      children: [
        for (final student in students)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    selected: student.id == selectedId,
                    selectedTileColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: CircleAvatar(
                      child: Text(student.name.characters.first),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${student.id} · ${student.className}\nAvg ${student.average}% · Attendance ${student.attendance}%',
                    ),
                    isThreeLine: true,
                    trailing: Chip(label: Text(teacherStudentRiskLabel(student.risk))),
                    onTap: () => onSelected(student),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => onProfile(student),
                  child: const Text('Profile'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SelectedStudentCard extends StatelessWidget {
  const _SelectedStudentCard({
    required this.student,
    required this.noteController,
    required this.savedNote,
    required this.notice,
    required this.noticeSuccess,
    required this.onProfile,
    required this.onSaveNote,
    required this.onNavigate,
  });

  final TeacherStudentSummary student;
  final TextEditingController noteController;
  final TeacherStudentNote? savedNote;
  final String? notice;
  final bool noticeSuccess;
  final VoidCallback onProfile;
  final VoidCallback onSaveNote;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(student.id, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(
                student.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text('${student.className} · Mathematics'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniMetric(label: 'Average', value: '${student.average}%'),
                  _MiniMetric(label: 'Attendance', value: '${student.attendance}%'),
                  _MiniMetric(
                    label: 'Trend',
                    value: '${student.trend > 0 ? '+' : ''}${student.trend.toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Current intervention',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                student.intervention,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                onPressed: onProfile,
                child: const Text('Open full student profile'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onNavigate('assessments'),
                child: const Text('Assessment history'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onNavigate('attendance'),
                child: const Text('Attendance history'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onNavigate('messages'),
                child: const Text('Contact channel'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Teacher note',
                  hintText: 'Add a professional teaching/intervention note...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onSaveNote,
                child: Text(savedNote == null ? 'Save note' : 'Update note'),
              ),
              if (notice != null) ...[
                const SizedBox(height: 8),
                Text(
                  notice!,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: noticeSuccess
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                teacherStudentNoteBoundary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _TeacherStudentProfileSheet extends StatelessWidget {
  const _TeacherStudentProfileSheet({
    required this.profile,
    required this.controller,
    required this.onNavigate,
  });

  final TeacherStudentProfile profile;
  final ScrollController controller;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          Text(
            profile.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text('${profile.className} · ${profile.status}'),
          if (profile.admissionNo.isNotEmpty) Text(profile.admissionNo),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniMetric(label: 'Average', value: '${profile.average}%'),
              _MiniMetric(label: 'Attendance', value: '${profile.attendance}%'),
              _MiniMetric(
                label: 'Trend',
                value: '${profile.trend > 0 ? '+' : ''}${profile.trend.toStringAsFixed(1)}%',
              ),
              _MiniMetric(label: 'Class teacher', value: profile.classTeacher),
            ],
          ),
          const SizedBox(height: 18),
          Text('Current attention', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(profile.attention),
          if (profile.subjects.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Academic evidence', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final subject in profile.subjects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(subject.name),
                trailing: Text(
                  '${subject.score}% · ${subject.trend > 0 ? '+' : ''}${subject.trend.toStringAsFixed(1)}%',
                ),
              ),
          ],
          if (profile.attendanceSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Attendance context', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in profile.attendanceSummary)
                  _MiniMetric(label: item.label, value: item.value),
              ],
            ),
          ],
          if (profile.timeline.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Teacher-visible timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in profile.timeline)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text('${item.date} · ${item.title}'),
                subtitle: Text('${item.detail}\nVisibility: ${item.visibility}'),
                isThreeLine: true,
              ),
          ] else ...[
            const SizedBox(height: 18),
            const Text(
              'This demo learner has directory-level teacher context only. No confidential profile fields are invented or cached.',
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('learning-progress'),
                child: const Text('Learning Progress'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('assessments'),
                child: const Text('Assessments'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('attendance'),
                child: const Text('Attendance'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('messages'),
                child: const Text('Contact channel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            teacherStudentsPrivacyBoundary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(body),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
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
            const Text('Unable to load assigned students.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
