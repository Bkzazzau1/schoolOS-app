import 'package:flutter/material.dart';

import '../data/driver_incident_repository.dart';
import '../domain/driver_incident_models.dart';

class DriverIncidentsPage extends StatefulWidget {
  const DriverIncidentsPage({
    super.key,
    required this.repository,
    this.onIncidentChanged,
  });

  final DriverIncidentRepository repository;
  final VoidCallback? onIncidentChanged;

  @override
  State<DriverIncidentsPage> createState() => _DriverIncidentsPageState();
}

class _DriverIncidentsPageState extends State<DriverIncidentsPage> {
  late Future<DriverIncidentSnapshot> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadToday();
  }

  void _reload() {
    setState(() => _future = widget.repository.loadToday());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DriverIncidentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _FailureState(
            message: '${snapshot.error ?? 'Transport incidents could not be loaded.'}',
            onRetry: _reload,
          );
        }
        return _buildPage(snapshot.data!);
      },
    );
  }

  Widget _buildPage(DriverIncidentSnapshot snapshot) {
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
              _Header(
                snapshot: snapshot,
                onReport: _saving ? null : () => _openReport(snapshot),
              ),
              const SizedBox(height: 16),
              _Stats(snapshot: snapshot),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _incidentList(snapshot)),
                    const SizedBox(width: 18),
                    const Expanded(flex: 3, child: _SafetyPanel()),
                  ],
                )
              else ...[
                _incidentList(snapshot),
                const SizedBox(height: 18),
                const _SafetyPanel(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _incidentList(DriverIncidentSnapshot snapshot) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Today\'s reports',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text('${snapshot.incidents.length} total'),
          ],
        ),
        const SizedBox(height: 10),
        if (snapshot.incidents.isEmpty)
          const _EmptyState()
        else
          for (final incident in snapshot.incidents) ...[
            _IncidentCard(incident: incident),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _openReport(DriverIncidentSnapshot snapshot) async {
    final result = await showDialog<_IncidentDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _IncidentReportDialog(snapshot: snapshot),
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      final incident = await widget.repository.report(
        category: result.category,
        severity: result.severity,
        description: result.description,
        locationNote: result.locationNote,
        studentId: result.studentId,
      );
      if (!mounted) return;
      widget.onIncidentChanged?.call();
      setState(() {
        _saving = false;
        _future = widget.repository.loadToday();
      });
      final message = incident.requiresImmediateEscalation
          ? 'Incident saved locally and queued. Follow emergency/escalation procedures now; queued does not mean acknowledged.'
          : 'Incident saved locally and queued for Transport Control.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
}

class _Header extends StatelessWidget {
  const _Header({required this.snapshot, required this.onReport});

  final DriverIncidentSnapshot snapshot;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DRIVER PORTAL · TRANSPORT SAFETY',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Incidents & Exceptions',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${snapshot.context.routeId} · ${snapshot.context.vehicle} · ${snapshot.context.phase.label}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.add_alert_outlined),
          label: const Text('Report incident'),
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.snapshot});

  final DriverIncidentSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Open reports', '${snapshot.openCount}', Icons.assignment_outlined),
      ('Escalation', '${snapshot.escalationCount}', Icons.notification_important_outlined),
      ('Critical', '${snapshot.criticalCount}', Icons.crisis_alert_outlined),
      ('Trip phase', snapshot.context.phase.label, Icons.route_outlined),
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
                                    .titleLarge
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final DriverTransportIncident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  incident.category.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _Badge(label: incident.severity.label),
                _Badge(label: incident.status.label),
                if (incident.requiresImmediateEscalation)
                  const _Badge(label: 'Escalate now'),
              ],
            ),
            const SizedBox(height: 8),
            Text(incident.description),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Meta(icon: Icons.route_outlined, text: incident.phase.label),
                if (incident.locationNote.isNotEmpty)
                  _Meta(
                    icon: Icons.location_on_outlined,
                    text: incident.locationNote,
                  ),
                if (incident.hasStudent)
                  _Meta(
                    icon: Icons.person_outline,
                    text: incident.studentName,
                  ),
                _Meta(
                  icon: Icons.schedule_outlined,
                  text: _displayTime(incident.reportedAt),
                ),
              ],
            ),
            if (incident.status == DriverIncidentStatus.queued) ...[
              const SizedBox(height: 10),
              Text(
                'Stored on this device and queued for sync. This does not mean Transport Control has received or acknowledged it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _displayTime(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _IncidentReportDialog extends StatefulWidget {
  const _IncidentReportDialog({required this.snapshot});

  final DriverIncidentSnapshot snapshot;

  @override
  State<_IncidentReportDialog> createState() => _IncidentReportDialogState();
}

class _IncidentReportDialogState extends State<_IncidentReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DriverIncidentCategory _category = DriverIncidentCategory.trafficDelay;
  DriverIncidentSeverity _severity = DriverIncidentSeverity.medium;
  String _studentId = '';

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _urgent =>
      _severity == DriverIncidentSeverity.high ||
      _severity == DriverIncidentSeverity.critical ||
      _category == DriverIncidentCategory.accident;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report transport incident'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.snapshot.context.routeId} · ${widget.snapshot.context.vehicle} · ${widget.snapshot.context.phase.label}',
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<DriverIncidentCategory>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final value in DriverIncidentCategory.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DriverIncidentSeverity>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: [
                    for (final value in DriverIncidentSeverity.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _severity = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _studentId.isEmpty ? null : _studentId,
                  decoration: const InputDecoration(
                    labelText: 'Related student (optional)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No student linked'),
                    ),
                    for (final student in widget.snapshot.assignedStudents)
                      DropdownMenuItem(
                        value: student.studentId,
                        child: Text(
                          '${student.name} · ${student.className}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _studentId = value ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location / stop note (optional)',
                    hintText: 'For example: Kakuri Roundabout',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'What happened?',
                    hintText: 'Use short factual operational details.',
                  ),
                  validator: (value) => (value ?? '').trim().length < 10
                      ? 'Add at least 10 characters.'
                      : null,
                ),
                if (_urgent) ...[
                  const SizedBox(height: 12),
                  const _UrgentNotice(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _IncidentDraft(
                category: _category,
                severity: _severity,
                description: _descriptionController.text.trim(),
                locationNote: _locationController.text.trim(),
                studentId: _studentId,
              ),
            );
          },
          icon: const Icon(Icons.send_outlined),
          label: const Text('Save & queue report'),
        ),
      ],
    );
  }
}

