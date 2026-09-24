import 'package:flutter/material.dart';

import '../data/administrator_academics_repository.dart';
import '../domain/administrator_academics_models.dart';

class AdministratorCurriculumPage extends StatefulWidget {
  const AdministratorCurriculumPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onChanged,
  });

  final String schoolName;
  final AdministratorAcademicsRepository repository;
  final VoidCallback onChanged;

  @override
  State<AdministratorCurriculumPage> createState() =>
      _AdministratorCurriculumPageState();
}

class _AdministratorCurriculumPageState
    extends State<AdministratorCurriculumPage> {
  AdministratorAcademicsSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  String? _sessionId;
  String? _classId;
  String? _classSubjectId;
  String? _termId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool preserve = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final oldSession = _sessionId;
      final oldClass = _classId;
      final oldClassSubject = _classSubjectId;
      final oldTerm = _termId;
      setState(() {
        _snapshot = snapshot;
        _sessionId = preserve && snapshot.sessions.any((e) => e.id == oldSession)
            ? oldSession
            : snapshot.activeSession?.id ?? snapshot.sessions.firstOrNull?.id;
        _classId = preserve && snapshot.classes.any((e) => e.id == oldClass)
            ? oldClass
            : snapshot.classes.where((e) => e.isActive).firstOrNull?.id;
        final available = _visibleClassSubjects(snapshot);
        _classSubjectId = preserve && available.any((e) => e.id == oldClassSubject)
            ? oldClassSubject
            : available.firstOrNull?.id;
        final sessionTerms = snapshot.terms
            .where((e) => e.sessionId == _sessionId)
            .toList(growable: false);
        _termId = preserve && sessionTerms.any((e) => e.id == oldTerm)
            ? oldTerm
            : snapshot.activeTermFor(_sessionId ?? '')?.id ??
                sessionTerms.firstOrNull?.id;
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

  List<AdministratorClassSubject> _visibleClassSubjects(
    AdministratorAcademicsSnapshot snapshot,
  ) {
    final sessionId = _sessionId ?? snapshot.activeSession?.id;
    final classId = _classId;
    if (sessionId == null || classId == null) return const [];
    return snapshot.classSubjects
        .where(
          (item) =>
              item.sessionId == sessionId &&
              item.classId == classId &&
              item.isActive,
        )
        .toList(growable: false);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(Future<void> Function() action, String message) async {
    try {
      await action();
      widget.onChanged();
      await _load();
      _say(message);
    } catch (error) {
      _say('$error');
    }
  }

  Future<void> _editSubject([AdministratorSubject? subject]) async {
    final code = TextEditingController(text: subject?.code ?? '');
    final name = TextEditingController(text: subject?.name ?? '');
    final shortName = TextEditingController(text: subject?.shortName ?? '');
    final section = TextEditingController(text: subject?.section ?? '');
    var active = subject?.isActive ?? true;

    final result = await showDialog<AdministratorSubject>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(subject == null ? 'New subject' : 'Edit subject'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Subject name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: code,
                          decoration: const InputDecoration(
                            labelText: 'Code',
                            hintText: 'MATH',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: shortName,
                          decoration: const InputDecoration(
                            labelText: 'Short name',
                            hintText: 'Maths',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: section,
                    decoration: const InputDecoration(
                      labelText: 'Section scope (optional)',
                      hintText: 'Secondary · leave blank for all sections',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active subject'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty || code.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        AdministratorSubject(
                          id: subject?.id ??
                              AdministratorAcademicsRepository.newId(),
                          code: code.text.trim().toUpperCase(),
                          name: name.text.trim(),
                          shortName: shortName.text.trim(),
                          section: section.text.trim(),
                          isActive: active,
                        ),
                      ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    shortName.dispose();
    section.dispose();
    if (result == null) return;
    await _save(
      () => widget.repository.saveSubject(result),
      'Subject saved offline and queued for server validation.',
    );
  }

  Future<void> _editClassSubject([AdministratorClassSubject? current]) async {
    final snapshot = _snapshot;
    final sessionId = _sessionId;
    final classId = _classId;
    if (snapshot == null || sessionId == null || classId == null) {
      _say('Choose an academic session and class first.');
      return;
    }
    final academicClass = snapshot.classes.where((e) => e.id == classId).firstOrNull;
    if (academicClass == null) return;
    final availableSubjects = snapshot.subjects
        .where(
          (s) =>
              s.isActive &&
              (s.section.trim().isEmpty ||
                  s.section.trim().toLowerCase() ==
                      academicClass.section.trim().toLowerCase()),
        )
        .toList(growable: false);
    if (availableSubjects.isEmpty) {
      _say('Create an active subject for ${academicClass.section} first.');
      return;
    }

    var subjectId = current?.subjectId ?? availableSubjects.first.id;
    var requirement = current?.requirement ?? 'compulsory';
    var periods = current?.periodsPerWeek ?? 4;
    var active = current?.isActive ?? true;

    final result = await showDialog<AdministratorClassSubject>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null
              ? 'Add subject to ${academicClass.name}'
              : 'Edit class curriculum'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final subject in availableSubjects)
                      DropdownMenuItem(
                        value: subject.id,
                        child: Text('${subject.name} · ${subject.code}'),
                      ),
                  ],
                  onChanged: current == null
                      ? (value) => setDialogState(
                            () => subjectId = value ?? subjectId,
                          )
                      : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: requirement,
                  decoration: const InputDecoration(
                    labelText: 'Requirement',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'compulsory',
                      child: Text('Compulsory'),
                    ),
                    DropdownMenuItem(
                      value: 'elective',
                      child: Text('Elective'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => requirement = value ?? requirement,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Periods per week')),
                    IconButton(
                      onPressed: periods > 1
                          ? () => setDialogState(() => periods--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$periods',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    IconButton(
                      onPressed: periods < 30
                          ? () => setDialogState(() => periods++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active in this session'),
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
              onPressed: () => Navigator.pop(
                dialogContext,
                AdministratorClassSubject(
                  id: current?.id ?? AdministratorAcademicsRepository.newId(),
                  sessionId: sessionId,
                  classId: classId,
                  subjectId: subjectId,
                  requirement: requirement,
                  periodsPerWeek: periods,
                  isActive: active,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _save(
      () => widget.repository.saveClassSubject(result),
      'Class curriculum saved offline and queued for server validation.',
    );
  }

  Future<void> _editTopic([AdministratorCurriculumTopic? current]) async {
    final classSubjectId = _classSubjectId;
    final termId = _termId;
    if (classSubjectId == null || termId == null) {
      _say('Choose a class subject and term first.');
      return;
    }
    final title = TextEditingController(text: current?.title ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    var sequence = current?.sequence ?? 1;

    final result = await showDialog<AdministratorCurriculumTopic>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(current == null ? 'New curriculum topic' : 'Edit topic'),
          content: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Topic title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description / learning scope',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Teaching sequence')),
                    IconButton(
                      onPressed: sequence > 1
                          ? () => setDialogState(() => sequence--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$sequence'),
                    IconButton(
                      onPressed: () => setDialogState(() => sequence++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
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
              onPressed: title.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        AdministratorCurriculumTopic(
                          id: current?.id ??
                              AdministratorAcademicsRepository.newId(),
                          classSubjectId: classSubjectId,
                          termId: termId,
                          sequence: sequence,
                          title: title.text.trim(),
                          description: description.text.trim(),
                        ),
                      ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (result == null) return;
    await _save(
      () => widget.repository.saveCurriculumTopic(result),
      'Curriculum topic saved offline and queued for server validation.',
    );
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
    final snapshot = _snapshot!;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final curriculum = _visibleClassSubjects(snapshot);
    if (!curriculum.any((e) => e.id == _classSubjectId)) {
      _classSubjectId = curriculum.firstOrNull?.id;
    }
    final topics = snapshot.topics
        .where(
          (item) =>
              item.classSubjectId == _classSubjectId && item.termId == _termId,
        )
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(wide ? 28 : 16),
        children: [
          Text(
            'ADMINISTRATION · ACADEMIC CURRICULUM',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Subjects & Curriculum',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Define the school subject catalog, what each class studies in each session, and the ordered topics for every term. · ${widget.schoolName}',
          ),
          const SizedBox(height: 18),
          _SubjectCatalogCard(
            subjects: snapshot.subjects,
            onAdd: () => _editSubject(),
            onEdit: _editSubject,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Class curriculum',
            subtitle:
                'A class-subject requirement is the authority for compulsory/elective status and periods per week. Teacher assignment comes later from the Principal workspace.',
            child: Column(
              children: [
                _filters(snapshot),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _sessionId == null || _classId == null
                        ? null
                        : () => _editClassSubject(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add class subject'),
                  ),
                ),
                const SizedBox(height: 8),
                if (curriculum.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No subjects assigned to this class/session yet.'),
                  )
                else
                  for (final item in curriculum)
                    ListTile(
                      selected: item.id == _classSubjectId,
                      onTap: () => setState(() => _classSubjectId = item.id),
                      leading: Icon(
                        item.compulsory
                            ? Icons.lock_outline_rounded
                            : Icons.tune_rounded,
                      ),
                      title: Text(
                        item.subject.isEmpty
                            ? _subjectName(snapshot, item.subjectId)
                            : item.subject,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${item.requirement == 'compulsory' ? 'Compulsory' : 'Elective'} · ${item.periodsPerWeek} periods/week',
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.pendingSync) const Chip(label: Text('Queued')),
                          if (!item.isActive) const Chip(label: Text('Inactive')),
                          IconButton(
                            tooltip: 'Edit curriculum requirement',
                            onPressed: () => _editClassSubject(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Term curriculum topics',
            subtitle:
                'Topics belong to a class-subject and a specific term. Closing a term freezes its curriculum history on the server.',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _termId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Term',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final term in snapshot.terms.where(
                      (item) => item.sessionId == _sessionId,
                    ))
                      DropdownMenuItem(
                        value: term.id,
                        child: Text('${term.name} · ${term.status}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _termId = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _classSubjectId == null || _termId == null
                        ? null
                        : () => _editTopic(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add topic'),
                  ),
                ),
                if (_classSubjectId == null)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Choose a class subject above to manage topics.'),
                  )
                else if (topics.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No topics recorded for this term yet.'),
                  )
                else
                  for (final item in topics)
                    ListTile(
                      leading: CircleAvatar(child: Text('${item.sequence}')),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: item.description.isEmpty
                          ? null
                          : Text(item.description),
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.pendingSync) const Chip(label: Text('Queued')),
                          IconButton(
                            onPressed: () => _editTopic(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'AUTHORITY RULE · Student subject access is derived from the canonical class curriculum. Compulsory subjects apply automatically. Electives require an explicit student selection. Promotion creates a new enrollment context, so a previous class elective is never silently carried into the next class.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(AdministratorAcademicsSnapshot snapshot) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _sessionId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academic session',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final session in snapshot.sessions)
                DropdownMenuItem(value: session.id, child: Text(session.name)),
            ],
            onChanged: (value) => setState(() {
              _sessionId = value;
              _classSubjectId = null;
              final terms = snapshot.terms.where((e) => e.sessionId == value);
              _termId = terms.where((e) => e.status == 'active').firstOrNull?.id ??
                  terms.firstOrNull?.id;
            }),
          ),
          DropdownButtonFormField<String>(
            initialValue: _classId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academic class',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final academicClass in snapshot.classes.where((e) => e.isActive))
                DropdownMenuItem(
                  value: academicClass.id,
                  child: Text('${academicClass.name} · ${academicClass.section}'),
                ),
            ],
            onChanged: (value) => setState(() {
              _classId = value;
              _classSubjectId = null;
            }),
          ),
        ];
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              fields.first,
              const SizedBox(height: 10),
              fields.last,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: fields.first),
            const SizedBox(width: 10),
            Expanded(child: fields.last),
          ],
        );
      },
    );
  }

  String _subjectName(AdministratorAcademicsSnapshot snapshot, String id) =>
      snapshot.subjects.where((e) => e.id == id).firstOrNull?.name ?? id;
}

class _SubjectCatalogCard extends StatelessWidget {
  const _SubjectCatalogCard({
    required this.subjects,
    required this.onAdd,
    required this.onEdit,
  });

  final List<AdministratorSubject> subjects;
  final VoidCallback onAdd;
  final ValueChanged<AdministratorSubject> onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Subject catalog',
      subtitle:
          'One canonical subject identity is reused across sessions and classes. Once used in curriculum history, its identity is frozen.',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New subject'),
            ),
          ),
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No subjects configured yet.'),
            )
          else
            for (final subject in subjects)
              ListTile(
                leading: CircleAvatar(
                  child: Text(subject.code.length > 3
                      ? subject.code.substring(0, 3)
                      : subject.code),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${subject.code}${subject.section.isEmpty ? ' · All sections' : ' · ${subject.section}'}',
                ),
                trailing: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (subject.pendingSync) const Chip(label: Text('Queued')),
                    if (!subject.isActive) const Chip(label: Text('Inactive')),
                    IconButton(
                      onPressed: () => onEdit(subject),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
