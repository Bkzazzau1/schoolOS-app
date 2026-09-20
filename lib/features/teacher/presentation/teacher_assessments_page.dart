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
  TeacherAssessmentScoreSheet? _sheet;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load().then((snapshot) {
      _sheet ??= snapshot.sheet;
      return snapshot;
    });
  }

  void _setScore(String studentId, String raw) {
    final current = _sheet;
    if (current == null || !current.teacherEditable) return;
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    final clamped = parsed.clamp(0, current.maximumScore);
    setState(() {
      _sheet = current.copyWith(
        entries: current.entries
            .map((entry) => entry.studentId == studentId
                ? entry.copyWith(score: clamped)
                : entry)
            .toList(growable: false),
      );
      _notice = null;
    });
  }

  void _setClass(String? value) {
    final current = _sheet;
    if (current == null || value == null || !current.teacherEditable) return;
    setState(() => _sheet = current.copyWith(className: value));
  }

  void _setAssessment(String? value) {
    final current = _sheet;
    if (current == null || value == null || !current.teacherEditable) return;
    final max = value.contains('30 marks') ? 30 : 20;
    setState(() => _sheet = current.copyWith(
          assessmentLabel: value,
          maximumScore: max,
          entries: current.entries
              .map((entry) => entry.copyWith(score: entry.score.clamp(0, max)))
              .toList(growable: false),
        ));
  }

  Future<void> _saveProgress() async {
    final current = _sheet;
    if (current == null) return;
    final result = await widget.repository.saveProgress(current);
    if (!mounted) return;
    setState(() {
      if (result.sheet != null) _sheet = result.sheet;
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) widget.onMutationQueued();
  }

  Future<void> _submitScores() async {
    final current = _sheet;
    if (current == null) return;
    final result = await widget.repository.submitScores(current);
    if (!mounted) return;
    setState(() {
      if (result.sheet != null) _sheet = result.sheet;
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) widget.onMutationQueued();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAssessmentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || _sheet == null) {
          return _ErrorState(onRetry: () {
            setState(() {
              _sheet = null;
              _future = widget.repository.load().then((value) {
                _sheet = value.sheet;
                return value;
              });
            });
          });
        }
        return _content(context, snapshot.data!);
      },
    );
  }

  Widget _content(BuildContext context, TeacherAssessmentSnapshot snapshot) {
    final sheet = _sheet!;
    final editable = sheet.teacherEditable && snapshot.permissions.canEnterScores;
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
              for (final item in teacherAssessmentKpis)
                _KpiCard(label: item.$1, value: item.$2, hint: item.$3),
            ],
          ),
          const SizedBox(height: 18),
          if (_notice != null) ...[
            _Notice(message: _notice!, success: _noticeSuccess),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final scoreCard = _ScoreEntryCard(
                sheet: sheet,
                editable: editable,
                onClassChanged: _setClass,
                onAssessmentChanged: _setAssessment,
                onScoreChanged: _setScore,
                onSave: editable ? _saveProgress : null,
                onSubmit: editable && snapshot.permissions.canSubmitScores
                    ? _submitScores
                    : null,
                onShare: () => widget.onNavigate('messages'),
              );
              const insight = _PerformanceInsight();
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
          _AssessmentRegister(register: snapshot.register),
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
    required this.sheet,
    required this.editable,
    required this.onClassChanged,
    required this.onAssessmentChanged,
    required this.onScoreChanged,
    required this.onSave,
    required this.onSubmit,
    required this.onShare,
  });

  final TeacherAssessmentScoreSheet sheet;
  final bool editable;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onAssessmentChanged;
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
                        Text('Enter CA scores for a selected assigned class.'),
                      ],
                    ),
                  ),
                  Chip(label: Text(teacherAssessmentSheetStateLabel(sheet.state))),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 520
                    ? Column(
                        children: [
                          _classSelect(),
                          const SizedBox(height: 10),
                          _assessmentSelect(),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _classSelect()),
                          const SizedBox(width: 10),
                          Expanded(child: _assessmentSelect()),
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              for (final entry in sheet.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.studentId)),
                      SizedBox(
                        width: 92,
                        child: TextFormField(
                          key: ValueKey('${sheet.version}-${entry.studentId}-${entry.score}'),
                          initialValue: '${entry.score}',
                          enabled: editable,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true),
                          onChanged: (value) => onScoreChanged(entry.studentId, value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('/${sheet.maximumScore}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(child: Text('Demo average')),
                  Text('${sheet.average.toStringAsFixed(1)} / ${sheet.maximumScore}',
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

  Widget _classSelect() => DropdownButtonFormField<String>(
        value: sheet.className,
        decoration: const InputDecoration(labelText: 'Class'),
        items: [
          for (final item in teacherAssessmentClassOptions)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: editable ? onClassChanged : null,
      );

  Widget _assessmentSelect() => DropdownButtonFormField<String>(
        value: sheet.assessmentLabel,
        decoration: const InputDecoration(labelText: 'Assessment'),
        items: [
          for (final item in teacherAssessmentOptions)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: editable ? onAssessmentChanged : null,
      );
}

class _PerformanceInsight extends StatelessWidget {
  const _PerformanceInsight();

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
                        Text('Performance insight',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Class-level assessment intelligence.'),
                      ],
                    ),
                  ),
                  const Chip(label: Text('AI ANALYSIS')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('$teacherAssessmentCurrentAverage%',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 34)),
              const Text('JSS 2B current average'),
              const SizedBox(height: 16),
              for (final metric in teacherAssessmentMetrics) ...[
                Row(
                  children: [
                    Expanded(child: Text(metric.$1)),
                    Text('${metric.$2}%',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(value: metric.$2 / 100),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teacher AI observation',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text(teacherAssessmentAiObservation),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _AssessmentRegister extends StatelessWidget {
  const _AssessmentRegister({required this.register});
  final List<TeacherAssessmentRegisterItem> register;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assessment register',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        Text('Completion status and class performance.'),
                      ],
                    ),
                  ),
                  OutlinedButton(onPressed: null, child: Text('+ New assessment')),
                ],
              ),
              const SizedBox(height: 14),
              for (final item in register)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.title} · ${item.className}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    'Max ${item.maximumScore} · ${item.entered}/${item.total} scores entered · Average ${item.average}',
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
              const SizedBox(height: 8),
              const Text(teacherAssessmentInterventionBoundary),
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
