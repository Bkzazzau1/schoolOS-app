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
  TeacherAssessmentScoreSheet? _draft;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.load();
    });
  }

  void _select(TeacherAssessmentSnapshot snapshot, String id) {
    setState(() {
      _selectedId = id;
      _draft = snapshot.sheets[id];
      _notice = null;
    });
  }

  void _setScore(String studentId, String raw) {
    final current = _draft;
    if (current == null || !current.teacherEditable) return;
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, current.maximumScore);
    setState(() {
      _draft = current.copyWith(
        entries: current.entries
            .map((entry) => entry.studentId == studentId
                ? entry.copyWith(score: clamped)
                : entry)
            .toList(growable: false),
      );
      _notice = null;
    });
  }

  Future<void> _saveProgress() async {
    final current = _draft;
    if (current == null) return;
    final result = await widget.repository.saveProgress(current);
    if (!mounted) return;
    setState(() {
      if (result.sheet != null) _draft = result.sheet;
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  Future<void> _submitScores() async {
    final current = _draft;
    if (current == null) return;
    final result = await widget.repository.submitScores(current);
    if (!mounted) return;
    setState(() {
      if (result.sheet != null) _draft = result.sheet;
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  Future<void> _createAssessment(TeacherAssessmentSnapshot snapshot) async {
    final draft = await showDialog<_NewAssessmentDraft>(
      context: context,
      builder: (context) => _NewAssessmentDialog(classOptions: snapshot.classOptions),
    );
    if (draft == null) return;
    final result = await widget.repository.createAssessment(
      className: draft.className,
      title: draft.title,
      maximumScore: draft.maximumScore,
    );
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
      if (result.success && result.sheet != null) {
        _selectedId = result.sheet!.id;
      }
    });
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
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
        if (_selectedId == null || !data.sheets.containsKey(_selectedId)) {
          _selectedId = data.register.isEmpty ? null : data.register.first.id;
          _draft = _selectedId == null ? null : data.sheets[_selectedId];
        }
        return _content(context, data);
      },
    );
  }

  Widget _content(BuildContext context, TeacherAssessmentSnapshot snapshot) {
    final editable = _draft != null &&
        _draft!.teacherEditable &&
        snapshot.permissions.canEnterScores;
    final entered = snapshot.register.fold<int>(0, (sum, item) => sum + item.entered);
    final total = snapshot.register.fold<int>(0, (sum, item) => sum + item.total);
    final scored = snapshot.register.where((item) => item.entered > 0).toList();
    final averagePercent = scored.isEmpty
        ? null
        : (scored.fold<double>(
                  0,
                  (sum, item) => sum + (item.average / item.maximumScore * 100),
                ) /
                scored.length)
            .round();
    final pending = snapshot.register.where((item) => item.state == TeacherAssessmentRegisterState.inProgress).length;

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
              _KpiCard(label: 'Assessments', value: '${snapshot.register.length}', hint: 'Your assigned classes'),
              _KpiCard(label: 'Scores entered', value: '$entered/$total', hint: 'Across your assessments'),
              _KpiCard(
                label: 'Average score',
                value: averagePercent == null ? '—' : '$averagePercent%',
                hint: averagePercent == null ? 'No scores entered yet' : 'Across assessments with scores',
              ),
              _KpiCard(label: 'Pending submission', value: '$pending', hint: 'Not yet submitted for review'),
            ],
          ),
          const SizedBox(height: 18),
          if (_notice != null) ...[
            _Notice(message: _notice!, success: _noticeSuccess),
            const SizedBox(height: 14),
          ],
          if (snapshot.classOptions.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No classes are assigned to you yet. The owner or the administrator assigns classes to teachers.'),
              ),
            )
          else if (snapshot.register.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No assessments yet for your assigned classes.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _createAssessment(snapshot),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New assessment'),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final scoreCard = _ScoreEntryCard(
                  snapshot: snapshot,
                  selectedId: _selectedId!,
                  draft: _draft!,
                  editable: editable,
                  onSelect: (id) => _select(snapshot, id),
                  onScoreChanged: _setScore,
                  onSave: editable ? _saveProgress : null,
                  onSubmit: editable && snapshot.permissions.canSubmitScores ? _submitScores : null,
                  onShare: () => widget.onNavigate('messages'),
                );
                final insight = _PerformanceInsight(item: snapshot.register.firstWhere((i) => i.id == _selectedId));
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
                return Column(
                  children: [scoreCard, const SizedBox(height: 14), insight],
                );
              },
            ),
          const SizedBox(height: 18),
          _AssessmentRegister(
            register: snapshot.register,
            selectedId: _selectedId,
            onSelect: (id) => _select(snapshot, id),
            onCreate: snapshot.classOptions.isEmpty ? null : () => _createAssessment(snapshot),
          ),
          const SizedBox(height: 18),
          _Boundaries(onNavigate: widget.onNavigate),
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
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                const SizedBox(height: 4),
                Text('Assessments',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                const SizedBox(height: 4),
                const Text('Create tests, enter CA scores and monitor class performance.'),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('classes'),
                child: const Text('My Classes'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('messages'),
                child: const Text('Share work'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('dashboard'),
                child: const Text('Dashboard'),
              ),
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
                Text(value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                const SizedBox(height: 4),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _ScoreEntryCard extends StatelessWidget {
  const _ScoreEntryCard({
    required this.snapshot,
    required this.selectedId,
    required this.draft,
    required this.editable,
    required this.onSelect,
    required this.onScoreChanged,
    required this.onSave,
    required this.onSubmit,
    required this.onShare,
  });

  final TeacherAssessmentSnapshot snapshot;
  final String selectedId;
  final TeacherAssessmentScoreSheet draft;
  final bool editable;
  final ValueChanged<String> onSelect;
  final void Function(String studentId, String raw) onScoreChanged;
  final VoidCallback? onSave;
  final VoidCallback? onSubmit;
  final VoidCallback onShare;

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
                        Text('Score entry',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Enter scores for one of your own created assessments.'),
                      ],
                    ),
                  ),
                  Chip(label: Text(teacherAssessmentSheetStateLabel(draft.state))),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedId,
                decoration: const InputDecoration(labelText: 'Assessment'),
                items: [
                  for (final item in snapshot.register)
                    DropdownMenuItem(value: item.id, child: Text('${item.title} · ${item.className}')),
                ],
                onChanged: (value) {
                  if (value != null) onSelect(value);
                },
              ),
              const SizedBox(height: 14),
              for (final entry in draft.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(snapshot.studentNames[entry.studentId] ?? entry.studentId)),
                      SizedBox(
                        width: 92,
                        child: TextFormField(
                          key: ValueKey('${draft.version}-${entry.studentId}-${entry.score}'),
                          initialValue: '${entry.score}',
                          enabled: editable,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (value) => onScoreChanged(entry.studentId, value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('/${draft.maximumScore}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Class average')),
                  Text('${draft.average.toStringAsFixed(1)} / ${draft.maximumScore}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: onShare, child: const Text('Share results')),
                  OutlinedButton(onPressed: onSave, child: const Text('Save progress')),
                  FilledButton(onPressed: onSubmit, child: const Text('Submit scores')),
                ],
              ),
              if (!editable) ...[
                const SizedBox(height: 12),
                const Text(
                  'This score sheet is locked for teacher editing after submission. Review/locking and result release require the authorized school workflow.',
                ),
              ],
            ],
          ),
        ),
      );
}

