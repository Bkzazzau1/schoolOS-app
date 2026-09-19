import 'package:flutter/material.dart';

import '../data/administrator_attendance_demo_data.dart';
import '../data/administrator_attendance_repository.dart';
import '../domain/administrator_attendance_models.dart';

class AdministratorAttendancePage extends StatefulWidget {
  const AdministratorAttendancePage({
    super.key,
    required this.schoolName,
    required this.repository,
  });

  final String schoolName;
  final AdministratorAttendanceRepository repository;

  @override
  State<AdministratorAttendancePage> createState() =>
      _AdministratorAttendancePageState();
}

class _AdministratorAttendancePageState
    extends State<AdministratorAttendancePage> {
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
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
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

  void _reviewCorrection(AdministratorAttendanceCorrection correction) {
    if (!(_permissions?.canReviewCorrections ?? false)) return;
    showDialog<void>(
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
              const SizedBox(height: 14),
              const _Notice(text: administratorAttendanceCorrectionBoundary),
            ],
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
            ),
            const SizedBox(height: 18),
            const _Kpis(),
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
              ),
              const SizedBox(height: 16),
              _DevicesCard(devices: _devices),
            ],
            const SizedBox(height: 16),
            if (wide)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _SectionsCard()),
                  SizedBox(width: 16),
                  Expanded(child: _ExceptionsCard()),
                ],
              )
            else ...[
              const _SectionsCard(),
              const SizedBox(height: 16),
              const _ExceptionsCard(),
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
  });

  final String schoolName;
  final VoidCallback onExport;
  final VoidCallback onRegisterDevice;

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
                'Monitor device events, student check-in/check-out, late arrivals, offline sync and documented corrections from one operational view. · $schoolName',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
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
  const _Kpis();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Present today', '623', '96.1% of expected students'),
      ('Late arrivals', '27', 'Across all sections'),
      ('Absent / not checked in', '25', 'Requires normal follow-up'),
      ('Active devices', '4 / 5', '1 device currently offline'),
      ('Queued events', '42', 'Waiting for device sync'),
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
            const Text('Prototype architecture for gate terminals and attendance devices.'),
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
  });

  final List<AdministratorAttendanceEvent> events;
  final String filter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    const filters = ['All', 'Checked in', 'Late', 'Offline synced', 'Unknown scan'];
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
                      Text('Live attendance events', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      Text('Latest device activity for the school day.'),
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
            for (final item in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.student, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.className} · ${item.method}\n${item.device}'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.time, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(item.status.label),
                    Text('Parent: ${item.parentState}', style: Theme.of(context).textTheme.bodySmall),
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
            const Text('Connectivity and event-sync status.'),
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
  const _SectionsCard();

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
            const Text('Current school-day picture from synchronized records.'),
            const SizedBox(height: 12),
            for (final item in administratorAttendanceSections) ...[
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
                child: Text('${item.present} present · ${item.late} late · ${item.absent} absent'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExceptionsCard extends StatelessWidget {
  const _ExceptionsCard();

  @override
  Widget build(BuildContext context) {
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
            for (final entry in administratorAttendanceExceptions) ...[
              Builder(builder: (context) {
                final parts = entry.split('|');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parts[0], style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(parts[1]),
                      Text(parts[2], style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }),
            ],
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
                subtitle: Text('${item.className} · ${item.requestedChange}\n${item.evidence}'),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: canReview ? () => onReview(item) : null,
                  child: const Text('Review'),
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
