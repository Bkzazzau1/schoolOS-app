import 'package:flutter/material.dart';

import '../data/principal_teachers_demo_data.dart';
import '../data/principal_teachers_repository.dart';
import '../domain/principal_teachers_models.dart';
import 'principal_teacher_profile_page.dart';

class PrincipalTeachersPage extends StatefulWidget {
  const PrincipalTeachersPage({
    super.key,
    required this.repository,
    required this.onActionRequested,
    required this.onQueuedForSync,
  });

  final PrincipalTeachersRepository repository;
  final ValueChanged<String> onActionRequested;
  final VoidCallback onQueuedForSync;

  @override
  State<PrincipalTeachersPage> createState() => _PrincipalTeachersPageState();
}

class _PrincipalTeachersPageState extends State<PrincipalTeachersPage> {
  final _queryController = TextEditingController();
  final _noteController = TextEditingController();
  PrincipalTeachersSnapshot? _snapshot;
  String _department = 'All departments';
  String _status = 'All statuses';
  String _selectedId = 'TCH-001';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final selectedId = snapshot.teachers.any((t) => t.id == _selectedId)
          ? _selectedId
          : snapshot.teachers.first.id;
      setState(() {
        _snapshot = snapshot;
        _selectedId = selectedId;
        _noteController.text = snapshot.notes[selectedId]?.text ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _selectTeacher(String id) {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    setState(() {
      _selectedId = id;
      _noteController.text = snapshot.notes[id]?.text ?? '';
    });
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    final result = await widget.repository.savePrivateNote(
      teacherId: _selectedId,
      text: _noteController.text,
    );
    if (!mounted) return;
    if (result.success) widget.onQueuedForSync();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) await _load();
  }

  Future<void> _openProfile(PrincipalTeacherProfile profile) async {
    final note = _snapshot?.notes[profile.directoryId]?.text ?? '';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrincipalTeacherProfilePage(
          profile: profile,
          repository: widget.repository,
          initialNote: note,
          onActionRequested: widget.onActionRequested,
          onQueuedForSync: widget.onQueuedForSync,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text('Unable to load Secondary teacher oversight.\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]),
        ),
      );
    }

    final snapshot = _snapshot!;
    final selected = snapshot.teachers.firstWhere((t) => t.id == _selectedId);
    final profile = snapshot.profiles.firstWhere((p) => p.directoryId == _selectedId);
    final filtered = snapshot.teachers
        .where((t) => t.matches(query: _queryController.text, departmentFilter: _department, statusFilter: _status))
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onActionRequested: widget.onActionRequested),
        const SizedBox(height: 16),
        const _Kpis(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1050;
            final directory = _Directory(
              teachers: filtered,
              selectedId: _selectedId,
              queryController: _queryController,
              department: _department,
              status: _status,
              onQueryChanged: (_) => setState(() {}),
              onDepartmentChanged: (value) => setState(() => _department = value),
              onStatusChanged: (value) => setState(() => _status = value),
              onSelectTeacher: _selectTeacher,
              onOpenProfile: (id) {
                final p = snapshot.profiles.firstWhere((x) => x.directoryId == id);
                _openProfile(p);
              },
            );
            final detail = _TeacherDetail(
              teacher: selected,
              noteController: _noteController,
              saving: _saving,
              onSaveNote: _saveNote,
              onOpenProfile: () => _openProfile(profile),
              onActionRequested: widget.onActionRequested,
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(flex: 3, child: directory), const SizedBox(width: 16), Expanded(flex: 2, child: detail)],
                  )
                : Column(children: [directory, const SizedBox(height: 16), detail]);
          },
        ),
        const SizedBox(height: 16),
        const _Guidance(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onActionRequested});
  final ValueChanged<String> onActionRequested;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 620,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRINCIPAL · SECONDARY SCHOOL · TEACHER OVERSIGHT', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text('Teachers', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Text('Monitor workload, attendance, teaching compliance and support needs inside the Secondary School section.'),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onActionRequested('assignments'), child: const Text('Teaching Assignments')),
            OutlinedButton(onPressed: () => onActionRequested('approvals'), child: const Text('Approvals')),
            OutlinedButton(onPressed: () => onActionRequested('academics'), child: const Text('Academics')),
            TextButton(onPressed: () => onActionRequested('dashboard'), child: const Text('Dashboard')),
          ]),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis();
  @override
  Widget build(BuildContext context) {
    final hints = <String, String>{
      'Secondary teaching staff': 'Current section',
      'Staff attendance': 'Current prototype average',
      'Needs support': 'Flagged for follow-up',
      'Pending teacher work': 'Awaiting review/action',
      'Lesson-plan compliance': 'Secondary section',
      'Assessment completion': 'Secondary section',
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in principalTeacherKpis.entries)
          SizedBox(
            width: 190,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
                  Text(entry.value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  Text(hints[entry.key]!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory({
    required this.teachers,
    required this.selectedId,
    required this.queryController,
    required this.department,
    required this.status,
    required this.onQueryChanged,
    required this.onDepartmentChanged,
    required this.onStatusChanged,
    required this.onSelectTeacher,
    required this.onOpenProfile,
  });

  final List<PrincipalTeacher> teachers;
  final String selectedId;
  final TextEditingController queryController;
  final String department;
  final String status;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onDepartmentChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSelectTeacher;
  final ValueChanged<String> onOpenProfile;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Secondary teacher directory', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const Text('Select a teacher for a quick review or open the complete staff profile.'),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: 260, child: TextField(controller: queryController, onChanged: onQueryChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search teacher or subject...'))),
              SizedBox(width: 200, child: DropdownButtonFormField<String>(initialValue: department, items: [for (final item in principalTeacherDepartments) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) { if (value != null) onDepartmentChanged(value); }, decoration: const InputDecoration(labelText: 'Department'))),
              SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: status, items: [for (final item in principalTeacherStatuses) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) { if (value != null) onStatusChanged(value); }, decoration: const InputDecoration(labelText: 'Status'))),
            ]),
            const SizedBox(height: 12),
            if (teachers.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No Secondary teachers match these filters.')))
            else
              for (final teacher in teachers)
                _TeacherRow(
                  teacher: teacher,
                  selected: teacher.id == selectedId,
                  onTap: () => onSelectTeacher(teacher.id),
                  onProfile: () => onOpenProfile(teacher.id),
                ),
          ]),
        ),
      );
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.teacher, required this.selected, required this.onTap, required this.onProfile});
  final PrincipalTeacher teacher;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer.withValues(alpha: .55) : null,
        border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final person = Row(children: [CircleAvatar(child: Text(teacher.initials)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text(teacher.subjects, style: Theme.of(context).textTheme.bodySmall)]))]);
            final stats = Wrap(spacing: 14, runSpacing: 6, children: [
              _MiniStat(label: 'Attendance', value: '${teacher.attendance}%'),
              _MiniStat(label: 'Lesson plans', value: '${teacher.lessonPlans}%'),
              _MiniStat(label: 'Syllabus', value: '${teacher.syllabus}%'),
              _MiniStat(label: 'Assessments', value: '${teacher.assessments}%'),
              Chip(label: Text(teacher.status)),
              OutlinedButton(onPressed: onProfile, child: const Text('Profile')),
            ]);
            return compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [person, const SizedBox(height: 8), Text(teacher.department, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6), stats])
                : Row(children: [Expanded(flex: 2, child: person), SizedBox(width: 110, child: Text(teacher.department)), Expanded(flex: 3, child: stats)]);
          }),
        ),
      ),
    );
  }
}

