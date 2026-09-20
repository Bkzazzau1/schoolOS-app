import 'package:flutter/material.dart';

import '../data/driver_route_repository.dart';
import '../domain/driver_route_models.dart';

const driverRoutePrivacyBoundary =
    'This route view uses approved school transport stop names only. It does not reveal student home addresses, guardian contact details, or unrelated family information.';

const driverRouteGpsBoundary =
    'Route progression is manual in this version. Live GPS, ETA and geofence detection are not required for the driver to complete transport operations offline.';

class DriverRoutePage extends StatefulWidget {
  const DriverRoutePage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final DriverRouteRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<DriverRoutePage> createState() => _DriverRoutePageState();
}

class _DriverRoutePageState extends State<DriverRoutePage> {
  late Future<DriverRouteSnapshot> _future;
  DriverRouteDirection _direction = DriverRouteDirection.morning;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadToday();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadToday());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverRouteSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Assigned route could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildRoute(snapshot.data!);
      },
    );
  }

  Widget _buildRoute(DriverRouteSnapshot snapshot) {
    final stops = snapshot.stopsFor(_direction);
    final completed = snapshot.completedStops(_direction);

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
              _Header(snapshot: snapshot),
              const SizedBox(height: 16),
              _RouteSummary(
                snapshot: snapshot,
                direction: _direction,
                completedStops: completed,
              ),
              const SizedBox(height: 16),
              _DirectionSelector(
                value: _direction,
                onChanged: (value) => setState(() => _direction = value),
              ),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _timeline(stops)),
                    const SizedBox(width: 18),
                    Expanded(flex: 3, child: _sidePanel(snapshot)),
                  ],
                )
              else ...[
                _timeline(stops),
                const SizedBox(height: 18),
                _sidePanel(snapshot),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _timeline(List<DriverRouteStopView> stops) {
    final morning = _direction == DriverRouteDirection.morning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TerminalCard(
          icon: morning ? Icons.home_outlined : Icons.school_outlined,
          title: morning ? 'Home pickup route' : 'School departure',
          subtitle: morning
              ? 'Begin with the first approved pickup stop.'
              : 'Board and reconcile students before leaving school.',
        ),
        for (var index = 0; index < stops.length; index++) ...[
          _RouteConnector(
            completed: stops[index].state == DriverRouteStopState.completed ||
                stops[index].state == DriverRouteStopState.noService,
          ),
          _StopCard(stop: stops[index]),
        ],
        _RouteConnector(
          completed: stops.every(
            (stop) =>
                stop.state == DriverRouteStopState.completed ||
                stop.state == DriverRouteStopState.noService,
          ),
        ),
        _TerminalCard(
          icon: morning ? Icons.school_outlined : Icons.home_outlined,
          title: morning ? 'School arrival' : 'Route completion',
          subtitle: morning
              ? 'Arrival is confirmed explicitly in Morning Run.'
              : 'Every boarded rider must be safely released or returned to school.',
        ),
      ],
    );
  }

  Widget _sidePanel(DriverRouteSnapshot snapshot) {
    final runKey = _direction == DriverRouteDirection.morning
        ? 'morning'
        : 'afternoon';
    final runLabel = _direction == DriverRouteDirection.morning
        ? 'Open Morning Run'
        : 'Open Afternoon Run';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Operational actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Route & Stops is read-only. Record boarding, arrival, departure and drop-off only inside the active trip workflow.',
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => widget.onNavigate(runKey),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(runLabel),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate('riders'),
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('View assigned riders'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _BoundaryCard(
          icon: Icons.location_off_outlined,
          title: 'No GPS dependency',
          body: driverRouteGpsBoundary,
        ),
        const SizedBox(height: 12),
        const _BoundaryCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Stop privacy',
          body: driverRoutePrivacyBoundary,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final DriverRouteSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · ASSIGNED ROUTE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Route & Stops',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${snapshot.routeId} · ${snapshot.routeName} · ${snapshot.serviceDate}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({
    required this.snapshot,
    required this.direction,
    required this.completedStops,
  });

  final DriverRouteSnapshot snapshot;
  final DriverRouteDirection direction;
  final int completedStops;

  @override
  Widget build(BuildContext context) {
    final stops = snapshot.stopsFor(direction);
    final metrics = [
      ('Vehicle', snapshot.vehicle, Icons.directions_bus_outlined),
      ('Assistant', snapshot.assistantName, Icons.support_agent_outlined),
      ('Assigned riders', '${snapshot.totalAssignedRiders}', Icons.groups_2_outlined),
      ('Stops complete', '$completedStops/${stops.length}', Icons.route_outlined),
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
                              Text(metric.$1, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 3),
                              Text(
                                metric.$2,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
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

class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector({required this.value, required this.onChanged});

  final DriverRouteDirection value;
  final ValueChanged<DriverRouteDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DriverRouteDirection>(
      segments: const [
        ButtonSegment(
          value: DriverRouteDirection.morning,
          icon: Icon(Icons.wb_sunny_outlined),
          label: Text('Morning · Home → School'),
        ),
        ButtonSegment(
          value: DriverRouteDirection.afternoon,
          icon: Icon(Icons.nights_stay_outlined),
          label: Text('Afternoon · School → Home'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({required this.stop});

  final DriverRouteStopView stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Text('${stop.sequence}'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        stop.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _StateChip(state: stop.state),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Scheduled ${stop.scheduledTime} · ${stop.assignedRiders} assigned riders',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      _CountLabel(label: stop.primaryLabel, value: stop.primaryCount),
                      _CountLabel(label: stop.secondaryLabel, value: stop.secondaryCount),
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

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final DriverRouteStopState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      DriverRouteStopState.pending => Icons.schedule_outlined,
      DriverRouteStopState.active => Icons.location_on_outlined,
      DriverRouteStopState.completed => Icons.check_circle_outline_rounded,
      DriverRouteStopState.noService => Icons.remove_circle_outline_rounded,
    };
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(state.label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: '$value',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 2,
        height: 22,
        margin: const EdgeInsets.only(left: 34),
        color: completed
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _TerminalCard extends StatelessWidget {
  const _TerminalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
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
