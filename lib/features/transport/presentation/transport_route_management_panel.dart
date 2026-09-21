import 'package:flutter/material.dart';

import '../data/transport_rider_assignment_repository.dart';
import '../data/transport_route_management_repository.dart';
import '../data/transport_vehicle_readiness_repository.dart';
import '../domain/transport_route_management_models.dart';
import 'transport_rider_assignments_panel.dart';
import 'transport_vehicle_readiness_panel.dart';

class TransportRouteManagementPanel extends StatefulWidget {
  const TransportRouteManagementPanel({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final TransportRouteManagementRepository repository;
  final VoidCallback? onChanged;

  @override
  State<TransportRouteManagementPanel> createState() =>
      _TransportRouteManagementPanelState();
}

class _TransportRouteManagementPanelState
    extends State<TransportRouteManagementPanel> {
  late Future<TransportRouteManagementSnapshot> _future;
  late final TransportRiderAssignmentRepository _riders;
  late final TransportVehicleReadinessRepository _vehicles;
  bool _saving = false;
  int _childRevision = 0;

  @override
  void initState() {
    super.initState();
    _riders = TransportRiderAssignmentRepository(
      localDatabase: widget.repository.localDatabase,
      schoolSession: widget.repository.schoolSession,
    );
    _vehicles = TransportVehicleReadinessRepository(
      localDatabase: widget.repository.localDatabase,
      schoolSession: widget.repository.schoolSession,
    );
    _future = widget.repository.load();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  void _changed() {
    widget.onChanged?.call();
    setState(() {
      _childRevision++;
      _future = widget.repository.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<TransportRouteManagementSnapshot>(
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
                        'Routes & stops management',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text('${snapshot.error ?? 'Routes could not be loaded.'}'),
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
            return _buildRoutes(snapshot.data!);
          },
        ),
        const SizedBox(height: 18),
        TransportRiderAssignmentsPanel(
          key: ValueKey('transport-riders-$_childRevision'),
          repository: _riders,
          routeManagementRepository: widget.repository,
          onChanged: _changed,
        ),
        const SizedBox(height: 18),
        TransportVehicleReadinessPanel(
          key: ValueKey('transport-vehicles-$_childRevision'),
          repository: _vehicles,
          onChanged: _changed,
        ),
      ],
    );
  }

  Widget _buildRoutes(TransportRouteManagementSnapshot snapshot) {
    final theme = Theme.of(context);
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
                        'TRANSPORT CONTROL · ROUTE PLAN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Routes & stops management',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage route identity, assigned vehicle/assistant, stop order and morning/afternoon schedules. Driver Portal consumes this plan read-only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (snapshot.canManage)
                  FilledButton.icon(
                    onPressed: _saving ? null : _createRoute,
                    icon: const Icon(Icons.add_road_rounded),
                    label: const Text('New route'),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.visibility_outlined, size: 18),
                    label: Text('View only'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric('Routes', '${snapshot.routes.length}'),
                _Metric('Configured', '${snapshot.configuredRoutes}'),
                _Metric('Stops', '${snapshot.totalStops}'),
                _Metric('Locked today', '${snapshot.lockedToday}'),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No transport routes are configured.')),
              )
            else
              for (final entry in snapshot.routes) ...[
                _RoutePlanCard(
                  entry: entry,
                  canManage: snapshot.canManage,
                  busy: _saving,
                  onEditRoute: () => _editRoute(entry),
                  onAddStop: () => _addStop(entry),
                  onEditStop: (stop) => _editStop(entry, stop),
                  onMoveStop: (stop, direction) =>
                      _moveStop(entry, stop, direction),
                  onRemoveStop: (stop) => _removeStop(entry, stop),
                ),
                const SizedBox(height: 12),
              ],
            Text(
              'Configuration boundary: once a Driver manifest or vehicle check exists for today, route and stop changes are frozen for that service day. Changes otherwise save locally first and queue for synchronization.',
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

  Future<void> _createRoute() async {
    final value = await showDialog<_RouteEditValue>(
      context: context,
      builder: (context) => const _RouteEditDialog(),
    );
    if (value == null) return;
    await _run(() => widget.repository.createRoute(
          name: value.name,
          vehicle: value.vehicle,
          assistant: value.assistant,
          note: value.note,
        ));
  }

  Future<void> _editRoute(TransportRouteManagementEntry entry) async {
    final value = await showDialog<_RouteEditValue>(
      context: context,
      builder: (context) => _RouteEditDialog(entry: entry),
    );
    if (value == null) return;
    await _run(() => widget.repository.updateRoute(
          routeId: entry.route.id,
          name: value.name,
          vehicle: value.vehicle,
          assistant: value.assistant,
          note: value.note,
        ));
  }

  Future<void> _addStop(TransportRouteManagementEntry entry) async {
    final value = await showDialog<_StopEditValue>(
      context: context,
      builder: (context) => const _StopEditDialog(),
    );
    if (value == null) return;
    await _run(() => widget.repository.addStop(
          routeId: entry.route.id,
          name: value.name,
          morningTime: value.morningTime,
          afternoonTime: value.afternoonTime,
        ));
  }

  Future<void> _editStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
  ) async {
    final value = await showDialog<_StopEditValue>(
      context: context,
      builder: (context) => _StopEditDialog(stop: stop),
    );
    if (value == null) return;
    await _run(() => widget.repository.updateStop(
          routeId: entry.route.id,
          stopId: stop.id,
          name: value.name,
          morningTime: value.morningTime,
          afternoonTime: value.afternoonTime,
        ));
  }

  Future<void> _moveStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
    int direction,
  ) async {
    await _run(() => widget.repository.moveStop(
          routeId: entry.route.id,
          stopId: stop.id,
          direction: direction,
        ));
  }

  Future<void> _removeStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove stop from future route plan?'),
        content: Text(
          '${stop.name} will no longer appear in future manifests. Historical trip records remain unchanged. Students assigned to this stop must be reassigned first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove stop'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => widget.repository.deactivateStop(
          routeId: entry.route.id,
          stopId: stop.id,
        ));
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await action();
      if (!mounted) return;
      final message = result.message as String;
      final success = result.success as bool;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _saving = false;
        _future = widget.repository.load();
        if (success) _childRevision++;
      });
      if (success) widget.onChanged?.call();
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

class _RoutePlanCard extends StatelessWidget {
  const _RoutePlanCard({
    required this.entry,
    required this.canManage,
    required this.busy,
    required this.onEditRoute,
    required this.onAddStop,
    required this.onEditStop,
    required this.onMoveStop,
    required this.onRemoveStop,
  });

