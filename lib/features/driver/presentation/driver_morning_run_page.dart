import 'package:flutter/material.dart';

import '../data/driver_morning_run_demo_data.dart';
import '../data/driver_morning_run_repository.dart';
import '../domain/driver_morning_run_models.dart';

class DriverMorningRunPage extends StatefulWidget {
  const DriverMorningRunPage({
    super.key,
    required this.repository,
    this.onRunChanged,
  });

  final DriverMorningRunRepository repository;
  final VoidCallback? onRunChanged;

  @override
  State<DriverMorningRunPage> createState() => _DriverMorningRunPageState();
}

class _DriverMorningRunPageState extends State<DriverMorningRunPage> {
  late Future<DriverMorningRun> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadToday();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadToday());
  }

  Future<void> _run(
    Future<DriverMorningRun> Function() action, {
    String? success,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await action();
      if (!mounted) return;
      widget.onRunChanged?.call();
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
    return FutureBuilder<DriverMorningRun>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Morning run could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildRun(snapshot.data!);
      },
    );
  }

  Widget _buildRun(DriverMorningRun run) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final padding = wide ? 28.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(padding, 20, padding, 40),
          children: [
            _Header(run: run),
            const SizedBox(height: 14),
            _StatusStrip(run: run),
            const SizedBox(height: 16),
            _PrimaryActionCard(
              run: run,
              saving: _saving,
              onStart: () => _run(
                widget.repository.startRun,
                success: 'Morning run started on this device and queued for sync.',
              ),
              onArriveNext: run.nextPendingStop == null
                  ? null
                  : () => _run(
                        () => widget.repository.arriveAtStop(run.nextPendingStop!.id),
                        success: 'Stop opened for rider check.',
                      ),
              onArriveSchool: () => _confirmSchoolArrival(run),
              onComplete: () => _run(
                widget.repository.completeRun,
                success: 'Morning run completed and queued for synchronization.',
              ),
            ),
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _stops(run)),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: _safetyPanel(run)),
                ],
              )
            else ...[
              _stops(run),
              const SizedBox(height: 18),
              _safetyPanel(run),
            ],
          ],
        );
      },
    );
  }

  Widget _stops(DriverMorningRun run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Route stops',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Work in order. A stop cannot be departed until every assigned rider has a recorded outcome.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        for (final stop in run.stops) ...[
          _StopCard(
            run: run,
            stop: stop,
            saving: _saving,
            canOpen: _canOpen(run, stop),
            onOpen: () => _run(
              () => widget.repository.arriveAtStop(stop.id),
              success: '${stop.name} opened.',
            ),
            onDepart: () => _run(
              () => widget.repository.departStop(stop.id),
              success: '${stop.name} departed and queued for sync.',
            ),
            onRiderStatus: (rider, status) =>
                _setRiderStatus(stop, rider, status),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  bool _canOpen(DriverMorningRun run, DriverMorningStop stop) {
    if (_saving || run.status != DriverMorningRunStatus.inProgress) return false;
    if (run.activeStop != null || stop.status != DriverMorningStopStatus.pending) {
      return false;
    }
    return run.nextPendingStop?.id == stop.id;
  }

  Future<void> _setRiderStatus(
    DriverMorningStop stop,
    DriverMorningRider rider,
    DriverMorningRiderStatus status,
  ) async {
    var note = '';
    if (status == DriverMorningRiderStatus.exception) {
      final result = await _exceptionNote(rider.name);
      if (result == null || result.trim().isEmpty) return;
      note = result.trim();
    }
    await _run(
      () => widget.repository.setRiderStatus(
        stopId: stop.id,
        studentId: rider.studentId,
        status: status,
        note: note,
      ),
    );
  }

  Future<String?> _exceptionNote(String riderName) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transport exception'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a short operational note for $riderName.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Exception note',
                hintText: 'For example: guardian requested office follow-up',
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
            child: const Text('Save exception'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _confirmSchoolArrival(DriverMorningRun run) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm arrival at school'),
        content: Text(
          '${run.boardedRiders} boarded rider${run.boardedRiders == 1 ? '' : 's'} will be marked as arrived at school. No-show, guardian-cancelled and exception records remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Confirm arrival'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(
      widget.repository.arriveAtSchool,
      success: 'School arrival recorded locally and queued for sync.',
    );
  }

  Widget _safetyPanel(DriverMorningRun run) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Morning accountability',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _Rule(
                  icon: Icons.person_search_outlined,
                  title: 'Record every rider',
                  body: 'Boarded, no-show, guardian cancelled or exception. Never leave a rider unresolved.',
                ),
                _Rule(
                  icon: Icons.directions_bus_filled_outlined,
                  title: 'Depart only after reconciliation',
                  body: 'A stop remains open until all assigned riders have an outcome.',
                ),
                _Rule(
                  icon: Icons.school_outlined,
                  title: 'Arrival is explicit',
                  body: 'Boarded does not mean arrived at school. Arrival is confirmed only at the school.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_person_outlined),
                const SizedBox(height: 10),
                Text(
                  'Transport privacy',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(driverMorningRunBoundary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerLow,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Text(driverMorningOfflineBoundary),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.run});

  final DriverMorningRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · MORNING SERVICE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Home → School',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${run.routeId} · ${run.vehicle} · ${run.serviceDate}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.run});

  final DriverMorningRun run;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(label: 'Run status', value: run.status.label),
        _Metric(label: 'Expected', value: '${run.expectedRiders} riders'),
        _Metric(label: 'Boarded', value: '${run.boardedRiders}'),
        _Metric(label: 'Exceptions', value: '${run.exceptions}'),
        _Metric(label: 'Stops complete', value: '${run.stops.where((s) => s.status == DriverMorningStopStatus.departed).length}/${run.stops.length}'),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({
    required this.run,
    required this.saving,
    required this.onStart,
    required this.onArriveNext,
    required this.onArriveSchool,
    required this.onComplete,
  });

  final DriverMorningRun run;
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback? onArriveNext;
  final VoidCallback onArriveSchool;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = run.activeStop;
    final next = run.nextPendingStop;

    String title;
    String body;
    Widget? action;

    switch (run.status) {
      case DriverMorningRunStatus.notStarted:
        title = 'Ready to begin morning service';
        body = 'The assigned manifest is stored on this device. Start the run before recording stop activity.';
        action = FilledButton.icon(
          onPressed: saving ? null : onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start morning run'),
        );
      case DriverMorningRunStatus.inProgress:
        if (active != null) {
          title = 'At ${active.name}';
          body = '${active.resolvedCount}/${active.riders.length} riders resolved. Record every rider before departure.';
        } else if (next != null) {
          title = 'Next stop: ${next.name}';
          body = 'Scheduled ${next.scheduledTime}. Open the stop when the vehicle reaches the pickup point.';
          action = FilledButton.icon(
            onPressed: saving ? null : onArriveNext,
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Arrived at stop'),
          );
        } else {
          title = 'All stops completed';
          body = '${run.boardedRiders} riders are on the bus. Confirm only when the vehicle has physically arrived at school.';
          action = FilledButton.icon(
            onPressed: saving ? null : onArriveSchool,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Arrived at school'),
          );
        }
      case DriverMorningRunStatus.arrivedSchool:
        title = 'School arrival confirmed';
        body = '${run.arrivedSchoolRiders} boarded riders are recorded as arrived at school. Complete the run after reconciliation.';
        action = FilledButton.icon(
          onPressed: saving ? null : onComplete,
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Complete morning run'),
        );
      case DriverMorningRunStatus.completed:
        title = 'Morning service completed';
        body = '${run.arrivedSchoolRiders} arrived · ${run.exceptions} exceptions · completion ${_time(run.completedAt)}.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              child: Icon(
                run.status == DriverMorningRunStatus.completed
                    ? Icons.done_all_rounded
                    : Icons.directions_bus_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 14),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.run,
    required this.stop,
    required this.saving,
    required this.canOpen,
    required this.onOpen,
    required this.onDepart,
    required this.onRiderStatus,
  });

  final DriverMorningRun run;
  final DriverMorningStop stop;
  final bool saving;
  final bool canOpen;
  final VoidCallback onOpen;
  final VoidCallback onDepart;
  final void Function(DriverMorningRider rider, DriverMorningRiderStatus status)
      onRiderStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = stop.status == DriverMorningStopStatus.active;
    final departed = stop.status == DriverMorningStopStatus.departed;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: active
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : null,
            child: Row(
              children: [
                CircleAvatar(
                  child: Text('${stop.sequence}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Scheduled ${stop.scheduledTime} · ${stop.riders.length} riders',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: stop.status.label),
              ],
            ),
          ),
          if (active || departed) ...[
            const Divider(height: 1),
            for (final rider in stop.riders)
              _RiderRow(
                rider: rider,
                editable: active && !saving,
                onStatus: (status) => onRiderStatus(rider, status),
              ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    departed
                        ? 'Departed ${_time(stop.departedAt)} · ${stop.boardedCount} boarded · ${stop.exceptionCount} exceptions'
                        : active
                            ? '${stop.resolvedCount}/${stop.riders.length} rider outcomes recorded'
                            : 'Waiting for previous route activity',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canOpen)
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Arrived at stop'),
                  ),
                if (active)
                  FilledButton.icon(
                    onPressed: saving || !stop.allRidersResolved ? null : onDepart,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Depart stop'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.rider,
    required this.editable,
    required this.onStatus,
  });

  final DriverMorningRider rider;
  final bool editable;
  final ValueChanged<DriverMorningRiderStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(_initials(rider.name)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${rider.className} · ${rider.studentId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (rider.note.isNotEmpty)
                  Text(
                    rider.note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(label: rider.status.label),
          if (editable) ...[
            const SizedBox(width: 4),
            PopupMenuButton<DriverMorningRiderStatus>(
              tooltip: 'Record rider status',
              onSelected: onStatus,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: DriverMorningRiderStatus.boarded,
                  child: Text('Boarded'),
                ),
                PopupMenuItem(
                  value: DriverMorningRiderStatus.noShow,
                  child: Text('No-show'),
                ),
                PopupMenuItem(
                  value: DriverMorningRiderStatus.guardianCancelled,
                  child: Text('Guardian cancelled'),
                ),
                PopupMenuItem(
                  value: DriverMorningRiderStatus.exception,
                  child: Text('Exception…'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
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
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

String _time(String iso) {
  if (iso.isEmpty) return '—';
  final value = DateTime.tryParse(iso)?.toLocal();
  if (value == null) return '—';
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
