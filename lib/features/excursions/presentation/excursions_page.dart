import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_academics_models.dart';
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

  Future<void> _openNewTrip() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    if (snapshot.availableTerms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No academic term is set up yet. Ask an Administrator to set up Academic Structure first.',
          ),
        ),
      );
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _NewTripDialog(
        repository: widget.repository,
        sessions: snapshot.availableSessions,
        terms: snapshot.availableTerms,
        classes: snapshot.availableClasses,
      ),
    );
    if (created == true) {
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
                if (snapshot.permissions.canCreateTrip)
                  FilledButton.icon(
                    onPressed: _openNewTrip,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New trip'),
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
              if (trip.hasCanonicalTerm)
                _Pill('${trip.termName} · ${trip.sessionName}')
              else
                const _Pill('No academic term linked (legacy)'),
              if (trip.className.isNotEmpty) _Pill(trip.className),
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

class _NewTripDialog extends StatefulWidget {
  const _NewTripDialog({
    required this.repository,
    required this.sessions,
    required this.terms,
    required this.classes,
  });

  final ExcursionRepository repository;
  final List<AdministratorAcademicSession> sessions;
  final List<AdministratorAcademicTerm> terms;
  final List<AdministratorAcademicClass> classes;

  @override
  State<_NewTripDialog> createState() => _NewTripDialogState();
}

class _NewTripDialogState extends State<_NewTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _destinationController = TextEditingController();
  final _coordinatorController = TextEditingController();
  final _studentsController = TextEditingController(text: '0');
  final _transportController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _noteController = TextEditingController();
  late AdministratorAcademicTerm _term;
  AdministratorAcademicClass? _academicClass;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _term = widget.terms.firstWhere(
      (term) => term.status == 'active',
      orElse: () => widget.terms.first,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _destinationController.dispose();
    _coordinatorController.dispose();
    _studentsController.dispose();
    _transportController.dispose();
    _emergencyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await widget.repository.createTrip(
      title: _titleController.text,
      date: _dateController.text,
      destination: _destinationController.text,
      coordinator: _coordinatorController.text,
      students: int.tryParse(_studentsController.text) ?? 0,
      transport: _transportController.text,
      emergency: _emergencyController.text,
      note: _noteController.text,
      term: _term,
      session: widget.sessions.firstWhere(
        (session) => session.id == _term.sessionId,
        orElse: () => AdministratorAcademicSession(
          id: _term.sessionId,
          code: '',
          name: '',
          startsOn: '',
          endsOn: '',
          status: '',
        ),
      ),
      academicClass: _academicClass,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New trip'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    hintText: 'e.g. 12 Nov 2026',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AdministratorAcademicTerm>(
                  initialValue: _term,
                  decoration: const InputDecoration(labelText: 'Academic term'),
                  items: [
                    for (final term in widget.terms)
                      DropdownMenuItem(value: term, child: Text(term.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _term = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<AdministratorAcademicClass?>(
                  initialValue: _academicClass,
                  decoration: const InputDecoration(
                    labelText: 'Class (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<AdministratorAcademicClass?>(
                      value: null,
                      child: Text('Not a single class (e.g. a club)'),
                    ),
                    for (final academicClass in widget.classes)
                      DropdownMenuItem(
                        value: academicClass,
                        child: Text(academicClass.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _academicClass = value),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _destinationController,
                  decoration: const InputDecoration(labelText: 'Destination'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _coordinatorController,
                  decoration: const InputDecoration(labelText: 'Coordinator'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _studentsController,
                  decoration: const InputDecoration(
                    labelText: 'Students expected',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _transportController,
                  decoration: const InputDecoration(labelText: 'Transport'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emergencyController,
                  decoration: const InputDecoration(labelText: 'Emergency contacts'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add trip'),
        ),
      ],
    );
  }
}