class _PerformanceInsight extends StatelessWidget {
  const _PerformanceInsight({required this.item});
  final TeacherAssessmentRegisterItem item;

  @override
  Widget build(BuildContext context) {
    final percent = item.entered == 0 ? null : (item.average / item.maximumScore * 100).round();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance overview', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text('${item.title} · ${item.className}'),
            const SizedBox(height: 16),
            Text(percent == null ? '—' : '$percent%',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 34)),
            Text(percent == null ? 'No scores entered yet' : 'Average of scores entered so far'),
            const SizedBox(height: 16),
            Text('${item.entered} of ${item.total} students scored'),
            const SizedBox(height: 12),
            const Text(
              'Deeper AI-assisted performance analysis (concept mastery, question-level patterns) is not available yet for this assessment.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentRegister extends StatelessWidget {
  const _AssessmentRegister({
    required this.register,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });
  final List<TeacherAssessmentRegisterItem> register;
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
                        Text('Assessment register',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Completion status and class performance.'),
                      ],
                    ),
                  ),
                  OutlinedButton(onPressed: onCreate, child: const Text('+ New assessment')),
                ],
              ),
              const SizedBox(height: 14),
              for (final item in register)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: item.id == selectedId,
                  onTap: () => onSelect(item.id),
                  title: Text('${item.title} · ${item.className}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    'Max ${item.maximumScore} · ${item.entered}/${item.total} scores entered · Average ${item.average.toStringAsFixed(1)}',
                  ),
                  trailing: Chip(
                    label: Text(item.state == TeacherAssessmentRegisterState.complete
                        ? 'Complete'
                        : 'In progress'),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Boundaries extends StatelessWidget {
  const _Boundaries({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assessment controls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(teacherAssessmentSaveBoundary),
              const SizedBox(height: 8),
              const Text(teacherAssessmentSubmissionBoundary),
              const SizedBox(height: 8),
              const Text(teacherAssessmentAiBoundary),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onNavigate('lesson-plans'),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Create revision lesson'),
              ),
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
          color: success
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
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

class _NewAssessmentDraft {
  const _NewAssessmentDraft({required this.className, required this.title, required this.maximumScore});
  final String className;
  final String title;
  final int maximumScore;
}

class _NewAssessmentDialog extends StatefulWidget {
  const _NewAssessmentDialog({required this.classOptions});
  final List<String> classOptions;

  @override
  State<_NewAssessmentDialog> createState() => _NewAssessmentDialogState();
}

class _NewAssessmentDialogState extends State<_NewAssessmentDialog> {
  late String _className = widget.classOptions.first;
  final _titleController = TextEditingController(text: 'CA 1');
  final _maxController = TextEditingController(text: '20');
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final max = int.tryParse(_maxController.text.trim());
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title for the assessment.');
      return;
    }
    if (max == null || max <= 0) {
      setState(() => _error = 'Enter a positive maximum score.');
      return;
    }
    Navigator.of(context).pop(_NewAssessmentDraft(className: _className, title: title, maximumScore: max));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New assessment'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _className,
              decoration: const InputDecoration(labelText: 'Class'),
              items: [
                for (final item in widget.classOptions) DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _className = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. CA 1'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum score'),
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
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
