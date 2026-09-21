import 'package:flutter/material.dart';

import '../data/transport_rider_assignment_repository.dart';
import '../data/transport_route_management_repository.dart';
import '../domain/transport_rider_assignment_models.dart';
import '../domain/transport_route_management_models.dart';

class TransportRiderAssignmentsPanel extends StatefulWidget {
  const TransportRiderAssignmentsPanel({
    super.key,
    required this.repository,
    required this.routeManagementRepository,
    this.onChanged,
  });

  final TransportRiderAssignmentRepository repository;
  final TransportRouteManagementRepository routeManagementRepository;
  final VoidCallback? onChanged;

  @override
  State<TransportRiderAssignmentsPanel> createState() =>
      _TransportRiderAssignmentsPanelState();
}

class _TransportRiderAssignmentsPanelState
    extends State<TransportRiderAssignmentsPanel> {
  final _searchController = TextEditingController();
  late Future<_RiderAssignmentViewData> _future;
  bool _saving = false;
  bool _unassignedOnly = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_RiderAssignmentViewData> _load() async {
    final riders = await widget.repository.load();
    final routes = await widget.routeManagementRepository.load();
    return _RiderAssignmentViewData(riders: riders, routes: routes);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RiderAssignmentViewData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Student / rider assignments',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Transport riders could not be loaded.'}'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildPanel(snapshot.data!);
      },
    );
  }

  Widget _buildPanel(_RiderAssignmentViewData data) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final visible = data.riders.riders.where((rider) {
      if (_unassignedOnly && rider.assigned) return false;
      if (query.isEmpty) return true;
      return '${rider.studentId} ${rider.name} ${rider.className}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);

    final routeById = {
      for (final route in data.routes.routes) route.route.id: route,
    };
    final stopById = <String, String>{};
    for (final route in data.routes.routes) {
      for (final stop in route.plan.activeStops) {
        stopById[stop.id] = stop.name;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
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
                        'TRANSPORT CONTROL · RIDERS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Student / rider assignments',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assign each transport student to one route and one public pickup/drop stop. Home addresses and unrelated family records are not part of this roster.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    data.riders.canManage
                        ? Icons.manage_accounts_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(data.riders.canManage ? 'Management enabled' : 'View only'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric('Students', '${data.riders.riders.length}'),
                _Metric('Assigned', '${data.riders.assignedCount}'),
                _Metric('Unassigned', '${data.riders.unassignedCount}'),
                _Metric('Routes', '${data.routes.routes.length}'),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final search = TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search student ID, name or class...',
                    border: OutlineInputBorder(),
                  ),
                );
                final filter = FilterChip(
                  selected: _unassignedOnly,
                  onSelected: (value) => setState(() => _unassignedOnly = value),
                  label: const Text('Unassigned only'),
                  avatar: const Icon(Icons.person_off_outlined, size: 18),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [search, const SizedBox(height: 10), filter],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 12),
                    filter,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No students match this transport filter.')),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        for (final rider in visible) ...[
                          _RiderCard(
                            rider: rider,
                            routeName: routeById[rider.currentRouteId]?.route.name ?? '',
                            stopName: stopById[rider.currentStopId] ?? '',
                            canManage: data.riders.canManage,
                            busy: _saving,
                            onAssign: () => _assign(rider, data.routes),
                            onUnassign: () => _unassign(rider),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final rider in visible)
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: _RiderCard(
                            rider: rider,
                            routeName: routeById[rider.currentRouteId]?.route.name ?? '',
                            stopName: stopById[rider.currentStopId] ?? '',
                            canManage: data.riders.canManage,
                            busy: _saving,
                            onAssign: () => _assign(rider, data.routes),
                            onUnassign: () => _unassign(rider),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            Text(
              'Safety boundary: rider changes affect future manifests only. Once a route has today’s manifest or vehicle check, assignments on that route are locked for the service day. Queued assignment changes are not server-confirmed until synchronization succeeds.',
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

  Future<void> _assign(
    TransportRiderCandidate rider,
    TransportRouteManagementSnapshot routes,
  ) async {
    if (_saving) return;
    final selection = await showDialog<_RouteStopSelection>(
      context: context,
      builder: (context) => _RouteStopDialog(
        rider: rider,
        routes: routes.routes,
      ),
    );
    if (selection == null) return;

    setState(() => _saving = true);
    try {
      final result = await widget.repository.assignStudent(
        studentId: rider.studentId,
        routeId: selection.routeId,
        stopId: selection.stopId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      setState(() {
        _saving = false;
        _future = _load();
      });
      if (result.success) widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Future<void> _unassign(TransportRiderCandidate rider) async {
    if (_saving || !rider.assigned) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove transport assignment?'),
        content: Text(
          '${rider.name} will be removed from future school transport manifests. Historical trip records are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await widget.repository.unassignStudent(rider.studentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      setState(() {
        _saving = false;
        _future = _load();
      });
      if (result.success) widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  String _message(Object error) {
    if (error is StateError) return error.message;
    if (error is ArgumentError) return '${error.message}';
    return '$error';
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _RiderCard extends StatelessWidget {
  const _RiderCard({
    required this.rider,
    required this.routeName,
    required this.stopName,
    required this.canManage,
    required this.busy,
    required this.onAssign,
    required this.onUnassign,
  });

  final TransportRiderCandidate rider;
  final String routeName;
  final String stopName;
  final bool canManage;
  final bool busy;
  final VoidCallback onAssign;
  final VoidCallback onUnassign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Text(
                  rider.name.trim().isEmpty ? '?' : rider.name.trim()[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text('${rider.studentId} · ${rider.className}'),
                  ],
                ),
              ),
              Chip(
                label: Text(rider.assigned ? 'Assigned' : 'Unassigned'),
                avatar: Icon(
                  rider.assigned
                      ? Icons.directions_bus_outlined
                      : Icons.person_off_outlined,
                  size: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rider.assigned
                ? '$routeName · $stopName'
                : 'No school transport route assigned',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onAssign,
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: Text(rider.assigned ? 'Reassign' : 'Assign'),
                ),
                if (rider.assigned)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onUnassign,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteStopDialog extends StatefulWidget {
  const _RouteStopDialog({required this.rider, required this.routes});

  final TransportRiderCandidate rider;
  final List<TransportRouteManagementEntry> routes;

  @override
  State<_RouteStopDialog> createState() => _RouteStopDialogState();
}

class _RouteStopDialogState extends State<_RouteStopDialog> {
  String? _routeId;
  String? _stopId;

  @override
  void initState() {
    super.initState();
    if (widget.rider.currentRouteId.isNotEmpty &&
        widget.routes.any((entry) => entry.route.id == widget.rider.currentRouteId)) {
      _routeId = widget.rider.currentRouteId;
      _stopId = widget.rider.currentStopId;
    }
  }

  @override
  Widget build(BuildContext context) {
    TransportRouteManagementEntry? selectedRoute;
    for (final route in widget.routes) {
      if (route.route.id == _routeId) {
        selectedRoute = route;
        break;
      }
    }
    final stops = selectedRoute?.plan.activeStops ?? const <TransportStopDefinition>[];
    if (_stopId != null && !stops.any((stop) => stop.id == _stopId)) {
      _stopId = null;
    }

    return AlertDialog(
      title: Text(widget.rider.assigned ? 'Reassign rider' : 'Assign rider'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.rider.name} · ${widget.rider.studentId} · ${widget.rider.className}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _routeId,
              decoration: const InputDecoration(
                labelText: 'Transport route',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final route in widget.routes)
                  DropdownMenuItem(
                    value: route.route.id,
                    child: Text(
                      '${route.route.id} · ${route.route.name}${route.lockedForToday ? ' · Locked today' : ''}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _routeId = value;
                _stopId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _stopId,
              decoration: const InputDecoration(
                labelText: 'Pickup / drop stop',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final stop in stops)
                  DropdownMenuItem(
                    value: stop.id,
                    child: Text(
                      '${stop.sequence}. ${stop.name} · ${stop.morningTime} / ${stop.afternoonTime}',
                    ),
                  ),
              ],
              onChanged: stops.isEmpty
                  ? null
                  : (value) => setState(() => _stopId = value),
            ),
            if (selectedRoute?.lockedForToday == true) ...[
              const SizedBox(height: 12),
              Text(
                selectedRoute!.lockReason,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _routeId == null ||
                  _stopId == null ||
                  selectedRoute?.lockedForToday == true
              ? null
              : () => Navigator.of(context).pop(
                    _RouteStopSelection(routeId: _routeId!, stopId: _stopId!),
                  ),
          child: const Text('Save assignment'),
        ),
      ],
    );
  }
}

class _RouteStopSelection {
  const _RouteStopSelection({required this.routeId, required this.stopId});
  final String routeId;
  final String stopId;
}

class _RiderAssignmentViewData {
  const _RiderAssignmentViewData({required this.riders, required this.routes});
  final TransportRiderAssignmentSnapshot riders;
  final TransportRouteManagementSnapshot routes;
}