  final TransportRouteManagementEntry entry;
  final bool canManage;
  final bool busy;
  final VoidCallback onEditRoute;
  final VoidCallback onAddStop;
  final ValueChanged<TransportStopDefinition> onEditStop;
  final void Function(TransportStopDefinition stop, int direction) onMoveStop;
  final ValueChanged<TransportStopDefinition> onRemoveStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = entry.plan.activeStops;
    final controlsEnabled = canManage && !busy && !entry.lockedForToday;
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
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(entry.route.id)),
              Chip(label: Text('${entry.route.riders} riders')),
              Chip(label: Text('${entry.activeStopCount} stops')),
              if (entry.assignedDriverName.isNotEmpty)
                Chip(label: Text('Driver · ${entry.assignedDriverName}')),
              if (entry.lockedForToday)
                const Chip(
                  avatar: Icon(Icons.lock_outline_rounded, size: 17),
                  label: Text('Locked today'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.route.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('${entry.route.vehicle} · Assistant ${entry.route.assistant}'),
          if (entry.route.note.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(entry.route.note, style: theme.textTheme.bodySmall),
          ],
          if (entry.lockedForToday) ...[
            const SizedBox(height: 8),
            Text(
              entry.lockReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: controlsEnabled ? onEditRoute : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit route'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controlsEnabled ? onAddStop : null,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Add stop'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (stops.isEmpty)
            const Text('No active stops configured yet.')
          else
            for (var index = 0; index < stops.length; index++) ...[
              _StopRow(
                stop: stops[index],
                canManage: controlsEnabled,
                canMoveUp: index > 0,
                canMoveDown: index < stops.length - 1,
                onEdit: () => onEditStop(stops[index]),
                onMoveUp: () => onMoveStop(stops[index], -1),
                onMoveDown: () => onMoveStop(stops[index], 1),
                onRemove: () => onRemoveStop(stops[index]),
              ),
              if (index != stops.length - 1) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.canManage,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final TransportStopDefinition stop;
  final bool canManage;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 16, child: Text('${stop.sequence}')),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stop.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('AM ${stop.morningTime} · PM ${stop.afternoonTime}'),
            ],
          ),
        ),
        if (canManage)
          PopupMenuButton<String>(
            tooltip: 'Stop actions',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'up') onMoveUp();
              if (value == 'down') onMoveDown();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit stop')),
              PopupMenuItem(
                value: 'up',
                enabled: canMoveUp,
                child: const Text('Move earlier'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: canMoveDown,
                child: const Text('Move later'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'remove', child: Text('Remove stop')),
            ],
          ),
      ],
    );
  }
}

