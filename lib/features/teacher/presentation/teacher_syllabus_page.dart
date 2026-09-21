import 'package:flutter/material.dart';

import '../data/teacher_syllabus_demo_data.dart';
import '../data/teacher_syllabus_repository.dart';
import '../domain/teacher_syllabus_models.dart';

class TeacherSyllabusPage extends StatefulWidget {
  const TeacherSyllabusPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherSyllabusRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherSyllabusPage> createState() => _TeacherSyllabusPageState();
}

class _TeacherSyllabusPageState extends State<TeacherSyllabusPage> {
  late Future<TeacherSyllabusSnapshot> _future;
  final _search = TextEditingController();
  String _className = teacherSyllabusClassOptions.first;
  String _query = '';
  String? _notice;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  Future<void> _mark(
    TeacherSyllabusRow row,
    TeacherSyllabusStatus status,
  ) async {
    final result = await widget.repository.markStatus(row: row, status: status);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) {
      widget.onMutationQueued();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherSyllabusSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry syllabus'),
            ),
          );
        }

        final data = snapshot.requireData;
        final classRows = data.rows
            .where((row) => row.className == _className)
            .toList(growable: false);
        final visible = classRows
            .where(
              (row) => row.matches(
                _query,
                reportedStatus: data.progress[row.id]?.reportedStatus,
              ),
            )
            .toList(growable: false);
        final completed = visible
            .where((row) => data.effectiveStatus(row) == TeacherSyllabusStatus.completed)
            .length;
        final plannedLessons = visible.fold<int>(
          0,
          (sum, row) => sum + row.plannedLessons,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Topbar(onNavigate: widget.onNavigate),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _Notice(text: _notice!),
              ],
              const SizedBox(height: 16),
              _Hero(
                className: _className,
                onClassChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _className = value;
                    _query = '';
                    _search.clear();
                    _notice = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Stat(label: 'Completed topics', value: '$completed', hint: 'selected class'),
                  const _Stat(label: 'Current week', value: '6', hint: 'term calendar'),
                  _Stat(label: 'Planned lessons', value: '$plannedLessons', hint: 'visible weeks'),
                  _Stat(
                    label: 'Pacing status',
                    value: teacherSyllabusPacingLabel(_className),
                    hint: 'AI-assisted check',
                  ),
                ],
              ),
              if (_className == 'JSS 2B') ...[
                const SizedBox(height: 16),
                _PacingAlert(onNavigate: widget.onNavigate),
              ],
              const SizedBox(height: 16),
              _SchemePanel(
                rows: visible,
                snapshot: data,
                searchController: _search,
                onSearch: (value) => setState(() => _query = value),
                onMark: _mark,
                onNavigate: widget.onNavigate,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _AiInsight(
                      className: _className,
                      onNavigate: widget.onNavigate,
                    ),
                    const _Controls(),
                  ];
                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cards[0], const SizedBox(height: 12), cards[1]],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const _BoundaryCard(),
            ],
          ),
        );
      },
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.onNavigate});
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
              const Text('TEACHER PORTAL · SYLLABUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Syllabus Tracker', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Text('Track where each assigned class should be, what has been taught and what comes next.'),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('lesson-plans'), child: const Text('Lesson plans')),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.className, required this.onClassChanged});
  final String className;
  final ValueChanged<String?> onClassChanged;

  @override
  Widget build(BuildContext context) {
    final progress = teacherSyllabusProgressByClass[className] ?? 0;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
        isExpanded: true,
                initialValue: className,
                decoration: const InputDecoration(labelText: 'Selected class'),
                items: [
                  for (final item in teacherSyllabusClassOptions)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: onClassChanged,
              ),
            ),
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Curriculum coverage')),
                      Text('$progress%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress / 100),
                  const SizedBox(height: 6),
                  Text(teacherSyllabusPacingHint(className)),
                ],
              ),
            ),
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Next planned topic'),
                  Text(
                    teacherSyllabusNextTopic(className),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const Text('Use this to prepare the next lesson plan'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _PacingAlert extends StatelessWidget {
  const _PacingAlert({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const SizedBox(
                width: 650,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pacing alert', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('This class is approximately two lessons behind the expected position. Consider revision consolidation and avoid skipping prerequisite material.'),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => onNavigate('lesson-plans'),
                child: const Text('Plan recovery lesson'),
              ),
            ],
          ),
        ),
      );
}

class _SchemePanel extends StatelessWidget {
  const _SchemePanel({
    required this.rows,
    required this.snapshot,
    required this.searchController,
    required this.onSearch,
    required this.onMark,
    required this.onNavigate,
  });

  final List<TeacherSyllabusRow> rows;
  final TeacherSyllabusSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final Future<void> Function(TeacherSyllabusRow, TeacherSyllabusStatus) onMark;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scheme of work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('Update progress only for classes assigned to you.'),
                  ],
                ),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearch,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search topics or weeks...',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No syllabus rows match your search.'),
              )
            else
              ...[
                for (final row in rows)
                  _SchemeRow(
                    row: row,
                    status: snapshot.effectiveStatus(row),
                    reported: snapshot.progress.containsKey(row.id),
                    canReport: snapshot.permissions.canReportCoverage,
                    onMark: onMark,
                    onNavigate: onNavigate,
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _SchemeRow extends StatelessWidget {
  const _SchemeRow({
    required this.row,
    required this.status,
    required this.reported,
    required this.canReport,
    required this.onMark,
    required this.onNavigate,
  });

  final TeacherSyllabusRow row;
  final TeacherSyllabusStatus status;
  final bool reported;
  final bool canReport;
  final Future<void> Function(TeacherSyllabusRow, TeacherSyllabusStatus) onMark;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Week'),
                Text('${row.week}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          SizedBox(
            width: 330,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Topic'),
                Text(row.topic, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('${row.plannedLessons} planned lessons'),
              ],
            ),
          ),
          Chip(
            label: Text(
              reported
                  ? '${teacherSyllabusStatusLabel(status)} · teacher reported'
                  : teacherSyllabusStatusLabel(status),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: canReport ? () => onMark(row, TeacherSyllabusStatus.completed) : null,
                child: const Text('Mark complete'),
              ),
              OutlinedButton(
                onPressed: canReport ? () => onMark(row, TeacherSyllabusStatus.inProgress) : null,
                child: const Text('In progress'),
              ),
              TextButton(
                onPressed: () => onNavigate('lesson-plans'),
                child: const Text('Create plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiInsight extends StatelessWidget {
  const _AiInsight({required this.className, required this.onNavigate});
  final String className;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Teacher AI pacing insight', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              Text(teacherSyllabusAiInsight(className)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => onNavigate('ai'),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Ask AI for pacing plan'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Curriculum controls', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              SizedBox(height: 12),
              Text('Teacher updates progress', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('You can report what has been taught, but cannot silently change the school-approved scheme.'),
              SizedBox(height: 12),
              Text('Leadership approves changes', style: TextStyle(fontWeight: FontWeight.w900)),
              Text('Topic reordering, removal or curriculum replacement should require authorized academic approval.'),
            ],
          ),
        ),
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Syllabus authority boundary', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text(teacherSyllabusAuthorityBoundary),
              SizedBox(height: 6),
              Text(teacherSyllabusAiBoundary),
              SizedBox(height: 6),
              Text(teacherSyllabusOfflineBoundary),
            ],
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}
