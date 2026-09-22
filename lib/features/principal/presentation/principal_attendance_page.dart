import 'package:flutter/material.dart';

import '../data/principal_attendance_repository.dart';
import '../domain/principal_attendance_models.dart';

class PrincipalAttendancePage extends StatefulWidget {
  const PrincipalAttendancePage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final PrincipalAttendanceRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<PrincipalAttendancePage> createState() => _PrincipalAttendancePageState();
}

class _PrincipalAttendancePageState extends State<PrincipalAttendancePage> {
  PrincipalAttendanceSnapshot? _snapshot;
  String? _error;
  bool _students = true;
  String _query = '';
  String _classFilter = 'All classes';
  String _statusFilter = 'All statuses';
  String _date = '2026-09-13';

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

  Future<void> _resolve(String id) async {
    final result = await widget.repository.resolveFollowUp(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      widget.onMutationQueued();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 850;
      final classRows = snapshot.classes.where((row) {
        final q = _query.toLowerCase();
        return (_classFilter == 'All classes' || row.className == _classFilter) &&
            (_statusFilter == 'All statuses' || row.status.label == _statusFilter) &&
            row.className.toLowerCase().contains(q);
      }).toList(growable: false);
      final staffRows = snapshot.staff.where((row) {
        final q = _query.toLowerCase();
        final status = row.status == PrincipalAttendanceStaffStatus.present ? 'Present' : 'Absent';
        return (_statusFilter == 'All statuses' || status == _statusFilter) && '${row.name} ${row.role} $status'.toLowerCase().contains(q);
      }).toList(growable: false);
      final openFollowUps = snapshot.followUps.where((item) => !item.resolved).length;

      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.all(compact ? 14 : 24),
          children: [
            _header(context, compact),
            const SizedBox(height: 14),
            _offlineBanner(context, snapshot),
            const SizedBox(height: 14),
            _kpis(context, compact, snapshot, openFollowUps),
            const SizedBox(height: 18),
            compact
                ? Column(children: [_register(context, true, snapshot.classes, classRows, staffRows), const SizedBox(height: 14), _trend(context)])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _register(context, false, snapshot.classes, classRows, staffRows)), const SizedBox(width: 14), Expanded(flex: 1, child: _trend(context))]),
            const SizedBox(height: 18),
            _scannerSection(context, compact, snapshot),
            const SizedBox(height: 18),
            _recentBiometricEvents(context, snapshot),
            const SizedBox(height: 18),
            compact
                ? Column(children: [_followUps(context, snapshot), const SizedBox(height: 14), _rules(context)])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _followUps(context, snapshot)), const SizedBox(width: 14), Expanded(flex: 2, child: _rules(context))]),
          ],
        ),
      );
    });
  }

  Widget _header(BuildContext context, bool compact) {
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRINCIPAL · ATTENDANCE', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('Attendance Oversight', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Monitor daily student and staff attendance, lateness, repeated absence and follow-up actions.'),
    ]);
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton(onPressed: () => widget.onNavigate('dashboard'), child: const Text('Dashboard')),
      OutlinedButton(onPressed: () => widget.onNavigate('students'), child: const Text('Students')),
      OutlinedButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Teachers')),
    ]);
    return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
  }

  Widget _offlineBanner(BuildContext context, PrincipalAttendanceSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.offline_bolt_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Expanded(child: Text('100% OFFLINE ATTENDANCE MODE', style: TextStyle(fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 6),
            const Text(principalAttendanceOfflineRule),
            const SizedBox(height: 8),
            Text('${snapshot.scanners.length} local biometric devices · ${snapshot.pendingBiometricMutations + snapshot.scanners.fold(0, (sum, scanner) => sum + scanner.pendingEvents)} attendance events awaiting or eligible for later sync', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _kpis(BuildContext context, bool compact, PrincipalAttendanceSnapshot snapshot, int openFollowUps) {
    final classes = snapshot.classes;
    final totalStudents = classes.fold<int>(0, (sum, c) => sum + c.total);
    final presentStudents = classes.fold<int>(0, (sum, c) => sum + c.present);
    final absentStudents = classes.fold<int>(0, (sum, c) => sum + c.absent);
    final lateStudents = classes.fold<int>(0, (sum, c) => sum + c.late);
    final overallRate = totalStudents == 0 ? 0 : (presentStudents * 100 / totalStudents).round();
    final rows = [
      ('Student attendance', totalStudents == 0 ? 'No students' : '$overallRate%', '$presentStudents of $totalStudents present'),
      ('Absent students', '$absentStudents', 'Across monitored classes'),
      ('Late students', '$lateStudents', 'Requires punctuality follow-up'),
      ('Staff present', 'Not tracked yet', 'No real per-day staff check-in feed yet'),
      ('Open follow-ups', '$openFollowUps', 'Attendance actions'),
    ];
    final cards = rows.map((row) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.$1), const SizedBox(height: 3), Text(row.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text(row.$3, style: Theme.of(context).textTheme.bodySmall)]))));
    return compact ? Wrap(spacing: 8, runSpacing: 8, children: [for (final card in cards) SizedBox(width: 165, child: card)]) : Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card))]);
  }

  Widget _register(BuildContext context, bool compact, List<PrincipalClassAttendance> allClasses, List<PrincipalClassAttendance> classes, List<PrincipalStaffAttendance> staff) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Daily attendance register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Switch between student-class and staff attendance views.')])),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('Students')), ButtonSegment(value: false, label: Text('Staff'))],
                selected: {_students},
                onSelectionChanged: (value) => setState(() {
                  _students = value.first;
                  _statusFilter = 'All statuses';
                }),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(width: compact ? double.infinity : 240, child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: _students ? 'Search class...' : 'Search staff...', border: const OutlineInputBorder()), onChanged: (value) => setState(() => _query = value))),
              if (_students)
                DropdownButton<String>(value: _classFilter, items: [const DropdownMenuItem(value: 'All classes', child: Text('All classes')), for (final row in allClasses) DropdownMenuItem(value: row.className, child: Text(row.className))], onChanged: (value) => setState(() => _classFilter = value ?? 'All classes')),
              DropdownButton<String>(
                value: _statusFilter,
                items: _students
                    ? const [DropdownMenuItem(value: 'All statuses', child: Text('All statuses')), DropdownMenuItem(value: 'Strong', child: Text('Strong')), DropdownMenuItem(value: 'Watch', child: Text('Watch')), DropdownMenuItem(value: 'Needs attention', child: Text('Needs attention'))]
                    : const [DropdownMenuItem(value: 'All statuses', child: Text('All statuses')), DropdownMenuItem(value: 'Present', child: Text('Present')), DropdownMenuItem(value: 'Absent', child: Text('Absent'))],
                onChanged: (value) => setState(() => _statusFilter = value ?? 'All statuses'),
              ),
              DropdownButton<String>(value: _date, items: const [DropdownMenuItem(value: '2026-09-13', child: Text('Today'))], onChanged: (value) => setState(() => _date = value ?? _date)),
            ]),
            const SizedBox(height: 12),
            if (_students) ...[
              for (final row in classes) _classRow(context, row, compact),
              if (classes.isEmpty && allClasses.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No Secondary students are on the register yet.')),
              if (classes.isEmpty && allClasses.isNotEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No classes match these filters.')),
            ] else ...[
              const Padding(padding: EdgeInsets.all(14), child: Text('No real per-day staff check-in feed exists yet. Staff attendance is tracked as a period average on the Teachers screen instead.')),
            ],
          ]),
        ),
      );

  Widget _classRow(BuildContext context, PrincipalClassAttendance row, bool compact) {
    final items = [
      _cell('Class', row.className, sub: '${row.total} students'),
      _cell('Present', '${row.present}'),
      _cell('Absent', '${row.absent}'),
      _cell('Late', '${row.late}'),
      _cell('Excused', '${row.excused}'),
      _cell('Rate', '${row.rate}%'),
      _cell('Trend', '${row.trend > 0 ? '+' : ''}${row.trend}%'),
      _cell('Status', row.status.label),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: compact ? Wrap(spacing: 18, runSpacing: 10, children: items.map((item) => SizedBox(width: 110, child: item)).toList()) : Row(children: [for (final item in items) Expanded(child: item)]),
    );
  }

  Widget _trend(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Weekly attendance trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Whole-school student attendance across the current week.'),
            const SizedBox(height: 14),
            const Text('Not available yet: the real attendance record only keeps today\'s figures, so there is no real day-over-day history to chart yet.'),
            const Divider(height: 22),
            const Text('Principal AI observation', style: TextStyle(fontWeight: FontWeight.w900)),
            const Text('Not available yet: ask Principal AI once real multi-day attendance evidence exists.'),
            const SizedBox(height: 8),
            TextButton(onPressed: () => widget.onNavigate('ai'), child: const Text('Ask Principal AI')),
          ]),
        ),
      );

  Widget _scannerSection(BuildContext context, bool compact, PrincipalAttendanceSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Offline biometric capture', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Palm and fingerprint devices verify locally and queue attendance for later synchronization.'),
            const SizedBox(height: 12),
            if (compact)
              Column(children: [for (final scanner in snapshot.scanners) _scannerCard(context, scanner)])
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final scanner in snapshot.scanners) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: _scannerCard(context, scanner)))]),
            const SizedBox(height: 10),
            Text(principalAttendanceBiometricPrivacyRule, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _scannerCard(BuildContext context, PrincipalBiometricScanner scanner) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(scanner.modality == PrincipalBiometricModality.palm ? Icons.back_hand_outlined : Icons.fingerprint), const SizedBox(width: 6), Expanded(child: Text(scanner.name, style: const TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 6),
          Text(scanner.location),
          Text('${scanner.modality.label} · ${scanner.transport.name.toUpperCase()} · ${scanner.status.label}'),
          Text('${scanner.enrolledTemplates} local templates · ${scanner.pendingEvents} device events pending'),
          Text('Last event: ${scanner.lastEventAt}', style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _recentBiometricEvents(BuildContext context, PrincipalAttendanceSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent biometric evidence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Opaque template references only. Raw palm/fingerprint images are not part of the attendance ledger.'),
            const SizedBox(height: 10),
            for (final event in snapshot.biometricEvents.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(event.modality == PrincipalBiometricModality.palm ? Icons.back_hand_outlined : Icons.fingerprint),
                title: Text('${event.personReference} · ${event.classOrRole}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${event.scannerId} · seq ${event.localSequence} · score ${(event.matchScore * 100).toStringAsFixed(1)}%'),
                trailing: Chip(label: Text(event.matchStatus.name)),
              ),
            if (snapshot.biometricEvents.isEmpty) const Text('No local biometric attendance events yet.'),
          ]),
        ),
      );

  Widget _followUps(BuildContext context, PrincipalAttendanceSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Follow-up queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Repeated absence, lateness and staff attendance issues requiring action.')])), TextButton(onPressed: () => widget.onNavigate('communication'), child: const Text('Open communication'))]),
            const SizedBox(height: 8),
            if (snapshot.followUps.isEmpty)
              const Text('No real attendance follow-up evidence exists yet: detecting a repeated-absence or repeated-lateness pattern needs multi-day history, and today is all the real record keeps so far.')
            else
              for (final item in snapshot.followUps)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Chip(label: Text(item.severity.label)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.person, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${item.type.name} · ${item.classOrRole}'), Text('${item.issue} · ${item.count}')])),
                    Wrap(spacing: 4, children: [
                      TextButton(onPressed: () => widget.onNavigate(item.type == PrincipalAttendancePersonType.student ? 'students' : 'teachers'), child: const Text('Open record')),
                      TextButton(onPressed: () => widget.onNavigate('communication'), child: const Text('Contact')),
                      FilledButton.tonal(onPressed: item.resolved ? null : () => _resolve(item.id), child: Text(item.resolved ? 'Resolved' : 'Mark resolved')),
                    ]),
                  ]),
                ),
          ]),
        ),
      );

  Widget _rules(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Attendance rules & signals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _rule('REPEATED ABSENCE', 'Flag students or staff with recurring absence patterns.'),
            _rule('LATENESS', 'Surface repeated late arrival rather than treating each day in isolation.'),
            _rule('CLASS COMPARISON', 'Compare attendance rates to identify class-level operational problems.'),
            _rule('FOLLOW-UP', 'Principal can move directly from an attendance alert into student, teacher or communication workflows.'),
            const Divider(height: 22),
            Text(principalAttendanceIntegrityRule, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(principalAttendanceScopeBoundary, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _rule(String title, String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)), Text(text)]));

  Widget _cell(String label, String value, {String? sub}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800)), if (sub != null) Text(sub, style: const TextStyle(fontSize: 11))]);
}
