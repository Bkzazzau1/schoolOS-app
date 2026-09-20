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
  List<TeacherCbtPracticeSet> _sets = const [];
  String? _selectedId;
  TeacherCbtPracticeSet? _editing;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load().then((snapshot) {
      _sets = snapshot.sets;
      _selectedId ??= snapshot.sets.isEmpty ? null : snapshot.sets.first.id;
      _editing ??= snapshot.sets.isEmpty ? null : snapshot.sets.first;
      return snapshot;
    });
  }

  void _selectSet(TeacherCbtPracticeSet value) {
    setState(() {
      _selectedId = value.id;
      _editing = value;
      _notice = null;
    });
  }

  void _replaceEditing(TeacherCbtPracticeSet value) {
    if (!value.teacherEditable) return;
    setState(() {
      _editing = value;
      _notice = null;
    });
  }

  Future<void> _saveDraft() async {
    final value = _editing;
    if (value == null) return;
    final result = await widget.repository.saveDraft(value);
    if (!mounted) return;
    _applyResult(result);
  }

  Future<void> _publish() async {
    final value = _editing;
    if (value == null) return;
    final result = await widget.repository.queuePublication(value);
    if (!mounted) return;
    _applyResult(result);
  }

  void _applyResult(TeacherCbtActionResult result) {
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.set != null) {
        final updated = result.set!;
        _editing = updated;
        _sets = _sets
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      }
    });
    if (result.success) widget.onMutationQueued();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherCbtSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load CBT Practice: ${snapshot.error}'));
          }
          return LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 700 ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(constraints.maxWidth),
                  const SizedBox(height: 18),
                  _kpis(constraints.maxWidth),
                  const SizedBox(height: 18),
                  if (_notice != null) ...[
                    _noticeCard(),
                    const SizedBox(height: 18),
                  ],
                  _topGrid(constraints.maxWidth),
                  const SizedBox(height: 18),
                  _evidenceGrid(constraints.maxWidth),
                  const SizedBox(height: 18),
                  _learningHandoff(),
                  const SizedBox(height: 18),
                  _boundaries(),
                ],
              ),
            ),
          );
        },
      );

  Widget _header(double width) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => widget.onNavigate('dashboard'),
          child: const Text('Dashboard'),
        ),
        OutlinedButton(
          onPressed: () => widget.onNavigate('assessments'),
          child: const Text('Assessments'),
        ),
        OutlinedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student CBT kiosk is a separate student experience.'),
            ),
          ),
          child: const Text('Open student kiosk'),
        ),
      ],
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEACHER PORTAL · CBT PRACTICE CENTER',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'CBT Practice Center',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Create computer-based practice, assign it to classes, review attempts and feed topic-level evidence into Learning Intelligence.',
        ),
      ],
    );
    if (width < 760) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 12), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: title), const SizedBox(width: 20), actions],
    );
  }

  Widget _kpis(double width) {
    final cardWidth = width < 700 ? double.infinity : (width - 72) / 4;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in teacherCbtKpis)
          SizedBox(
            width: cardWidth,
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
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

  Widget _topGrid(double width) {
    final children = [_setList(), _configuration()];
    if (width < 900) {
      return Column(
        children: [children[0], const SizedBox(height: 16), children[1]],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 16),
        Expanded(child: children[1]),
      ],
    );
  }

  Widget _setList() => Card(
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
                        Text('My CBT practice sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('Practice is for learning and exam familiarity, not permanent ranking.'),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create a new CBT draft from the question-authoring workflow.')),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('New set'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final set in _sets) ...[
                ListTile(
                  selected: set.id == _selectedId,
                  selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(set.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${set.id} · ${set.className}\n${set.questions} questions · ${set.durationMinutes} minutes · ${set.attempts} attempts',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(teacherCbtSetStateLabel(set.state), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (set.attempts > 0) Text('Avg ${set.averageAccuracy}%'),
                    ],
                  ),
                  onTap: () => _selectSet(set),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      );

  Widget _configuration() {
    final value = _editing;
    if (value == null) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No practice set selected.')));
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Practice configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      Text(value.id),
                    ],
                  ),
                ),
                Chip(label: Text(teacherCbtSetStateLabel(value.state))),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: ValueKey('cbt-title-${value.id}-${value.version}'),
              initialValue: value.title,
              enabled: editable,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              onChanged: (text) => _replaceEditing(value.copyWith(title: text)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: value.className,
              decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
              items: const ['JSS 2A', 'JSS 2B', 'JSS 3A']
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(growable: false),
              onChanged: editable ? (item) { if (item != null) _replaceEditing(value.copyWith(className: item)); } : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('cbt-q-${value.id}-${value.version}'),
                    initialValue: '${value.questions}',
                    enabled: editable,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Questions', border: OutlineInputBorder()),
                    onChanged: (text) {
                      final parsed = int.tryParse(text);
                      if (parsed != null) _replaceEditing(value.copyWith(questions: parsed));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: value.resultMode,
              decoration: const InputDecoration(labelText: 'Result mode', border: OutlineInputBorder()),
              items: const [
                'Show score + topic feedback',
                'Show score only',
                'Teacher review before release',
              ].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(growable: false),
              onChanged: editable ? (item) { if (item != null) _replaceEditing(value.copyWith(resultMode: item)); } : null,
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
                OutlinedButton(onPressed: editable ? _saveDraft : null, child: const Text('Save draft')),
                FilledButton(onPressed: editable ? _publish : null, child: const Text('Publish practice')),
              ],
            ),
            if (!editable) ...[
              const SizedBox(height: 10),
              const Text('Published, queued and closed practice sets are read-only here. Use an auditable revision workflow for later changes.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _evidenceGrid(double width) {
    final children = [_questionPreview(), _results()];
    if (width < 900) return Column(children: [children[0], const SizedBox(height: 16), children[1]]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: children[0]), const SizedBox(width: 16), Expanded(child: children[1])],
    );
  }

  Widget _questionPreview() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Question preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('Sample question from the selected practice set.'),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Text('Question 7 of 20', style: TextStyle(fontWeight: FontWeight.w800))),
                  Chip(label: Text(teacherCbtQuestionTopic)),
                ],
              ),
              const Text(teacherCbtQuestionText),
              const SizedBox(height: 10),
              for (final option in teacherCbtQuestionOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(option),
                ),
              const Divider(),
              const Text('Question design principle', style: TextStyle(fontWeight: FontWeight.w900)),
              const Text(teacherCbtDesignBoundary),
            ],
          ),
        ),
      );

  Widget _results() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent learner results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('Evidence from practice attempts.'),
              const SizedBox(height: 12),
              for (final result in teacherCbtResults)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(result.student, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${result.className} · ${result.score} · ${result.accuracy}\nTime ${result.time} · Practice focus: ${result.focus}'),
                  isThreeLine: true,
                  trailing: const Text('Review'),
                ),
            ],
          ),
        ),
      );

  Widget _learningHandoff() => Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Learning Intelligence handoff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text('CBT should contribute evidence, not replace teacher judgment.'),
              SizedBox(height: 10),
              Text('Example insight', style: TextStyle(fontWeight: FontWeight.w900)),
              Text(teacherCbtLearningHandoff),
            ],
          ),
        ),
      );

  Widget _boundaries() => Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CBT Practice boundaries', style: TextStyle(fontWeight: FontWeight.w900)),
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

  Widget _noticeCard() => Card(
        elevation: 0,
        child: ListTile(
          leading: Icon(_noticeSuccess ? Icons.check_circle_outline : Icons.info_outline),
          title: Text(_notice!),
        ),
      );
}