class _TeacherDetail extends StatelessWidget {
  const _TeacherDetail({
    required this.teacher,
    required this.noteController,
    required this.saving,
    required this.onSaveNote,
    required this.onOpenProfile,
    required this.onActionRequested,
  });

  final PrincipalTeacher teacher;
  final TextEditingController noteController;
  final bool saving;
  final VoidCallback onSaveNote;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onActionRequested;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [CircleAvatar(radius: 28, child: Text(teacher.initials)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(teacher.id, style: Theme.of(context).textTheme.bodySmall), Text(teacher.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text('${teacher.department} · ${teacher.subjects}')]))]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _Summary(label: 'Assigned classes', value: '${teacher.classes}'),
              _Summary(label: 'Students', value: '${teacher.students}'),
              _Summary(label: 'Workload', value: teacher.workload),
              _Summary(label: 'Pending work', value: '${teacher.pending}'),
            ]),
            const SizedBox(height: 14),
            _Progress(label: 'Attendance', value: teacher.attendance),
            _Progress(label: 'Punctuality', value: teacher.punctuality),
            _Progress(label: 'Lesson-plan compliance', value: teacher.lessonPlans),
            _Progress(label: 'Syllabus pace', value: teacher.syllabus),
            _Progress(label: 'Assessment completion', value: teacher.assessments),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Current principal insight', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(teacher.note)])),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: onOpenProfile, icon: const Icon(Icons.badge_outlined), label: const Text('Open full staff profile')),
              OutlinedButton(onPressed: () => onActionRequested('assignments'), child: const Text('Manage teaching assignments')),
              OutlinedButton(onPressed: () => onActionRequested('approvals'), child: const Text('Review submitted work')),
              OutlinedButton(onPressed: () => onActionRequested('communication'), child: const Text('Message teacher')),
            ]),
            const SizedBox(height: 14),
            TextField(controller: noteController, minLines: 4, maxLines: 6, decoration: const InputDecoration(labelText: 'Private principal note', hintText: 'Add support, observation or follow-up note...')),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: saving ? null : onSaveNote, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving...' : 'Save note')),
          ]),
        ),
      );
}

class _Guidance extends StatelessWidget {
  const _Guidance();
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Principal guidance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final entry in principalTeacherGuidance.entries)
                SizedBox(width: 320, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700))]))),
            ]),
          ]),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelSmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]);
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(width: 120, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelSmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])));
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(children: [Row(children: [Expanded(child: Text(label)), Text('$value%', style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 4), LinearProgressIndicator(value: value / 100)]));
}
