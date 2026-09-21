import 'package:flutter/material.dart';

import '../data/transport_operational_reports_repository.dart';
import '../domain/transport_operational_reports_models.dart';

class TransportOperationalReportsPanel extends StatefulWidget {
  const TransportOperationalReportsPanel({
    super.key,
    required this.repository,
  });

  final TransportOperationalReportsRepository repository;

  @override
  State<TransportOperationalReportsPanel> createState() =>
      _TransportOperationalReportsPanelState();
}

class _TransportOperationalReportsPanelState
    extends State<TransportOperationalReportsPanel> {
  final _searchController = TextEditingController();
  late Future<TransportOperationalReportsSnapshot> _future;
  _ReportWindow _window = _ReportWindow.thirtyDays;
  String _routeId = 'all';
  bool _attentionOnly = false;

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
    return FutureBuilder<TransportOperationalReportsSnapshot>(
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
                    'Trip history & operational reports',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('${snapshot.error ?? 'Transport history could not be loaded.'}'),
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

  Widget _buildPanel(TransportOperationalReportsSnapshot snapshot) {
    final theme = Theme.of(context);
    final routes = <String, String>{};
    for (final entry in snapshot.entries) {
      routes.putIfAbsent(entry.routeId, () => entry.routeName);
    }
    if (_routeId != 'all' && !routes.containsKey(_routeId)) {
      _routeId = 'all';
    }

    final query = _searchController.text.trim().toLowerCase();
    final filtered = snapshot.entries.where((entry) {
      if (!_window.includes(entry.serviceDate)) return false;
      if (_routeId != 'all' && entry.routeId != _routeId) return false;
      if (_attentionOnly && !entry.hasSafetyAttention) return false;
      if (query.isEmpty) return true;
      return '${entry.serviceDate} ${entry.routeId} ${entry.routeName} ${entry.driverSummary} ${entry.vehicleSummary}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);
    final filteredSnapshot = TransportOperationalReportsSnapshot(
      entries: filtered,
    );

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
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRANSPORT CONTROL · HISTORY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Trip history & operational reports',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review school-wide transport service history without changing historical custody, safety or incident records.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.lock_outline_rounded, size: 18),
                  label: Text('Read only'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric('Route-service days', '${filteredSnapshot.recordedRouteDays}'),
                _Metric('Completed AM + PM', '${filteredSnapshot.completedServiceDays}'),
                _Metric('Drivers recorded', '${filteredSnapshot.distinctDrivers}'),
                _Metric('Incidents', '${filteredSnapshot.totalIncidents}'),
                _Metric('Vehicle defects', '${filteredSnapshot.totalVehicleDefects}'),
                _Metric('Blocking defects', '${filteredSnapshot.blockingVehicleDefects}'),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FlowMetric(
                  title: 'Morning arrivals',
                  value: '${filteredSnapshot.morningArrived} / ${filteredSnapshot.morningExpected}',
                ),
                _FlowMetric(
                  title: 'Afternoon safe resolutions',
                  value:
                      '${filteredSnapshot.afternoonSafelyReleased} / ${filteredSnapshot.afternoonExpected}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_ReportWindow>(
                  segments: const [
                    ButtonSegment(
                      value: _ReportWindow.sevenDays,
                      label: Text('7 days'),
                    ),
                    ButtonSegment(
                      value: _ReportWindow.thirtyDays,
                      label: Text('30 days'),
                    ),
                    ButtonSegment(
                      value: _ReportWindow.all,
                      label: Text('All'),
                    ),
                  ],
                  selected: {_window},
                  onSelectionChanged: (values) =>
                      setState(() => _window = values.first),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _routeId,
                    decoration: const InputDecoration(
                      labelText: 'Route',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All routes'),
                      ),
                      for (final entry in routes.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text('${entry.key} · ${entry.value}'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _routeId = value ?? 'all'),
                  ),
                ),
                FilterChip(
                  selected: _attentionOnly,
                  onSelected: (value) =>
                      setState(() => _attentionOnly = value),
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Safety attention only'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search date, route, Driver or vehicle...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text('No transport history matches this filter.'),
                ),
              )
            else
              for (final entry in filtered) ...[
                _HistoryCard(entry: entry),
                const SizedBox(height: 10),
              ],
            Text(
              transportOperationalReportsBoundary,
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
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final TransportOperationalReportEntry entry;

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
              Chip(label: Text(entry.serviceDate)),
              Chip(label: Text(entry.routeId)),
              Chip(
                avatar: Icon(
                  entry.serviceCompleted
                      ? Icons.check_circle_outline_rounded
                      : Icons.timelapse_rounded,
                  size: 17,
                ),
                label: Text(
                  entry.serviceCompleted
                      ? 'AM + PM complete'
                      : 'Service not fully completed',
                ),
              ),
              if (entry.hasSafetyAttention)
                const Chip(
                  avatar: Icon(Icons.warning_amber_rounded, size: 17),
                  label: Text('Safety attention'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.routeName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text('Driver · ${entry.driverSummary}'),
          Text('Vehicle · ${entry.vehicleSummary}'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final morning = _RunSummary(
                title: 'Morning · Home → School',
                status: entry.morningStatusLabel,
                line1: '${entry.morningArrived} / ${entry.morningExpected} arrived school',
                line2: '${entry.morningExceptions} exceptions',
                driver: entry.morningDriverName,
                vehicle: entry.morningVehicle,
              );
              final afternoon = _RunSummary(
                title: 'Afternoon · School → Home',
                status: entry.afternoonStatusLabel,
                line1:
                    '${entry.afternoonSafelyReleased} / ${entry.afternoonExpected} safely resolved',
                line2: '${entry.afternoonExceptions} exceptions',
                driver: entry.afternoonDriverName,
                vehicle: entry.afternoonVehicle,
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    morning,
                    const SizedBox(height: 10),
                    afternoon,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: morning),
                  const SizedBox(width: 10),
                  Expanded(child: afternoon),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                '${entry.incidentCount} incident${entry.incidentCount == 1 ? '' : 's'}',
              ),
              if (entry.urgentIncidentCount > 0)
                _InfoPill('${entry.urgentIncidentCount} urgent'),
              _InfoPill(
                '${entry.vehicleDefectCount} defect${entry.vehicleDefectCount == 1 ? '' : 's'}',
              ),
              if (entry.blockingVehicleDefectCount > 0)
                _InfoPill('${entry.blockingVehicleDefectCount} blocking'),
              if (entry.openIncidentCount > 0)
                _InfoPill('${entry.openIncidentCount} incident open'),
              if (entry.openVehicleDefectCount > 0)
                _InfoPill('${entry.openVehicleDefectCount} defect open'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RunSummary extends StatelessWidget {
  const _RunSummary({
    required this.title,
    required this.status,
    required this.line1,
    required this.line2,
    required this.driver,
    required this.vehicle,
  });

  final String title;
  final String status;
  final String line1;
  final String line2;
  final String driver;
  final String vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(status),
          Text(line1),
          Text(line2),
          if (driver.trim().isNotEmpty) Text('Driver · $driver'),
          if (vehicle.trim().isNotEmpty) Text('Vehicle · $vehicle'),
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

class _FlowMetric extends StatelessWidget {
  const _FlowMetric({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$title · $value'),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

enum _ReportWindow {
  sevenDays,
  thirtyDays,
  all;

  bool includes(String serviceDate) {
    if (this == _ReportWindow.all) return true;
    final parsed = DateTime.tryParse(serviceDate);
    if (parsed == null) return true;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(
      Duration(days: this == _ReportWindow.sevenDays ? 6 : 29),
    );
    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    return !normalized.isBefore(start);
  }
}
