import 'package:flutter/material.dart';

import '../data/house_demo_data.dart';
import '../data/house_repository.dart';
import '../domain/house_models.dart';

class HousesPage extends StatefulWidget {
  const HousesPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onBack,
  });

  final String schoolName;
  final HouseRepository repository;
  final VoidCallback onBack;

  @override
  State<HousesPage> createState() => _HousesPageState();
}

class _HousesPageState extends State<HousesPage> {
  final _searchController = TextEditingController();
  HouseSnapshot? _snapshot;
  String? _selectedId;
  bool _loading = true;

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
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _selectedId ??= snapshot.houses.isEmpty ? null : snapshot.houses.first.id;
      _loading = false;
    });
  }

  List<SchoolHouse> get _visibleHouses {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    return snapshot.houses
        .where((house) => house.matches(_searchController.text))
        .toList(growable: false);
  }

  SchoolHouse? get _selectedHouse {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.houses.isEmpty) return null;
    for (final house in snapshot.houses) {
      if (house.id == _selectedId) return house;
    }
    return snapshot.houses.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final wide = constraints.maxWidth >= 1050;
        return ListView(
          padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 22, compact ? 16 : 26, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      schoolName: widget.schoolName,
                      compact: compact,
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 16),
                    const _ScopeCard(),
                    const SizedBox(height: 16),
                    _KpiGrid(compact: compact),
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildStandings()),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: _buildSidebar()),
                        ],
                      )
                    else ...[
                      _buildStandings(),
                      const SizedBox(height: 16),
                      _buildSidebar(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStandings() {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('House standings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              houseStandingsDescription,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search house, captain or coordinator...',
              ),
            ),
            const SizedBox(height: 16),
            if (_visibleHouses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('No houses match this search.')),
              )
            else
              for (final house in _visibleHouses) ...[
                _HouseRow(
                  house: house,
                  selected: house.id == _selectedHouse?.id,
                  onTap: () => setState(() => _selectedId = house.id),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final current = _selectedHouse;
    return Column(
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: current == null
                ? const Text('No house selected.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SELECTED HOUSE', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(current.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      _DetailLine('${current.points} points', 'Current-term prototype total.'),
                      _DetailLine(current.captain, 'Student captain'),
                      _DetailLine(current.coordinator, 'Staff coordinator'),
                      const SizedBox(height: 10),
                      Text(
                        'Sports ${current.sports} · Academic competitions ${current.academicCompetitions} · Community/service ${current.service}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOUSE RULE', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(houseAcademicBoundary, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName, required this.compact, required this.onBack});

  final String schoolName;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SCHOOL LIFE · HOUSES & TEAMS', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Houses & Teams', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        Text(schoolName, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    if (compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('School Life'))]);
    }
    return Row(children: [Expanded(child: title), OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), label: const Text('School Life'))]);
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(houseScopeTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  Text(houseScopeSubtitle, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Text(houseScopeDescription, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kpi in houseKpis)
          SizedBox(
            width: compact ? double.infinity : 210,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kpi.label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(kpi.value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(kpi.detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HouseRow extends StatelessWidget {
  const _HouseRow({required this.house, required this.selected, required this.onTap});

  final SchoolHouse house;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Text(house.name.characters.first)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 6, children: [Chip(label: Text(house.status)), Chip(label: Text('${house.members} members'))]),
                    Text(house.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Captain ${house.captain} · Coordinator ${house.coordinator}'),
                    const SizedBox(height: 8),
                    Text('Sports ${house.sports} · Academic competitions ${house.academicCompetitions} · Community/service ${house.service}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('${house.points}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.title, this.detail);
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
