import 'package:flutter/material.dart';

import '../../driver/domain/driver_incident_models.dart';
import '../data/transport_incident_defect_control_repository.dart';
import '../domain/transport_incident_defect_control_models.dart';

class TransportIncidentDefectControlPanel extends StatefulWidget {
  const TransportIncidentDefectControlPanel({
    super.key,
    required this.repository,
    this.onChanged,
  });

  final TransportIncidentDefectControlRepository repository;
  final VoidCallback? onChanged;

  @override
  State<TransportIncidentDefectControlPanel> createState() =>
      _TransportIncidentDefectControlPanelState();
}

class _TransportIncidentDefectControlPanelState
    extends State<TransportIncidentDefectControlPanel> {
  final _searchController = TextEditingController();
  late Future<TransportIncidentDefectSnapshot> _future;
  bool _defects = false;
  bool _openOnly = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.repository.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TransportIncidentDefectSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Incidents & defects control',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Transport cases could not be loaded.'}'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildPanel(snapshot.data!);
      },
    );
  }

  Widget _buildPanel(TransportIncidentDefectSnapshot snapshot) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    final incidents = snapshot.incidents.where((item) {
      if (_openOnly && !item.isOpen) return false;
      if (query.isEmpty) return true;
      return '${item.routeId} ${item.routeName} ${item.vehicle} ${item.driverName} ${item.category.label} ${item.description} ${item.studentName}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);
    final defects = snapshot.defects.where((item) {
      if (_openOnly && !item.isOpen) return false;
      if (query.isEmpty) return true;
      return '${item.routeId} ${item.routeName} ${item.vehicle} ${item.driverName} ${item.itemLabel} ${item.note}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSPORT CONTROL · SAFETY CASES',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Incidents & defects control',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review Driver incident reports and vehicle defects, record management action and close cases only after the operational issue has been handled.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    snapshot.canManage
                        ? Icons.admin_panel_settings_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(snapshot.canManage ? 'Management enabled' : 'View only'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric('Open incidents', '${snapshot.openIncidents}'),
                _Metric('Urgent', '${snapshot.urgentIncidents}'),
                _Metric('Open defects', '${snapshot.openDefects}'),
                _Metric('Blocking defects', '${snapshot.blockingDefects}'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: !_defects,
                  onSelected: (_) => setState(() => _defects = false),
                  label: const Text('Incidents'),
                  avatar: const Icon(Icons.report_problem_outlined, size: 18),
                ),
                ChoiceChip(
                  selected: _defects,
                  onSelected: (_) => setState(() => _defects = true),
                  label: const Text('Vehicle defects'),
                  avatar: const Icon(Icons.car_repair_outlined, size: 18),
                ),
                FilterChip(
                  selected: _openOnly,
                  onSelected: (value) => setState(() => _openOnly = value),
                  label: const Text('Open only'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _defects
                    ? 'Search vehicle, route, driver or defect...'
                    : 'Search route, driver, category, student or incident...',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (!_defects)
              if (incidents.isEmpty)
                const _EmptyCase(message: 'No incidents match this filter.')
              else
                for (final incident in incidents) ...[
                  _IncidentCard(
                    incident: incident,
                    canManage: snapshot.canManage,
                    busy: _saving,
                    onAcknowledge: () => _run(
                      () => widget.repository.acknowledgeIncident(incident.id),
                    ),
                    onReview: () => _reviewIncident(incident),
                    onResolve: () => _resolveIncident(incident),
                  ),
                  const SizedBox(height: 10),
                ]
            else if (defects.isEmpty)
              const _EmptyCase(message: 'No vehicle defects match this filter.')
            else
              for (final defect in defects) ...[
                _DefectCard(
                  defect: defect,
                  canManage: snapshot.canManage,
                  busy: _saving,
                  onAcknowledge: () => _run(
                    () => widget.repository.acknowledgeDefect(defect.id),
                  ),
                  onReview: () => _reviewDefect(defect),
                  onClear: () => _clearDefect(defect),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 4),
            Text(
              transportIncidentDefectBoundary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewIncident(TransportIncidentControlEntry incident) async {
    final note = await _noteDialog(
      title: 'Start incident review',
      hint: 'Optional management review note',
      required: false,
      initial: incident.managementNote,
      confirmLabel: 'Under review',
    );
    if (note == null) return;
    await _run(
      () => widget.repository.reviewIncident(incident.id, note: note),
    );
  }

  Future<void> _resolveIncident(TransportIncidentControlEntry incident) async {
    final note = await _noteDialog(
      title: 'Resolve incident',
      hint: 'State what was done and why the incident can be closed.',
      required: true,
      initial: incident.managementNote,
      confirmLabel: 'Resolve',
    );
    if (note == null) return;
    await _run(
      () => widget.repository.resolveIncident(
        incidentId: incident.id,
        note: note,
      ),
    );
  }

  Future<void> _reviewDefect(TransportVehicleDefectControlEntry defect) async {
    final note = await _noteDialog(
      title: 'Review vehicle defect',
      hint: 'Optional maintenance / inspection note',
      required: false,
      initial: defect.managementNote,
      confirmLabel: 'Under review',
    );
    if (note == null) return;
    await _run(
      () => widget.repository.reviewDefect(defect.id, note: note),
    );
  }

  Future<void> _clearDefect(TransportVehicleDefectControlEntry defect) async {
    final note = await _noteDialog(
      title: 'Clear vehicle defect',
      hint: 'Describe the repair, inspection or corrective action completed.',
      required: true,
      initial: defect.managementNote,
      confirmLabel: 'Clear defect',
    );
    if (note == null) return;
    await _run(
      () => widget.repository.clearDefect(defectId: defect.id, note: note),
    );
  }

  Future<String?> _noteDialog({
    required String title,
    required String hint,
    required bool required,
    required String confirmLabel,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 540,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: required ? 'Management note · required' : 'Management note',
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message as String)),
      );
      final success = result.success as bool;
      setState(() {
        _saving = false;
        _future = widget.repository.load();
      });
      if (success) widget.onChanged?.call();
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

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.canManage,
    required this.busy,
    required this.onAcknowledge,
    required this.onReview,
    required this.onResolve,
  });

  final TransportIncidentControlEntry incident;
  final bool canManage;
  final bool busy;
  final VoidCallback onAcknowledge;
  final VoidCallback onReview;
  final VoidCallback onResolve;

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
              Chip(label: Text(incident.routeId)),
              Chip(label: Text(incident.severity.label)),
              Chip(label: Text(incident.status.label)),
              if (incident.urgent)
                const Chip(
                  avatar: Icon(Icons.priority_high_rounded, size: 17),
                  label: Text('Immediate escalation'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            incident.category.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text('${incident.routeName} · ${incident.vehicle} · ${incident.driverName}'),
          const SizedBox(height: 8),
          Text(incident.description),
          if (incident.locationNote.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('Location note · ${incident.locationNote}'),
          ],
          if (incident.studentName.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('Linked rider · ${incident.studentName} (${incident.studentId})'),
          ],
          const SizedBox(height: 6),
          Text(
            '${incident.serviceDate} · ${incident.phase.label}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (incident.managementNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Management · ${incident.managementNote}',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (canManage && incident.isOpen) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (incident.status == DriverIncidentStatus.queued ||
                    incident.status == DriverIncidentStatus.submitted)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAcknowledge,
                    icon: const Icon(Icons.done_outlined, size: 18),
                    label: const Text('Acknowledge'),
                  ),
                if (incident.status != DriverIncidentStatus.underReview)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReview,
                    icon: const Icon(Icons.manage_search_outlined, size: 18),
                    label: const Text('Review'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onResolve,
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DefectCard extends StatelessWidget {
  const _DefectCard({
    required this.defect,
    required this.canManage,
    required this.busy,
    required this.onAcknowledge,
    required this.onReview,
    required this.onClear,
  });

  final TransportVehicleDefectControlEntry defect;
  final bool canManage;
  final bool busy;
  final VoidCallback onAcknowledge;
  final VoidCallback onReview;
  final VoidCallback onClear;

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
              Chip(label: Text(defect.routeId)),
              Chip(label: Text(defect.statusLabel)),
              Chip(label: Text(defect.severity)),
              if (defect.blocksService)
                const Chip(
                  avatar: Icon(Icons.block_outlined, size: 17),
                  label: Text('Trip blocking'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            defect.itemLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text('${defect.vehicle} · ${defect.routeName} · ${defect.driverName}'),
          if (defect.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(defect.note),
          ],
          const SizedBox(height: 6),
          Text(
            '${defect.serviceDate} · ${defect.period.isEmpty ? 'Vehicle check' : defect.period}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (defect.managementNote.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Management · ${defect.managementNote}',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (canManage && defect.isOpen) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (defect.status.toLowerCase() == 'reported')
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAcknowledge,
                    icon: const Icon(Icons.done_outlined, size: 18),
                    label: const Text('Acknowledge'),
                  ),
                if (defect.status.toLowerCase() != 'under_review')
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReview,
                    icon: const Icon(Icons.manage_search_outlined, size: 18),
                    label: const Text('Review'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onClear,
                  icon: const Icon(Icons.build_circle_outlined, size: 18),
                  label: const Text('Clear defect'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCase extends StatelessWidget {
  const _EmptyCase({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(child: Text(message)),
    );
  }
}
