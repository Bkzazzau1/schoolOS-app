import 'package:flutter/material.dart';

import '../data/teacher_assessment_demo_data.dart';
import '../data/teacher_assessment_repository.dart';
import '../domain/teacher_assessment_models.dart';

class TeacherAssessmentsPage extends StatefulWidget {
  const TeacherAssessmentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherAssessmentRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherAssessmentsPage> createState() => _TeacherAssessmentsPageState();
}

class _TeacherAssessmentsPageState extends State<TeacherAssessmentsPage> {
  late Future<TeacherAssessmentSnapshot> _future;
  String? _selectedId;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  void _select(String id) => setState(() {
        _selectedId = id;
        _notice = null;
      });

  void _report(TeacherAssessmentActionResult result) {
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.success && result.assessment != null) _selectedId = result.assessment!.id;
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  Future<void> _createAssessment(TeacherAssessmentSnapshot snapshot) async {
    final option = await showDialog<TeacherAssessmentOption>(
      context: context,
      builder: (context) => _ClassSubjectPickerDialog(options: snapshot.options),
    );
    if (option == null) return;
    final draft = snapshot.draft.copyWith(
      classSubjectId: option.classSubjectId,
      termId: option.termId,
      term: option.term,
      className: option.className,
      subject: option.subject,
      title: '',
      type: TeacherAssessmentType.ca,
      maximumScore: 20,
    );
    _report(await widget.repository.saveDraft(draft));
  }

  Future<void> _saveDraftEdits(TeacherAssessment draft) async {
    _report(await widget.repository.saveDraft(draft));
  }

  Future<void> _publish(TeacherAssessment draft) async {
    _report(await widget.repository.publish(draft));
  }

  Future<void> _saveScores(TeacherAssessment assessment) async {
    _report(await widget.repository.saveScores(assessment));
  }

  Future<void> _submit(TeacherAssessment assessment) async {
    _report(await widget.repository.submit(assessment));
  }

  Future<void> _correct(TeacherAssessment assessment, TeacherAssessmentEntry entry) async {
    final result = await showDialog<_CorrectionDraft>(
      context: context,
      builder: (context) => _CorrectionDialog(entry: entry, maximumScore: assessment.maximumScore),
    );
    if (result == null) return;
    _report(await widget.repository.correctScore(
      assessment,
      studentId: entry.studentId,
      score: result.score,
      comment: result.comment,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAssessmentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorState(onRetry: _reload);
        }
        final data = snapshot.requireData;
        final all = [data.draft, ...data.assessments];
        if (_selectedId == null || !all.any((a) => a.id == _selectedId)) {
          _selectedId = all.isEmpty ? null : all.first.id;
        }
        return _content(context, data, all);
      },
    );
  }

  Widget _content(BuildContext context, TeacherAssessmentSnapshot snapshot, List<TeacherAssessment> all) {
    final selected = all.firstWhere((a) => a.id == _selectedId, orElse: () => snapshot.draft);
    final published = snapshot.assessments;
    final totalEntered = published.fold<int>(0, (sum, a) => sum + a.entered);
    final totalStudents = published.fold<int>(0, (sum, a) => sum + a.totalStudents);
    final scored = published.where((a) => a.averagePercent != null).toList();
    final overallAverage = scored.isEmpty
        ? null
        : (scored.fold<double>(0, (sum, a) => sum + a.averagePercent!) / scored.length).round();
    final pendingReview = published.where((a) => a.state == TeacherAssessmentState.submitted).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onNavigate: widget.onNavigate),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KpiCard(label: 'Assessments', value: '${published.length}', hint: 'Published or further along'),
              _KpiCard(label: 'Scores entered', value: '$totalEntered/$totalStudents', hint: 'Across your assessments'),
              _KpiCard(
                label: 'Average score',
                value: overallAverage == null ? '—' : '$overallAverage%',
                hint: overallAverage == null ? 'No scores entered yet' : 'Across assessments with scores',
              ),
              _KpiCard(label: 'Awaiting lock/release', value: '$pendingReview', hint: 'Submitted, not yet locked or released'),
            ],
          ),
          const SizedBox(height: 18),
          if (_notice != null) ...[
            _Notice(message: _notice!, success: _noticeSuccess),
            const SizedBox(height: 14),
          ],
          if (snapshot.options.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No classes are assigned to you yet. The owner or the administrator assigns classes to teachers.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final scoreCard = _ScoreEntryCard(
                  snapshot: snapshot,
                  assessment: selected,
                  onSaveDraft: _saveDraftEdits,
                  onPublish: _publish,
                  onSaveScores: _saveScores,
                  onSubmit: _submit,
                  onCorrect: (entry) => _correct(selected, entry),
                );
                final insight = _PerformanceInsight(assessment: selected);
                if (constraints.maxWidth >= 980) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: scoreCard),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: insight),
                    ],
                  );
                }
                return Column(children: [scoreCard, const SizedBox(height: 14), insight]);
              },
            ),
          const SizedBox(height: 18),
          _AssessmentRegister(
            all: all,
            selectedId: _selectedId,
            onSelect: _select,
            onCreate: snapshot.options.isEmpty ? null : () => _createAssessment(snapshot),
          ),
          const SizedBox(height: 18),
          const _Boundaries(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TEACHER · ASSESSMENTS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Assessments', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Create CA, quizzes, tests and exams, enter scores and track class performance.'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(onPressed: () => onNavigate('classes'), child: const Text('My Classes')),
              OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            ],
          ),
        ],
      );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _ScoreEntryCard extends StatefulWidget {
  const _ScoreEntryCard({
    required this.snapshot,
    required this.assessment,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onSaveScores,
    required this.onSubmit,
    required this.onCorrect,
  });

  final TeacherAssessmentSnapshot snapshot;
  final TeacherAssessment assessment;
  final ValueChanged<TeacherAssessment> onSaveDraft;
  final ValueChanged<TeacherAssessment> onPublish;
  final ValueChanged<TeacherAssessment> onSaveScores;
  final ValueChanged<TeacherAssessment> onSubmit;
  final ValueChanged<TeacherAssessmentEntry> onCorrect;

  @override
  State<_ScoreEntryCard> createState() => _ScoreEntryCardState();
}

