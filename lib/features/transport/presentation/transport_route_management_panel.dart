import 'package:flutter/material.dart';

import '../data/transport_route_management_repository.dart';
import '../domain/transport_route_management_models.dart';

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
  bool _saving = false;

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
    return FutureBuilder<TransportRouteManagementSnapshot>(
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
                    'Routes & Stops Management',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Routes and stops could not be loaded.'}'),
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

  Widget _buildPanel(TransportRouteManagementSnapshot snapshot) {
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
                        'TRANSPORT CONTROL · ROUTE DESIGN',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Routes & Stops Management',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Maintain route identity, assigned vehicle/assistant, stop order and AM/PM timetable. Driver Portal consumes this plan as read-only operational scope.',
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
            _Metrics(snapshot: snapshot),
            const SizedBox(height: 18),
            if (snapshot.routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
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
                  onDeactivateStop: (stop) => _deactivateStop(entry, stop),
                ),
                const SizedBox(height: 12),
              ],
            Text(
              'Safety boundary: once a Driver manifest or vehicle check exists for today, route structure is locked for that service day. Historical trip records are never rewritten when the future route plan changes.',
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
    final value = await showDialog<_RouteFormValue>(
      context: context,
      builder: (_) => const _RouteFormDialog(),
    );
    if (value == null) return;
    await _perform(
      () => widget.repository.createRoute(
        name: value.name,
        vehicle: value.vehicle,
        assistant: value.assistant,
        note: value.note,
      ),
    );
  }

  Future<void> _editRoute(TransportRouteManagementEntry entry) async {
    final value = await showDialog<_RouteFormValue>(
      context: context,
      builder: (_) => _RouteFormDialog(
        title: 'Edit ${entry.route.id}',
        initial: _RouteFormValue(
          name: entry.route.name,
          vehicle: entry.route.vehicle,
          assistant: entry.route.assistant,
          note: entry.route.note,
        ),
      ),
    );
    if (value == null) return;
    await _perform(
      () => widget.repository.updateRoute(
        routeId: entry.route.id,
        name: value.name,
        vehicle: value.vehicle,
        assistant: value.assistant,
        note: value.note,
      ),
    );
  }

  Future<void> _addStop(TransportRouteManagementEntry entry) async {
    final value = await showDialog<_StopFormValue>(
      context: context,
      builder: (_) => _StopFormDialog(
        title: 'Add stop · ${entry.route.id}',
      ),
    );
    if (value == null) return;
    await _perform(
      () => widget.repository.addStop(
        routeId: entry.route.id,
        name: value.name,
        morningTime: value.morningTime,
        afternoonTime: value.afternoonTime,
      ),
    );
  }

  Future<void> _editStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
  ) async {
    final value = await showDialog<_StopFormValue>(
      context: context,
      builder: (_) => _StopFormDialog(
        title: 'Edit stop ${stop.sequence}',
        initial: _StopFormValue(
          name: stop.name,
          morningTime: stop.morningTime,
          afternoonTime: stop.afternoonTime,
        ),
      ),
    );
    if (value == null) return;
    await _perform(
      () => widget.repository.updateStop(
        routeId: entry.route.id,
        stopId: stop.id,
        name: value.name,
        morningTime: value.morningTime,
        afternoonTime: value.afternoonTime,
      ),
    );
  }

  Future<void> _moveStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
    int direction,
  ) async {
    await _perform(
      () => widget.repository.moveStop(
        routeId: entry.route.id,
        stopId: stop.id,
        direction: direction,
      ),
    );
  }

  Future<void> _deactivateStop(
    TransportRouteManagementEntry entry,
    TransportStopDefinition stop,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove stop from future plan?'),
        content: Text(
          '${stop.name} will be removed from future route sequencing. Historical trips remain unchanged. A stop with registered riders cannot be removed until those riders are reassigned.',
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
    await _perform(
      () => widget.repository.deactivateStop(
        routeId: entry.route.id,
        stopId: stop.id,
      ),
    );
  }

  Future<void> _perform(
    Future<dynamic> Function() action,
  ) async {
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

class _Metrics extends StatelessWidget {
  const _Metrics({required this.snapshot});

  final TransportRouteManagementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('Routes', '${snapshot.routes.length}', Icons.alt_route_rounded),
      ('Configured', '${snapshot.configuredRoutes}', Icons.route_outlined),
      ('Active stops', '${snapshot.totalStops}', Icons.pin_drop_outlined),
      ('Locked today', '${snapshot.lockedToday}', Icons.lock_clock_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(value.$3, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            value.$1,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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

class _RoutePlanCard extends StatelessWidget {
  const _RoutePlanCard({
    required this.entry,
    required this.canManage,
    required this.busy,
    required this.onEditRoute,
    required this.onAddStop,
    required this.onEditStop,
    required this.onMoveStop,
    required this.onDeactivateStop,
  });

  final TransportRouteManagementEntry entry;
  final bool canManage;
  final bool busy;
  final VoidCallback onEditRoute;
  final VoidCallback onAddStop;
  final ValueChanged<TransportStopDefinition> onEditStop;
  final void Function(TransportStopDefinition, int) onMoveStop;
  final ValueChanged<TransportStopDefinition> onDeactivateStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = entry.plan.activeStops;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: entry.lockedForToday
              ? theme.colorScheme.tertiary.withValues(alpha: .55)
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        Chip(label: Text(entry.route.id)),
                        Chip(label: Text('${stops.length} stops')),
                        if (entry.assignedDriverName.isNotEmpty)
                          Chip(label: Text(entry.assignedDriverName)),
                        if (entry.lockedForToday)
                          const Chip(
                            avatar: Icon(Icons.lock_clock_outlined, size: 16),
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
                    const SizedBox(height: 3),
                    Text(
                      '${entry.route.vehicle} · Assistant ${entry.route.assistant}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entry.route.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.route.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  enabled: !busy && !entry.lockedForToday,
                  onSelected: (value) {
                    if (value == 'edit') onEditRoute();
                    if (value == 'add') onAddStop();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit route details')),
                    PopupMenuItem(value: 'add', child: Text('Add stop')),
                  ],
                ),
            ],
          ),
          if (entry.lockedForToday) ...[
            const SizedBox(height: 10),
            Text(
              entry.lockReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (stops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No active stops configured for this route.'),
            )
          else
            for (var index = 0; index < stops.length; index++) ...[
              _StopRow(
                stop: stops[index],
                first: index == 0,
                last: index == stops.length - 1,
                canManage: canManage && !entry.lockedForToday && !busy,
                onEdit: () => onEditStop(stops[index]),
                onMoveUp: () => onMoveStop(stops[index], -1),
                onMoveDown: () => onMoveStop(stops[index], 1),
                onRemove: () => onDeactivateStop(stops[index]),
              ),
              if (index != stops.length - 1) const Divider(height: 14),
            ],
          if (canManage && !entry.lockedForToday) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : onAddStop,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add stop'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.first,
    required this.last,
    required this.canManage,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final TransportStopDefinition stop;
  final bool first;
  final bool last;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          child: Text('${stop.sequence}'),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'AM ${stop.morningTime} · PM ${stop.afternoonTime}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (canManage)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'up') onMoveUp();
              if (value == 'down') onMoveDown();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit stop')),
              PopupMenuItem(
                value: 'up',
                enabled: !first,
                child: const Text('Move earlier'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: !last,
                child: const Text('Move later'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove from future plan'),
              ),
            ],
          ),
      ],
    );
  }
}

class _RouteFormDialog extends StatefulWidget {
  const _RouteFormDialog({
    this.title = 'Create transport route',
    this.initial,
  });

  final String title;
  final _RouteFormValue? initial;

  @override
  State<_RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends State<_RouteFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _vehicle;
  late final TextEditingController _assistant;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _vehicle = TextEditingController(text: widget.initial?.vehicle ?? '');
    _assistant = TextEditingController(text: widget.initial?.assistant ?? '');
    _note = TextEditingController(text: widget.initial?.note ?? '');
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
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Route name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _vehicle,
                decoration: const InputDecoration(
                  labelText: 'Vehicle',
                  hintText: 'Toyota Coaster · BGA-05',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _assistant,
                decoration: const InputDecoration(
                  labelText: 'Route assistant',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Operational note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _RouteFormValue(
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

class _StopFormDialog extends StatefulWidget {
  const _StopFormDialog({
    required this.title,
    this.initial,
  });

  final String title;
  final _StopFormValue? initial;

  @override
  State<_StopFormDialog> createState() => _StopFormDialogState();
}

class _StopFormDialogState extends State<_StopFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _morning;
  late final TextEditingController _afternoon;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _morning = TextEditingController(text: widget.initial?.morningTime ?? '');
    _afternoon = TextEditingController(text: widget.initial?.afternoonTime ?? '');
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
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Stop name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _morning,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Morning HH:mm',
                      hintText: '06:45',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _afternoon,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Afternoon HH:mm',
                      hintText: '15:35',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _StopFormValue(
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

class _RouteFormValue {
  const _RouteFormValue({
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

class _StopFormValue {
  const _StopFormValue({
    required this.name,
    required this.morningTime,
    required this.afternoonTime,
  });

  final String name;
  final String morningTime;
  final String afternoonTime;
}