class _RouteEditDialog extends StatefulWidget {
  const _RouteEditDialog({this.entry});
  final TransportRouteManagementEntry? entry;

  @override
  State<_RouteEditDialog> createState() => _RouteEditDialogState();
}

class _RouteEditDialogState extends State<_RouteEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _vehicle;
  late final TextEditingController _assistant;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry?.route.name ?? '');
    _vehicle = TextEditingController(text: widget.entry?.route.vehicle ?? '');
    _assistant = TextEditingController(text: widget.entry?.route.assistant ?? '');
    _note = TextEditingController(text: widget.entry?.route.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _vehicle.dispose();
    _assistant.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Create transport route' : 'Edit route'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Route name')),
            const SizedBox(height: 10),
            TextField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Vehicle / fleet ID')),
            const SizedBox(height: 10),
            TextField(controller: _assistant, decoration: const InputDecoration(labelText: 'Assistant')),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Operational note')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _RouteEditValue(
              name: _name.text,
              vehicle: _vehicle.text,
              assistant: _assistant.text,
              note: _note.text,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StopEditDialog extends StatefulWidget {
  const _StopEditDialog({this.stop});
  final TransportStopDefinition? stop;

  @override
  State<_StopEditDialog> createState() => _StopEditDialogState();
}

class _StopEditDialogState extends State<_StopEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _morning;
  late final TextEditingController _afternoon;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.stop?.name ?? '');
    _morning = TextEditingController(text: widget.stop?.morningTime ?? '06:30');
    _afternoon = TextEditingController(text: widget.stop?.afternoonTime ?? '15:00');
  }

  @override
  void dispose() {
    _name.dispose();
    _morning.dispose();
    _afternoon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.stop == null ? 'Add transport stop' : 'Edit stop'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Public pickup / drop stop')),
            const SizedBox(height: 10),
            TextField(controller: _morning, decoration: const InputDecoration(labelText: 'Morning time · HH:mm')),
            const SizedBox(height: 10),
            TextField(controller: _afternoon, decoration: const InputDecoration(labelText: 'Afternoon time · HH:mm')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _StopEditValue(
              name: _name.text,
              morningTime: _morning.text,
              afternoonTime: _afternoon.text,
            ),
          ),
          child: const Text('Save stop'),
        ),
      ],
    );
  }
}

class _RouteEditValue {
  const _RouteEditValue({
    required this.name,
    required this.vehicle,
    required this.assistant,
    required this.note,
  });
  final String name;
  final String vehicle;
  final String assistant;
  final String note;
}

class _StopEditValue {
  const _StopEditValue({
    required this.name,
    required this.morningTime,
    required this.afternoonTime,
  });
  final String name;
  final String morningTime;
  final String afternoonTime;
}
