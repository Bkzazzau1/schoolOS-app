import 'package:flutter/material.dart';

import '../data/lost_found_demo_data.dart';
import '../data/lost_found_repository.dart';
import '../domain/lost_found_models.dart';

class LostFoundPage extends StatefulWidget {
  const LostFoundPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onLostFoundChanged,
  });

  final String schoolName;
  final LostFoundRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onLostFoundChanged;

  @override
  State<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends State<LostFoundPage> {
  final _searchController = TextEditingController();
  LostFoundSnapshot? _snapshot;
  LostFoundStatus? _statusFilter;
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

  List<LostFoundItem> get _visibleItems {
    final items = _snapshot?.items ?? const <LostFoundItem>[];
    return items
        .where((item) =>
            (_statusFilter == null || item.status == _statusFilter) &&
            item.matches(_searchController.text))
        .toList(growable: false);
  }

  Future<void> _startClaimReview(LostFoundItem item) async {
    final result = await widget.repository.startClaimReview(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onLostFoundChanged?.call();
      await _load();
    }
  }

  Future<void> _markReturned(LostFoundItem item) async {
    final result = await widget.repository.markReturned(item.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onLostFoundChanged?.call();
      await _load();
    }
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
              Text('Could not load Lost & Found: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = lostFoundStats(snapshot.items);
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
                        'Lost & Found',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Item recovery without exposing private identifiers',
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
            const Text(
              'Log found items, storage location and claim status. Public-facing descriptions must omit identifying details that could be used to falsely claim an item.',
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
              _RegisterCard(
                items: _visibleItems,
                permissions: snapshot.permissions,
                searchController: _searchController,
                statusFilter: _statusFilter,
                onSearchChanged: (_) => setState(() {}),
                onStatusChanged: (value) => setState(() => _statusFilter = value),
                onStartClaimReview: _startClaimReview,
                onMarkReturned: _markReturned,
              ),
              const SizedBox(height: 16),
              const _ClaimRulesCard(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _RegisterCard(
                      items: _visibleItems,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      onSearchChanged: (_) => setState(() {}),
                      onStatusChanged: (value) =>
                          setState(() => _statusFilter = value),
                      onStartClaimReview: _startClaimReview,
                      onMarkReturned: _markReturned,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _ClaimRulesCard()),
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

  final LostFoundStat stat;

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

class _RegisterCard extends StatelessWidget {
  const _RegisterCard({
    required this.items,
    required this.permissions,
    required this.searchController,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onStartClaimReview,
    required this.onMarkReturned,
  });

  final List<LostFoundItem> items;
  final LostFoundPermissions permissions;
  final TextEditingController searchController;
  final LostFoundStatus? statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<LostFoundStatus?> onStatusChanged;
  final ValueChanged<LostFoundItem> onStartClaimReview;
  final ValueChanged<LostFoundItem> onMarkReturned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found-item register',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Claim verification happens through staff; the school feed should never reveal every identifying detail.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search item, category or location...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                DropdownButton<LostFoundStatus?>(
                  value: statusFilter,
                  hint: const Text('All statuses'),
                  onChanged: onStatusChanged,
                  items: [
                    const DropdownMenuItem<LostFoundStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    for (final status in LostFoundStatus.values)
                      DropdownMenuItem<LostFoundStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No items match these filters.')),
              )
            else
              for (final item in items) ...[
                _ItemRow(
                  item: item,
                  canManageClaims: permissions.canManageClaims,
                  onStartClaimReview: () => onStartClaimReview(item),
                  onMarkReturned: () => onMarkReturned(item),
                ),
                if (item != items.last) const Divider(height: 28),
              ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.canManageClaims,
    required this.onStartClaimReview,
    required this.onMarkReturned,
  });

  final LostFoundItem item;
  final bool canManageClaims;
  final VoidCallback onStartClaimReview;
  final VoidCallback onMarkReturned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: const Icon(Icons.question_mark_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(item.category)),
                  Chip(label: Text(item.status.label)),
                  Chip(label: Text(item.date)),
                ],
              ),
              Text(
                item.item,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text('Found: ${item.found} · Stored: ${item.storage}'),
              const SizedBox(height: 4),
              Text(item.note),
              const SizedBox(height: 4),
              Text(
                'Claimant: ${item.claimant}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (canManageClaims) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: item.status == LostFoundStatus.claimReview
                          ? null
                          : onStartClaimReview,
                      child: const Text('Start claim review'),
                    ),
                    FilledButton.tonal(
                      onPressed: item.status == LostFoundStatus.returned
                          ? null
                          : onMarkReturned,
                      child: const Text('Mark returned'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClaimRulesCard extends StatelessWidget {
  const _ClaimRulesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CLAIM RULE',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in lostFoundClaimRules.entries) ...[
              Text(
                entry.key,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}
