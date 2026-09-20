import 'package:flutter/material.dart';

import '../data/driver_afternoon_run_demo_data.dart';
import '../data/driver_afternoon_run_repository.dart';
import '../domain/driver_afternoon_run_models.dart';

class DriverAfternoonRunPage extends StatefulWidget {
  const DriverAfternoonRunPage({
    super.key,
    required this.repository,
    this.onRunChanged,
  });

  final DriverAfternoonRunRepository repository;
  final VoidCallback? onRunChanged;

  @override
  State<DriverAfternoonRunPage> createState() =>
      _DriverAfternoonRunPageState();
}

class _DriverAfternoonRunPageState extends State<DriverAfternoonRunPage> {
  late Future<DriverAfternoonRun> _future;
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
    Future<DriverAfternoonRun> Function() action, {
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
    return FutureBuilder<DriverAfternoonRun>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Afternoon run could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildRun(snapshot.data!);
      },
    );
  }

  Widget _buildRun(DriverAfternoonRun run) {
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
                widget.repository.startBoarding,
                success:
                    'Afternoon boarding opened on this device and queued for sync.',
              ),
              onDepartSchool: () => _confirmDeparture(run),
              onArriveNext: run.nextPendingStop == null
                  ? null
                  : () => _run(
                        () => widget.repository
                            .arriveAtStop(run.nextPendingStop!.id),
                        success: 'Drop-off stop opened.',
                      ),
              onReturnSchool: () => _confirmReturn(run),
              onComplete: () => _run(
                widget.repository.completeRun,
                success:
                    'Afternoon run completed and queued for synchronization.',
              ),
            ),
            const SizedBox(height: 18),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _mainFlow(run)),
                  const SizedBox(width: 18),
                  Expanded(flex: 3, child: _safetyPanel(run)),
                ],
              )
            else ...[
              _mainFlow(run),
              const SizedBox(height: 18),
              _safetyPanel(run),
            ],
          ],
        );
      },
    );
  }

  Widget _mainFlow(DriverAfternoonRun run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BoardingManifest(
          run: run,
          saving: _saving,
          onStatus: _setBoardingStatus,
        ),
        const SizedBox(height: 18),
        Text(
          'Home drop-off stops',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Only students actually boarded at school enter this sequence. A vehicle reaching a stop does not automatically mark any child as dropped off.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        for (final stop in run.stops) ...[
          _DropStopCard(
            run: run,
            stop: stop,
            saving: _saving,
            canOpen: _canOpen(run, stop),
            onOpen: () => _run(
              () => widget.repository.arriveAtStop(stop.id),
              success: '${stop.name} opened for drop-off.',
            ),
            onDepart: () => _run(
              () => widget.repository.departStop(stop.id),
              success: '${stop.name} departed and queued for sync.',
            ),
            onDropStatus: (rider, status) =>
                _setDropStatus(stop, rider, status),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  bool _canOpen(DriverAfternoonRun run, DriverAfternoonStop stop) {
    if (_saving || run.status != DriverAfternoonRunStatus.inProgress) {
      return false;
    }
    if (run.activeStop != null ||
        stop.status != DriverAfternoonStopStatus.pending) {
      return false;
    }
    return run.nextPendingStop?.id == stop.id;
  }

  Future<void> _setBoardingStatus(
    DriverAfternoonRider rider,
    DriverAfternoonRiderStatus status,
  ) async {
    var note = '';
    if (status == DriverAfternoonRiderStatus.boardingException) {
      final result = await _noteDialog(
        title: 'Boarding exception',
        riderName: rider.name,
        hint: 'For example: student sent to school office for follow-up',
      );
      if (result == null || result.trim().isEmpty) return;
      note = result.trim();
    }
    await _run(
      () => widget.repository.setBoardingStatus(
        studentId: rider.studentId,
        status: status,
        note: note,
      ),
    );
  }

  Future<void> _setDropStatus(
    DriverAfternoonStop stop,
    DriverAfternoonRider rider,
    DriverAfternoonRiderStatus status,
  ) async {
    var note = '';
    if (status == DriverAfternoonRiderStatus.guardianUnavailable ||
        status == DriverAfternoonRiderStatus.dropException) {
      final result = await _noteDialog(
        title: status.label,
        riderName: rider.name,
        hint: status == DriverAfternoonRiderStatus.guardianUnavailable
            ? 'For example: no authorized guardian present at stop'
            : 'Describe the safe-operational issue briefly',
      );
      if (result == null || result.trim().isEmpty) return;
      note = result.trim();
    }
    await _run(
      () => widget.repository.setDropStatus(
        stopId: stop.id,
        studentId: rider.studentId,
        status: status,
        note: note,
      ),
    );
  }

  Future<String?> _noteDialog({
    required String title,
    required String riderName,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
              decoration: InputDecoration(
                labelText: 'Operational note',
                hintText: hint,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _confirmDeparture(DriverAfternoonRun run) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depart school'),
        content: Text(
          '${run.boardedRiders} students are recorded as boarded. ${run.guardianPickupCount} guardian pickups and ${run.notRidingCount} not-riding records will remain outside the bus manifest. Confirm only when the physical rider count matches.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.directions_bus_outlined),
            label: const Text('Depart school'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(
      widget.repository.departSchool,
      success: 'School departure recorded locally and queued for sync.',
    );
  }

  Future<void> _confirmReturn(DriverAfternoonRun run) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm safe return to school'),
        content: Text(
          '${run.stillOnBus} student${run.stillOnBus == 1 ? '' : 's'} remain onboard because safe home release was not completed. Confirm only after the vehicle and those students are physically back at school and handed to authorized school staff.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Returned to school'),
          ),
        ],
      ),
    );
    if (go != true) return;
    await _run(
      widget.repository.confirmReturnToSchool,
      success: 'Safe return to school recorded and queued for sync.',
    );
  }

  Widget _safetyPanel(DriverAfternoonRun run) {
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
                  'Afternoon accountability',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const _Rule(
                  icon: Icons.fact_check_outlined,
                  title: 'Resolve school boarding first',
                  body:
                      'Every expected rider must be boarded, guardian pickup, not riding or an explained boarding exception before departure.',
                ),
                const _Rule(
                  icon: Icons.handshake_outlined,
                  title: 'Drop-off is explicit',
                  body:
                      'Reaching the stop is not a release. Record the actual safe handover or approved drop point.',
                ),
                const _Rule(
                  icon: Icons.shield_outlined,
                  title: 'Unsafe handover stays onboard',
                  body:
                      'Guardian-unavailable and drop-exception students remain in transport custody until returned safely to school.',
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
                const Text(driverAfternoonRunBoundary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerLow,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverAfternoonSafetyBoundary,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                Text(driverAfternoonOfflineBoundary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.run});
  final DriverAfternoonRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · AFTERNOON SERVICE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'School → Home',
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
  final DriverAfternoonRun run;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(label: 'Run status', value: run.status.label),
        _Metric(label: 'Expected', value: '${run.expectedRiders} riders'),
        _Metric(label: 'Boarded', value: '${run.boardedRiders}'),
        _Metric(label: 'Safe release', value: '${run.safeDropCount}'),
        _Metric(label: 'Still onboard', value: '${run.stillOnBus}'),
        _Metric(label: 'Exceptions', value: '${run.exceptions}'),
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
      width: 170,
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
    required this.onDepartSchool,
    required this.onArriveNext,
    required this.onReturnSchool,
    required this.onComplete,
  });

  final DriverAfternoonRun run;
  final bool saving;
  final VoidCallback onStart;
  final VoidCallback onDepartSchool;
  final VoidCallback? onArriveNext;
  final VoidCallback onReturnSchool;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    String title;
    String body;
    Widget? action;

    switch (run.status) {
      case DriverAfternoonRunStatus.notStarted:
        title = 'Prepare afternoon boarding';
        body =
            'Open the school manifest and resolve every expected rider before departure.';
        action = FilledButton.icon(
          onPressed: saving ? null : onStart,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Start afternoon boarding'),
        );
      case DriverAfternoonRunStatus.boarding:
        title = run.unresolvedBoarding == 0
            ? 'Boarding manifest reconciled'
            : '${run.unresolvedBoarding} riders still unresolved';
        body = run.unresolvedBoarding == 0
            ? '${run.boardedRiders} students are boarded. Confirm the physical count before leaving school.'
            : 'Boarding cannot close until every expected student has an explicit outcome.';
        if (run.unresolvedBoarding == 0) {
          action = FilledButton.icon(
            onPressed: saving ? null : onDepartSchool,
            icon: const Icon(Icons.directions_bus_outlined),
            label: const Text('Depart school'),
          );
        }
      case DriverAfternoonRunStatus.inProgress:
        if (run.activeStop != null) {
          final stop = run.activeStop!;
          final pending = stop.riders
              .where((rider) =>
                  rider.status == DriverAfternoonRiderStatus.boarded)
              .length;
          title = 'At ${stop.name}';
          body = pending == 0
              ? 'All boarded riders for this stop have an outcome. Depart when physically ready.'
              : '$pending boarded rider${pending == 1 ? '' : 's'} still need a safe drop-off outcome.';
        } else if (run.nextPendingStop != null) {
          title = 'Next stop: ${run.nextPendingStop!.name}';
          body =
              'Open the stop only after the vehicle physically arrives at the assigned drop point.';
          action = FilledButton.icon(
            onPressed: saving ? null : onArriveNext,
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Arrived at stop'),
          );
        } else if (run.stillOnBus > 0) {
          title = '${run.stillOnBus} students still in transport custody';
          body =
              'Safe home release was not completed. Return these students to authorized school staff.';
          action = FilledButton.icon(
            onPressed: saving ? null : onReturnSchool,
            icon: const Icon(Icons.school_outlined),
            label: const Text('Confirm return to school'),
          );
        } else {
          title = 'All riders safely resolved';
          body = 'Every boarded student has a completed safe-release record.';
          action = FilledButton.icon(
            onPressed: saving ? null : onComplete,
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Complete afternoon run'),
          );
        }
      case DriverAfternoonRunStatus.returnedSchool:
        title = 'Return to school confirmed';
        body =
            'Students who could not be safely released at home are recorded as returned to school.';
        action = FilledButton.icon(
          onPressed: saving ? null : onComplete,
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Complete afternoon run'),
        );
      case DriverAfternoonRunStatus.completed:
        title = 'Afternoon service complete';
        body =
            'The trip is closed locally. Pending records remain queued until synchronization succeeds.';
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}

class _BoardingManifest extends StatelessWidget {
  const _BoardingManifest({
    required this.run,
    required this.saving,
    required this.onStatus,
  });

  final DriverAfternoonRun run;
  final bool saving;
  final void Function(DriverAfternoonRider, DriverAfternoonRiderStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    final editable = run.status == DriverAfternoonRunStatus.boarding;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'School boarding manifest',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Resolve all ${run.expectedRiders} expected riders before the vehicle departs school.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final stop in run.stops) ...[
              Text(
                '${stop.name} · ${stop.riders.length} riders',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              for (final rider in stop.riders)
                _RiderRow(
                  rider: rider,
                  enabled: editable && !saving,
                  onStatus: onStatus,
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropStopCard extends StatelessWidget {
  const _DropStopCard({
    required this.run,
    required this.stop,
    required this.saving,
    required this.canOpen,
    required this.onOpen,
    required this.onDepart,
    required this.onDropStatus,
  });

  final DriverAfternoonRun run;
  final DriverAfternoonStop stop;
  final bool saving;
  final bool canOpen;
  final VoidCallback onOpen;
  final VoidCallback onDepart;
  final void Function(DriverAfternoonRider, DriverAfternoonRiderStatus)
      onDropStatus;

  @override
  Widget build(BuildContext context) {
    final boarded = stop.riders
        .where((rider) => rider.status.enteredBus)
        .toList(growable: false);
    final active = stop.status == DriverAfternoonStopStatus.active;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stop.sequence}. ${stop.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${stop.scheduledTime} · ${boarded.length} boarded for this stop · ${stop.status.label}',
                    ),
                  ],
                ),
                if (canOpen)
                  OutlinedButton.icon(
                    onPressed: saving ? null : onOpen,
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Arrived'),
                  ),
              ],
            ),
            if (boarded.isEmpty) ...[
              const SizedBox(height: 10),
              const Text('No boarded riders for this stop today.'),
            ] else ...[
              const SizedBox(height: 12),
              for (final rider in boarded)
                _DropRiderRow(
                  rider: rider,
                  enabled: active &&
                      !saving &&
                      rider.status == DriverAfternoonRiderStatus.boarded,
                  onStatus: onDropStatus,
                ),
            ],
            if (active) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: saving ? null : onDepart,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Depart stop'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({
    required this.rider,
    required this.enabled,
    required this.onStatus,
  });

  final DriverAfternoonRider rider;
  final bool enabled;
  final void Function(DriverAfternoonRider, DriverAfternoonRiderStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const CircleAvatar(radius: 17, child: Icon(Icons.person_outline, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '${rider.className} · ${rider.status.label}${rider.note.isEmpty ? '' : ' · ${rider.note}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (enabled)
            PopupMenuButton<DriverAfternoonRiderStatus>(
              tooltip: 'Set boarding status',
              onSelected: (status) => onStatus(rider, status),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.boarded,
                  child: Text('Boarded'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.guardianPickup,
                  child: Text('Guardian pickup'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.notRiding,
                  child: Text('Not riding'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.boardingException,
                  child: Text('Boarding exception'),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
        ],
      ),
    );
  }
}

class _DropRiderRow extends StatelessWidget {
  const _DropRiderRow({
    required this.rider,
    required this.enabled,
    required this.onStatus,
  });

  final DriverAfternoonRider rider;
  final bool enabled;
  final void Function(DriverAfternoonRider, DriverAfternoonRiderStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        radius: 17,
        child: Icon(Icons.person_pin_circle_outlined, size: 18),
      ),
      title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        '${rider.className} · ${rider.status.label}${rider.note.isEmpty ? '' : ' · ${rider.note}'}',
      ),
      trailing: enabled
          ? PopupMenuButton<DriverAfternoonRiderStatus>(
              tooltip: 'Record safe drop-off',
              onSelected: (status) => onStatus(rider, status),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.droppedGuardian,
                  child: Text('Released to authorized guardian'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.droppedApprovedPoint,
                  child: Text('Approved drop point'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.guardianUnavailable,
                  child: Text('Guardian unavailable'),
                ),
                PopupMenuItem(
                  value: DriverAfternoonRiderStatus.dropException,
                  child: Text('Drop exception'),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            )
          : null,
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
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
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
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
