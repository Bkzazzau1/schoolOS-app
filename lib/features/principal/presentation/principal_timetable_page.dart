import 'package:flutter/material.dart';

import '../data/principal_timetable_repository.dart';
import '../domain/principal_timetable_models.dart';

class PrincipalTimetablePage extends StatefulWidget {
  const PrincipalTimetablePage({super.key, required this.repository, required this.onNavigate, this.onMutationQueued});

  final PrincipalTimetableRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalTimetablePage> createState() => _PrincipalTimetablePageState();
}

class _PrincipalTimetablePageState extends State<PrincipalTimetablePage> {
  PrincipalTimetableSnapshot? _snapshot;
  String? _error;

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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 8),
        const Text('Could not load timetable.', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]));
    }
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        const _ScheduleGridNotice(),
        const SizedBox(height: 16),
        _TeacherLoads(rows: snapshot.teacherLoads),
        const SizedBox(height: 12),
        const _Boundary(text: principalTimetableAuthorityBoundary),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 16,
        children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PRINCIPAL · TIMETABLE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            SizedBox(height: 4),
            Text('School Timetable', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
            SizedBox(height: 4),
            Text('Real teacher workload from real teaching assignments. A per-period lesson schedule is not tracked yet.'),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('teachers'), child: const Text('Teachers')),
            OutlinedButton(onPressed: () => onNavigate('assignments'), child: const Text('Assignments')),
          ]),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalTimetableSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final totalPeriods = snapshot.teacherLoads.fold<int>(0, (sum, row) => sum + row.lessons);
    final heavy = snapshot.teacherLoads.where((row) => row.status == 'Heavy').length;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _Kpi(label: 'Teachers with a real assignment', value: '${snapshot.teacherLoads.length}', note: 'Secondary teaching staff'),
      _Kpi(label: 'Weekly periods assigned', value: '$totalPeriods', note: 'Sum of real teaching assignments'),
      _Kpi(label: 'Above target load', value: '$heavy', note: 'Teachers over the weekly target'),
      const _Kpi(label: 'Per-period schedule', value: 'Not tracked', note: 'No real class-period grid recorded'),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(width: 200, child: Card(elevation: 0, child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(note, style: Theme.of(context).textTheme.bodySmall),
    ]),
  )));
}

class _ScheduleGridNotice extends StatelessWidget {
  const _ScheduleGridNotice();
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Not available yet. A real teaching assignment records a weekly period count (see Assignments), but not which day or time a class meets, so there is no real lesson grid, room list or schedule exception to show here. Teacher workload below is real.',
            ),
          ),
        ]),
      ));
}

class _TeacherLoads extends StatelessWidget {
  const _TeacherLoads({required this.rows});
  final List<PrincipalTeacherLoad> rows;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Teacher workload', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Text('Real weekly periods per real Secondary teacher, from Assignments.'),
          const SizedBox(height: 10),
          if (rows.isEmpty) const Text('No real Secondary teaching staff are on record yet.'),
          for (final row in rows) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${row.lessons} periods/week · target ${row.target}'),
            trailing: Chip(label: Text(row.status)),
          ),
        ]),
      ));
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_user_outlined, size: 20), const SizedBox(width: 10), Expanded(child: Text(text)),
        ]),
      ));
}
