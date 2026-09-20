import 'package:flutter/material.dart';

import '../data/parent_attendance_demo_data.dart';
import '../data/parent_attendance_repository.dart';
import '../domain/parent_attendance_models.dart';

class ParentAttendancePage extends StatefulWidget {
  const ParentAttendancePage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final ParentAttendanceRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<ParentAttendancePage> createState() => _ParentAttendancePageState();
}

class _ParentAttendancePageState extends State<ParentAttendancePage> {
  late Future<ParentAttendanceSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  void _reload() {
    setState(() => _snapshot = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParentAttendanceSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _LoadFailure(onRetry: _reload);
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000 ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    onDashboard: () => widget.onNavigate('dashboard'),
                    onChildren: () => widget.onNavigate('children'),
                  ),
                  const SizedBox(height: 18),
                  _KpiGrid(snapshot: data),
                  const SizedBox(height: 16),
                  _ChildrenGrid(children: data.children),
                  const SizedBox(height: 16),
                  _AttendanceHistory(events: data.events),
                  const SizedBox(height: 16),
                  _ResponsivePair(
                    left: _NotificationHistory(items: data.notifications),
                    right: const _AttendancePrinciple(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onDashboard, required this.onChildren});

  final VoidCallback onDashboard;
  final VoidCallback onChildren;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FAMILY ACCOUNT · ATTENDANCE',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Attendance & Arrival',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'See check-in, check-out and weekly attendance records for your linked children.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Dashboard'),
            ),
            OutlinedButton.icon(
              onPressed: onChildren,
              icon: const Icon(Icons.family_restroom_outlined, size: 18),
              label: const Text('My children'),
            ),
          ],
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 14), actions],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            actions,
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final ParentAttendanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = <_KpiItem>[
      for (final child in snapshot.children)
        _KpiItem(
          label: '${child.name.split(' ').first} attendance',
          value: '${child.attendancePercent}%',
          detail: '${child.presentDays} of ${child.totalSchoolDays} school days',
          icon: Icons.fact_check_outlined,
        ),
      _KpiItem(
        label: 'Late arrivals',
        value: '${snapshot.totalLateArrivals}',
        detail: 'Across both children',
        icon: Icons.schedule_outlined,
      ),
      _KpiItem(
        label: 'Today',
        value: '${snapshot.checkedInTodayCount} checked in',
        detail: snapshot.checkedInTodayCount == snapshot.children.length
            ? 'Both children arrived'
            : 'Current school arrival status',
        icon: Icons.login_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _KpiCard(item: item)),
          ],
        );
      },
    );
  }
}

class _KpiItem {
  const _KpiItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.item});

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
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

class _ChildrenGrid extends StatelessWidget {
  const _ChildrenGrid({required this.children});

  final List<ParentAttendanceChildSummary> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const _EmptyAttendanceCard();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width, child: _ChildAttendanceCard(child: child)),
          ],
        );
      },
    );
  }
}

class _ChildAttendanceCard extends StatelessWidget {
  const _ChildAttendanceCard({required this.child});

  final ParentAttendanceChildSummary child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        child.className,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${child.attendancePercent}%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _InfoGrid(
              items: [
                ('Present days', child.presentDaysLabel),
                ('Late arrivals', '${child.lateArrivals}'),
                ('Latest check-in', child.latestCheckInLabel),
                ('Captured by', child.captureDevice),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sensors_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      parentAttendanceArrivalNote,
                      style: TextStyle(height: 1.4),
                    ),
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

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AttendanceHistory extends StatelessWidget {
  const _AttendanceHistory({required this.events});

  final List<ParentAttendanceEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              title: 'Attendance history',
              subtitle: 'Arrival and departure facts for your linked children.',
            ),
            const SizedBox(height: 14),
            if (events.isEmpty)
              const _InlineEmpty(message: 'No attendance history is available yet.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        for (final event in events) ...[
                          _MobileEventCard(event: event),
                          if (event != events.last) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        columnSpacing: 26,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Child')),
                          DataColumn(label: Text('Check-in')),
                          DataColumn(label: Text('Check-out')),
                          DataColumn(label: Text('Gate')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: [
                          for (final event in events)
                            DataRow(
                              cells: [
                                DataCell(Text(event.dateLabel)),
                                DataCell(
                                  Text(
                                    event.childName,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                DataCell(Text(event.checkIn)),
                                DataCell(Text(event.checkOut)),
                                DataCell(Text(event.captureLabel)),
                                DataCell(_StatusPill(event: event)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileEventCard extends StatelessWidget {
  const _MobileEventCard({required this.event});

  final ParentAttendanceEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.childName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(event: event),
            ],
          ),
          const SizedBox(height: 4),
          Text(event.dateLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Fact(label: 'Check-in', value: event.checkIn),
              _Fact(label: 'Check-out', value: event.checkOut),
              _Fact(label: 'Gate', value: event.captureLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.event});

  final ParentAttendanceEvent event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: event.isLate ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        event.status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: event.isLate ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _NotificationHistory extends StatelessWidget {
  const _NotificationHistory({required this.items});

  final List<ParentAttendanceNotification> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              title: 'Notification history',
              subtitle: 'Examples of family-facing attendance messages.',
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _InlineEmpty(message: 'No attendance notifications yet.')
            else
              for (var i = 0; i < items.length; i++) ...[
                _NotificationRow(item: items[i]),
                if (i != items.length - 1) const Divider(height: 22),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});

  final ParentAttendanceNotification item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notifications_none_rounded, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(
                item.detail,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendancePrinciple extends StatelessWidget {
  const _AttendancePrinciple();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              title: 'Attendance principle',
              subtitle: 'Facts, not assumptions.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                parentAttendancePrinciple,
                style: TextStyle(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}

class _EmptyAttendanceCard extends StatelessWidget {
  const _EmptyAttendanceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'No family attendance data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Attendance records for linked children are not available on this device yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to open attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The locally available family attendance record could not be loaded.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
