import 'package:flutter/material.dart';

import '../data/transport_repository.dart';
import '../domain/transport_driver_assignment_models.dart';

class TransportDriverAssignmentsPanel extends StatefulWidget {
  const TransportDriverAssignmentsPanel({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final TransportRepository repository;
  final VoidCallback? onChanged;

  @override
  State<TransportDriverAssignmentsPanel> createState() =>
      _TransportDriverAssignmentsPanelState();
}

class _TransportDriverAssignmentsPanelState
    extends State<TransportDriverAssignmentsPanel> {
  late Future<TransportDriverAssignmentsSnapshot> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadDriverAssignments();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadDriverAssignments());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransportDriverAssignmentsSnapshot>(
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
                    'Drivers & assignments',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Driver assignments could not be loaded.'}'),
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

  Widget _buildPanel(TransportDriverAssignmentsSnapshot snapshot) {
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
                        'TRANSPORT CONTROL · STAFFING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Drivers & assignments',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Approved Driver staff appear here. A Driver needs an activated SchoolOS membership before an operational route can be assigned.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    snapshot.canManageAssignments
                        ? Icons.edit_road_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(
                    snapshot.canManageAssignments
                        ? 'Assignment management enabled'
                        : 'View only',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Metrics(snapshot: snapshot),
            if (snapshot.conflictingRoutes > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${snapshot.conflictingRoutes} route assignment conflict${snapshot.conflictingRoutes == 1 ? '' : 's'} detected. Resolve duplicate active assignments before assigning another Driver to those routes.',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (snapshot.drivers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No approved Driver staff or linked Driver memberships are available yet.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 920) {
                    return Column(
                      children: [
                        for (final driver in snapshot.drivers) ...[
                          _DriverCard(
                            driver: driver,
                            snapshot: snapshot,
                            busy: _saving,
                            canManage: snapshot.canManageAssignments,
                            onAssign: () => _assign(driver, snapshot),
                            onUnassign: () => _unassign(driver),
                          ),
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
                      for (final driver in snapshot.drivers)
                        SizedBox(
                          width: width,
                          child: _DriverCard(
                            driver: driver,
                            snapshot: snapshot,
                            busy: _saving,
                            canManage: snapshot.canManageAssignments,
                            onAssign: () => _assign(driver, snapshot),
                            onUnassign: () => _unassign(driver),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            Text(
              'Assignment boundary: assigning a route changes the Driver Portal operational scope only. It does not change the person’s staff role, payroll, employment status or vehicle maintenance state. Changes are stored offline first and queued for sync.',
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
    TransportDriverRosterEntry driver,
    TransportDriverAssignmentsSnapshot snapshot,
  ) async {
    if (_saving || !driver.canReceiveOperationalAssignment) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => _RouteAssignmentDialog(
        driver: driver,
        routes: snapshot.routes,
      ),
    );
    if (selected == null || selected.isEmpty) return;

    setState(() => _saving = true);
    try {
      final result = await widget.repository.assignDriver(
        membershipId: driver.membershipId,
        routeId: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) widget.onChanged?.call();
      setState(() {
        _saving = false;
        _future = widget.repository.loadDriverAssignments();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(error))),
      );
    }
  }

  Future<void> _unassign(TransportDriverRosterEntry driver) async {
    if (_saving || !driver.assigned) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign Driver?'),
        content: Text(
          '${driver.name} will lose operational access to ${driver.routeName}. Historical trip records remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final result = await widget.repository.unassignDriver(driver.membershipId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) widget.onChanged?.call();
      setState(() {
        _saving = false;
        _future = widget.repository.loadDriverAssignments();
      });
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

  final TransportDriverAssignmentsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Driver staff', '${snapshot.drivers.length}', Icons.badge_outlined),
      ('Accounts linked', '${snapshot.linkedDrivers}', Icons.link_rounded),
      ('Assigned', '${snapshot.assignedDrivers}', Icons.route_outlined),
      ('Awaiting activation', '${snapshot.pendingActivation}', Icons.person_clock_outlined),
      ('Unassigned linked', '${snapshot.unassignedLinkedDrivers}', Icons.person_off_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 680
                ? 3
                : constraints.maxWidth >= 440
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
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(metric.$3, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metric.$2,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              metric.$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
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

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.snapshot,
    required this.busy,
    required this.canManage,
    required this.onAssign,
    required this.onUnassign,
  });

  final TransportDriverRosterEntry driver;
  final TransportDriverAssignmentsSnapshot snapshot;
  final bool busy;
  final bool canManage;
  final VoidCallback onAssign;
  final VoidCallback onUnassign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountLabel = driver.accountLinked
        ? 'SchoolOS account linked'
        : 'Account activation pending';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(
          color: driver.routeConflict
              ? theme.colorScheme.error
              : theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                child: Icon(
                  driver.accountLinked
                      ? Icons.directions_bus_outlined
                      : Icons.person_clock_outlined,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      driver.workArea.isEmpty
                          ? driver.jobTitle
                          : '${driver.jobTitle} · ${driver.workArea}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              Chip(label: Text(accountLabel)),
              if (driver.isDemoMembership)
                const Chip(label: Text('Demo membership')),
              if (driver.routeConflict)
                const Chip(label: Text('Assignment conflict')),
            ],
          ),
          const SizedBox(height: 8),
          if (driver.assigned) ...[
            Text(
              '${driver.routeId} · ${driver.routeName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(driver.vehicle, style: theme.textTheme.bodySmall),
          ] else
            Text(
              driver.accountLinked
                  ? 'No active transport route assigned.'
                  : 'Complete account activation before assigning a route.',
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
                OutlinedButton.icon(
                  onPressed: busy || !driver.canReceiveOperationalAssignment
                      ? null
                      : onAssign,
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: Text(driver.assigned ? 'Reassign' : 'Assign route'),
                ),
                if (driver.assigned)
                  TextButton.icon(
                    onPressed: busy ? null : onUnassign,
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Unassign'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteAssignmentDialog extends StatefulWidget {
  const _RouteAssignmentDialog({
    required this.driver,
    required this.routes,
  });

  final TransportDriverRosterEntry driver;
  final List<TransportAssignableRoute> routes;

  @override
  State<_RouteAssignmentDialog> createState() =>
      _RouteAssignmentDialogState();
}

class _RouteAssignmentDialogState extends State<_RouteAssignmentDialog> {
  String? _routeId;

  @override
  void initState() {
    super.initState();
    _routeId = widget.driver.assigned ? widget.driver.routeId : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.driver.assigned ? 'Reassign Driver' : 'Assign Driver'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.driver.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _routeId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Transport route',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final route in widget.routes)
                  DropdownMenuItem<String>(
                    value: route.routeId,
                    enabled: !route.hasConflict &&
                        (!route.alreadyAssigned ||
                            route.assignedMembershipId ==
                                widget.driver.membershipId),
                    child: Text(
                      '${route.routeId} · ${route.routeName} · ${route.vehicle}'
                      '${route.hasConflict ? ' · CONFLICT' : route.alreadyAssigned && route.assignedMembershipId != widget.driver.membershipId ? ' · assigned' : route.available ? '' : ' · maintenance'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _routeId = value),
            ),
            const SizedBox(height: 10),
            Text(
              'A route under maintenance may remain assigned, but the Driver Portal will still block service until vehicle readiness is cleared.',
              style: Theme.of(context).textTheme.bodySmall,
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
          onPressed: _routeId == null
              ? null
              : () => Navigator.of(context).pop(_routeId),
          child: const Text('Save assignment'),
        ),
      ],
    );
  }
}
