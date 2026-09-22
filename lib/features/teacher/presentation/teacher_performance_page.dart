import 'package:flutter/material.dart';

import '../data/teacher_performance_demo_data.dart';
import '../data/teacher_performance_repository.dart';
import '../domain/teacher_performance_models.dart';

class TeacherPerformancePage extends StatefulWidget {
  const TeacherPerformancePage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final TeacherPerformanceDataSource repository;
  final ValueChanged<String> onNavigate;

  @override
  State<TeacherPerformancePage> createState() => _TeacherPerformancePageState();
}

class _TeacherPerformancePageState extends State<TeacherPerformancePage> {
  TeacherPerformancePeriod _period = TeacherPerformancePeriod.thisTerm;
  TeacherPerformanceSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _addReflection() async {
    final controller = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add private reflection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This note stays on this device in the current workflow and is not sent to leadership.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reflection',
                hintText: 'What would you like to improve or follow up?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save privately'),
          ),
        ],
      ),
    );
    // The dialog's exit transition is still animating and reading this controller for a frame or two
    // after showDialog's future completes, so disposing it synchronously here throws "used after disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (body == null) return;

    final result = await widget.repository.addPrivateReflection(body);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40),
              const SizedBox(height: 12),
              Text('Could not load My Performance\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _header(context),
        const SizedBox(height: 16),
        _overview(context),
        const SizedBox(height: 16),
        _metrics(context, snapshot.metrics),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;
            final children = [
              Expanded(flex: 3, child: _classOutcomes(context, snapshot.classPerformance)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _development(context, snapshot)),
            ];
            if (!narrow) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
            return Column(
              children: [
                _classOutcomes(context, snapshot.classPerformance),
                const SizedBox(height: 16),
                _development(context, snapshot),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _principles(context),
      ],
    );
  }

  Widget _header(BuildContext context) => Wrap(
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
                Text(
                  'PRIVATE TEACHER VIEW',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'My Performance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Professional-development indicators for your own teaching activity and assigned classes.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<TeacherPerformancePeriod>(
                value: _period,
                onChanged: (value) {
                  if (value != null) setState(() => _period = value);
                },
                items: [
                  for (final value in TeacherPerformancePeriod.values)
                    DropdownMenuItem(value: value, child: Text(value.label)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate('dashboard'),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Dashboard'),
              ),
            ],
          ),
        ],
      );

  Widget _overview(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final score = Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text(
                        '$teacherPerformanceScore',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Text('/100'),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(label: Text(teacherPerformanceScoreLabel)),
                        const SizedBox(height: 8),
                        Text(
                          teacherPerformanceHeadline,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(teacherPerformanceSummary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          final focus = Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Professional focus', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const Text('Suggested next action'),
                  const SizedBox(height: 14),
                  const Text(teacherProfessionalFocusTitle, style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text(teacherProfessionalFocusCopy),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => widget.onNavigate('syllabus'),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Open syllabus'),
                  ),
                ],
              ),
            ),
          );
          if (narrow) {
            return Column(children: [score, const SizedBox(height: 12), focus]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 3, child: score), const SizedBox(width: 16), Expanded(flex: 2, child: focus)],
          );
        },
      );

  Widget _metrics(BuildContext context, List<TeacherPerformanceMetric> metrics) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Core teaching indicators', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text('These indicators should support coaching and self-improvement, not act as an automatic disciplinary ranking.'),
                    ],
                  ),
                  Chip(label: Text(_period.label)),
                ],
              ),
              const SizedBox(height: 16),
              for (final metric in metrics) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(metric.note),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${metric.value}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('Target ${metric.target}%', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: metric.value / 100),
                if (metric != metrics.last) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
              ],
            ],
          ),
        ),
      );

  Widget _classOutcomes(BuildContext context, List<TeacherClassPerformance> classes) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assigned-class outcomes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Text('Context for your teaching—not a claim of sole causation.'),
              const SizedBox(height: 14),
              if (classes.isEmpty) const Text('No assigned classes yet.'),
              for (final item in classes) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          Text('Class avg ${item.average}% · Attendance ${item.attendance}% · Syllabus ${item.syllabusPace}%'),
                        ],
                      ),
                    ),
                    Text(
                      item.change,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: item.isImproving
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                if (item != classes.last) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
              ],
            ],
          ),
        ),
      );

  Widget _development(BuildContext context, TeacherPerformanceSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My development log', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Text('Private actions and coaching follow-up.'),
              const SizedBox(height: 14),
              for (final item in snapshot.developmentLog)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(item.detail),
                ),
              if (snapshot.reflections.isNotEmpty) ...[
                const Divider(),
                const Text('Private reflections', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                for (final reflection in snapshot.reflections.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline_rounded),
                    title: Text(reflection.body),
                    subtitle: const Text('Private on this device'),
                  ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: snapshot.permissions.canAddPrivateReflection ? _addReflection : null,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add private reflection'),
              ),
              const SizedBox(height: 8),
              const Text(
                teacherPerformanceReflectionBoundary,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _principles(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How this score should be used', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const Text('SchoolOS should avoid misleading teacher rankings.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final principle in teacherPerformanceUsagePrinciples)
                    SizedBox(
                      width: 290,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(principle.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              Text(principle.$2),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(teacherPerformanceBoundary, style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(teacherPerformancePrivacyBoundary),
            ],
          ),
        ),
      );
}
