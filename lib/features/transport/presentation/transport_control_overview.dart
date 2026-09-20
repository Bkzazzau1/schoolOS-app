import 'package:flutter/material.dart';

import '../domain/transport_control_models.dart';

class TransportControlOverview extends StatelessWidget {
  const TransportControlOverview({
    super.key,
    required this.snapshot,
  });

  final TransportControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSPORT CONTROL · TODAY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Operations overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Morning and afternoon custody state from Driver Portal records for ${snapshot.serviceDate}.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _SourceBadge(
                  label:
                      '${snapshot.routesWithDriverActivity}/${snapshot.routes.length} routes with driver activity',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Metrics(snapshot: snapshot),
            const SizedBox(height: 18),
            if (snapshot.routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No configured transport routes are available.'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 900;
                  if (!twoColumns) {
                    return Column(
                      children: [
                        for (final route in snapshot.routes) ...[
                          _ActivityCard(route: route),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final route in snapshot.routes)
                        SizedBox(
                          width: width,
                          child: _ActivityCard(route: route),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 10),
            Text(
              'Operational boundary: this view can include local queued Driver activity. Queued does not mean server-confirmed, and a baseline route without Driver records is not presented as a live trip.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.snapshot});

  final TransportControlSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = <({String label, String value, String detail, IconData icon})>[
      (
        label: 'Active runs',
        value: '${snapshot.activeRuns}',
        detail: 'Vehicles currently on morning or afternoon route',
        icon: Icons.route_outlined,
      ),
      (
        label: 'Students onboard',
        value: '${snapshot.ridersCurrentlyOnBoard}',
        detail: 'Current local custody count from active Driver runs',
        icon: Icons.groups_2_outlined,
      ),
      (
        label: 'Incidents today',
        value: '${snapshot.incidentsToday}',
        detail: '${snapshot.urgentIncidentsToday} requiring immediate escalation',
        icon: Icons.report_problem_outlined,
      ),
      (
        label: 'Vehicle defects',
        value: '${snapshot.vehicleDefectsToday}',
        detail:
            '${snapshot.blockingVehicleDefectsToday} currently marked trip-blocking',
        icon: Icons.build_circle_outlined,
      ),
      (
        label: 'Need attention',
        value: '${snapshot.routesNeedingAttention}',
        detail: 'Routes with custody, urgent incident or blocking defect',
        icon: Icons.notification_important_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 5
            : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 480
                    ? 2
                    : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        metric.icon,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        metric.value,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        metric.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        metric.detail,
                        style: Theme.of(context).textTheme.bodySmall,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.route});

  final TransportControlRouteActivity route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(
          color: route.needsAttention
              ? theme.colorScheme.error.withValues(alpha: .45)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Pill(route.phase.label),
              _Pill('${route.expectedRiders} riders'),
              if (route.currentlyOnBoard > 0)
                _Pill('${route.currentlyOnBoard} onboard'),
              if (route.urgentIncidentCount > 0)
                _Pill('${route.urgentIncidentCount} urgent'),
              if (route.blockingVehicleDefectCount > 0)
                _Pill('${route.blockingVehicleDefectCount} blocking defect'),
              _SourceBadge(
                label: route.hasDriverActivity
                    ? 'Driver record'
                    : 'Baseline only',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${route.routeId} · ${route.routeName}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text('${route.vehicle} · Driver ${route.driverName}'),
          const SizedBox(height: 12),
          _OperationLine(
            icon: Icons.wb_sunny_outlined,
            label: 'Morning',
            value: route.morningSummary,
          ),
          const SizedBox(height: 8),
          _OperationLine(
            icon: Icons.nights_stay_outlined,
            label: 'Afternoon',
            value: route.afternoonSummary,
          ),
          if (route.incidentCount > 0 || route.vehicleDefectCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (route.incidentCount > 0)
                  Text(
                    '${route.incidentCount} incident${route.incidentCount == 1 ? '' : 's'} reported',
                    style: theme.textTheme.bodySmall,
                  ),
                if (route.vehicleDefectCount > 0)
                  Text(
                    '${route.vehicleDefectCount} vehicle defect${route.vehicleDefectCount == 1 ? '' : 's'} reported',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OperationLine extends StatelessWidget {
  const _OperationLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
