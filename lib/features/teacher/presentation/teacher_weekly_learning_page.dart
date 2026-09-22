import 'package:flutter/material.dart';

import '../data/teacher_weekly_learning_demo_data.dart';
import '../data/teacher_weekly_learning_repository.dart';
import '../domain/teacher_weekly_learning_models.dart';

class TeacherWeeklyLearningPage extends StatefulWidget {
  const TeacherWeeklyLearningPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherWeeklyLearningRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherWeeklyLearningPage> createState() =>
      _TeacherWeeklyLearningPageState();
}

class _TeacherWeeklyLearningPageState extends State<TeacherWeeklyLearningPage> {
  final _planned = TextEditingController();
  final _covered = TextEditingController();
  final _evidence = TextEditingController();
  final _support = TextEditingController();
  final _next = TextEditingController();
  final _note = TextEditingController();

  TeacherWeeklyLearningSnapshot? _snapshot;
  TeacherWeeklyLearningUpdate? _working;
  int _selected = 0;
  bool _loading = true;
  String? _error;
  String _displayStatus = 'Draft';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _planned.dispose();
    _covered.dispose();
    _evidence.dispose();
    _support.dispose();
    _next.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _working = snapshot.update;
        _loading = false;
        _error = null;
        _displayStatus = teacherWeeklyPublicationLabel(snapshot.update.state);
      });
      _syncControllers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Weekly learning data could not be loaded.';
      });
    }
  }

  void _syncControllers() {
    final update = _working;
    if (update == null || update.subjects.isEmpty) return;
    final safeIndex = _selected < 0
        ? 0
        : (_selected >= update.subjects.length
            ? update.subjects.length - 1
            : _selected);
    final subject = update.subjects[safeIndex];
    _planned.text = subject.planned;
    _covered.text = subject.covered;
    _evidence.text = subject.evidence;
    _support.text = subject.support;
    _next.text = subject.next;
    _note.text = update.note;
  }

  void _selectSubject(int index) {
    setState(() => _selected = index);
    _syncControllers();
  }

  void _editSubject({
    String? planned,
    String? covered,
    String? evidence,
    String? support,
    String? next,
  }) {
    final update = _working;
    if (update == null || !update.teacherEditable) return;
    final subjects = List<TeacherWeeklySubjectUpdate>.from(update.subjects);
    subjects[_selected] = subjects[_selected].copyWith(
      planned: planned,
      covered: covered,
      evidence: evidence,
      support: support,
      next: next,
    );
    setState(() {
      _working = update.copyWith(subjects: subjects);
      _displayStatus = 'Draft changed';
    });
  }

  void _editMeta({String? className, String? week, String? note}) {
    final update = _working;
    if (update == null || !update.teacherEditable) return;
    setState(() {
      _working = update.copyWith(
        className: className,
        week: week,
        note: note,
      );
      _displayStatus = 'Draft changed';
    });
  }

  Future<void> _saveDraft() async {
    final update = _working;
    if (update == null) return;
    final result = await widget.repository.saveDraft(update);
    if (!mounted) return;
    setState(() {
      if (result.update != null) _working = result.update;
      _displayStatus = result.success
          ? 'Draft saved · sync pending'
          : _displayStatus;
    });
    if (result.success) widget.onMutationQueued();
    _show(result.message, success: result.success);
  }

  Future<void> _publish() async {
    final update = _working;
    if (update == null) return;
    final result = await widget.repository.queuePublication(update);
    if (!mounted) return;
    setState(() {
      if (result.update != null) _working = result.update;
      _displayStatus = result.success
          ? 'Queued for parent publication · sync pending'
          : _displayStatus;
    });
    if (result.success) widget.onMutationQueued();
    _show(result.message, success: result.success);
  }

  void _show(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? message : 'Unable to continue: $message'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _working == null || _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Weekly learning data is unavailable.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final update = _working!;
    final editable = update.teacherEditable;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(onNavigate: widget.onNavigate),
              const SizedBox(height: 16),
              _Stats(update: update, status: _displayStatus),
              const SizedBox(height: 16),
              const _FlowCard(),
              const SizedBox(height: 16),
              _EditorArea(
                update: update,
                selected: _selected,
                editable: editable,
                planned: _planned,
                covered: _covered,
                evidence: _evidence,
                support: _support,
                next: _next,
                onSelectSubject: _selectSubject,
                onClassChanged: (value) => _editMeta(className: value),
                onWeekChanged: (value) => _editMeta(week: value),
                onPlannedChanged: (value) => _editSubject(planned: value),
                onCoveredChanged: (value) => _editSubject(covered: value),
                onEvidenceChanged: (value) => _editSubject(evidence: value),
                onSupportChanged: (value) => _editSubject(support: value),
                onNextChanged: (value) => _editSubject(next: value),
                onSave: _saveDraft,
                onPublish: _publish,
              ),
              const SizedBox(height: 16),
              _ParentPreview(
                update: update,
                status: _displayStatus,
                noteController: _note,
                editable: editable,
                onNoteChanged: (value) => _editMeta(note: value),
              ),
              const SizedBox(height: 16),
              const _Rules(),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
                'TEACHER PORTAL · WEEKLY LEARNING UPDATE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly Learning Progress',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text(
                'Turn approved lesson plans into one parent-ready weekly update without rewriting the same work.',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => onNavigate('lesson-plans'),
              child: const Text('Lesson Plans'),
            ),
            OutlinedButton(
              onPressed: () => onNavigate('assignments'),
              child: const Text('Assignments'),
            ),
            OutlinedButton(
              onPressed: () => onNavigate('messages'),
              child: const Text('Messages'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.update, required this.status});
  final TeacherWeeklyLearningUpdate update;
  final String status;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      ('Class', update.className, 'current selection'),
      ('Week', update.week, teacherWeeklyTermLabel),
      ('Subjects ready', '${update.subjects.length}', '${update.completionPercent}% with coverage notes'),
      ('Publication', status, 'parent-safe summary'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 220,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 5),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
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

class _FlowCard extends StatelessWidget {
  const _FlowCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teacher does the work once',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in teacherWeeklyFlow)
                    SizedBox(
                      width: 210,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(item.$2),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _EditorArea extends StatelessWidget {
  const _EditorArea({
    required this.update,
    required this.selected,
    required this.editable,
    required this.planned,
    required this.covered,
    required this.evidence,
    required this.support,
    required this.next,
    required this.onSelectSubject,
    required this.onClassChanged,
    required this.onWeekChanged,
    required this.onPlannedChanged,
    required this.onCoveredChanged,
    required this.onEvidenceChanged,
    required this.onSupportChanged,
    required this.onNextChanged,
    required this.onSave,
    required this.onPublish,
  });

  final TeacherWeeklyLearningUpdate update;
  final int selected;
  final bool editable;
  final TextEditingController planned;
  final TextEditingController covered;
  final TextEditingController evidence;
  final TextEditingController support;
  final TextEditingController next;
  final ValueChanged<int> onSelectSubject;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onWeekChanged;
  final ValueChanged<String> onPlannedChanged;
  final ValueChanged<String> onCoveredChanged;
  final ValueChanged<String> onEvidenceChanged;
  final ValueChanged<String> onSupportChanged;
  final ValueChanged<String> onNextChanged;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final list = _SubjectList(
          update: update,
          selected: selected,
          onSelectSubject: onSelectSubject,
          onClassChanged: onClassChanged,
          onWeekChanged: onWeekChanged,
          editable: editable,
        );
        final editor = _SubjectEditor(
          subject: update.subjects[selected],
          editable: editable,
          planned: planned,
          covered: covered,
          evidence: evidence,
          support: support,
          next: next,
          onPlannedChanged: onPlannedChanged,
          onCoveredChanged: onCoveredChanged,
          onEvidenceChanged: onEvidenceChanged,
          onSupportChanged: onSupportChanged,
          onNextChanged: onNextChanged,
          onSave: onSave,
          onPublish: onPublish,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [list, const SizedBox(height: 16), editor],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 6, child: editor),
          ],
        );
      },
    );
  }
}

