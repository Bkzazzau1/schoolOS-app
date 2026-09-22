import 'package:flutter/material.dart';

import '../data/teacher_learning_progress_demo_data.dart';
import '../data/teacher_learning_progress_repository.dart';
import '../domain/teacher_learning_progress_models.dart';

class TeacherLearningProgressPage extends StatefulWidget {
  const TeacherLearningProgressPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final TeacherLearningProgressRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<TeacherLearningProgressPage> createState() =>
      _TeacherLearningProgressPageState();
}

class _TeacherLearningProgressPageState
    extends State<TeacherLearningProgressPage> {
  late Future<TeacherLearningProgressSnapshot> _future;
  String _classFilter = 'All classes';
  String _selectedId = 'STU-001';
  String _evidence = 'All evidence';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherLearningProgressSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(onRetry: () {
              setState(() {
                _future = widget.repository.load();
              });
            });
          }
          return _content(snapshot.data!);
        },
      );

  Widget _content(TeacherLearningProgressSnapshot snapshot) {
    final visible = snapshot.students
        .where((student) =>
            _classFilter == 'All classes' || student.className == _classFilter)
        .toList(growable: false);
    final selected = visible.firstWhere(
      (student) => student.id == _selectedId,
      orElse: () => visible.isNotEmpty ? visible.first : snapshot.students.first,
    );

    if (selected.id != _selectedId && visible.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedId != selected.id) {
          setState(() => _selectedId = selected.id);
        }
      });
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(),
        const SizedBox(height: 16),
        _kpis(),
        const SizedBox(height: 16),
        _evidenceFlow(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final directory = _studentDirectory(visible, selected);
            final summary = _studentSummary(selected);
            if (!wide) {
              return Column(
                children: [directory, const SizedBox(height: 14), summary],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: directory),
                const SizedBox(width: 14),
                Expanded(flex: 7, child: summary),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _topicMatrix(selected),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final interpretation = _interpretationPanel();
            final actions = _actionQueue();
            if (!wide) {
              return Column(
                children: [interpretation, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: interpretation),
                const SizedBox(width: 14),
                Expanded(child: actions),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _governance(),
      ],
    );
  }

  Widget _header() => Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEACHER PORTAL · LEARNING PROGRESS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Learning Progress & Performance',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'Combine classwork, assignments, assessments and CBT evidence to identify the exact subjects and topics that need more teaching support.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => widget.onNavigate('assignments'),
                child: const Text('Assignments'),
              ),
              OutlinedButton(
                onPressed: () => widget.onNavigate('assessments'),
                child: const Text('Assessments'),
              ),
              OutlinedButton(
                onPressed: () => widget.onNavigate('cbt'),
                child: const Text('CBT Practice'),
              ),
              OutlinedButton(
                onPressed: () => widget.onNavigate('students'),
                child: const Text('Students'),
              ),
            ],
          ),
        ],
      );

  Widget _kpis() => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in teacherLearningProgressKpis)
            SizedBox(
              width: 230,
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
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(item.$3, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _evidenceFlow() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One learning evidence model',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in teacherLearningEvidenceFlow)
                    Container(
                      width: 190,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text(item.$2, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _studentDirectory(
    List<TeacherLearningStudentEvidence> visible,
    TeacherLearningStudentEvidence selected,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Students',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('Select a learner to inspect evidence by topic.'),
                    ],
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _classFilter,
                      isExpanded: true,
                      items: const [
                        'All classes',
                        'JSS 2A',
                        'JSS 2B',
                        'JSS 3A',
                      ]
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _classFilter = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final student in visible) ...[
                InkWell(
                  onTap: () => setState(() => _selectedId = student.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected.id == student.id
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${student.className} · ${student.subject}'),
                              Text(student.id,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        _miniMetric('${student.average}%', 'Avg'),
                        const SizedBox(width: 12),
                        _miniMetric('${student.attendance}%', 'Attendance'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      );

  Widget _miniMetric(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _studentSummary(TeacherLearningStudentEvidence selected) {
    final weakest = selected.weakestTopic;
    final strongest = selected.strongestTopic;
    final suggestion = weakest.trend < 0
        ? '${weakest.name} is declining across more than one evidence source. Re-teach the core concept with guided examples, then collect another short classwork sample before deciding whether the support should continue.'
        : '${weakest.name} remains the lowest-evidence topic, but the recent trend is improving. Continue focused practice and review again after the next assignment or CBT set.';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    Text('${selected.className} · ${selected.subject}'),
                  ],
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: _evidence,
                    isExpanded: true,
                    items: const [
                      'All evidence',
                      'Classwork',
                      'Assignments',
                      'Assessments',
                      'CBT',
                    ]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ))
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _evidence = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _highlight('Current average', '${selected.average}%'),
                _highlight('Attendance context', '${selected.attendance}%'),
                _highlight('Main practice area', weakest.name,
                    detail: '${weakest.combined}% combined evidence', watch: true),
                _highlight('Strongest topic', strongest.name,
                    detail: '${strongest.combined}% combined evidence'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suggested next teaching action',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(suggestion),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlight(String label, String value,
          {String? detail, bool watch = false}) =>
      Container(
        width: 190,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: watch
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      );

  Widget _topicMatrix(TeacherLearningStudentEvidence selected) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Topic evidence matrix',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text(
                  'Compare evidence sources before deciding that a learner has a weak area.'),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Topic')),
                    DataColumn(label: Text('Classwork')),
                    DataColumn(label: Text('Assignment')),
                    DataColumn(label: Text('Assessment')),
                    DataColumn(label: Text('CBT')),
                    DataColumn(label: Text('Combined')),
                    DataColumn(label: Text('Trend')),
                  ],
                  rows: [
                    for (final topic in selected.topics)
                      DataRow(cells: [
                        DataCell(Text(topic.name,
                            style: const TextStyle(fontWeight: FontWeight.w800))),
                        DataCell(Text('${topic.classwork}%')),
                        DataCell(Text('${topic.assignment}%')),
                        DataCell(Text('${topic.assessment}%')),
                        DataCell(Text('${topic.cbt}%')),
                        DataCell(Text('${topic.combined}%')),
                        DataCell(Text('${topic.trend > 0 ? '+' : ''}${topic.trend}%')),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _interpretationPanel() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Evidence interpretation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('Look for patterns, not one bad score.'),
              const SizedBox(height: 12),
              for (final item in teacherLearningInterpretationPrinciples) ...[
                Text(item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(item.$2),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );

  Widget _actionQueue() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Teacher action queue',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('Supportive next steps generated from current evidence.'),
              const SizedBox(height: 12),
              for (final action in teacherLearningSupportActions) ...[
                Text('${action.student} · ${action.topic}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(action.detail),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () => widget.onNavigate(action.destination),
                  child: Text(action.actionLabel),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );

  Widget _governance() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Learning Intelligence rule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text(teacherLearningGovernanceBoundary),
              SizedBox(height: 10),
              Text(teacherLearningEvidenceBoundary),
              SizedBox(height: 10),
              Text(teacherLearningOfflineBoundary),
            ],
          ),
        ),
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
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 10),
              const Text('Learning Progress could not be loaded.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
