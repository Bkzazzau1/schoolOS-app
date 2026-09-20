import 'package:flutter/material.dart';

import '../data/teacher_dashboard_demo_data.dart';
import '../domain/teacher_dashboard_models.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({
    super.key,
    required this.schoolName,
    required this.onNavigate,
  });

  final String schoolName;
  final ValueChanged<String> onNavigate;

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  final _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = teacherStudentReview.where((item) => item.matches(_query)).toList();
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
              _Welcome(onNavigate: widget.onNavigate),
              const SizedBox(height: 16),
              _AiBrief(onNavigate: widget.onNavigate),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in teacherKpis)
                    SizedBox(
                      width: compact ? double.infinity : 210,
                      child: _KpiCard(item: item),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _pair(
                compact,
                _Panel(
                  title: "Today's timetable",
                  subtitle: 'Your teaching schedule for today',
                  actionLabel: 'Open full timetable',
                  onAction: () => widget.onNavigate('timetable'),
                  child: const _ScheduleList(),
                ),
                _Panel(
                  title: 'My action list',
                  subtitle: 'What needs your attention',
                  child: _TaskList(onNavigate: widget.onNavigate),
                ),
              ),
              const SizedBox(height: 16),
              _pair(
                compact,
                _Panel(
                  title: 'My classes',
                  subtitle: 'Class size, next lesson and curriculum progress',
                  child: _ClassList(onNavigate: widget.onNavigate),
                ),
                _Panel(
                  title: 'Students needing attention',
                  subtitle: 'Generated from attendance and academic trends',
                  actionLabel: 'Open learning evidence',
                  onAction: () => widget.onNavigate('learning-progress'),
                  child: _StudentList(items: students),
                ),
              ),
              const SizedBox(height: 16),
              _pair(
                compact,
                _Panel(
                  title: 'Planning, weekly learning & evidence',
                  subtitle: 'One connected teaching workflow',
                  child: _PlanningSummary(onNavigate: widget.onNavigate),
                ),
                _Panel(
                  title: 'My performance',
                  subtitle: 'Private professional dashboard',
                  actionLabel: 'Open my performance',
                  onAction: () => widget.onNavigate('performance'),
                  child: const _PerformanceSummary(),
                ),
              ),
              const SizedBox(height: 16),
              const _BoundaryCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _pair(bool compact, Widget first, Widget second) {
    if (compact) {
      return Column(children: [first, const SizedBox(height: 16), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
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
            const Text('TEACHER WORKSPACE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text('$schoolName · Kaduna Campus'),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search students, classes, tasks...',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(teacherDateLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Good morning, Mrs. Amina.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('You have 4 lessons today, a weekly learning update to publish, and topic-level learning evidence ready for review.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: () => onNavigate('learning-progress'), child: const Text('Open learning progress')),
                FilledButton.tonal(onPressed: () => onNavigate('cbt'), child: const Text('Open CBT practice')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBrief extends StatelessWidget {
  const _AiBrief({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Text('AI')),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Teacher AI Daily Brief', style: TextStyle(fontWeight: FontWeight.w900)),
                  const Text('Updated 7:45 AM'),
                  const SizedBox(height: 8),
                  const Text(teacherAiBrief),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => onNavigate('learning-progress'), child: const Text('Review learning evidence')),
                      TextButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Teacher AI')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});
  final TeacherKpi item;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label),
              const SizedBox(height: 6),
              Text(item.value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              Text(item.hint),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child, this.actionLabel, this.onAction});

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(subtitle),
                    ],
                  );
                  if (onAction == null) return heading;
                  final action = TextButton(onPressed: onAction, child: Text('${actionLabel ?? 'Open'} →'));
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 4),
                        action,
                      ],
                    );
                  }
                  return Row(children: [Expanded(child: heading), action]);
                },
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final item in teacherTodaySchedule)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 62, child: Text(item.time, style: const TextStyle(fontWeight: FontWeight.w800))),
              title: Text(item.className, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(item.topic),
              trailing: Chip(label: Text(item.status)),
            ),
        ],
      );
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final task in teacherTasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(task.tone == 'urgent' ? Icons.priority_high_rounded : task.tone == 'warn' ? Icons.schedule_rounded : Icons.task_alt_rounded),
              title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(task.meta),
              trailing: TextButton(onPressed: () => onNavigate(task.destination), child: const Text('Open')),
            ),
        ],
      );
}

class _ClassList extends StatelessWidget {
  const _ClassList({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final item in teacherClasses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.subject), Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))])),
                          Text('${item.progress}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${item.students} students · Room ${item.room}'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: item.progress / 100),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text('Next: ${item.nextLesson}')),
                          TextButton(onPressed: () => onNavigate('classes'), child: const Text('Open class')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}

class _StudentList extends StatelessWidget {
  const _StudentList({required this.items});
  final List<TeacherStudentReview> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No students match this search.'));
    return Column(
      children: [
        for (final student in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text(_initials(student.name))),
            title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${student.className} · Avg ${student.average}% · Attendance ${student.attendance}%'),
            trailing: Chip(label: Text(student.signal)),
          ),
      ],
    );
  }

  static String _initials(String value) => value.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join();
}

class _PlanningSummary extends StatelessWidget {
  const _PlanningSummary({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Stat(label: 'Lesson plans submitted', value: '11 / 12'),
              _Stat(label: 'Weekly update', value: 'Draft ready'),
              _Stat(label: 'CBT sets published', value: '8'),
              _Stat(label: 'Evidence sources', value: '4'),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Connected workflow', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(teacherConnectedWorkflow),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => onNavigate('learning-progress'), child: const Text('Open Learning Progress'))),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}

class _PerformanceSummary extends StatelessWidget {
  const _PerformanceSummary();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 34, child: Text('88', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Very good', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('Your strongest areas are attendance completion and lesson-plan quality. Syllabus pace needs attention in JSS 2B.', style: Theme.of(context).textTheme.bodyMedium)])),
            ],
          ),
          const SizedBox(height: 12),
          for (final metric in teacherPerformanceMetrics) ...[
            Row(children: [Expanded(child: Text(metric.label)), Text('${metric.value}%', style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: metric.value / 100),
            const SizedBox(height: 10),
          ],
        ],
      );
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher evidence boundaries', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text(teacherReviewSignalBoundary),
              SizedBox(height: 6),
              Text(teacherAiBoundary),
              SizedBox(height: 6),
              Text(teacherOfflineBoundary),
            ],
          ),
        ),
      );
}
