import 'package:flutter/material.dart';

import '../data/teacher_classes_demo_data.dart';
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
  String _selectedId = 'jss2a';

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
                    return _ErrorCard(
                      onRetry: () => setState(() => _future = widget.repository.load()),
                    );
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
  });

  final String schoolName;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
            Text('$schoolName · Kaduna Campus'),
          ],
        ),
        SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search class or topic...',
              isDense: true,
            ),
          ),
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
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MY TEACHING ASSIGNMENTS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Classes you are responsible for',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Each class connects directly to attendance, lesson plans, syllabus, assignments and assessment work.',
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
          child: Text('No classes are assigned to you yet. The owner or the administrator assigns classes to teachers.'),
        ),
      );
    }
    final filtered = snapshot.assignments.where((item) => item.matches(query)).toList();
    final current = snapshot.assignments.firstWhere(
      (item) => item.id == selectedId,
      orElse: () => snapshot.assignments.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  width: 300,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final focus = _TeachingFocus(item: current, onNavigate: onNavigate);
            const activity = _ClassActivity();
            if (compact) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [],
              )._withChildren([focus, const SizedBox(height: 16), activity]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: focus),
                const SizedBox(width: 16),
                const Expanded(child: activity),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const _BoundaryCard(),
      ],
    );
  }
}

extension on Column {
  Column _withChildren(List<Widget> value) => Column(
        crossAxisAlignment: crossAxisAlignment,
        children: value,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.subject),
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.progress}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${item.students} students · Room ${item.room}'),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: item.progress / 100),
              const SizedBox(height: 10),
              Text('Next: ${item.nextLesson}'),
              const SizedBox(height: 2),
              Text(item.topic, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
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
                      'SELECTED CLASS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${item.name} · ${item.subject}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text('${item.students} students · Room ${item.room} · Next lesson ${item.nextLesson}'),
                  ],
                ),
                const Chip(label: Text('On track')),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DetailKpi(label: 'Attendance', value: '${item.attendance}%', hint: 'Recent average'),
                _DetailKpi(label: 'Class average', value: '${item.classAverage}%', hint: 'Latest assessments'),
                _DetailKpi(label: 'Syllabus', value: '${item.progress}%', hint: 'Term coverage'),
                _DetailKpi(label: 'Pending marking', value: '${item.pendingMarking}', hint: 'Submissions'),
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
  const _DetailKpi({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
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
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  static const _actions = <(String, String, String, IconData)>[
    ('Take attendance', 'Open the attendance register for this class.', 'attendance', Icons.fact_check_outlined),
    ('Lesson plans', 'Create or continue the next class lesson plan.', 'lesson-plans', Icons.description_outlined),
    ('Syllabus progress', 'Track completed and upcoming curriculum topics.', 'syllabus', Icons.menu_book_outlined),
    ('Assignments', 'Create work, mark submissions and review missing work.', 'assignments', Icons.assignment_outlined),
    ('Assessments', 'Enter CA scores and review class performance.', 'assessments', Icons.grading_outlined),
    ('Class students', 'Open the authorized class roster and student profiles.', 'students', Icons.groups_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final action in _actions)
          SizedBox(
            width: 310,
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
                        Text(action.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
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

class _TeachingFocus extends StatelessWidget {
  const _TeachingFocus({required this.item, required this.onNavigate});
  final TeacherClassAssignment item;
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
            Row(
              children: [
                const Expanded(
                  child: Text('Current teaching focus', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
                Chip(label: Text(item.name)),
              ],
            ),
            const SizedBox(height: 12),
            _FocusRow(label: 'Current topic', value: item.topic),
            const _FocusRow(label: 'Next action', value: 'Complete classwork and record coverage'),
            const _FocusRow(label: 'Suggested preparation', value: '5-question recap activity'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onNavigate('ai'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ask Teacher AI for this class'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _ClassActivity extends StatelessWidget {
  const _ClassActivity();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text('Class activity', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ),
                Text('This week'),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in teacherClassActivity)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Class evidence & authority boundary', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(teacherClassesBoundary),
              const SizedBox(height: 8),
              Text(teacherClassAiBoundary, style: Theme.of(context).textTheme.bodySmall),
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
