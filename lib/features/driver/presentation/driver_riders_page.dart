import 'package:flutter/material.dart';

import '../data/driver_riders_repository.dart';
import '../domain/driver_riders_models.dart';

class DriverRidersPage extends StatefulWidget {
  const DriverRidersPage({
    super.key,
    required this.repository,
  });

  final DriverRidersRepository repository;

  @override
  State<DriverRidersPage> createState() => _DriverRidersPageState();
}

class _DriverRidersPageState extends State<DriverRidersPage> {
  final _searchController = TextEditingController();
  late Future<DriverRidersSnapshot> _future;
  DriverRiderViewFilter _filter = DriverRiderViewFilter.all;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadToday();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadToday());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverRidersSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Assigned riders could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildRoster(snapshot.data!);
      },
    );
  }

  Widget _buildRoster(DriverRidersSnapshot snapshot) {
    final query = _searchController.text;
    final visible = snapshot.riders
        .where((rider) => rider.matches(query, _filter))
        .toList(growable: false);

    final grouped = <String, List<DriverRiderOperationalView>>{};
    for (final rider in visible) {
      grouped.putIfAbsent(rider.stopName, () => []).add(rider);
    }

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
              _Header(snapshot: snapshot),
              const SizedBox(height: 16),
              _Stats(snapshot: snapshot),
              const SizedBox(height: 16),
              _Filters(
                searchController: _searchController,
                filter: _filter,
                onSearchChanged: (_) => setState(() {}),
                onFilterChanged: (value) {
                  if (value == null) return;
                  setState(() => _filter = value);
                },
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                const _EmptyState()
              else
                for (final entry in grouped.entries) ...[
                  _StopSection(
                    stopName: entry.key,
                    riders: entry.value,
                  ),
                  const SizedBox(height: 14),
                ],
              const SizedBox(height: 4),
              const _PrivacyBoundary(),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot});

  final DriverRidersSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DRIVER PORTAL · ASSIGNED RIDERS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Riders',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${snapshot.routeId} · ${snapshot.vehicle} · ${snapshot.serviceDate}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.snapshot});

  final DriverRidersSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Assigned riders', '${snapshot.riders.length}', Icons.groups_2_outlined),
      ('Needs attention', '${snapshot.needsAttention}', Icons.warning_amber_rounded),
      ('Currently onboard', '${snapshot.onboard}', Icons.directions_bus_outlined),
      ('Completed today', '${snapshot.completed}', Icons.verified_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(metric.$3, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(metric.$1),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.searchController,
    required this.filter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final DriverRiderViewFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DriverRiderViewFilter?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final search = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Search assigned riders',
            hintText: 'Name, student ID, class or stop',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
        final filterField = DropdownButtonFormField<DriverRiderViewFilter>(
          initialValue: filter,
          decoration: const InputDecoration(
            labelText: 'View',
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: [
            for (final item in DriverRiderViewFilter.values)
              DropdownMenuItem(value: item, child: Text(item.label)),
          ],
          onChanged: onFilterChanged,
        );

        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              search,
              const SizedBox(height: 12),
              filterField,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: 12),
            Expanded(child: filterField),
          ],
        );
      },
    );
  }
}

class _StopSection extends StatelessWidget {
  const _StopSection({required this.stopName, required this.riders});

  final String stopName;
  final List<DriverRiderOperationalView> riders;

  @override
  Widget build(BuildContext context) {
    final first = riders.first;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Wrap(
              spacing: 12,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  stopName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('${riders.length} rider${riders.length == 1 ? '' : 's'}'),
                Text('AM ${first.morningScheduledTime}'),
                Text('PM ${first.afternoonScheduledTime}'),
              ],
            ),
          ),
          for (var index = 0; index < riders.length; index++) ...[
            _RiderRow(rider: riders[index]),
            if (index < riders.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.rider});

  final DriverRiderOperationalView rider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Text(
                  rider.name.isEmpty ? '?' : rider.name.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text('${rider.studentId} · ${rider.className}'),
                    if (rider.needsAttention) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 17,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Transport attention required',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final statuses = _RiderStatuses(rider: rider);
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 14),
                statuses,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: identity),
              const SizedBox(width: 18),
              Expanded(flex: 5, child: statuses),
            ],
          );
        },
      ),
    );
  }
}

class _RiderStatuses extends StatelessWidget {
  const _RiderStatuses({required this.rider});

  final DriverRiderOperationalView rider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusLine(
          icon: Icons.wb_sunny_outlined,
          label: 'Morning',
          value: rider.morningStatus.label,
          note: rider.morningNote,
        ),
        const SizedBox(height: 9),
        _StatusLine(
          icon: Icons.nights_stay_outlined,
          label: 'Afternoon',
          value: rider.afternoonStatus.label,
          note: rider.afternoonNote,
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBoundary extends StatelessWidget {
  const _PrivacyBoundary();

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
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Driver access is limited to assigned transport riders and operational trip status. Home addresses, guardian phone numbers, academic results, fees, medical records, siblings and unrelated student information are not exposed here.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.person_search_outlined, size: 42),
            const SizedBox(height: 10),
            Text(
              'No assigned riders match this view.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
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
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