class _ScoreEntryCardState extends State<_ScoreEntryCard> {
  late TeacherAssessment _working = widget.assessment;
  late final _titleController = TextEditingController(text: _working.title);
  late final _maxController = TextEditingController(text: '${_working.maximumScore}');
  late final _weightController = TextEditingController(text: _working.weight.toStringAsFixed(2));

  @override
  void didUpdateWidget(covariant _ScoreEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assessment.id != widget.assessment.id || oldWidget.assessment.version != widget.assessment.version) {
      _working = widget.assessment;
      _titleController.text = _working.title;
      _maxController.text = '${_working.maximumScore}';
      _weightController.text = _working.weight.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _maxController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _setScore(String studentId, String raw) {
    final parsed = raw.trim().isEmpty ? null : double.tryParse(raw);
    setState(() {
      _working = _working.copyWith(
        entries: _working.entries
            .map((e) => e.studentId == studentId ? e.copyWith(score: parsed, clearScore: parsed == null) : e)
            .toList(growable: false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _working;
    final editableDraft = a.teacherEditable;
    final editableScores = a.scoresEditable;

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
                      Text('Score entry', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      Text('One of your own current class subjects.'),
                    ],
                  ),
                ),
                Chip(label: Text(teacherAssessmentStateLabel(a.state))),
              ],
            ),
            const SizedBox(height: 6),
            Text(a.className.isEmpty ? 'Choose a class subject below.' : '${a.className}${a.subject.isEmpty ? '' : ' · ${a.subject}'}'),
            const SizedBox(height: 16),
            if (editableDraft) ...[
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. First CA'),
                onChanged: (v) => _working = _working.copyWith(title: v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<TeacherAssessmentType>(
                      initialValue: a.type,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: [
                        for (final t in TeacherAssessmentType.values)
                          DropdownMenuItem(
                            value: t,
                            child: Text(
                              teacherAssessmentTypeLabel(t),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _working = _working.copyWith(type: v));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Maximum score'),
                      onChanged: (v) => _working = _working.copyWith(maximumScore: int.tryParse(v) ?? _working.maximumScore),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weight'),
                      onChanged: (v) => _working = _working.copyWith(weight: double.tryParse(v) ?? _working.weight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: () => widget.onSaveDraft(_working), child: const Text('Save draft')),
                  FilledButton(onPressed: () => widget.onPublish(_working), child: const Text('Publish · open for scoring')),
                ],
              ),
            ] else if (a.className.isEmpty) ...[
              const Text('Use "+ New assessment" below to start one for a class subject you currently teach.'),
            ] else ...[
              for (final entry in a.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.studentName)),
                      SizedBox(
                        width: 92,
                        child: TextFormField(
                          key: ValueKey('${a.version}-${entry.studentId}-${entry.score}'),
                          initialValue: entry.score?.toStringAsFixed(0) ?? '',
                          enabled: editableScores,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true, hintText: '—'),
                          onChanged: (v) => _setScore(entry.studentId, v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('/${a.maximumScore}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (a.canCorrect) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Correct this score (audited)',
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          onPressed: () => widget.onCorrect(entry),
                        ),
                      ],
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Class average')),
                  Text('${a.average.toStringAsFixed(1)} / ${a.maximumScore}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 14),
              if (editableScores)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(onPressed: () => widget.onSaveScores(_working), child: const Text('Save progress')),
                    FilledButton(onPressed: () => widget.onSubmit(_working), child: const Text('Submit for review')),
                  ],
                )
              else
                const Text(
                  'This assessment is submitted, locked or released. Use the correction control on a row above to make an audited change.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PerformanceInsight extends StatelessWidget {
  const _PerformanceInsight({required this.assessment});
  final TeacherAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final percent = assessment.averagePercent?.round();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance overview', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text(assessment.title.isEmpty ? 'Untitled draft' : '${assessment.title} · ${assessment.className}'),
            const SizedBox(height: 16),
            Text(percent == null ? '—' : '$percent%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 34)),
            Text(percent == null ? 'No scores entered yet' : 'Average of scores entered so far'),
            const SizedBox(height: 16),
            Text('${assessment.entered} of ${assessment.totalStudents} students scored'),
            const SizedBox(height: 12),
            const Text(
              'Deeper AI-assisted performance analysis is not available yet for this assessment.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentRegister extends StatelessWidget {
  const _AssessmentRegister({required this.all, required this.selectedId, required this.onSelect, required this.onCreate});
  final List<TeacherAssessment> all;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Card(
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
                        Text('Assessment register', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Completion status and class performance.'),
                      ],
                    ),
                  ),
                  OutlinedButton(onPressed: onCreate, child: const Text('+ New assessment')),
                ],
              ),
              const SizedBox(height: 14),
              for (final item in all)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: item.id == selectedId,
                  onTap: () => onSelect(item.id),
                  title: Text(
                    item.title.isEmpty ? 'Untitled draft · ${item.className}' : '${item.title} · ${item.className}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${teacherAssessmentTypeLabel(item.type)} · Max ${item.maximumScore} · ${item.entered}/${item.totalStudents} scores entered',
                  ),
                  trailing: Chip(label: Text(teacherAssessmentStateLabel(item.state))),
                ),
            ],
          ),
        ),
      );
}

