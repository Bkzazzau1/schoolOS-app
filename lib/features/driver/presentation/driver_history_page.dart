import 'package:flutter/material.dart';

import '../data/driver_history_repository.dart';
import '../domain/driver_history_models.dart';

class DriverHistoryPage extends StatefulWidget {
  const DriverHistoryPage({
    super.key,
    required this.repository,
  });

  final DriverHistoryRepository repository;

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
  late Future<DriverHistorySnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverHistorySnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Driver history could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildPage(snapshot.data!);
      },
    );
  }

  Widget _buildPage(DriverHistorySnapshot snapshot) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final padding = wide ? 28.0 : 16.0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 40),
            children: [
              const _Header(),
              const SizedBox(height: 16),
              _ProfileCard(profile: snapshot.profile),
              const SizedBox(height: 16),
              _Summary(snapshot: snapshot),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _HistoryList(snapshot: snapshot)),
                    const SizedBox(width: 18),
                    const Expanded(flex: 3, child: _BoundaryCard()),
                  ],
                )
              else ...[
                _HistoryList(snapshot: snapshot),
                const SizedBox(height: 18),
                const _BoundaryCard(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · PERSONAL OPERATIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Trip History & Profile',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Read-only operational history derived from your assigned transport records on this device.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final DriverProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final identity = Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.directions_bus_outlined, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.driverName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text('${profile.roleLabel} · ${profile.schoolName}'),
                      Text(
                        'Membership ${profile.membershipId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );

            final assignment = Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _ProfileDatum(label: 'Route', value: '${profile.routeId} · ${profile.routeName}'),
                _ProfileDatum(label: 'Vehicle', value: profile.vehicle),
                _ProfileDatum(label: 'Assistant', value: profile.assistantName),
                _ProfileDatum(label: 'Assigned riders', value: '${profile.assignedRiders}'),
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: 18),
                  assignment,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: identity),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: assignment),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileDatum extends StatelessWidget {
  const _ProfileDatum({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});

  final DriverHistorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Recorded days', '${snapshot.recordedDays}', Icons.calendar_month_outlined),
      ('Completed service days', '${snapshot.completedServiceDays}', Icons.task_alt_outlined),
      ('Incidents reported', '${snapshot.totalIncidents}', Icons.report_problem_outlined),
      ('Vehicle defects', '${snapshot.totalVehicleDefects}', Icons.build_circle_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(metric.$3, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.$2,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(metric.$1),
                            ],
                          ),
                        ),
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

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.snapshot});

  final DriverHistorySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Transport history',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (snapshot.history.isEmpty)
          const _EmptyState()
        else
          for (final entry in snapshot.history) ...[
            _HistoryCard(entry: entry),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final DriverTripHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.serviceDate,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${entry.routeId} · ${entry.vehicle}'),
                    ],
                  ),
                ),
                Chip(
                  label: Text(entry.serviceCompleted ? 'Service complete' : 'Partial record'),
                ),
              ],
            ),
            const Divider(height: 26),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _RunSummary(
                  title: 'Morning · Home → School',
                  status: entry.morningStatus,
                  primary: '${entry.morningArrived}/${entry.morningExpected} arrived',
                  exceptions: entry.morningExceptions,
                ),
                _RunSummary(
                  title: 'Afternoon · School → Home',
                  status: entry.afternoonStatus,
                  primary: '${entry.afternoonSafelyReleased}/${entry.afternoonExpected} safely resolved',
                  exceptions: entry.afternoonExceptions,
                ),
              ],
            ),
            if (entry.incidentCount > 0 || entry.vehicleDefectCount > 0) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (entry.incidentCount > 0)
                    Chip(label: Text('${entry.incidentCount} incident${entry.incidentCount == 1 ? '' : 's'}')),
                  if (entry.vehicleDefectCount > 0)
                    Chip(label: Text('${entry.vehicleDefectCount} vehicle defect${entry.vehicleDefectCount == 1 ? '' : 's'}')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RunSummary extends StatelessWidget {
  const _RunSummary({
    required this.title,
    required this.status,
    required this.primary,
    required this.exceptions,
  });

  final String title;
  final String status;
  final String primary;
  final int exceptions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(status),
          Text(primary),
          Text('$exceptions transport exception${exceptions == 1 ? '' : 's'}'),
        ],
      ),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile & history boundary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This page is read-only and derived from transport records assigned to your Driver membership. It does not expose payroll, private HR notes, disciplinary records, other drivers, parent contact details, student academic records, or unrelated school data.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Queued local transport activity remains subject to synchronization and server acknowledgement; history shown on this device is not a substitute for the authoritative server audit record.',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.history_toggle_off_outlined, size: 40),
            const SizedBox(height: 10),
            const Text(
              'No transport history yet',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'Trip history will appear as Morning Run, Afternoon Run, incident and vehicle-check records are created for this Driver membership.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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
}
