import 'package:flutter/material.dart';

import '../data/administrator_academics_repository.dart';
import '../domain/administrator_academics_models.dart';

class AdministratorSubjectsCurriculumPage extends StatefulWidget {
  const AdministratorSubjectsCurriculumPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onChanged,
  });

  final String schoolName;
  final AdministratorAcademicsRepository repository;
  final VoidCallback onChanged;

  @override
  State<AdministratorSubjectsCurriculumPage> createState() =>
      _AdministratorSubjectsCurriculumPageState();
}

class _AdministratorSubjectsCurriculumPageState
    extends State<AdministratorSubjectsCurriculumPage> {
  AdministratorAcademicsSnapshot? _snapshot;
  String? _error;
  String? _sessionId;
  String? _classId;
  String? _classSubjectId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final activeSession = snapshot.activeSession;
      final nextSessionId = snapshot.sessions.any((item) => item.id == _sessionId)
          ? _sessionId
          : activeSession?.id ?? snapshot.sessions.firstOrNull?.id;
      final activeClasses = snapshot.classes.where((item) => item.isActive).toList();
      final nextClassId = activeClasses.any((item) => item.id == _classId)
          ? _classId
          : activeClasses.firstOrNull?.id;
      setState(() {
        _snapshot = snapshot;
        _sessionId = nextSessionId;
        _classId = nextClassId;
        _error = null;
        if (!snapshot.classSubjects.any((item) => item.id == _classSubjectId)) {
          _classSubjectId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  AdministratorAcademicClass? _selectedClass(AdministratorAcademicsSnapshot snapshot) =>
      snapshot.classes.where((item) => item.id == _classId).firstOrNull;

  List<AdministratorClassSubject> _classCurriculum(AdministratorAcademicsSnapshot snapshot) {
    final sessionId = _sessionId;
    final classId = _classId;
    if (sessionId == null || classId == null) return const [];
    return snapshot.subjectsForClass(sessionId, classId);
  }

  Future<void> _addSubject() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final shortName = TextEditingController();
    String section = _selectedClass(_snapshot!)?.section ?? '';
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New subject'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Subject name')),
                const SizedBox(height: 10),
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Subject code')),
                const SizedBox(height: 10),
                TextField(controller: shortName, decoration: const InputDecoration(labelText: 'Short name (optional)')),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(labelText: 'Section (optional)', hintText: 'Primary, Secondary, or leave blank for all'),
                  controller: TextEditingController(text: section),
                  onChanged: (value) => setDialogState(() => section = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save subject')),
          ],
        ),
      ),
    );
    if (save != true) return;
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
      _say('Subject name and code are required.');
      return;
    }
    await widget.repository.saveSubject(
      AdministratorSubject(
        id: AdministratorAcademicsRepository.newId(),
        code: code.text.trim().toUpperCase(),
        name: name.text.trim(),
        shortName: shortName.text.trim(),
        section: section.trim(),
        isActive: true,
      ),
    );
    widget.onChanged();
    await _load();
    _say('Subject saved locally and queued for server validation.');
  }

  Future<void> _addClassSubject() async {
    final snapshot = _snapshot!;
    final sessionId = _sessionId;
    final academicClass = _selectedClass(snapshot);
    if (sessionId == null || academicClass == null) {
      _say('Choose an academic session and class first.');
      return;
    }
    final existing = _classCurriculum(snapshot).map((item) => item.subjectId).toSet();
    final available = snapshot.subjects.where((subject) {
      if (!subject.isActive || existing.contains(subject.id)) return false;
      return subject.section.trim().isEmpty ||
          subject.section.trim().toLowerCase() == academicClass.section.trim().toLowerCase();
    }).toList();
    if (available.isEmpty) {
      _say('No unused active subjects match this class. Add a subject first.');
      return;
    }
    String subjectId = available.first.id;
    String requirement = 'compulsory';
    int periods = 5;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add subject to ${academicClass.name}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: [for (final item in available) DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.code}'))],
                  onChanged: (value) => setDialogState(() => subjectId = value ?? subjectId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: requirement,
                  decoration: const InputDecoration(labelText: 'Requirement'),
                  items: const [
                    DropdownMenuItem(value: 'compulsory', child: Text('Compulsory')),
                    DropdownMenuItem(value: 'elective', child: Text('Elective')),
                  ],
                  onChanged: (value) => setDialogState(() => requirement = value ?? requirement),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: periods,
                  decoration: const InputDecoration(labelText: 'Periods per week'),
                  items: [for (var value = 1; value <= 15; value++) DropdownMenuItem(value: value, child: Text('$value'))],
                  onChanged: (value) => setDialogState(() => periods = value ?? periods),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add to curriculum')),
          ],
        ),
      ),
    );
    if (save != true) return;
    await widget.repository.saveClassSubject(
      AdministratorClassSubject(
        id: AdministratorAcademicsRepository.newId(),
        sessionId: sessionId,
        classId: academicClass.id,
        subjectId: subjectId,
        requirement: requirement,
        periodsPerWeek: periods,
        isActive: true,
      ),
    );
    widget.onChanged();
    await _load();
    _say('Class curriculum updated locally and queued for server validation.');
  }

  Future<void> _addTopic() async {
    final snapshot = _snapshot!;
    final classSubject = snapshot.classSubjects.where((item) => item.id == _classSubjectId).firstOrNull;
    if (classSubject == null) {
      _say('Select a class subject first.');
      return;
    }
    final terms = snapshot.terms.where((item) => item.sessionId == classSubject.sessionId && item.status != 'closed').toList();
    if (terms.isEmpty) {
      _say('This session has no open term available for curriculum topics.');
      return;
    }
    String termId = terms.first.id;
    final existing = snapshot.topics.where((item) => item.classSubjectId == classSubject.id && item.termId == termId).toList();
    int sequence = existing.isEmpty ? 1 : existing.map((item) => item.sequence).reduce((a, b) => a > b ? a : b) + 1;
    final title = TextEditingController();
    final description = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add topic · ${classSubject.subject}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: termId,
                  decoration: const InputDecoration(labelText: 'Term'),
                  items: [for (final term in terms) DropdownMenuItem(value: term.id, child: Text(term.name))],
                  onChanged: (value) => setDialogState(() => termId = value ?? termId),
                ),
                const SizedBox(height: 10),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Topic title')),
                const SizedBox(height: 10),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / learning focus')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add topic')),
          ],
        ),
      ),
    );
    if (save != true || title.text.trim().isEmpty) return;
    final termTopics = snapshot.topics.where((item) => item.classSubjectId == classSubject.id && item.termId == termId).toList();
    sequence = termTopics.isEmpty ? 1 : termTopics.map((item) => item.sequence).reduce((a, b) => a > b ? a : b) + 1;
    await widget.repository.saveCurriculumTopic(
      AdministratorCurriculumTopic(
        id: AdministratorAcademicsRepository.newId(),
        classSubjectId: classSubject.id,
        termId: termId,
        sequence: sequence,
        title: title.text.trim(),
        description: description.text.trim(),
      ),
    );
    widget.onChanged();
    await _load();
    _say('Curriculum topic saved locally and queued for server validation.');
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());
    final academicClass = _selectedClass(snapshot);
    final curriculum = _classCurriculum(snapshot);
    final selectedClassSubject = curriculum.where((item) => item.id == _classSubjectId).firstOrNull;
    final topics = selectedClassSubject == null
        ? const <AdministratorCurriculumTopic>[]
        : snapshot.topics.where((item) => item.classSubjectId == selectedClassSubject.id).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return ListView(
          padding: EdgeInsets.all(compact ? 14 : 24),
          children: [
            Text('Subjects & Curriculum', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${widget.schoolName} · Canonical curriculum by academic session, class and term.'),
            const SizedBox(height: 8),
            const Text('Compulsory subjects are automatically eligible for every pupil in the class. Electives require an individual pupil selection. Weekly periods belong to the curriculum, not to a teacher assignment.'),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    initialValue: _sessionId,
                    decoration: const InputDecoration(labelText: 'Academic session'),
                    items: [for (final item in snapshot.sessions) DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.status}'))],
                    onChanged: (value) => setState(() {
                      _sessionId = value;
                      _classSubjectId = null;
                    }),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    initialValue: _classId,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: [for (final item in snapshot.classes.where((item) => item.isActive)) DropdownMenuItem(value: item.id, child: Text('${item.name} · ${item.section}'))],
                    onChanged: (value) => setState(() {
                      _classId = value;
                      _classSubjectId = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            compact
                ? Column(children: [_subjectsCard(snapshot), const SizedBox(height: 12), _curriculumCard(snapshot, academicClass, curriculum), const SizedBox(height: 12), _topicsCard(snapshot, selectedClassSubject, topics)])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _subjectsCard(snapshot)),
                    const SizedBox(width: 12),
                    Expanded(child: _curriculumCard(snapshot, academicClass, curriculum)),
                    const SizedBox(width: 12),
                    Expanded(child: _topicsCard(snapshot, selectedClassSubject, topics)),
                  ]),
          ],
        );
      },
    );
  }

  Widget _subjectsCard(AdministratorAcademicsSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Expanded(child: Text('Subject catalog', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(onPressed: _addSubject, tooltip: 'Add subject', icon: const Icon(Icons.add_rounded))]),
            const Text('One canonical list for the school. Section may be blank when a subject spans the whole school.'),
            const SizedBox(height: 10),
            if (snapshot.subjects.isEmpty) const Text('No subjects configured yet.'),
            for (final item in snapshot.subjects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.code}${item.section.isEmpty ? '' : ' · ${item.section}'}'),
                trailing: item.pendingSync ? const Chip(label: Text('Queued')) : (!item.isActive ? const Chip(label: Text('Inactive')) : null),
              ),
          ]),
        ),
      );

  Widget _curriculumCard(AdministratorAcademicsSnapshot snapshot, AdministratorAcademicClass? academicClass, List<AdministratorClassSubject> curriculum) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text(academicClass == null ? 'Class curriculum' : '${academicClass.name} curriculum', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(onPressed: _addClassSubject, tooltip: 'Add class subject', icon: const Icon(Icons.add_rounded))]),
            const Text('This is the subject eligibility and teaching requirement for the selected session.'),
            const SizedBox(height: 10),
            if (curriculum.isEmpty) const Text('No subjects assigned to this class for the selected session.'),
            for (final item in curriculum)
              ListTile(
                selected: _classSubjectId == item.id,
                onTap: () => setState(() => _classSubjectId = item.id),
                contentPadding: EdgeInsets.zero,
                title: Text(item.subject.isEmpty ? item.subjectId : item.subject, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.requirement == 'elective' ? 'Elective' : 'Compulsory'} · ${item.periodsPerWeek} periods/week'),
                trailing: item.pendingSync ? const Chip(label: Text('Queued')) : const Icon(Icons.chevron_right_rounded),
              ),
          ]),
        ),
      );

  Widget _topicsCard(AdministratorAcademicsSnapshot snapshot, AdministratorClassSubject? classSubject, List<AdministratorCurriculumTopic> topics) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text(classSubject == null ? 'Term topics' : '${classSubject.subject} topics', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), IconButton(onPressed: classSubject == null ? null : _addTopic, tooltip: 'Add term topic', icon: const Icon(Icons.add_rounded))]),
            const Text('Topics are tied to a term and become historical once that term closes.'),
            const SizedBox(height: 10),
            if (classSubject == null) const Text('Select a class subject to see its term topics.'),
            if (classSubject != null && topics.isEmpty) const Text('No topics configured yet.'),
            for (final item in topics)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('${item.sequence}')),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${snapshot.terms.where((term) => term.id == item.termId).firstOrNull?.name ?? 'Term'}${item.description.isEmpty ? '' : ' · ${item.description}'}'),
                trailing: item.pendingSync ? const Chip(label: Text('Queued')) : null,
              ),
          ]),
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