class _UrgentNotice extends StatelessWidget {
  const _UrgentNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'High/critical incidents require immediate safety and escalation procedures. Saving this report locally is not a substitute for emergency action or direct contact with Transport Control.',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _SafetyPanel extends StatelessWidget {
  const _SafetyPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _BoundaryCard(
          icon: Icons.emergency_outlined,
          title: 'Safety first',
          body:
              'For an accident, medical emergency or immediate danger, follow the school emergency procedure and contact the appropriate emergency/transport channel. Do not wait for sync.',
        ),
        SizedBox(height: 12),
        _BoundaryCard(
          icon: Icons.cloud_off_outlined,
          title: 'Offline reporting',
          body:
              'Reports save on this device first. Queued locally does not mean submitted, acknowledged, investigated or resolved by the school.',
        ),
        SizedBox(height: 12),
        _BoundaryCard(
          icon: Icons.verified_user_outlined,
          title: 'Driver authority',
          body:
              'The Driver can report facts. Transport Control owns acknowledgement, investigation, resolution and closure.',
        ),
      ],
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(body),
          ],
        ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'No incidents reported today',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use Report incident when a transport exception, delay, safety concern or emergency needs to be recorded.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Flexible(child: Text(text)),
      ],
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
            const SizedBox(height: 10),
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

class _IncidentDraft {
  const _IncidentDraft({
    required this.category,
    required this.severity,
    required this.description,
    required this.locationNote,
    required this.studentId,
  });

  final DriverIncidentCategory category;
  final DriverIncidentSeverity severity;
  final String description;
  final String locationNote;
  final String studentId;
}
