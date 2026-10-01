import 'package:flutter/material.dart';

import '../data/house_policy_copy.dart';
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
  String _message = '';

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

  Future<void> _addHouse() async {
    final name = TextEditingController();
    final captain = TextEditingController();
    final coordinator = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a house'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'House name')),
              const SizedBox(height: 12),
              TextField(controller: captain, decoration: const InputDecoration(labelText: 'Student captain (optional)')),
              const SizedBox(height: 12),
              TextField(controller: coordinator, decoration: const InputDecoration(labelText: 'Staff coordinator (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add house')),
        ],
      ),
    );
    final addName = name.text;
    final addCaptain = captain.text;
    final addCoordinator = coordinator.text;
    name.dispose();
    captain.dispose();
    coordinator.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.create(name: addName, captain: addCaptain, coordinator: addCoordinator);
    if (result.success) await _load();
    if (!mounted) return;
    setState(() => _message = result.message);
  }

  Future<void> _editHouse(SchoolHouse house) async {
    final name = TextEditingController(text: house.name);
    final captain = TextEditingController(text: house.captain);
    final coordinator = TextEditingController(text: house.coordinator);
    final status = TextEditingController(text: house.status);
    final members = TextEditingController(text: '${house.members}');
    final points = TextEditingController(text: '${house.points}');
    final sports = TextEditingController(text: '${house.sports}');
    final academics = TextEditingController(text: '${house.academicCompetitions}');
    final service = TextEditingController(text: '${house.service}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${house.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'House name')),
                const SizedBox(height: 12),
                TextField(controller: captain, decoration: const InputDecoration(labelText: 'Student captain')),
                const SizedBox(height: 12),
                TextField(controller: coordinator, decoration: const InputDecoration(labelText: 'Staff coordinator')),
                const SizedBox(height: 12),
                TextField(controller: status, decoration: const InputDecoration(labelText: 'Status (e.g. Active)')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: members, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Members'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: sports, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sports'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: academics, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Academic'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: service, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Service'))),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    final values = (
      name: name.text,
      captain: captain.text,
      coordinator: coordinator.text,
      status: status.text,
      members: int.tryParse(members.text) ?? house.members,
      points: int.tryParse(points.text) ?? house.points,
      sports: int.tryParse(sports.text) ?? house.sports,
      academics: int.tryParse(academics.text) ?? house.academicCompetitions,
      service: int.tryParse(service.text) ?? house.service,
    );
    name.dispose();
    captain.dispose();
    coordinator.dispose();
    status.dispose();
    members.dispose();
    points.dispose();
    sports.dispose();
    academics.dispose();
    service.dispose();
    if (confirmed != true) return;
    final result = await widget.repository.edit(
      id: house.id,
      name: values.name,
      captain: values.captain,
      coordinator: values.coordinator,
      members: values.members,
      points: values.points,
      sports: values.sports,
      academicCompetitions: values.academics,
      service: values.service,
      status: values.status,
    );
    if (result.success) await _load();
    if (!mounted) return;
    setState(() => _message = result.message);
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
                    _KpiGrid(houses: _snapshot?.houses ?? const [], compact: compact),
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
    final canManage = _snapshot?.permissions.canManageAll ?? false;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('House standings', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ),
                if (canManage)
                  OutlinedButton.icon(onPressed: _addHouse, icon: const Icon(Icons.add_rounded), label: const Text('Add house')),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              houseStandingsDescription,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_message, style: theme.textTheme.bodySmall),
            ],
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    (_snapshot?.houses.isEmpty ?? true)
                        ? 'No houses yet. Add the first one above.'
                        : 'No houses match this search.',
                  ),
                ),
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
    final canManage = _snapshot?.permissions.canManageAll ?? false;
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text('SELECTED HOUSE', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
                          ),
                          if (canManage)
                            IconButton(
                              onPressed: () => _editHouse(current),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit house',
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(current.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      _DetailLine('${current.points} points', 'Manually maintained by school leadership.'),
                      _DetailLine(current.captain.isEmpty ? 'Not set' : current.captain, 'Student captain'),
                      _DetailLine(current.coordinator.isEmpty ? 'Not set' : current.coordinator, 'Staff coordinator'),
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
  const _KpiGrid({required this.houses, required this.compact});

  final List<SchoolHouse> houses;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final leading = houses.isEmpty
        ? null
        : houses.reduce((current, next) => next.points > current.points ? next : current);
    final kpis = <HouseKpi>[
      HouseKpi('Active houses', '${houses.length}', 'Whole-school structure'),
      HouseKpi('Members', '${houses.fold<int>(0, (total, house) => total + house.members)}', 'Across every real house'),
      HouseKpi(
        'Leading house',
        leading?.name ?? 'None yet',
        leading == null ? 'Add a house to begin' : '${leading.points} points',
      ),
      const HouseKpi('Ranking scope', 'House only', 'No academic rank conversion'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kpi in kpis)
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
                    Text('Captain ${house.captain.isEmpty ? 'Not set' : house.captain} · Coordinator ${house.coordinator.isEmpty ? 'Not set' : house.coordinator}'),
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
