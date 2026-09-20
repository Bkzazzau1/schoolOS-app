import 'package:flutter/material.dart';

import '../data/transport_demo_data.dart';
import '../data/transport_repository.dart';
import '../domain/transport_control_models.dart';
import '../domain/transport_models.dart';
import 'transport_control_overview.dart';
import 'transport_driver_assignments_panel.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onTransportChanged,
  });

  final String schoolName;
  final TransportRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onTransportChanged;

  @override
  State<TransportPage> createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage> {
  final _searchController = TextEditingController();
  TransportSnapshot? _snapshot;
  TransportControlSnapshot? _controlSnapshot;
  TransportRouteStatus? _statusFilter;
  bool _loading = true;
  String? _error;
  String? _controlError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _controlError = null;
    });
    try {
      final snapshot = await widget.repository.load();
      TransportControlSnapshot? controlSnapshot;
      String? controlError;
      if (snapshot.permissions.canViewOperationsControl) {
        try {
          controlSnapshot = await widget.repository.loadControlOverview();
        } catch (error) {
          controlError = '$error';
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _controlSnapshot = controlSnapshot;
        _controlError = controlError;
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

  Future<void> _toggleReview(SchoolTransportRoute route) async {
    final result = await widget.repository.toggleRouteReview(route.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onTransportChanged?.call();
      await _load();
    }
  }

  void _assignmentChanged() {
    widget.onTransportChanged?.call();
    _load();
  }

  List<SchoolTransportRoute> get _visibleRoutes {
    final routes = _snapshot?.routes ?? const <SchoolTransportRoute>[];
    return routes
        .where((route) => route.matches(_searchController.text, _statusFilter))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text('Could not load school transport: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = transportStats(snapshot.routes);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              22,
              compact ? 16 : 28,
              40,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to School Life',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School Transport',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.schoolName} · Routes, vehicles and rider accountability',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Coordinate school buses, routes, drivers, assistants, stops and daily rider checks. $transportGpsBoundary',
                style: theme.textTheme.bodyMedium,
              ),
              if (snapshot.permissions.canViewOperationsControl) ...[
                const SizedBox(height: 20),
                if (_controlSnapshot != null)
                  TransportControlOverview(snapshot: _controlSnapshot!)
                else
                  _ControlFailureCard(
                    message: _controlError ??
                        'Transport Operations Control could not be loaded.',
                    onRetry: _load,
                  ),
                const SizedBox(height: 18),
                TransportDriverAssignmentsPanel(
                  repository: widget.repository,
                  onChanged: _assignmentChanged,
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final stat in stats)
                    SizedBox(
                      width: compact ? 160 : 205,
                      child: _StatCard(stat: stat),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              if (compact) ...[
                _RouteRegister(
                  routes: _visibleRoutes,
                  permissions: snapshot.permissions,
                  searchController: _searchController,
                  statusFilter: _statusFilter,
                  onQueryChanged: (_) => setState(() {}),
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                  onToggleReview: _toggleReview,
                ),
                const SizedBox(height: 16),
                const _SafetySidebar(),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _RouteRegister(
                        routes: _visibleRoutes,
                        permissions: snapshot.permissions,
                        searchController: _searchController,
                        statusFilter: _statusFilter,
                        onQueryChanged: (_) => setState(() {}),
                        onStatusChanged: (value) =>
                            setState(() => _statusFilter = value),
                        onToggleReview: _toggleReview,
                      ),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(flex: 3, child: _SafetySidebar()),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ControlFailureCard extends StatelessWidget {
  const _ControlFailureCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transport Operations Control unavailable',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload transport control'),
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final TransportStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 7),
            Text(
              stat.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              stat.detail,
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

class _RouteRegister extends StatelessWidget {
  const _RouteRegister({
    required this.routes,
    required this.permissions,
    required this.searchController,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onToggleReview,
  });

  final List<SchoolTransportRoute> routes;
  final TransportPermissions permissions;
  final TextEditingController searchController;
  final TransportRouteStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TransportRouteStatus?> onStatusChanged;
  final ValueChanged<SchoolTransportRoute> onToggleReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transport routes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Operational status should show who is expected, who checked in and whether the vehicle is cleared.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 560;
                final search = TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search route, vehicle or driver...',
                    border: OutlineInputBorder(),
                  ),
                );
                final filter = DropdownButtonFormField<TransportRouteStatus?>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<TransportRouteStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    for (final status in TransportRouteStatus.values)
                      DropdownMenuItem<TransportRouteStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: onStatusChanged,
                );
                if (stacked) {
                  return Column(
                    children: [search, const SizedBox(height: 10), filter],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 10),
                    Expanded(child: filter),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No routes match these filters.')),
              )
            else
              for (final route in routes) ...[
                _RouteCard(
                  route: route,
                  canReview: permissions.canReviewRoutes,
                  onToggleReview: () => onToggleReview(route),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.canReview,
    required this.onToggleReview,
  });

  final SchoolTransportRoute route;
  final bool canReview;
  final VoidCallback onToggleReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Pill(route.status.label),
              _Pill('${route.riders} riders'),
              _Pill('${route.stops} stops'),
              if (route.reviewed) const _Pill('Reviewed'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            route.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${route.vehicle} · Driver ${route.driver} · Assistant ${route.assistant}',
          ),
          const SizedBox(height: 7),
          Text(
            route.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Morning: ${route.morning} · Afternoon: ${route.afternoon}',
            style: theme.textTheme.bodySmall,
          ),
          if (canReview) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onToggleReview,
              icon: Icon(
                route.reviewed
                    ? Icons.restart_alt_rounded
                    : Icons.fact_check_outlined,
                size: 18,
              ),
              label: Text(
                route.reviewed ? 'Reopen check' : 'Mark route reviewed',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

class _SafetySidebar extends StatelessWidget {
  const _SafetySidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRANSPORT SAFETY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in transportSafetyRules.entries) ...[
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(entry.value, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PARENT EXPERIENCE LATER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  transportParentExperience,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
