import 'package:flutter/material.dart';

import '../data/boarding_demo_data.dart';
import '../data/boarding_repository.dart';
import '../domain/boarding_models.dart';

class BoardingPage extends StatefulWidget {
  const BoardingPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onBoardingChanged,
  });

  final String schoolName;
  final BoardingRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onBoardingChanged;

  @override
  State<BoardingPage> createState() => _BoardingPageState();
}

class _BoardingPageState extends State<BoardingPage> {
  final _searchController = TextEditingController();
  BoardingSnapshot? _snapshot;
  bool _previewEnabled = true;
  bool _loading = true;
  String? _error;

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
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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

  Future<void> _toggleReview(BoardingDorm dorm) async {
    final result = await widget.repository.toggleHandoverReview(dorm.name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onBoardingChanged?.call();
      await _load();
    }
  }

  List<BoardingDorm> get _visibleDorms {
    final dorms = _snapshot?.dorms ?? const <BoardingDorm>[];
    return dorms
        .where((dorm) => dorm.matches(_searchController.text))
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
              Text('Could not load boarding: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = boardingStats(
      snapshot.dorms,
      previewEnabled: _previewEnabled,
    );
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        return ListView(
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
                        'Boarding & Hostel',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Optional school module',
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
              'Schools without boarding can remove this module through tenant configuration later. This screen previews enabled/disabled UI states; the preview toggle does not change school configuration.',
              style: theme.textTheme.bodyMedium,
            ),
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
              _DormitoryOverview(
                dorms: _visibleDorms,
                permissions: snapshot.permissions,
                searchController: _searchController,
                previewEnabled: _previewEnabled,
                onQueryChanged: (_) => setState(() {}),
                onPreviewChanged: () => setState(
                  () => _previewEnabled = !_previewEnabled,
                ),
                onToggleReview: _toggleReview,
              ),
              const SizedBox(height: 16),
              const _BoundarySidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DormitoryOverview(
                      dorms: _visibleDorms,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      previewEnabled: _previewEnabled,
                      onQueryChanged: (_) => setState(() {}),
                      onPreviewChanged: () => setState(
                        () => _previewEnabled = !_previewEnabled,
                      ),
                      onToggleReview: _toggleReview,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _BoundarySidebar()),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final BoardingStat stat;

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

class _DormitoryOverview extends StatelessWidget {
  const _DormitoryOverview({
    required this.dorms,
    required this.permissions,
    required this.searchController,
    required this.previewEnabled,
    required this.onQueryChanged,
    required this.onPreviewChanged,
    required this.onToggleReview,
  });

  final List<BoardingDorm> dorms;
  final BoardingPermissions permissions;
  final TextEditingController searchController;
  final bool previewEnabled;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPreviewChanged;
  final ValueChanged<BoardingDorm> onToggleReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                      Text(
                        'Dormitory overview',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Operational accountability without continuous or invasive monitoring of students.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onPreviewChanged,
                  child: Text(
                    previewEnabled
                        ? 'Preview disabled state'
                        : 'Restore enabled preview',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!previewEnabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disabled-state preview only',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(boardingDisabledPreviewNote),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: searchController,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search dorm or house parent...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              if (dorms.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('No dormitories match this search.')),
                )
              else
                for (final dorm in dorms) ...[
                  _DormCard(
                    dorm: dorm,
                    canReview: permissions.canReviewHandover,
                    onToggleReview: () => onToggleReview(dorm),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _DormCard extends StatelessWidget {
  const _DormCard({
    required this.dorm,
    required this.canReview,
    required this.onToggleReview,
  });

  final BoardingDorm dorm;
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
              _Pill(dorm.status.label),
              _Pill('${dorm.occupied}/${dorm.capacity} occupied'),
              _Pill('${dorm.approvedLeave} on leave'),
              if (dorm.handoverReviewed) const _Pill('Reviewed'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            dorm.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('House parent: ${dorm.houseParent}'),
          const SizedBox(height: 7),
          Text(
            dorm.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dorm.onCampus} on campus · ${dorm.maintenance} maintenance items',
            style: theme.textTheme.bodySmall,
          ),
          if (canReview) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onToggleReview,
              icon: Icon(
                dorm.handoverReviewed
                    ? Icons.restart_alt_rounded
                    : Icons.fact_check_outlined,
                size: 18,
              ),
              label: Text(
                dorm.handoverReviewed
                    ? 'Reopen review'
                    : 'Mark handover reviewed',
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

class _BoundarySidebar extends StatelessWidget {
  const _BoundarySidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BOARDING BOUNDARY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in boardingBoundaryRules.entries) ...[
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
    );
  }
}
