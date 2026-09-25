// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../data/teacher_cbt_demo_data.dart';
import '../data/teacher_cbt_repository.dart';
import '../domain/teacher_cbt_models.dart';

class TeacherCbtPage extends StatefulWidget {
  const TeacherCbtPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherCbtRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherCbtPage> createState() => _TeacherCbtPageState();
}

class _TeacherCbtPageState extends State<TeacherCbtPage> {
  late Future<TeacherCbtSnapshot> _future;
  String? _selectedId;
  TeacherCbtTest? _editing;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() {
        _future = widget.repository.load();
      });

  void _select(TeacherCbtTest value) => setState(() {
        _selectedId = value.id;
        _editing = value;
        _notice = null;
      });

  void _replaceEditing(TeacherCbtTest value) {
    if (!value.teacherEditable) return;
    setState(() {
      _editing = value;
      _notice = null;
    });
  }

  void _applyResult(TeacherCbtActionResult result) {
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.success && result.test != null) {
        _editing = result.test;
        _selectedId = result.test!.id;
      }
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  Future<void> _createTest(TeacherCbtSnapshot snapshot) async {
    final picked = await showDialog<(TeacherCbtOption, String)>(
      context: context,
      builder: (context) => _ClassSubjectPickerDialog(options: snapshot.options),
    );
    if (picked == null) return;
    final (option, title) = picked;
    final draft = snapshot.draft.copyWith(
      classSubjectId: option.classSubjectId,
      termId: option.termId,
      term: option.term,
      className: option.className,
      subject: option.subject,
      title: title,
    );
    _applyResult(await widget.repository.saveDraft(draft));
  }

  Future<void> _saveDraft() async {
    final value = _editing;
    if (value == null) return;
    _applyResult(await widget.repository.saveDraft(value));
  }

  Future<void> _publish() async {
    final value = _editing;
    if (value == null) return;
    _applyResult(await widget.repository.publish(value));
  }

  Future<void> _close(TeacherCbtTest value) async {
    _applyResult(await widget.repository.close(value));
  }

  Future<void> _addOrEditQuestion(TeacherCbtTest value, int? index) async {
    final existing = index == null ? null : value.questions[index];
    final question = await showDialog<TeacherCbtQuestion>(
      context: context,
      builder: (context) => _QuestionDialog(existing: existing),
    );
    if (question == null) return;
    final items = [...value.questions];
    if (index == null) {
      items.add(question);
    } else {
      items[index] = question;
    }
    _replaceEditing(value.copyWith(questions: items));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherCbtSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load CBT tests.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        final all = [data.draft, ...data.tests];
        if (_selectedId == null || !all.any((t) => t.id == _selectedId)) {
          _selectedId = all.isEmpty ? null : all.first.id;
        }
        _editing ??= all.firstWhere((t) => t.id == _selectedId, orElse: () => data.draft);
        if (_editing!.id != _selectedId) {
          _editing = all.firstWhere((t) => t.id == _selectedId, orElse: () => data.draft);
        }
        return _content(context, data, all);
      },
    );
  }

  Widget _content(BuildContext context, TeacherCbtSnapshot snapshot, List<TeacherCbtTest> all) {
    final value = _editing!;
    final published = snapshot.tests.where((t) => t.state == TeacherCbtTestState.published).length;
    final draftCount = snapshot.tests.where((t) => t.state == TeacherCbtTestState.draft).length;
    final totalSubmitted = snapshot.tests.fold<int>(0, (sum, t) => sum + t.submittedCount);
    final withAttempts = snapshot.tests.where((t) => t.averageScorePercent != null).toList();
    final avgAccuracy = withAttempts.isEmpty
        ? null
        : (withAttempts.fold<double>(0, (sum, t) => sum + t.averageScorePercent!) / withAttempts.length).round();

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 700 ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(constraints.maxWidth),
            const SizedBox(height: 18),
            _kpis(published, draftCount, totalSubmitted, avgAccuracy),
            const SizedBox(height: 18),
            if (_notice != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _noticeSuccess ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_notice!),
              ),
              const SizedBox(height: 18),
            ],
            if (snapshot.options.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No classes are assigned to you yet. The owner or the administrator assigns classes to teachers.'),
                ),
              )
            else ...[
              _topGrid(constraints.maxWidth, all, value, snapshot),
              const SizedBox(height: 18),
              _evidenceGrid(constraints.maxWidth, value),
            ],
            const SizedBox(height: 18),
            _boundaries(),
          ],
        ),
      ),
    );
  }

  Widget _header(double width) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(onPressed: () => widget.onNavigate('dashboard'), child: const Text('Dashboard')),
        OutlinedButton(onPressed: () => widget.onNavigate('assessments'), child: const Text('Assessments')),
      ],
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TEACHER · CBT', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        const SizedBox(height: 5),
        Text('Computer-Based Tests', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Create a CBT test for one of your own class subjects, publish it, and review real attempts.'),
      ],
    );
    if (width < 760) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), const SizedBox(width: 20), actions]);
  }

  Widget _kpis(int published, int draftCount, int totalSubmitted, int? avgAccuracy) {
    final kpis = <(String, String, String)>[
      ('Tests', '${published + draftCount}', '$published published · $draftCount draft'),
      ('Attempts submitted', '$totalSubmitted', totalSubmitted == 0 ? 'No attempts recorded yet' : 'this term'),
      ('Average score', avgAccuracy == null ? '—' : '$avgAccuracy%', avgAccuracy == null ? 'No attempts recorded yet' : 'across tests with attempts'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in kpis)
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
                    Text(item.$2, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _topGrid(double width, List<TeacherCbtTest> all, TeacherCbtTest value, TeacherCbtSnapshot snapshot) {
    final children = [_testList(all, snapshot), _configuration(value)];
    if (width < 900) return Column(children: [children[0], const SizedBox(height: 16), children[1]]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: children[0]), const SizedBox(width: 16), Expanded(child: children[1])]);
  }

  Widget _testList(List<TeacherCbtTest> all, TeacherCbtSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My CBT tests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('Practice is for learning and exam familiarity, not permanent ranking.'),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createTest(snapshot),
                    icon: const Icon(Icons.add),
                    label: const Text('New test'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final test in all) ...[
                ListTile(
                  selected: test.id == _selectedId,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(
                    test.title.isEmpty ? 'Untitled draft · ${test.className}' : '${test.title} · ${test.className}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${test.subject.isEmpty ? '' : '${test.subject} · '}${test.questionCount} questions · ${test.durationMinutes} minutes · ${test.submittedCount} attempts',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(teacherCbtTestStateLabel(test.state), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (test.averageScorePercent != null) Text('Avg ${test.averageScorePercent!.round()}%'),
                    ],
                  ),
                  onTap: () => _select(test),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      );

  Widget _configuration(TeacherCbtTest value) {
    final editable = value.teacherEditable;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Test configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Chip(label: Text(teacherCbtTestStateLabel(value.state))),
              ],
            ),
            const SizedBox(height: 6),
            Text(value.className.isEmpty ? 'Choose a class subject below.' : '${value.className}${value.subject.isEmpty ? '' : ' · ${value.subject}'}'),
            const SizedBox(height: 14),
            if (value.className.isEmpty)
              const Text('Use "New test" to start one for a class subject you currently teach.')
            else ...[
              TextFormField(
                key: ValueKey('cbt-title-${value.id}-${value.version}'),
                initialValue: value.title,
                enabled: editable,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                onChanged: (text) => _replaceEditing(value.copyWith(title: text)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('cbt-duration-${value.id}-${value.version}'),
                initialValue: '${value.durationMinutes}',
                enabled: editable,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (minutes)', border: OutlineInputBorder()),
                onChanged: (text) {
                  final parsed = int.tryParse(text);
                  if (parsed != null) _replaceEditing(value.copyWith(durationMinutes: parsed));
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TeacherCbtResultMode>(
                initialValue: value.resultMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Result mode', border: OutlineInputBorder()),
                items: [
                  for (final mode in TeacherCbtResultMode.values)
                    DropdownMenuItem(value: mode, child: Text(teacherCbtResultModeLabel(mode))),
                ],
                onChanged: editable ? (mode) { if (mode != null) _replaceEditing(value.copyWith(resultMode: mode)); } : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey('cbt-instructions-${value.id}-${value.version}'),
                initialValue: value.instructions,
                enabled: editable,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder()),
                onChanged: (text) => _replaceEditing(value.copyWith(instructions: text)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (editable) ...[
                    OutlinedButton(onPressed: _saveDraft, child: const Text('Save draft')),
                    FilledButton(onPressed: _publish, child: const Text('Publish')),
                  ] else if (value.canClose)
                    FilledButton.tonal(onPressed: () => _close(value), child: const Text('Close test')),
                ],
              ),
              if (!editable && !value.canClose) ...[
                const SizedBox(height: 10),
                const Text('This test is closed and read-only here.'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _evidenceGrid(double width, TeacherCbtTest value) {
    final children = [_questionEditor(value), _results(value)];
    if (width < 900) return Column(children: [children[0], const SizedBox(height: 16), children[1]]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: children[0]), const SizedBox(width: 16), Expanded(child: children[1])]);
  }

  Widget _questionEditor(TeacherCbtTest value) {
    final editable = value.teacherEditable;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                if (editable)
                  FilledButton.icon(
                    onPressed: () => _addOrEditQuestion(value, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add question'),
                  ),
              ],
            ),
            const Text('Real questions a student answers when they take this test.'),
            const SizedBox(height: 12),
            if (value.questions.isEmpty)
              const Text('No real questions have been added yet. This test cannot be published until it has at least one.')
            else
              for (var i = 0; i < value.questions.length; i++) ...[
                _QuestionTile(
                  index: i,
                  question: value.questions[i],
                  editable: editable,
                  onEdit: () => _addOrEditQuestion(value, i),
                  onDelete: () => _replaceEditing(
                    value.copyWith(questions: [for (var j = 0; j < value.questions.length; j++) if (j != i) value.questions[j]]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const Divider(),
            const Text('Question design principle', style: TextStyle(fontWeight: FontWeight.w900)),
            const Text(teacherCbtDesignBoundary),
          ],
        ),
      ),
    );
  }

  Widget _results(TeacherCbtTest value) {
    final hasAttempts = value.submittedCount > 0;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent learner results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('${value.totalRecipients} eligible students.'),
            const SizedBox(height: 12),
            if (hasAttempts)
              Text('${value.submittedCount} real attempt${value.submittedCount == 1 ? '' : 's'} recorded · average score ${value.averageScorePercent?.round() ?? 0}%.')
            else
              const Text(teacherCbtResultsUnavailable),
          ],
        ),
      ),
    );
  }

  Widget _boundaries() => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CBT boundaries', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(teacherCbtPracticeBoundary),
              SizedBox(height: 8),
              Text(teacherCbtAiBoundary),
              SizedBox(height: 8),
              Text(teacherCbtPublicationBoundary),
            ],
          ),
        ),
      );
}

