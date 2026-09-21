import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_coordinator.dart';
import '../../../core/sync/sync_mutation.dart';
import '../../../core/sync/sync_scope.dart';
import '../../../shared/models/school_membership.dart';

class SyncCenterPage extends StatefulWidget {
  const SyncCenterPage({
    super.key,
    required this.localDatabase,
    required this.membership,
  });

  final LocalDatabase localDatabase;
  final SchoolMembership membership;

  @override
  State<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends State<SyncCenterPage> {
  List<SyncQueueItem> _items = const [];
  SyncCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The queue changes as syncing goes on, so it is read again on every step.
    final coordinator = SyncScope.maybeOf(context);
    if (coordinator == _coordinator) return;
    _coordinator?.removeListener(_load);
    _coordinator = coordinator;
    coordinator?.addListener(_load);
  }

  @override
  void dispose() {
    _coordinator?.removeListener(_load);
    super.dispose();
  }

  void _load() {
    final items = widget.localDatabase.syncQueueItems(
      tenantId: widget.membership.schoolId,
    );
    if (!mounted) return;
    setState(() => _items = items);
  }

  void _queueRetry(SyncQueueItem item) {
    if (!item.canQueueRetry) return;

    widget.localDatabase.queueMutationForRetry(
      tenantId: widget.membership.schoolId,
      mutationId: item.id,
    );
    _load();

    _coordinator?.requestSync(immediately: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The failed change has been placed back in the sync queue.'),
      ),
    );
  }

  Future<void> _discard(SyncQueueItem item) async {
    final conflict = item.isConflict;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(conflict ? "Use the school's version?" : 'Discard this change?'),
        content: Text(
          conflict
              ? 'Someone else changed this record first. Your change will be dropped and the school\'s version will replace it on this device.'
              : 'The school refused this change. It will be dropped and the school\'s version will be used on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(conflict ? "Use the school's version" : 'Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    widget.localDatabase.discardMutation(
      tenantId: widget.membership.schoolId,
      mutationId: item.id,
    );
    _load();
    _coordinator?.requestSync(immediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _items
        .where((item) => item.status == SyncMutationStatus.pending)
        .length;
    final syncing = _items
        .where((item) => item.status == SyncMutationStatus.syncing)
        .length;
    final conflicts = _items.where((item) => item.isConflict).length;
    final failed = _items
        .where(
          (item) =>
              item.status == SyncMutationStatus.failed && !item.isConflict,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Center'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.membership.schoolName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.membership.roleLabel} · This queue only contains changes for the active school.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _SyncStatusCard(coordinator: _coordinator),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CountChip(
                label: 'Waiting',
                count: pending,
                icon: Icons.schedule_rounded,
              ),
              _CountChip(
                label: 'Sending',
                count: syncing,
                icon: Icons.sync_rounded,
              ),
              _CountChip(
                label: 'Failed',
                count: failed,
                icon: Icons.error_outline_rounded,
              ),
              _CountChip(
                label: 'Conflicts',
                count: conflicts,
                icon: Icons.compare_arrows_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_items.isEmpty)
            const _EmptySyncQueue()
          else
            for (final item in _items) ...[
              _SyncQueueCard(
                item: item,
                onRetry: item.canQueueRetry ? () => _queueRetry(item) : null,
                onDiscard: item.status == SyncMutationStatus.failed ? () => _discard(item) : null,
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 12),
          Text(
            'A conflict means the school\'s record changed after your copy was downloaded. SchoolOS never overwrites the school\'s record silently: you can keep waiting, or use the school\'s version. Comparing the two side by side is not available yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where syncing stands, in words, with a button to sync right now.
class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.coordinator});

  final SyncCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coordinator = this.coordinator;
    if (coordinator == null) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('Demo data'),
          subtitle: const Text('This copy of SchoolOS is not connected to a school server.'),
        ),
      );
    }

    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final status = coordinator.status;
        final (icon, title) = switch (status) {
          SyncStatus.idle => (
              Icons.cloud_done_outlined,
              coordinator.lastSyncedAt == null
                  ? 'Not synced yet'
                  : 'Up to date · last synced ${_formatTime(coordinator.lastSyncedAt!.toLocal())}',
            ),
          SyncStatus.syncing => (Icons.sync_rounded, 'Syncing...'),
          SyncStatus.offline => (Icons.cloud_off_rounded, 'Offline'),
          SyncStatus.needsSignIn => (Icons.lock_clock_outlined, 'Your sign-in has ended'),
          SyncStatus.lostAccess => (Icons.block_rounded, 'No access to this school'),
          SyncStatus.error => (Icons.error_outline_rounded, 'Something went wrong'),
        };
        final canSync = status != SyncStatus.syncing &&
            status != SyncStatus.needsSignIn &&
            status != SyncStatus.lostAccess;

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (coordinator.message != null) ...[
                        const SizedBox(height: 4),
                        Text(coordinator.message!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: canSync ? coordinator.syncNow : null,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Sync now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatTime(DateTime value) {
  final minute = value.minute.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label · $count'),
    );
  }
}

