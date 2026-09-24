import 'package:flutter/material.dart';

import '../data/teacher_classes_repository.dart';
import '../domain/teacher_classes_models.dart';

class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onNavigate,
  });

  final String schoolName;
  final TeacherClassesRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  late Future<TeacherClassesSnapshot> _future;
  final _queryController = TextEditingController();
  String _query = '';
  String _selectedId = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _future = widget.repository.load();
      });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                schoolName: widget.schoolName,
                controller: _queryController,
                onChanged: (value) => setState(() => _query = value),
                onRefresh: _reload,
              ),
              const SizedBox(height: 16),
              _Hero(onNavigate: widget.onNavigate),
              const SizedBox(height: 16),
              FutureBuilder<TeacherClassesSnapshot>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return _ErrorCard(onRetry: _reload);
                  }
                  return _ClassesContent(
                    snapshot: snapshot.requireData,
                    query: _query,
                    selectedId: _selectedId,
                    onSelect: (id) => setState(() => _selectedId = id),
                    onNavigate: widget.onNavigate,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.controller,
    required this.onChanged,
    required this.onRefresh,
  });

  final String schoolName;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TEACHER WORKSPACE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'My Classes',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(schoolName),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search class, subject or topic...',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh assignments',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
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
                    'CANONICAL TEACHING RESPONSIBILITY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classes assigned to your Teacher account',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'These assignments come from the school curriculum and Principal teaching assignments. Session, class, subject, periods and current-term topics are server-authoritative.',
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => onNavigate('timetable'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('View timetable'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassesContent extends StatelessWidget {
  const _ClassesContent({
    required this.snapshot,
    required this.query,
    required this.selectedId,
    required this.onSelect,
    required this.onNavigate,
  });

  final TeacherClassesSnapshot snapshot;
  final String query;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (snapshot.assignments.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No active teaching assignments',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              SizedBox(height: 6),
              Text(
                'A Principal must assign a subject from the canonical class curriculum to your active Teacher account before it appears here.',
              ),
            ],
          ),
        ),
      );
    }

    final filtered = snapshot.assignments
        .where((item) => item.matches(query))
        .toList(growable: false);
    final current = snapshot.assignments.firstWhere(
      (item) => item.id == selectedId,
      orElse: () => snapshot.assignments.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(snapshot: snapshot),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No assigned classes match your search.'),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in filtered)
                SizedBox(
                  width: 310,
                  child: _ClassOverviewCard(
                    item: item,
                    selected: item.id == current.id,
                    onTap: () => onSelect(item.id),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        _ClassDetail(item: current, onNavigate: onNavigate),
        const SizedBox(height: 16),
        _TopicsCard(item: current, onNavigate: onNavigate),
        const SizedBox(height: 16),
        const _BoundaryCard(),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final TeacherClassesSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final periods = snapshot.assignments.fold<int>(
      0,
      (sum, item) => sum + item.periodsPerWeek,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Metric(label: 'Assignments', value: '${snapshot.assignments.length}'),
        _Metric(label: 'Periods / week', value: '$periods'),
        _Metric(label: 'Roster entries', value: '${snapshot.totalStudents}'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ClassOverviewCard extends StatelessWidget {
  const _ClassOverviewCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TeacherClassAssignment item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: selected ? scheme.primaryContainer.withValues(alpha: .55) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.subject),
              const SizedBox(height: 2),
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 10),
              _MetaLine(
                icon: Icons.calendar_today_outlined,
                text: item.sessionName.isNotEmpty
                    ? item.sessionName
                    : (item.sessionId.isNotEmpty ? item.sessionId : 'Session not published'),
              ),
              _MetaLine(
                icon: Icons.schedule_outlined,
                text: item.periodsPerWeek > 0
                    ? '${item.periodsPerWeek} periods/week'
                    : 'Periods not configured',
              ),
              _MetaLine(
                icon: Icons.groups_outlined,
                text: '${item.students} current students',
              ),
              _MetaLine(
                icon: Icons.menu_book_outlined,
                text: item.currentTerm.isNotEmpty
                    ? item.currentTerm
                    : 'No active term',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 7),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _ClassDetail extends StatelessWidget {
  const _ClassDetail({required this.item, required this.onNavigate});

  final TeacherClassAssignment item;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED CANONICAL ASSIGNMENT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${item.name} · ${item.subject}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                if (item.currentTerm.isNotEmpty)
                  Chip(label: Text(item.currentTerm)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailKpi(
                  label: 'Academic session',
                  value: item.sessionName.isNotEmpty
                      ? item.sessionName
                      : (item.sessionId.isNotEmpty ? item.sessionId : '—'),
                  hint: 'Canonical session',
                ),
                _DetailKpi(
                  label: 'Periods / week',
                  value: item.periodsPerWeek > 0 ? '${item.periodsPerWeek}' : '—',
                  hint: 'From class curriculum',
                ),
                _DetailKpi(
                  label: 'Current students',
                  value: '${item.students}',
                  hint: 'Active class roster',
                ),
                _DetailKpi(
                  label: 'Attendance',
                  value: item.attendance > 0 ? '${item.attendance}%' : '—',
                  hint: 'Latest recorded register',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ActionGrid(onNavigate: onNavigate),
          ],
        ),
      ),
    );
  }
}

class _DetailKpi extends StatelessWidget {
  const _DetailKpi({
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _TopicsCard extends StatelessWidget {
  const _TopicsCard({required this.item, required this.onNavigate});

  final TeacherClassAssignment item;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final topics = [...item.curriculumTopics]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.currentTerm.isEmpty
                          ? 'Current-term curriculum'
                          : '${item.currentTerm} curriculum',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 3),
                    const Text('Topics published for this class-subject assignment.'),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => onNavigate('syllabus'),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open syllabus'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (topics.isEmpty)
              const Text(
                'No topics have been published for the active term yet.',
              )
            else
              for (final topic in topics)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text('${topic.sequence}'),
                  ),
                  title: Text(
                    topic.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: topic.description.trim().isEmpty
                      ? null
                      : Text(topic.description),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  static const _actions = <(String, String, String, IconData)>[
    ('Take attendance', 'Open the attendance register.', 'attendance', Icons.fact_check_outlined),
    ('Lesson plans', 'Prepare teaching from the class curriculum.', 'lesson-plans', Icons.description_outlined),
    ('Syllabus', 'Review current-term curriculum topics.', 'syllabus', Icons.menu_book_outlined),
    ('Assignments', 'Create and review class work.', 'assignments', Icons.assignment_outlined),
    ('Assessments', 'Open continuous assessment work.', 'assessments', Icons.grading_outlined),
    ('Class students', 'Open the authorized current roster.', 'students', Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final action in _actions)
          SizedBox(
            width: 300,
            child: OutlinedButton(
              onPressed: () => onNavigate(action.$3),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(action.$4),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.$1,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(action.$2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assignment authority',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                'Teachers can work only with classes and subjects published to their own active Teacher membership. Class membership follows the pupils’ current enrollment; promotion, transfer or graduation must not leave a pupil attached to an old teaching roster.',
              ),
            ],
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Could not load assigned classes.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