class _SubjectList extends StatelessWidget {
  const _SubjectList({
    required this.update,
    required this.selected,
    required this.onSelectSubject,
    required this.onClassChanged,
    required this.onWeekChanged,
    required this.editable,
  });

  final TeacherWeeklyLearningUpdate update;
  final int selected;
  final ValueChanged<int> onSelectSubject;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onWeekChanged;
  final bool editable;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Subjects this week',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const Text('Select a subject and confirm what was actually taught.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                    isExpanded: true,
                      initialValue: update.className,
                      decoration: const InputDecoration(labelText: 'Class'),
                      items: [
                        for (final item in teacherWeeklyClassOptions)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: editable
                          ? (value) {
                              if (value != null) onClassChanged(value);
                            }
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                    isExpanded: true,
                      initialValue: update.week,
                      decoration: const InputDecoration(labelText: 'Week'),
                      items: [
                        for (final item in teacherWeeklyWeekOptions)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: editable
                          ? (value) {
                              if (value != null) onWeekChanged(value);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < update.subjects.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    selected: selected == i,
                    selectedTileColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(
                      update.subjects[i].subject,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      '${update.subjects[i].covered}\nNext: ${update.subjects[i].next}',
                    ),
                    trailing: Text(
                      update.subjects[i].linkedPlanId == 'LP-206'
                          ? 'From LP-206'
                          : 'Linked plan',
                    ),
                    onTap: () => onSelectSubject(i),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _SubjectEditor extends StatelessWidget {
  const _SubjectEditor({
    required this.subject,
    required this.editable,
    required this.planned,
    required this.covered,
    required this.evidence,
    required this.support,
    required this.next,
    required this.onPlannedChanged,
    required this.onCoveredChanged,
    required this.onEvidenceChanged,
    required this.onSupportChanged,
    required this.onNextChanged,
    required this.onSave,
    required this.onPublish,
  });

  final TeacherWeeklySubjectUpdate subject;
  final bool editable;
  final TextEditingController planned;
  final TextEditingController covered;
  final TextEditingController evidence;
  final TextEditingController support;
  final TextEditingController next;
  final ValueChanged<String> onPlannedChanged;
  final ValueChanged<String> onCoveredChanged;
  final ValueChanged<String> onEvidenceChanged;
  final ValueChanged<String> onSupportChanged;
  final ValueChanged<String> onNextChanged;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                subject.subject,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Planned from lesson plan',
                controller: planned,
                enabled: editable,
                onChanged: onPlannedChanged,
              ),
              _Field(
                label: 'Actually covered',
                controller: covered,
                enabled: editable,
                onChanged: onCoveredChanged,
              ),
              _Field(
                label: 'Classwork / assignment evidence',
                controller: evidence,
                enabled: editable,
                onChanged: onEvidenceChanged,
              ),
              _Field(
                label: 'Topic or support area to continue',
                controller: support,
                enabled: editable,
                onChanged: onSupportChanged,
              ),
              _Field(
                label: 'What comes next',
                controller: next,
                enabled: editable,
                onChanged: onNextChanged,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: editable ? onSave : null,
                    child: const Text('Save draft'),
                  ),
                  FilledButton(
                    onPressed: editable ? onPublish : null,
                    child: const Text('Publish weekly update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
          ),
        ),
      );
}

class _ParentPreview extends StatelessWidget {
  const _ParentPreview({
    required this.update,
    required this.status,
    required this.noteController,
    required this.editable,
    required this.onNoteChanged,
  });

  final TeacherWeeklyLearningUpdate update;
  final String status;
  final TextEditingController noteController;
  final bool editable;
  final ValueChanged<String> onNoteChanged;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parent preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text('Family-safe version generated from the classroom record.'),
                    ],
                  ),
                  Chip(label: Text(status)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'WEEKLY LEARNING UPDATE',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Text(
                '${update.className} · ${update.week}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Text('Teacher: Mrs. Amina Yusuf'),
              const Text('BrightGate Academy'),
              const SizedBox(height: 14),
              for (final subject in update.subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.subject,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text('This week: ${subject.covered}'),
                      Text('Evidence: ${subject.evidence}'),
                      Text('Next: ${subject.next}'),
                      Text(
                        subject.support,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: noteController,
                enabled: editable,
                minLines: 2,
                maxLines: 4,
                onChanged: onNoteChanged,
                decoration: const InputDecoration(
                  labelText: 'Whole-class note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Text(update.note),
            ],
          ),
        ),
      );
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Publication rule',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(teacherWeeklyPublicationBoundary),
              const SizedBox(height: 12),
              const Text(
                'Delivery & evidence boundary',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(teacherWeeklyDeliveryBoundary),
              const SizedBox(height: 8),
              const Text(teacherWeeklyEvidenceBoundary),
            ],
          ),
        ),
      );
}