class _EmptySyncQueue extends StatelessWidget {
  const _EmptySyncQueue();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Column(
          children: [
            Icon(
              Icons.cloud_done_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No local changes are waiting',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New offline attendance, lesson-plan, and other supported changes will appear here until the cloud accepts them.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncQueueCard extends StatelessWidget {
  const _SyncQueueCard({
    required this.item,
    required this.onRetry,
    this.onDiscard,
  });

  final SyncQueueItem item;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusPresentation(item);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: status.background,
              foregroundColor: status.foreground,
              child: Icon(status.icon, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _entityLabel(item.entityType),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(status.label),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_operationLabel(item.operation)} · ${_friendlyEntityId(item)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Queued ${_formatDateTime(item.createdAt.toLocal())} · Attempts ${item.attemptCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.baseVersion != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Based on cloud version ${item.baseVersion}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (item.lastError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _cleanError(item.lastError!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.isConflict
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onRetry != null || onDiscard != null) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onRetry != null)
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  if (onDiscard != null)
                    TextButton(
                      onPressed: onDiscard,
                      child: Text(item.isConflict ? "Use school's version" : 'Discard'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

_StatusPresentation _statusPresentation(SyncQueueItem item) {
  if (item.isConflict) {
    return const _StatusPresentation(
      label: 'Conflict',
      icon: Icons.compare_arrows_rounded,
      background: Color(0xFFFFE4E6),
      foreground: Color(0xFFBE123C),
    );
  }

  return switch (item.status) {
    SyncMutationStatus.pending => const _StatusPresentation(
        label: 'Waiting',
        icon: Icons.schedule_rounded,
        background: Color(0xFFE0F2FE),
        foreground: Color(0xFF0369A1),
      ),
    SyncMutationStatus.syncing => const _StatusPresentation(
        label: 'Sending',
        icon: Icons.sync_rounded,
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF15803D),
      ),
    SyncMutationStatus.failed => const _StatusPresentation(
        label: 'Failed',
        icon: Icons.error_outline_rounded,
        background: Color(0xFFFFEDD5),
        foreground: Color(0xFFC2410C),
      ),
  };
}

String _entityLabel(String entityType) {
  return switch (entityType) {
    'attendance_session' => 'Attendance',
    'lesson_plan' => 'Lesson plan',
    _ => entityType
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part.characters.first.toUpperCase()}${part.substring(1)}',
        )
        .join(' '),
  };
}

String _operationLabel(SyncOperation operation) {
  return switch (operation) {
    SyncOperation.create => 'Create',
    SyncOperation.update => 'Update',
    SyncOperation.delete => 'Delete',
  };
}

String _friendlyEntityId(SyncQueueItem item) {
  if (item.entityType == 'attendance_session') {
    final parts = item.entityId.split(':');
    if (parts.length >= 2) return '${parts.first} · ${parts.last}';
  }
  return item.entityId;
}

String _cleanError(String value) {
  const conflictPrefix = 'SYNC_CONFLICT:';
  if (value.startsWith(conflictPrefix)) {
    return value.substring(conflictPrefix.length).trim();
  }
  return value;
}

String _formatDateTime(DateTime value) {
  final minute = value.minute.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year} $hour:$minute';
}
