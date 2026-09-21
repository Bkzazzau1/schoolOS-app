import 'package:flutter/material.dart';

import '../../driver/domain/driver_vehicle_check_models.dart';
import '../data/transport_vehicle_readiness_repository.dart';
import '../domain/transport_vehicle_readiness_models.dart';

class TransportVehicleReadinessPanel extends StatefulWidget {
  const TransportVehicleReadinessPanel({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final TransportVehicleReadinessRepository repository;
  final VoidCallback? onChanged;

  @override
  State<TransportVehicleReadinessPanel> createState() =>
      _TransportVehicleReadinessPanelState();
}

class _TransportVehicleReadinessPanelState
    extends State<TransportVehicleReadinessPanel> {
  late Future<TransportVehicleReadinessSnapshot> _future;
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
    return FutureBuilder<TransportVehicleReadinessSnapshot>(
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
                    'Vehicles & readiness',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Vehicle readiness could not be loaded.'}'),
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

  Widget _buildPanel(TransportVehicleReadinessSnapshot snapshot) {
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
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSPORT CONTROL · VEHICLES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Vehicles & readiness',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review the vehicle attached to each route, today’s Driver checks and open defects, then control whether the vehicle is released, held or under maintenance.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    snapshot.canManage
                        ? Icons.admin_panel_settings_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(snapshot.canManage ? 'Management enabled' : 'View only'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric('Vehicles', '${snapshot.vehicles.length}'),
                _Metric('Released', '${snapshot.releasedCount}'),
                _Metric('Blocked / held', '${snapshot.blockedCount}'),
                _Metric('Blocking defects', '${snapshot.blockingDefectCount}'),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No route vehicles are configured.')),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    for (final vehicle in snapshot.vehicles)
                      _VehicleCard(
                        vehicle: vehicle,
                        canManage: snapshot.canManage,
                        busy: _saving,
                        onRelease: () => _changeStatus(
                          vehicle,
                          TransportVehicleClearanceStatus.released,
                        ),
                        onHold: () => _changeStatus(
                          vehicle,
                          TransportVehicleClearanceStatus.held,
                        ),
                        onMaintenance: () => _changeStatus(
                          vehicle,
                          TransportVehicleClearanceStatus.maintenance,
                        ),
                      ),
                  ];
                  if (constraints.maxWidth < 960) {
                    return Column(
                      children: [
                        for (var index = 0; index < cards.length; index++) ...[
                          cards[index],
                          if (index != cards.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in cards)
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: card,
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 12),
            Text(
              transportVehicleReadinessBoundary,
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

  Future<void> _changeStatus(
    TransportVehicleReadinessEntry vehicle,
    TransportVehicleClearanceStatus status,
  ) async {
    if (_saving) return;
    var note = '';
    if (status != TransportVehicleClearanceStatus.released) {
      final controller = TextEditingController(text: vehicle.clearance.note);
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            status == TransportVehicleClearanceStatus.maintenance
                ? 'Mark vehicle under maintenance'
                : 'Hold vehicle from service',
          ),
          content: SizedBox(
            width: 520,
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Operational reason',
                hintText: 'Briefly state why this vehicle cannot be used.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (result == null || result.trim().isEmpty) return;
      note = result.trim();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Release vehicle for service?'),
          content: Text(
            '${vehicle.vehicle} will be marked released by Transport Control. Open trip-blocking defects will still prevent release.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Release'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final result = await widget.repository.setClearance(
        routeId: vehicle.routeId,
        status: status,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      setState(() {
        _saving = false;
        _future = widget.repository.load();
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

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.canManage,
    required this.busy,
    required this.onRelease,
    required this.onHold,
    required this.onMaintenance,
  });

  final TransportVehicleReadinessEntry vehicle;
  final bool canManage;
  final bool busy;
  final VoidCallback onRelease;
  final VoidCallback onHold;
  final VoidCallback onMaintenance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = vehicle.effectivelyReleased;
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
              Chip(label: Text(vehicle.routeId)),
              Chip(
                avatar: Icon(
                  effective
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_outlined,
                  size: 17,
                ),
                label: Text(vehicle.readinessLabel),
              ),
              if (vehicle.blockingDefectCount > 0)
                Chip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 17),
                  label: Text('${vehicle.blockingDefectCount} blocking defect${vehicle.blockingDefectCount == 1 ? '' : 's'}'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            vehicle.vehicle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text('${vehicle.routeName} · Driver ${vehicle.driverName}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CheckPill(
                label: 'Morning',
                status: vehicle.morningCheckStatus,
              ),
              _CheckPill(
                label: 'Afternoon',
                status: vehicle.afternoonCheckStatus,
              ),
              _SimplePill('${vehicle.openDefectCount} open defects'),
            ],
          ),
          if (vehicle.clearance.note.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              vehicle.clearance.note,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: busy || effective ? null : onRelease,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Release'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ||
                          vehicle.clearance.status ==
                              TransportVehicleClearanceStatus.held
                      ? null
                      : onHold,
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                  label: const Text('Hold'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ||
                          vehicle.clearance.status ==
                              TransportVehicleClearanceStatus.maintenance
                      ? null
                      : onMaintenance,
                  icon: const Icon(Icons.build_outlined, size: 18),
                  label: const Text('Maintenance'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
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

class _CheckPill extends StatelessWidget {
  const _CheckPill({required this.label, required this.status});
  final String label;
  final DriverVehicleCheckStatus? status;

  @override
  Widget build(BuildContext context) {
    return _SimplePill('$label · ${status?.label ?? 'No check'}');
  }
}

class _SimplePill extends StatelessWidget {
  const _SimplePill(this.label);
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
