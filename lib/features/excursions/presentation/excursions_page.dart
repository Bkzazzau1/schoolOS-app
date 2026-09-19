import 'package:flutter/material.dart';

import '../data/excursion_demo_data.dart';
import '../data/excursion_repository.dart';
import '../domain/excursion_models.dart';

class ExcursionsPage extends StatefulWidget {
  const ExcursionsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
    this.onExcursionsChanged,
  });

  final String schoolName;
  final ExcursionRepository repository;
  final VoidCallback onBack;
  final VoidCallback? onExcursionsChanged;

  @override
  State<ExcursionsPage> createState() => _ExcursionsPageState();
}

class _ExcursionsPageState extends State<ExcursionsPage> {
  final _searchController = TextEditingController();
  ExcursionSnapshot? _snapshot;
  TripStatus? _statusFilter;
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

  Future<void> _toggleReview(SchoolTrip trip) async {
    final result = await widget.repository.toggleReadinessReview(trip.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.success) {
      widget.onExcursionsChanged?.call();
      await _load();
    }
  }

  List<SchoolTrip> get _visibleTrips {
    final trips = _snapshot?.trips ?? const <SchoolTrip>[];
    return trips
        .where(
          (trip) => trip.matches(_searchController.text, _statusFilter),
        )
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
              Text('Could not load excursions: $_error'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final stats = excursionStats(snapshot.trips);
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
                        'Excursions & Consent',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${widget.schoolName} · Trips, transport and guardian approval',
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
              'Plan off-site and supervised special activities with audience, transport, consent, emergency-contact and readiness visibility.',
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
              _TripRegister(
                trips: _visibleTrips,
                permissions: snapshot.permissions,
                searchController: _searchController,
                statusFilter: _statusFilter,
                onQueryChanged: (_) => setState(() {}),
                onStatusChanged: (value) => setState(() => _statusFilter = value),
                onToggleReview: _toggleReview,
              ),
              const SizedBox(height: 16),
              const _DepartureSidebar(),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _TripRegister(
                      trips: _visibleTrips,
                      permissions: snapshot.permissions,
                      searchController: _searchController,
                      statusFilter: _statusFilter,
                      onQueryChanged: (_) => setState(() {}),
                      onStatusChanged: (value) => setState(() => _statusFilter = value),
                      onToggleReview: _toggleReview,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Expanded(flex: 3, child: _DepartureSidebar()),
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

  final ExcursionStat stat;

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

class _TripRegister extends StatelessWidget {
  const _TripRegister({
    required this.trips,
    required this.permissions,
    required this.searchController,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onToggleReview,
  });

  final List<SchoolTrip> trips;
  final ExcursionPermissions permissions;
  final TextEditingController searchController;
  final TripStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<TripStatus?> onStatusChanged;
  final ValueChanged<SchoolTrip> onToggleReview;

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
              'Trip register',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Readiness should be complete before departure, not reconstructed afterward.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 560;
                final search = TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search trip, destination or audience...',
                    border: OutlineInputBorder(),
                  ),
                );
                final filter = DropdownButtonFormField<TripStatus?>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<TripStatus?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    for (final status in TripStatus.values)
                      DropdownMenuItem<TripStatus?>(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: onStatusChanged,
                );
                if (stacked) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 10),
                      filter,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: search),
                    const SizedBox(width: 10),
                    Expanded(child: filter),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            if (trips.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: Text('No trips match these filters.')),
              )
            else
              for (final trip in trips) ...[
                _TripCard(
                  trip: trip,
                  canReview: permissions.canReviewReadiness,
                  onToggleReview: () => onToggleReview(trip),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.canReview,
    required this.onToggleReview,
  });

  final SchoolTrip trip;
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
              _Pill(trip.status.label),
              _Pill(trip.audience),
              _Pill('${trip.consentPercent}% consent'),
              if (trip.readinessReviewed) const _Pill('Reviewed'),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            trip.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text('${trip.date} · ${trip.destination} · ${trip.coordinator}'),
          const SizedBox(height: 7),
          Text(
            trip.note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: trip.consentPercent / 100),
          const SizedBox(height: 8),
          Text(
            '${trip.consentReceived}/${trip.students} consent received · ${trip.transport} · ${trip.emergency}',
            style: theme.textTheme.bodySmall,
          ),
          if (canReview) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onToggleReview,
              icon: Icon(
                trip.readinessReviewed
                    ? Icons.restart_alt_rounded
                    : Icons.fact_check_outlined,
                size: 18,
              ),
              label: Text(
                trip.readinessReviewed
                    ? 'Reopen review'
                    : 'Mark readiness reviewed',
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

class _DepartureSidebar extends StatelessWidget {
  const _DepartureSidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPARTURE CHECK',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                for (final entry in excursionDepartureChecks.entries) ...[
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
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRIVACY RULE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  excursionPrivacyRule,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
