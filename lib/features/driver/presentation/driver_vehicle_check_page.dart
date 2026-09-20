import 'package:flutter/material.dart';

import '../data/driver_vehicle_check_demo_data.dart';
import '../data/driver_vehicle_check_repository.dart';
import '../domain/driver_vehicle_check_models.dart';

class DriverVehicleCheckPage extends StatefulWidget {
  const DriverVehicleCheckPage({
    super.key,
    required this.repository,
    this.onCheckChanged,
  });

  final DriverVehicleCheckRepository repository;
  final VoidCallback? onCheckChanged;

  @override
  State<DriverVehicleCheckPage> createState() => _DriverVehicleCheckPageState();
}

class _DriverVehicleCheckPageState extends State<DriverVehicleCheckPage> {
  DriverVehicleCheckPeriod _period = DriverVehicleCheckPeriod.morning;
  late Future<DriverVehicleCheck> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadToday(_period);
  }

  void _reload() {
    setState(() => _future = widget.repository.loadToday(_period));
  }

  void _selectPeriod(DriverVehicleCheckPeriod period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _future = widget.repository.loadToday(period);
    });
  }

  Future<void> _run(
    Future<DriverVehicleCheck> Function() action, {
    String? success,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      widget.onCheckChanged?.call();
      setState(() {
        _future = Future.value(updated);
        _saving = false;
      });
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverVehicleCheck>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Vehicle check could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildCheck(snapshot.data!);
      },
    );
  }

  Widget _buildCheck(DriverVehicleCheck check) {
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
              _Header(check: check),
              const SizedBox(height: 16),
              _PeriodSelector(
                value: _period,
                onChanged: _selectPeriod,
              ),
              const SizedBox(height: 16),
              _StatusCard(check: check),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _checklist(check)),
                    const SizedBox(width: 18),
                    Expanded(flex: 3, child: _sidePanel(check)),
                  ],
                )
              else ...[
                _checklist(check),
                const SizedBox(height: 18),
                _sidePanel(check),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _checklist(DriverVehicleCheck check) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${check.period.label} pre-trip checklist',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Physically inspect every item. A failed critical item blocks departure until it is corrected and rechecked.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        for (final item in check.items) ...[
          _CheckItemCard(
            item: item,
            saving: _saving,
            onPass: () => _setItem(item, DriverVehicleCheckItemStatus.passed),
            onFail: () => _setItem(item, DriverVehicleCheckItemStatus.failed),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _setItem(
    DriverVehicleCheckItem item,
    DriverVehicleCheckItemStatus status,
  ) async {
    var note = '';
    if (status == DriverVehicleCheckItemStatus.failed) {
      final result = await _defectNote(item);
      if (result == null || result.trim().isEmpty) return;
      note = result.trim();
    }
    await _run(
      () => widget.repository.setItemStatus(
        period: _period,
        itemId: item.id,
        status: status,
        note: note,
      ),
    );
  }

  Future<String?> _defectNote(DriverVehicleCheckItem item) async {
    final controller = TextEditingController(text: item.note);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.label} — defect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observed issue',
                hintText: 'Describe only what you physically observed',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save defect'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _sidePanel(DriverVehicleCheck check) {
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
                  'Submit check',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text('${check.passedCount}/${check.items.length} passed'),
                Text('${check.failedCount} failed'),
                Text('${check.blockingFailureCount} blocking defect${check.blockingFailureCount == 1 ? '' : 's'}'),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _run(
                            () => widget.repository.submit(_period),
                            success: check.blockingFailureCount > 0
                                ? 'Vehicle check submitted. Departure remains blocked.'
                                : '${check.period.label} vehicle check submitted and queued for sync.',
                          ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    check.status == DriverVehicleCheckStatus.ready ||
                            check.status == DriverVehicleCheckStatus.blocked
                        ? 'Resubmit check'
                        : 'Submit check',
                  ),
                ),
                if (!check.allChecked) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${check.items.where((item) => !item.isChecked).length} item${check.items.where((item) => !item.isChecked).length == 1 ? '' : 's'} still unchecked.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _BoundaryCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Physical observation only',
          body: driverVehicleCheckSafetyBoundary,
        ),
        const SizedBox(height: 12),
        const _BoundaryCard(
          icon: Icons.cloud_off_outlined,
          title: 'Offline-first record',
          body: driverVehicleCheckOfflineBoundary,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.check});

  final DriverVehicleCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · VEHICLE SAFETY',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Vehicle Check',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${check.vehicle} · ${check.routeId} · ${check.serviceDate}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final DriverVehicleCheckPeriod value;
  final ValueChanged<DriverVehicleCheckPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DriverVehicleCheckPeriod>(
      segments: const [
        ButtonSegment(
          value: DriverVehicleCheckPeriod.morning,
          icon: Icon(Icons.wb_sunny_outlined),
          label: Text('Morning'),
        ),
        ButtonSegment(
          value: DriverVehicleCheckPeriod.afternoon,
          icon: Icon(Icons.nights_stay_outlined),
          label: Text('Afternoon'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.check});

  final DriverVehicleCheck check;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = check.status == DriverVehicleCheckStatus.blocked;
    final ready = check.status == DriverVehicleCheckStatus.ready;
    final icon = blocked
        ? Icons.block_outlined
        : ready
            ? Icons.verified_outlined
            : Icons.pending_actions_outlined;
    final body = blocked
        ? '${check.blockingFailureCount} critical safety defect${check.blockingFailureCount == 1 ? '' : 's'} block ${check.period.label.toLowerCase()} departure.'
        : ready
            ? '${check.period.label} check is ready on this device. Queued synchronization does not change the local safety decision.'
            : 'Complete every item and submit the check before this transport period can start.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: blocked
            ? scheme.errorContainer
            : ready
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.status.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
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

class _CheckItemCard extends StatelessWidget {
  const _CheckItemCard({
    required this.item,
    required this.saving,
    required this.onPass,
    required this.onFail,
  });

  final DriverVehicleCheckItem item;
  final bool saving;
  final VoidCallback onPass;
  final VoidCallback onFail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  item.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Chip(
                  avatar: Icon(
                    item.severity == DriverVehicleCheckSeverity.critical
                        ? Icons.shield_outlined
                        : Icons.info_outline,
                    size: 16,
                  ),
                  label: Text(item.severity.label),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(item.description),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Defect note: ${item.note}',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: saving ? null : onPass,
                  icon: Icon(
                    item.status == DriverVehicleCheckItemStatus.passed
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                  ),
                  label: const Text('Pass'),
                ),
                OutlinedButton.icon(
                  onPressed: saving ? null : onFail,
                  icon: Icon(
                    item.status == DriverVehicleCheckItemStatus.failed
                        ? Icons.error
                        : Icons.error_outline,
                  ),
                  label: const Text('Fail'),
                ),
                Chip(label: Text(item.status.label)),
              ],
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
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
