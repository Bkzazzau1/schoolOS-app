import 'package:flutter/material.dart';

import '../data/administrator_academics_repository.dart';
import '../data/administrator_curriculum_repository.dart';
import '../data/administrator_students_repository.dart';
import '../domain/administrator_academics_models.dart';
import '../domain/administrator_curriculum_models.dart';
import '../domain/administrator_students_models.dart';

class AdministratorCurriculumPage extends StatefulWidget {
  const AdministratorCurriculumPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.academics,
    required this.students,
    required this.onChanged,
  });

  final String schoolName;
  final AdministratorCurriculumRepository repository;
  final AdministratorAcademicsRepository academics;
  final AdministratorStudentsRepository students;
  final VoidCallback onChanged;

  @override
  State<AdministratorCurriculumPage> createState() =>
      _AdministratorCurriculumPageState();
}

class _AdministratorCurriculumPageState
    extends State<AdministratorCurriculumPage> {
  bool _loading = true;
  String? _error;
  AdministratorCurriculumSnapshot? _curriculum;
  AdministratorAcademicsSnapshot? _academics;
  List<AdministratorStudentRecord> _students = const [];
  String? _sessionId;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final curriculum = await widget.repository.load();
      final academics = await widget.academics.load();
      final students = (await widget.students.load()).students;
      if (!mounted) return;
      setState(() {
        _curriculum = curriculum;
        _academics = academics;
        _students = students;
        _sessionId = academics.sessions.any((item) => item.id == _sessionId)
            ? _sessionId
            : academics.activeSession?.id ?? academics.sessions.firstOrNull?.id;
        _classId = academics.classes.any((item) => item.id == _classId)
            ? _classId
            : academics.classes.where((item) => item.isActive).firstOrNull?.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveSubject([AdministratorSubject? existing]) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(text: existing?.description ?? '');
    var active = existing?.isActive ?? true;
    final result = await showDialog<AdministratorSubject>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New subject' : 'Edit subject'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Subject code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Subject name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active subject'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: code.text.trim().isEmpty || name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        AdministratorSubject(
                          id: existing?.id ?? AdministratorAcademicsRepository.newId(),
                          code: code.text.trim().toUpperCase(),
                          name: name.text.trim(),
                          description: description.text.trim(),
                          isActive: active,
                          pendingSync: true,
                        ),
                      ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await widget.repository.saveSubject(result);
    widget.onChanged();
    await _load();
    _say('Subject saved locally and queued for server validation.');
  }

  Future<void> _addClassSubject() async {
    final curriculum = _curriculum;
    final academics = _academics;
    if (curriculum == null || academics == null) return;
    final sessions = academics.sessions.where((item) => !item.isClosed).toList();
    final classes = academics.classes.where((item) => item.isActive).toList();
    final subjects = curriculum.subjects.where((item) => item.isActive).toList();
    if (sessions.isEmpty || classes.isEmpty || subjects.isEmpty) {
      _say('Configure an open academic session, an active class and at least one active subject first.');
      return;
    }
    var sessionId = _sessionId ?? sessions.first.id;
    var classId = _classId ?? classes.first.id;
    var subjectId = subjects.first.id;
    var requirement = 'compulsory';
    var periods = 4;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add subject to class curriculum'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: sessionId,
                  decoration: const InputDecoration(labelText: 'Academic session'),
                  items: [
                    for (final item in sessions)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) => setDialogState(() => sessionId = value ?? sessionId),
                ),
                DropdownButtonFormField<String>(
                  initialValue: classId,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: [
                    for (final item in classes)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) => setDialogState(() => classId = value ?? classId),
                ),
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [
                    for (final item in subjects)
                      DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.code}')),
                  ],
                  onChanged: (value) => setDialogState(() => subjectId = value ?? subjectId),
                ),
                DropdownButtonFormField<String>(
                  initialValue: requirement,
                  decoration: const InputDecoration(labelText: 'Requirement'),
                  items: const [
                    DropdownMenuItem(value: 'compulsory', child: Text('Compulsory')),
                    DropdownMenuItem(value: 'elective', child: Text('Elective')),
                  ],
                  onChanged: (value) => setDialogState(() => requirement = value ?? requirement),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Periods per week')),
                    DropdownButton<int>(
                      value: periods,
                      items: [
                        for (var value = 1; value <= 12; value++)
                          DropdownMenuItem(value: value, child: Text('$value')),
                      ],
                      onChanged: (value) => setDialogState(() => periods = value ?? periods),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final academicClass = classes.firstWhere((item) => item.id == classId);
    final subject = subjects.firstWhere((item) => item.id == subjectId);
    if (curriculum.classSubjects.any(
      (item) =>
          item.sessionId == sessionId &&
          item.classId == classId &&
          item.subjectId == subjectId &&
          item.isActive,
    )) {
      _say('${academicClass.name} already offers ${subject.name} in this session.');
      return;
    }
    await widget.repository.saveClassSubject(
      AdministratorClassSubject(
        id: AdministratorAcademicsRepository.newId(),
        sessionId: sessionId,
        classId: classId,
        className: academicClass.name,
        subjectId: subjectId,
        subjectCode: subject.code,
        subjectName: subject.name,
        requirement: requirement,
        periodsPerWeek: periods,
        isActive: true,
        pendingSync: true,
      ),
    );
    widget.onChanged();
    await _load();
    _say('Class curriculum change queued. Student eligibility changes only after server acceptance.');
  }

  Future<void> _manageElective(AdministratorClassSubject offering) async {
    final curriculum = _curriculum;
    if (curriculum == null || !offering.elective) return;
    final eligible = _students
        .where(
          (student) =>
              student.status == AdministratorStudentStatus.active &&
              student.className.trim().toLowerCase() ==
                  offering.className.trim().toLowerCase(),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final values = <String, bool>{
      for (final student in eligible)
        student.id: curriculum.isSelected(student.id, offering.id),
    };
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${offering.className} · ${offering.subjectName}'),
          content: SizedBox(
            width: 600,
            height: 480,
            child: eligible.isEmpty
                ? const Center(child: Text('No active pupils are currently in this class.'))
                : ListView(
                    children: [
                      const Text('Select only pupils taking this elective. Compulsory subjects never need individual selection.'),
                      const SizedBox(height: 10),
                      for (final student in eligible)
                        CheckboxListTile(
                          value: values[student.id] ?? false,
                          title: Text(student.name),
                          subtitle: Text(student.id),
                          onChanged: (value) => setDialogState(
                            () => values[student.id] = value ?? false,
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save selections')),
          ],
        ),
      ),
    );
    if (save != true) return;
    for (final student in eligible) {
      final selected = values[student.id] ?? false;
      final current = curriculum.isSelected(student.id, offering.id);
      if (selected == current) continue;
      await widget.repository.setElective(
        studentId: student.id,
        classSubjectId: offering.id,
        selected: selected,
      );
    }
    widget.onChanged();
    await _load();
    _say('Elective selections queued for server validation.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final curriculum = _curriculum!;
    final academics = _academics!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'ADMINISTRATION · SUBJECTS & CURRICULUM',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Subjects & Class Curriculum',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text('Canonical subject eligibility for ${widget.schoolName}. Class progression automatically moves pupils onto the destination class curriculum.'),
          const SizedBox(height: 18),
          _SectionCard(
            title: 'Subject catalog',
            action: FilledButton.tonalIcon(
              onPressed: () => _saveSubject(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New subject'),
            ),
            child: curriculum.subjects.isEmpty
                ? const Text('No subjects configured yet.')
                : Column(
                    children: [
                      for (final subject in curriculum.subjects)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${subject.code}${subject.pendingSync ? ' · Queued' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!subject.isActive) const Chip(label: Text('Inactive')),
                              IconButton(onPressed: () => _saveSubject(subject), icon: const Icon(Icons.edit_outlined)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Class curriculum',
            action: FilledButton.tonalIcon(
              onPressed: _addClassSubject,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Add class subject'),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    DropdownButton<String>(
                      value: _sessionId,
                      hint: const Text('Session'),
                      items: [
                        for (final item in academics.sessions)
                          DropdownMenuItem(value: item.id, child: Text(item.name)),
                      ],
                      onChanged: (value) => setState(() => _sessionId = value),
                    ),
                    DropdownButton<String>(
                      value: _classId,
                      hint: const Text('Class'),
                      items: [
                        for (final item in academics.classes.where((item) => item.isActive))
                          DropdownMenuItem(value: item.id, child: Text(item.name)),
                      ],
                      onChanged: (value) => setState(() => _classId = value),
                    ),
                  ],
                ),
                const Divider(),
                ...[
                  for (final offering in curriculum.classSubjects.where(
                    (item) =>
                        (_sessionId == null || item.sessionId == _sessionId) &&
                        (_classId == null || item.classId == _classId),
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(offering.subjectName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${offering.className} · ${offering.requirement} · ${offering.periodsPerWeek} periods/week${offering.pendingSync ? ' · Queued' : ''}'),
                      trailing: offering.elective
                          ? TextButton.icon(
                              onPressed: () => _manageElective(offering),
                              icon: const Icon(Icons.people_outline_rounded),
                              label: const Text('Pupils'),
                            )
                          : const Chip(label: Text('Automatic')),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Authority rule: compulsory subjects are inherited automatically from the pupil’s canonical class. Electives require an explicit pupil selection. A promotion/repeat creates a new enrollment context; eligibility is then recalculated from the destination session/class rather than copied from the old class.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