class _Boundaries extends StatelessWidget {
  const _Boundaries();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assessment controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(teacherAssessmentSaveBoundary),
              SizedBox(height: 8),
              Text(teacherAssessmentSubmissionBoundary),
              SizedBox(height: 8),
              Text(teacherAssessmentCorrectionBoundary),
              SizedBox(height: 8),
              Text(teacherAssessmentAiBoundary),
            ],
          ),
        ),
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
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Assessment data could not be loaded.'),
              const SizedBox(height: 10),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _ClassSubjectPickerDialog extends StatefulWidget {
  const _ClassSubjectPickerDialog({required this.options});
  final List<TeacherAssessmentOption> options;

  @override
  State<_ClassSubjectPickerDialog> createState() => _ClassSubjectPickerDialogState();
}

class _ClassSubjectPickerDialogState extends State<_ClassSubjectPickerDialog> {
  late TeacherAssessmentOption _selected = widget.options.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New assessment'),
        content: SizedBox(
          width: 380,
          child: DropdownButtonFormField<TeacherAssessmentOption>(
            isExpanded: true,
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Class subject'),
            items: [
              for (final option in widget.options) DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selected = v);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(_selected), child: const Text('Continue')),
        ],
      );
}

class _CorrectionDraft {
  const _CorrectionDraft({required this.score, required this.comment});
  final double? score;
  final String comment;
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.entry, required this.maximumScore});
  final TeacherAssessmentEntry entry;
  final int maximumScore;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final _scoreController = TextEditingController(text: widget.entry.score?.toStringAsFixed(0) ?? '');
  final _commentController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _scoreController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _scoreController.text.trim();
    final score = raw.isEmpty ? null : double.tryParse(raw);
    if (raw.isNotEmpty && (score == null || score < 0 || score > widget.maximumScore)) {
      setState(() => _error = 'Score must be between 0 and ${widget.maximumScore}.');
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      setState(() => _error = 'Add a short reason for this correction.');
      return;
    }
    Navigator.of(context).pop(_CorrectionDraft(score: score, comment: _commentController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Correct ${widget.entry.studentName}\'s score'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _scoreController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'New score', hintText: 'out of ${widget.maximumScore}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(labelText: 'Reason for correction'),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Save correction')),
        ],
      );
}
