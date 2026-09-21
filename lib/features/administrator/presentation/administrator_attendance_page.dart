import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../proprietor/presentation/owner_dialogs.dart';
import '../data/administrator_attendance_demo_data.dart';
import '../data/administrator_attendance_desk.dart';
import '../data/administrator_attendance_repository.dart';
import '../data/administrator_students_repository.dart';
import '../domain/administrator_attendance_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_attendance_dialogs.dart';

class AdministratorAttendancePage extends StatefulWidget {
  const AdministratorAttendancePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.students,
  });

  final String schoolName;
  final AdministratorAttendanceRepository repository;
  final AdministratorStudentsRepository students;

  @override
  State<AdministratorAttendancePage> createState() =>
      _AdministratorAttendancePageState();
}

class _AdministratorAttendancePageState
    extends State<AdministratorAttendancePage> with SyncRefresh<AdministratorAttendancePage> {
  @override
  void onSynced() => _load();

  AttendanceDesk? _desk;
  List<AdministratorStudentRecord> _expected = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  List<AdministratorAttendanceEvent> _events = const [];
  List<AdministratorAttendanceDevice> _devices = const [];
  List<AdministratorAttendanceCorrection> _corrections = const [];
  AdministratorAttendancePermissions? _permissions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final register = (await widget.students.load()).students;
      final expected = [for (final s in register) if (s.status != AdministratorStudentStatus.transferredOut) s];
      final snapshot = await widget.repository.load(students: expected);
      if (!mounted) return;
      setState(() {
        _expected = expected;
        _desk = buildAttendanceDesk(students: expected, events: snapshot.events, corrections: snapshot.corrections);
        _events = snapshot.events;
        _devices = snapshot.devices;
        _corrections = snapshot.corrections;
        _permissions = snapshot.permissions;
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

  List<AdministratorAttendanceEvent> get _filteredEvents {
    if (_filter == 'All') return _events;
    return _events.where((item) => item.status.label == _filter).toList();
  }

  void _exportToday() {
    final preview = widget.repository.exportTodayPreview(_events);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export today · preview'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: SelectableText(preview),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _registerDevice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(administratorAttendanceDeviceBoundary)),
    );
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finish(AdministratorAttendanceActionResult result) async {
    _say(result.message);
    if (result.success) await _load();
  }

  Future<void> _checkInByHand() async {
    final here = {for (final e in _events) if (!e.isUnknown) e.student.trim().toLowerCase()};
    final options = [for (final s in _expected) if (!here.contains(s.name.trim().toLowerCase())) s];
    final student = await askStudent(context, title: 'Check a student in', action: 'Check in', students: options,
        explanation: 'For a student the gate did not scan. After 08:00 they are marked late.');
    if (student == null) return;
    await _finish(await widget.repository.checkIn(student));
  }

  Future<void> _identify(AdministratorAttendanceEvent scan) async {
    final here = {for (final e in _events) if (!e.isUnknown) e.student.trim().toLowerCase()};
    final options = [for (final s in _expected) if (!here.contains(s.name.trim().toLowerCase())) s];
    final student = await askStudent(context, title: 'Who is this?', action: 'Identify', students: options,
        explanation: 'The device could not match this ${scan.method.toLowerCase()} scan at ${scan.time}. Choose the student only if you are sure.');
    if (student == null) return;
    await _finish(await widget.repository.identifyUnknown(scan, student));
  }

  Future<void> _reviewCorrection(AdministratorAttendanceCorrection correction) async {
    if (!(_permissions?.canReviewCorrections ?? false)) return;
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${correction.id} · ${correction.student}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Class', value: correction.className),
              _InfoRow(label: 'Requested', value: correction.requestedChange),
              _InfoRow(label: 'Evidence', value: correction.evidence),
              _InfoRow(label: 'Status', value: correction.status),
              if (correction.decisionNote.isNotEmpty) _InfoRow(label: 'Reason', value: correction.decisionNote),
              const SizedBox(height: 14),
              const _Notice(text: administratorAttendanceCorrectionBoundary),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          if (correction.isPending) ...[
            TextButton(key: const ValueKey('correction-decline'), onPressed: () => Navigator.of(context).pop('decline'), child: const Text('Decline')),
            FilledButton(key: const ValueKey('correction-approve'), onPressed: () => Navigator.of(context).pop('approve'), child: const Text('Approve')),
          ],
        ],
      ),
    );
    if (decision == null || !mounted) return;
    if (decision == 'approve') {
      await _finish(await widget.repository.decideCorrection(correction, approve: true));
    } else {
      final reason = await askReason(context, title: 'Decline ${correction.id}', action: 'Decline', label: 'Why (required)');
      if (reason == null) return;
      await _finish(await widget.repository.decideCorrection(correction, approve: false, note: reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(
              schoolName: widget.schoolName,
              onExport: _exportToday,
              onRegisterDevice: _registerDevice,
              onCheckIn: (_permissions?.canReviewCorrections ?? false) ? _checkInByHand : null,
            ),
            const SizedBox(height: 18),
            _Kpis(desk: _desk!),
            const SizedBox(height: 16),
            const _FlowCard(),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _EventsCard(
                      events: _filteredEvents,
                      filter: _filter,
                      onFilterChanged: (value) => setState(() => _filter = value),
                      onIdentify: (_permissions?.canReviewCorrections ?? false) ? _identify : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _DevicesCard(devices: _devices)),
                ],
              )
            else ...[
              _EventsCard(
                events: _filteredEvents,
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                onIdentify: (_permissions?.canReviewCorrections ?? false) ? _identify : null,
              ),
              const SizedBox(height: 16),
              _DevicesCard(devices: _devices),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SectionsCard(desk: _desk!)),
                  const SizedBox(width: 16),
                  Expanded(child: _ExceptionsCard(desk: _desk!)),
                ],
              )
            else ...[
              _SectionsCard(desk: _desk!),
              const SizedBox(height: 16),
              _ExceptionsCard(desk: _desk!),
            ],
            const SizedBox(height: 16),
            _CorrectionsCard(
              corrections: _corrections,
              canReview: _permissions?.canReviewCorrections ?? false,
              onReview: _reviewCorrection,
            ),
            const SizedBox(height: 16),
            const _Notice(text: administratorAttendanceIntegrityRule),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.onExport,
    required this.onRegisterDevice,
    this.onCheckIn,
  });

  final String schoolName;
  final VoidCallback onExport;
  final VoidCallback onRegisterDevice;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 14,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATION · HARDWARE ATTENDANCE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Attendance Control Center',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Today\'s check-ins, late arrivals, who has not arrived, scans to identify and documented corrections. · $schoolName',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (onCheckIn != null)
              FilledButton.icon(
                key: const ValueKey('attendance-checkin'),
                onPressed: onCheckIn,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: const Text('Check a student in'),
              ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export today'),
            ),
            FilledButton.icon(
              onPressed: onRegisterDevice,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Register device'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.desk});

  final AttendanceDesk desk;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Present today', '${desk.present}', desk.expected == 0 ? 'No students on the register' : '${desk.rate}% of ${desk.expected} expected students'),
      ('Late arrivals', '${desk.late}', 'After 08:00'),
      ('Absent / not checked in', '${desk.absent}', 'Requires normal follow-up'),
      ('Excused', '${desk.excused}', 'Approved by correction'),
      ('Scans to identify', '${desk.unknownScans}', desk.unknownScans == 0 ? 'None waiting' : 'A person must choose the student'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width: 210,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How hardware attendance reaches SchoolOS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            const Text('How gate terminals will reach SchoolOS once hardware is connected.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in administratorAttendanceFlow)
                  Builder(builder: (context) {
                    final parts = entry.split('|');
                    return SizedBox(
                      width: 180,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(parts[0], style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(parts[1]),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({
    required this.events,
    required this.filter,
    required this.onFilterChanged,
    this.onIdentify,
  });

  final List<AdministratorAttendanceEvent> events;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<AdministratorAttendanceEvent>? onIdentify;

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Checked in', 'Late', 'Excused', 'Offline synced', 'Unknown scan'];
    return Card(
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
                      Text('Attendance today', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      Text('Check-ins for the school day, from devices and the front desk.'),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: filter,
                  items: [for (final item in filters) DropdownMenuItem(value: item, child: Text(item))],
                  onChanged: (value) {
                    if (value != null) onFilterChanged(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (events.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No attendance recorded yet today.')),
            for (final item in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.student, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.className} · ${item.method}\n${item.device}${item.note.isEmpty ? '' : '\n${item.note}'}'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.time, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(item.status.label),
                    Text('Parent: ${item.parentState}', style: Theme.of(context).textTheme.bodySmall),
                    if (item.isUnknown && onIdentify != null)
                      TextButton(
                        key: const ValueKey('attendance-identify'),
                        onPressed: () => onIdentify!(item),
                        child: const Text('Identify'),
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

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices});
  final List<AdministratorAttendanceDevice> devices;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Device health', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Sample devices. Gate hardware is not connected yet, so these are examples.'),
            const SizedBox(height: 10),
            for (final item in devices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.location} · ${item.type}\nLast event ${item.lastEvent} · ${item.events}'),
                isThreeLine: true,
                trailing: Text(item.status.label, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionsCard extends StatelessWidget {
  const _SectionsCard({required this.desk});

  final AttendanceDesk desk;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance by section', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Today, from the check-ins and the student register.'),
            const SizedBox(height: 12),
            if (desk.sections.isEmpty) const Text('No students on the register.'),
            for (final item in desk.sections) ...[
              Row(
                children: [
                  SizedBox(width: 90, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Expanded(child: LinearProgressIndicator(value: item.rate / 100)),
                  const SizedBox(width: 10),
                  Text('${item.rate}%'),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 90, bottom: 10),
                child: Text('${item.present} present · ${item.late} late · ${item.absent} absent of ${item.expected}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard({required this.desk});

  final AttendanceDesk desk;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String)>[
      if (desk.unknownScans > 0)
        ('${desk.unknownScans} scan${desk.unknownScans == 1 ? '' : 's'} to identify', 'A device could not match the credential.', 'Review manually; never guess the student identity.'),
      if (desk.pendingCorrections > 0)
        ('${desk.pendingCorrections} correction request${desk.pendingCorrections == 1 ? '' : 's'}', 'Evidence conflicts with today\'s record.', 'Review with audit trail.'),
      if (desk.absent > 0)
        ('${desk.absent} not checked in', desk.absentNames.take(5).join(', ') + (desk.absent > 5 ? ' and ${desk.absent - 5} more' : ''), 'Follow up in the normal way. Nobody is marked absent for a reason from a scan alone.'),
    ];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exceptions requiring attention', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Hardware data should be trusted, but not blindly.'),
            const SizedBox(height: 12),
            if (items.isEmpty) const Text('Nothing needs attention.'),
            for (final entry in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(entry.$2),
                    Text(entry.$3, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionsCard extends StatelessWidget {
  const _CorrectionsCard({
    required this.corrections,
    required this.canReview,
    required this.onReview,
  });

  final List<AdministratorAttendanceCorrection> corrections;
  final bool canReview;
  final ValueChanged<AdministratorAttendanceCorrection> onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance corrections', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Text('Documented corrections remain available when hardware or operational records need review.'),
            const SizedBox(height: 12),
            for (final item in corrections)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.id} · ${item.student}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.className} · ${item.requestedChange}\n${item.evidence}${item.isPending ? '' : '\n${item.status}${item.decisionNote.isEmpty ? '' : ': ${item.decisionNote}'}'}'),
                isThreeLine: true,
                trailing: TextButton(
                  key: ValueKey('correction-${item.id}'),
                  onPressed: canReview ? () => onReview(item) : null,
                  child: Text(item.isPending ? 'Review' : 'View'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 95, child: Text(label)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