class _ClassSubjectPickerDialog extends StatefulWidget {
  const _ClassSubjectPickerDialog({required this.options});
  final List<TeacherCbtOption> options;

  @override
  State<_ClassSubjectPickerDialog> createState() => _ClassSubjectPickerDialogState();
}

class _ClassSubjectPickerDialogState extends State<_ClassSubjectPickerDialog> {
  late TeacherCbtOption _selected = widget.options.first;
  final _title = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Enter a title for the CBT test.');
      return;
    }
    Navigator.of(context).pop((_selected, _title.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New CBT test'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<TeacherCbtOption>(
                isExpanded: true,
                initialValue: _selected,
                decoration: const InputDecoration(labelText: 'Class subject'),
                items: [for (final option in widget.options) DropdownMenuItem(value: option, child: Text(option.label))],
                onChanged: (v) {
                  if (v != null) setState(() => _selected = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Continue')),
        ],
      );
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.index,
    required this.question,
    required this.editable,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final TeacherCbtQuestion question;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${index + 1}. ${question.prompt}', style: const TextStyle(fontWeight: FontWeight.w800))),
              if (editable) ...[
                IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
                IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline), tooltip: 'Delete'),
              ],
            ],
          ),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${i == question.correctIndex ? '✓ ' : ''}${question.options[i]}',
                style: TextStyle(
                  fontWeight: i == question.correctIndex ? FontWeight.w800 : FontWeight.w400,
                  color: i == question.correctIndex ? scheme.primary : null,
                ),
              ),
            ),
          if (question.explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(question.explanation, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog({this.existing});
  final TeacherCbtQuestion? existing;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  late final _promptController = TextEditingController(text: widget.existing?.prompt ?? '');
  late final _explanationController = TextEditingController(text: widget.existing?.explanation ?? '');
  late List<TextEditingController> _optionControllers = [
    for (final option in widget.existing?.options ?? const ['', '']) TextEditingController(text: option),
  ];
  late int _correctIndex = widget.existing?.correctIndex ?? 0;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    _explanationController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() => _optionControllers = [..._optionControllers, TextEditingController()]);
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers = [for (var i = 0; i < _optionControllers.length; i++) if (i != index) _optionControllers[i]];
      if (_correctIndex >= _optionControllers.length) _correctIndex = _optionControllers.length - 1;
      if (_correctIndex == index) _correctIndex = 0;
    });
  }

  void _submit() {
    final prompt = _promptController.text.trim();
    final options = [for (final controller in _optionControllers) controller.text.trim()];
    if (prompt.isEmpty) {
      setState(() => _error = 'Enter the question text.');
      return;
    }
    if (options.any((option) => option.isEmpty)) {
      setState(() => _error = 'Every option needs text.');
      return;
    }
    if (_correctIndex < 0 || _correctIndex >= options.length) {
      setState(() => _error = 'Choose which option is correct.');
      return;
    }
    Navigator.of(context).pop(TeacherCbtQuestion(
      id: widget.existing?.id ?? 'Q-${DateTime.now().microsecondsSinceEpoch}',
      prompt: prompt,
      options: options,
      correctIndex: _correctIndex,
      explanation: _explanationController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add question' : 'Edit question'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _promptController, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Question')),
              const SizedBox(height: 12),
              const Text('Options (select the correct one)', style: TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < _optionControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Radio<int>(value: i, groupValue: _correctIndex, onChanged: (value) => setState(() => _correctIndex = value ?? _correctIndex)),
                      Expanded(child: TextField(controller: _optionControllers[i], decoration: InputDecoration(labelText: 'Option ${i + 1}'))),
                      if (_optionControllers.length > 2)
                        IconButton(onPressed: () => _removeOption(i), icon: const Icon(Icons.close), tooltip: 'Remove option'),
                    ],
                  ),
                ),
              if (_optionControllers.length < 6)
                TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add), label: const Text('Add option')),
              const SizedBox(height: 8),
              TextField(controller: _explanationController, minLines: 1, maxLines: 2, decoration: const InputDecoration(labelText: 'Explanation (optional)')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
