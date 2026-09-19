import 'package:flutter/material.dart';

import '../data/administrator_staff_attendance_demo_data.dart';
import '../data/administrator_staff_attendance_repository.dart';
import '../domain/administrator_staff_attendance_models.dart';

class AdministratorStaffAttendancePage extends StatefulWidget {
  const AdministratorStaffAttendancePage({
    super.key,
    required this.schoolName,
    required this.repository,
    this.onAttendanceChanged,
  });

  final String schoolName;
  final AdministratorStaffAttendanceRepository repository;
  final VoidCallback? onAttendanceChanged;

  @override
  State<AdministratorStaffAttendancePage> createState() =>
      _AdministratorStaffAttendancePageState();
}

class _AdministratorStaffAttendancePageState
    extends State<AdministratorStaffAttendancePage> {
  AdministratorStaffAttendanceSnapshot? _snapshot;
  bool _loading = true;
  bool _sending = false;
  String? _error;

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
        _snapshot = snapshot;
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

  Future<void> _sendSummary() async {
    final snapshot = _snapshot;
    if (snapshot == null || _sending) return;
    setState(() => _sending = true);
    final result = await widget.repository.sendPayrollSummary(snapshot.records);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.summary != null) {
        _snapshot = AdministratorStaffAttendanceSnapshot(
          records: snapshot.records,
          devices: snapshot.devices,
          summary: result.summary!,
          permissions: snapshot.permissions,
        );
      }
    });
    if (result.success) widget.onAttendanceChanged?.call();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _showExportPreview() {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final preview = widget.repository.buildExportPreview(snapshot.records);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attendance export preview'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final canSend = snapshot.permissions.canSendPayrollSummary && !_sending;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(
              schoolName: widget.schoolName,
              sent: snapshot.summary.sent,
              canSend: canSend,
              onExport: _showExportPreview,
              onSend: _sendSummary,
            ),
            const SizedBox(height: 18),
            _KpiGrid(items: administratorStaffAttendanceKpis),
            const SizedBox(height: 16),
            _FlowCard(items: administratorStaffAttendanceFlow),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _LedgerCard(records: snapshot.records)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _DevicesCard(devices: snapshot.devices)),
                ],
              )
            else ...[
              _LedgerCard(records: snapshot.records),
              const SizedBox(height: 16),
              _DevicesCard(devices: snapshot.devices),
            ],
            const SizedBox(height: 16),
            _PayrollPreviewCard(records: snapshot.records),
            const SizedBox(height: 16),
            const _GovernanceBox(),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.sent,
    required this.canSend,
    required this.onExport,
    required this.onSend,
  });

  final String schoolName;
  final bool sent;
  final bool canSend;
  final VoidCallback onExport;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
              Text(
                'ADMINISTRATION · STAFF ATTENDANCE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Staff Attendance & Payroll Readiness',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use hardware attendance as operational evidence, review leave and exceptions, then hand a verified attendance summary to payroll. · $schoolName',
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: onExport,
              child: const Text('Export attendance'),
            ),
            FilledButton(
              onPressed: canSend ? onSend : null,
              child: Text(sent ? 'Summary sent' : 'Send payroll summary'),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.items});
  final List<StaffAttendanceKpi> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 1100 ? 5 : width >= 700 ? 3 : 1;
        final gap = 12.0;
        final itemWidth = (width - gap * (count - 1)) / count;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label),
                        const SizedBox(height: 5),
                        Text(
                          item.value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(item.note),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.items});
  final List<List<String>> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controlled attendance-to-payroll flow',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Attendance informs payroll preparation without silently changing anyone’s salary.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item[0], style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(item[1]),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.records});
  final List<StaffAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Staff attendance ledger',
      subtitle: 'Current payroll period summary.',
      child: Column(
        children: [
          for (final record in records) ...[
            _AttendanceRow(record: record),
            if (record != records.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record});
  final StaffAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${record.id} · ${record.role} · ${record.section}'),
                  ],
                ),
              ),
              _StatusChip(status: record.status),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _MiniMetric('${record.present}/${record.expected}', 'present days'),
              _MiniMetric('${record.leave}', 'approved leave'),
              _MiniMetric('${record.late}', 'late arrivals'),
              _MiniMetric('${record.unexplained}', 'unexplained absence'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({required this.devices});
  final List<StaffAttendanceDevice> devices;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Hardware status',
      subtitle: 'Devices supplying staff attendance evidence.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final device in devices) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${device.location}\n${device.method}'),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 145),
                child: Text(device.state, textAlign: TextAlign.end),
              ),
            ),
            if (device != devices.last) const Divider(height: 1),
          ],
          const SizedBox(height: 12),
          const _BoundaryBox(text: staffAttendanceSyncRule),
        ],
      ),
    );
  }
}

class _PayrollPreviewCard extends StatelessWidget {
  const _PayrollPreviewCard({required this.records});
  final List<StaffAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Payroll handoff preview',
      subtitle:
          'Only the reviewed attendance fields needed for payroll preparation move to Finance.',
      child: Column(
        children: [
          for (final record in records) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '${record.id} · Expected ${record.expected} · Present ${record.present} · Leave ${record.leave} · Unexplained ${record.unexplained}',
              ),
              trailing: Text(
                record.payrollState,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: record.payrollReady
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            if (record != records.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _GovernanceBox extends StatelessWidget {
  const _GovernanceBox();

  @override
  Widget build(BuildContext context) {
    return _BoundaryBox(text: 'Governance rule: $staffAttendanceGovernanceRule');
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final StaffAttendanceReviewStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status == StaffAttendanceReviewStatus.review
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _BoundaryBox extends StatelessWidget {
  const _BoundaryBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
