import 'package:flutter/material.dart';

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
  String? _className;
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

  Future<void> _markDemo(
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
        if (data.classes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No active curriculum topics are available for your assigned classes.',
              ),
            ),
          );
        }
        if (_className == null || !data.classes.contains(_className)) {
          _className = data.classes.first;
        }
        final className = _className!;
        final classRows = data.rows
            .where((row) => row.className == className)
            .toList(growable: false);
        final visible = classRows
            .where(
              (row) => row.matches(
                _query,
                reportedStatus: data.progress[row.id]?.reportedStatus,
              ),
            )
            .toList(growable: false);
        final completed = classRows
            .where(
              (row) =>
                  data.effectiveStatus(row) == TeacherSyllabusStatus.completed,
            )
            .length;
        final inProgress = classRows
            .where(
              (row) =>
                  data.effectiveStatus(row) == TeacherSyllabusStatus.inProgress,
            )
            .length;
        final deliveredLessons = classRows.fold<int>(
          0,
          (sum, row) => sum + (data.progress[row.id]?.deliveredLessons ?? 0),
        );
        final next = data.nextTopic(className);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Topbar(
                canonical: data.canonical,
                onNavigate: widget.onNavigate,
              ),
              if (_notice != null) ...[
                const SizedBox(height: 12),
                _Notice(text: _notice!),
              ],
              const SizedBox(height: 16),
              _Hero(
                className: className,
                classOptions: data.classes,
                coverage: data.coverageOf(className),
                nextTopic: next?.topic ?? 'All approved topics completed',
                canonical: data.canonical,
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
                  _Stat(
                    label: 'Completed topics',
                    value: '$completed/${classRows.length}',
                    hint: data.canonical ? 'delivery-backed' : 'demo reporting',
                  ),
                  _Stat(
                    label: 'In progress',
                    value: '$inProgress',
                    hint: 'topics with delivery evidence',
                  ),
                  _Stat(
                    label: 'Delivered lessons',
                    value: '$deliveredLessons',
                    hint: data.canonical ? 'server accepted' : 'demo evidence',
                  ),
                  _Stat(
                    label: 'Coverage',
                    value: '${data.coverageOf(className)}%',
                    hint: data.canonical
                        ? 'not a pacing judgement'
                        : 'demo syllabus coverage',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SchemePanel(
                rows: visible,
                snapshot: data,
                searchController: _search,
                onSearch: (value) => setState(() => _query = value),
                onMarkDemo: _markDemo,
                onNavigate: widget.onNavigate,
              ),
              const SizedBox(height: 16),
              _EvidenceBoundary(
                canonical: data.canonical,
                onNavigate: widget.onNavigate,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.canonical, required this.onNavigate});

  final bool canonical;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEACHER PORTAL · SYLLABUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Syllabus Progress',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  canonical
                      ? 'Coverage is derived from server-accepted delivered lessons. This screen cannot manufacture curriculum completion.'
                      : 'Standalone demo syllabus tracker.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('lesson-plans'),
                child: const Text('Lesson Plans & Delivery'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('timetable'),
                child: const Text('Timetable'),
              ),
            ],
          ),
        ],
      );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.className,
    required this.classOptions,
    required this.coverage,
    required this.nextTopic,
    required this.canonical,
    required this.onClassChanged,
  });

  final String className;
  final List<String> classOptions;
  final int coverage;
  final String nextTopic;
  final bool canonical;
  final ValueChanged<String?> onClassChanged;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: className,
                  decoration: const InputDecoration(labelText: 'Assigned class'),
                  items: [
                    for (final item in classOptions)
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
                        Text(
                          '$coverage%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: coverage / 100),
                    const SizedBox(height: 6),
                    Text(
                      canonical
                          ? 'Completed only when delivery evidence says the topic was completed.'
                          : 'Demo-reported coverage.',
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Next incomplete topic'),
                    Text(
                      nextTopic,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const Text('Open Lesson Plans & Delivery to plan the real occurrence.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
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
    required this.onMarkDemo,
    required this.onNavigate,
  });

  final List<TeacherSyllabusRow> rows;
  final TeacherSyllabusSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final Future<void> Function(TeacherSyllabusRow, TeacherSyllabusStatus)
      onMarkDemo;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Approved scheme of work',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        snapshot.canonical
                            ? 'Progress shown below comes from delivered lesson evidence.'
                            : 'Demo mode allows direct progress reporting.',
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearch,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search topics...',
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
                  child: Text('No syllabus rows match this search.'),
                )
              else
                for (final row in rows)
                  _SchemeRow(
                    row: row,
                    status: snapshot.effectiveStatus(row),
                    progress: snapshot.progress[row.id],
                    canonical: snapshot.canonical,
                    onMarkDemo: onMarkDemo,
                    onNavigate: onNavigate,
                  ),
            ],
          ),
        ),
      );
}

class _SchemeRow extends StatelessWidget {
  const _SchemeRow({
    required this.row,
    required this.status,
    required this.progress,
    required this.canonical,
    required this.onMarkDemo,
    required this.onNavigate,
  });

  final TeacherSyllabusRow row;
  final TeacherSyllabusStatus status;
  final TeacherSyllabusProgressRecord? progress;
  final bool canonical;
  final Future<void> Function(TeacherSyllabusRow, TeacherSyllabusStatus)
      onMarkDemo;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final evidence = progress == null
        ? 'No delivered lesson evidence yet'
        : '${progress!.deliveredLessons} delivered lesson(s)'
            '${progress!.latestDeliveryDate.isEmpty ? '' : ' · latest ${progress!.latestDeliveryDate}'}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
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
                const Text('Sequence'),
                Text(
                  '${row.week}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.topic, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(evidence),
              ],
            ),
          ),
          Chip(label: Text(teacherSyllabusStatusLabel(status))),
          if (canonical)
            FilledButton.tonal(
              onPressed: () => onNavigate('lesson-plans'),
              child: const Text('Open delivery evidence'),
            )
          else
            Wrap(
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      onMarkDemo(row, TeacherSyllabusStatus.completed),
                  child: const Text('Mark complete'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      onMarkDemo(row, TeacherSyllabusStatus.inProgress),
                  child: const Text('In progress'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EvidenceBoundary extends StatelessWidget {
  const _EvidenceBoundary({required this.canonical, required this.onNavigate});

  final bool canonical;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Syllabus evidence boundary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                canonical
                    ? 'A Teacher cannot directly mark a canonical topic complete here. The server derives In progress / Completed from accepted Lesson Delivery records tied to real timetable occurrences and approved lesson plans.'
                    : 'Demo progress is local-only and does not represent server curriculum authority.',
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => onNavigate('lesson-plans'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Open Lesson Plans & Delivery'),
              ),
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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}
