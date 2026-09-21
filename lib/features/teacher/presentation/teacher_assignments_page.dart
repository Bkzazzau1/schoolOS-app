import 'package:flutter/material.dart';

import '../data/teacher_assignment_demo_data.dart';
import '../data/teacher_assignment_repository.dart';
import '../domain/teacher_assignment_models.dart';

class TeacherAssignmentsPage extends StatefulWidget {
  const TeacherAssignmentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherAssignmentRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  late Future<TeacherAssignmentSnapshot> _future;
  TeacherAssignment? _draft;
  List<TeacherAssignment> _library = const [];
  String _query = '';
  String _selectedClass = 'All classes';
  String? _notice;
  bool _noticeSuccess = false;

  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _dueDate = TextEditingController();
  final _maximumScore = TextEditingController();
  TeacherAssignmentType _type = TeacherAssignmentType.homework;
  String _draftClass = teacherAssignmentClasses.first;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _dueDate.dispose();
    _maximumScore.dispose();
    super.dispose();
  }

  void _hydrate(TeacherAssignmentSnapshot snapshot) {
    if (_draft != null) return;
    _library = snapshot.assignments;
    _draft = snapshot.draft;
    _title.text = snapshot.draft.title;
    _instructions.text = snapshot.draft.instructions;
    _dueDate.text = snapshot.draft.dueDate;
    _maximumScore.text = '${snapshot.draft.maximumScore}';
    _draftClass = snapshot.draft.className;
    _type = snapshot.draft.type;
  }

  TeacherAssignment _editorDraft() {
    final current = _draft ?? teacherAssignmentDraft;
    return current.copyWith(
      title: _title.text.trim(),
      className: _draftClass,
      type: _type,
      instructions: _instructions.text.trim(),
      dueDate: _dueDate.text.trim(),
      maximumScore: int.tryParse(_maximumScore.text) ?? 0,
    );
  }

  Future<void> _saveDraft() async {
    final result = await widget.repository.saveDraft(_editorDraft());
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.assignment != null) _draft = result.assignment;
    });
    if (result.success) widget.onMutationQueued();
  }

  Future<void> _publish() async {
    final result = await widget.repository.queuePublication(_editorDraft());
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.assignment != null) _draft = result.assignment;
    });
    if (result.success) widget.onMutationQueued();
  }

  void _generateWithAi() {
    setState(() {
      _instructions.text = teacherAssignmentAiInstruction;
      _notice = 'Teacher AI draft inserted. Review and edit it before saving or publishing.';
      _noticeSuccess = true;
    });
  }

  List<TeacherAssignment> get _filtered => _library.where((assignment) {
        final classOk = _selectedClass == 'All classes' || assignment.className == _selectedClass;
        return classOk && assignment.matches(_query);
      }).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAssignmentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Unable to load assignments.'));
        }
        _hydrate(snapshot.data!);
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onNavigate: widget.onNavigate),
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _Notice(message: _notice!, success: _noticeSuccess),
                  ],
                  const SizedBox(height: 18),
                  _Kpis(wide: wide),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _editorCard()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _markingCard()),
                      ],
                    )
                  else ...[
                    _editorCard(),
                    const SizedBox(height: 16),
                    _markingCard(),
                  ],
                  const SizedBox(height: 18),
                  _libraryCard(wide),
                  const SizedBox(height: 18),
                  _boundaries(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _editorCard() {
    final editable = (_draft ?? teacherAssignmentDraft).teacherEditable;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create assignment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Prepare a new assignment for one of your assigned classes.'),
                    ],
                  ),
                ),
                Chip(label: Text(editable ? 'AI READY' : 'SYNC PENDING')),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
        isExpanded: true,
                    initialValue: _draftClass,
                    decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                    items: [for (final item in teacherAssignmentClasses) DropdownMenuItem(value: item, child: Text(item))],
                    onChanged: editable ? (value) => setState(() => _draftClass = value!) : null,
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<TeacherAssignmentType>(
        isExpanded: true,
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: [for (final item in teacherAssignmentTypes) DropdownMenuItem(value: item, child: Text(teacherAssignmentTypeLabel(item)))],
                    onChanged: editable ? (value) => setState(() => _type = value!) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _title, enabled: editable, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _instructions, enabled: editable, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: 210, child: TextField(controller: _dueDate, enabled: editable, decoration: const InputDecoration(labelText: 'Due date', border: OutlineInputBorder()))),
                SizedBox(width: 210, child: TextField(controller: _maximumScore, enabled: editable, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maximum score', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: editable ? _generateWithAi : null, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Generate with Teacher AI')),
                OutlinedButton.icon(onPressed: () => widget.onNavigate('messages'), icon: const Icon(Icons.share_outlined), label: const Text('Share assignment')),
                OutlinedButton(onPressed: editable ? _saveDraft : null, child: const Text('Save draft')),
                FilledButton(onPressed: editable ? _publish : null, child: const Text('Publish assignment')),
              ],
            ),
            if (!editable) ...[
              const SizedBox(height: 10),
              const Text('Queued for publication · sync pending. Student delivery is not yet confirmed.', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _markingCard() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(child: Text('Marking queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  Chip(label: Text('27 pending')),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Priority work waiting for feedback.'),
              const SizedBox(height: 12),
              for (final assignment in teacherAssignments) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${assignment.className} · ${assignment.unmarked == 0 ? 'marking complete' : '${assignment.unmarked} unmarked'}'),
                  trailing: assignment.unmarked == 0
                      ? const Chip(label: Text('Complete'))
                      : TextButton(onPressed: () => setState(() => _notice = 'Marking opens the authoritative student-submission workflow. Scores remain teacher-confirmed.'), child: const Text('Start marking')),
                ),
                const Divider(height: 1),
              ],
              const SizedBox(height: 14),
              const _InfoBox(
                title: 'Teacher AI marking support',
                body: 'AI can suggest rubric-aligned feedback and flag likely misconceptions, but the teacher confirms every score and comment.',
              ),
            ],
          ),
        ),
      );

  Widget _libraryCard(bool wide) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                Row(
                  children: [
                    const Expanded(child: _LibraryHeading()),
                    SizedBox(width: 240, child: _searchField()),
                    const SizedBox(width: 10),
                    SizedBox(width: 170, child: _classFilter()),
                  ],
                )
              else ...[
                const _LibraryHeading(),
                const SizedBox(height: 12),
                _searchField(),
                const SizedBox(height: 10),
                _classFilter(),
              ],
              const SizedBox(height: 14),
              for (final assignment in _filtered)
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: ListTile(
                    title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text('${assignment.className} · Due ${assignment.dueDate} · ${assignment.submissions}/${assignment.totalStudents} submissions · ${assignment.marked}/${assignment.submissions} marked'),
                    trailing: Chip(label: Text(teacherAssignmentStateLabel(assignment.state))),
                    onTap: () => setState(() => _notice = '${assignment.title} opened as read-only workflow evidence in this prototype.'),
                  ),
                ),
              if (_filtered.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: Text('No assignments match this filter.'))),
            ],
          ),
        ),
      );

  Widget _searchField() => TextField(
        decoration: const InputDecoration(labelText: 'Search assignments...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        onChanged: (value) => setState(() => _query = value),
      );

  Widget _classFilter() => DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _selectedClass,
        decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
        items: [
          const DropdownMenuItem(value: 'All classes', child: Text('All classes')),
          for (final item in teacherAssignmentClasses.take(3)) DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) => setState(() => _selectedClass = value!),
      );

  Widget _boundaries() => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assignment controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 10),
              Text(teacherAssignmentPublishBoundary),
              SizedBox(height: 8),
              Text(teacherAssignmentMarkingBoundary),
              SizedBox(height: 8),
              Text(teacherAssignmentEvidenceBoundary),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TEACHER · ASSIGNMENTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              Text('Assignments', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Text('Create, publish, collect and mark classwork and homework.'),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => onNavigate('classes'), child: const Text('My Classes')),
              OutlinedButton(onPressed: () => onNavigate('messages'), child: const Text('Share work')),
              OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            ],
          ),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: wide ? 2.1 : 1.55,
        children: [
          for (final kpi in teacherAssignmentKpis)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(kpi.$1),
                    Text(kpi.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(kpi.$3, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      );
}

class _LibraryHeading extends StatelessWidget {
  const _LibraryHeading();
  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assignment library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text('Track published work and marking progress.'),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.success});
  final String message;
  final bool success;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: success ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(body)]),
      );
}
