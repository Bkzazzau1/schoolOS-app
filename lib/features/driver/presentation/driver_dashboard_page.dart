import 'package:flutter/material.dart';

import '../data/driver_dashboard_demo_data.dart';
import '../data/driver_dashboard_repository.dart';
import '../domain/driver_dashboard_models.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final DriverDashboardRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  late Future<DriverDashboardSnapshot> _snapshot;

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
    return FutureBuilder<DriverDashboardSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Driver dashboard could not be loaded.'}',
            onRetry: _reload,
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final horizontal = wide ? 28.0 : 16.0;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
                children: [
                  _Header(
                    driverName: data.assignment.driverDisplayName,
                    routeId: data.route.id,
                  ),
                  const SizedBox(height: 18),
                  _RouteHero(data: data),
                  const SizedBox(height: 18),
                  _KpiGrid(data: data),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _MorningCard(
                            data: data,
                            onOpen: () => widget.onNavigate('morning'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _AfternoonCard(
                            data: data,
                            onOpen: () => widget.onNavigate('afternoon'),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _MorningCard(
                      data: data,
                      onOpen: () => widget.onNavigate('morning'),
                    ),
                    const SizedBox(height: 16),
                    _AfternoonCard(
                      data: data,
                      onOpen: () => widget.onNavigate('afternoon'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _VehicleCard(
                            data: data,
                            onOpen: () => widget.onNavigate('vehicle-check'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _QuickActions(
                            onNavigate: widget.onNavigate,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _VehicleCard(
                      data: data,
                      onOpen: () => widget.onNavigate('vehicle-check'),
                    ),
                    const SizedBox(height: 16),
                    _QuickActions(onNavigate: widget.onNavigate),
                  ],
                  const SizedBox(height: 16),
                  const _BoundaryCard(
                    icon: Icons.shield_outlined,
                    title: 'Driver privacy boundary',
                    body: driverPrivacyBoundary,
                  ),
                  const SizedBox(height: 12),
                  const _BoundaryCard(
                    icon: Icons.fact_check_outlined,
                    title: 'Transport event boundary',
                    body: driverSafetyBoundary,
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
  const _Header({required this.driverName, required this.routeId});

  final String driverName;
  final String routeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DRIVER PORTAL · TODAY',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Driver Dashboard',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$driverName · Assigned route $routeId',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Chip(
          avatar: const Icon(Icons.directions_bus_outlined, size: 18),
          label: const Text('Assigned transport only'),
        ),
      ],
    );
  }
}

class _RouteHero extends StatelessWidget {
  const _RouteHero({required this.data});

  final DriverDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: .55),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.route.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text('${data.route.vehicle} · ${data.route.stops} stops'),
                const SizedBox(height: 6),
                Text('Assistant: ${data.route.assistant}'),
                const SizedBox(height: 12),
                Text(
                  data.nextAction,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            );
            final status = _StatusBadge(label: data.route.status.label);
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 14), status],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                status,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.data});

  final DriverDashboardSnapshot data;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _KpiCard(
        icon: Icons.groups_2_outlined,
        label: 'Expected riders',
        value: '${data.route.riders}',
        detail: 'Assigned to ${data.route.id}',
      ),
      _KpiCard(
        icon: Icons.how_to_reg_outlined,
        label: 'Morning checked',
        value: '${data.morningChecked}/${data.morningExpected}',
        detail: data.route.morning,
      ),
      _KpiCard(
        icon: Icons.warning_amber_rounded,
        label: 'Morning exceptions',
        value: '${data.morningExceptions}',
        detail: data.morningExceptions == 0
            ? 'No unresolved rider exception'
            : 'Needs reconciliation',
      ),
      _KpiCard(
        icon: Icons.route_outlined,
        label: 'Stops',
        value: '${data.route.stops}',
        detail: data.route.status.label,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

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
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MorningCard extends StatelessWidget {
  const _MorningCard({required this.data, required this.onOpen});

  final DriverDashboardSnapshot data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Morning run · Home → School',
      subtitle: 'Pickup, boarding and school-arrival accountability.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: 'Rider check', value: data.route.morning),
          _InfoRow(label: 'Route status', value: data.route.status.label),
          _InfoRow(label: 'Exceptions', value: '${data.morningExceptions}'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Open morning run'),
          ),
        ],
      ),
    );
  }
}

class _AfternoonCard extends StatelessWidget {
  const _AfternoonCard({required this.data, required this.onOpen});

  final DriverDashboardSnapshot data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Afternoon run · School → Home',
      subtitle: 'Boarding at school and confirmed drop completion.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: 'Current status', value: data.route.afternoon),
          _InfoRow(label: 'Expected riders', value: '${data.route.riders}'),
          const _InfoRow(label: 'Drop rule', value: 'Confirm actual handover'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Open afternoon run'),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.data, required this.onOpen});

  final DriverDashboardSnapshot data;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Vehicle readiness',
      subtitle: data.route.vehicle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            label: 'Availability',
            value: data.routeAvailable ? 'Available' : 'Unavailable',
          ),
          _InfoRow(
            label: 'Daily check',
            value: data.vehicleCheckRequired ? 'Required before next run' : 'Completed',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Open vehicle check'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick actions',
      subtitle: 'Operational transport tools for the assigned route.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => onNavigate('riders'),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Riders'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigate('route'),
            icon: const Icon(Icons.route_outlined),
            label: const Text('Route & stops'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigate('incidents'),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report incident'),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigate('messages'),
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Transport messages'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
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
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
