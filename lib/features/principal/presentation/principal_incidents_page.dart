import 'package:flutter/material.dart';

import '../data/principal_incidents_demo_data.dart';
import '../data/principal_incidents_repository.dart';
import '../domain/principal_incidents_models.dart';

class PrincipalIncidentsPage extends StatefulWidget {
  const PrincipalIncidentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });
  final PrincipalIncidentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;
  @override
  State<PrincipalIncidentsPage> createState() => _PrincipalIncidentsPageState();
}

class _PrincipalIncidentsPageState extends State<PrincipalIncidentsPage> {
  final _note = TextEditingController();
  PrincipalIncidentsSnapshot? _snapshot;
  String? _error;
  String _selectedId = '';
  String _query = '';
  String _category = 'All categories';
  String _status = 'All statuses';
  String _severity = 'All severities';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _error = null;
        if (!data.cases.any((e) => e.id == _selectedId) &&
            data.cases.isNotEmpty) {
          _selectedId = data.cases.first.id;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  PrincipalIncident _selected(PrincipalIncidentsSnapshot s) => s.cases
      .firstWhere((e) => e.id == _selectedId, orElse: () => s.cases.first);

  List<PrincipalIncident> _filtered(PrincipalIncidentsSnapshot s) {
    final q = _query.trim().toLowerCase();
    return s.cases
        .where((e) {
          final text =
              '${e.id} ${e.title} ${e.category.label} ${e.person} ${e.context}'
                  .toLowerCase();
          return (q.isEmpty || text.contains(q)) &&
              (_category == 'All categories' ||
                  e.category.label == _category) &&
              (_status == 'All statuses' || e.status.label == _status) &&
              (_severity == 'All severities' || e.severity.label == _severity);
        })
        .toList(growable: false);
  }

  Future<void> _saveNote() async {
    final s = _snapshot;
    if (s == null || s.cases.isEmpty || _saving) return;
    setState(() => _saving = true);
    final r = await widget.repository.saveNote(
      incidentId: _selected(s).id,
      note: _note.text,
    );
    if (!mounted) return;
    if (r.success) {
      _note.clear();
      widget.onMutationQueued?.call();
      await _load();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(r.message)));
  }

  Future<void> _setStatus(PrincipalIncidentStatus status) async {
    final s = _snapshot;
    if (s == null || s.cases.isEmpty || _saving) return;
    setState(() => _saving = true);
    final r = await widget.repository.changeStatus(
      incidentId: _selected(s).id,
      status: status,
    );
    if (!mounted) return;
    if (r.success) {
      widget.onMutationQueued?.call();
      await _load();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(r.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const Text('Could not load incidents.'),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final s = _snapshot;
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.cases.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Header(onNavigate: widget.onNavigate),
          const Text(
            'No recorded Secondary incidents. Open cases: 0. No safeguarding or disciplinary conclusions have been recorded.',
          ),
          const Text(
            'Transport reports are managed in Transport; they are not automatically student disciplinary cases.',
          ),
          const _Governance(),
        ],
      );
    }
    final selected = _selected(s);
    final rows = _filtered(s);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Kpi('Open cases', '${s.openCases}', 'Across all categories'),
            _Kpi(
              'High priority',
              '${s.highPriority}',
              'Needs leadership attention',
            ),
            _Kpi('Safeguarding', '${s.safeguarding}', 'Restricted access'),
            _Kpi(
              'Guardian contact',
              '${s.awaitingGuardian}',
              'Pending follow-up',
            ),
            _Kpi(
              'Recorded resolved cases',
              '${s.cases.where((c) => c.status == PrincipalIncidentStatus.resolved).length}',
              'All recorded cases; no term inferred',
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final register = _Register(
              rows: rows,
              selectedId: selected.id,
              category: _category,
              status: _status,
              severity: _severity,
              onQuery: (v) => setState(() => _query = v),
              onCategory: (v) => setState(() => _category = v),
              onStatus: (v) => setState(() => _status = v),
              onSeverity: (v) => setState(() => _severity = v),
              onSelect: (v) {
                _note.clear();
                setState(() => _selectedId = v);
              },
            );
            final detail = _Detail(
              item: selected,
              permissions: s.permissions,
              note: _note,
              saving: _saving,
              onSaveNote: _saveNote,
              onInvestigating: () =>
                  _setStatus(PrincipalIncidentStatus.investigating),
              onMonitoring: () =>
                  _setStatus(PrincipalIncidentStatus.monitoring),
              onResolve: () => _setStatus(PrincipalIncidentStatus.resolved),
              onNavigate: widget.onNavigate,
            );
            return c.maxWidth >= 980
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: register),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: detail),
                    ],
                  )
                : Column(
                    children: [register, const SizedBox(height: 16), detail],
                  );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final activity = _Activity(events: s.audit);
            final ai = _Ai(onNavigate: widget.onNavigate);
            return c.maxWidth >= 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: activity),
                      const SizedBox(width: 16),
                      Expanded(child: ai),
                    ],
                  )
                : Column(children: [activity, const SizedBox(height: 16), ai]);
          },
        ),
        const SizedBox(height: 16),
        const _Governance(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    runSpacing: 12,
    spacing: 16,
    children: [
      const SizedBox(
        width: 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRINCIPAL · INCIDENTS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            SizedBox(height: 4),
            Text(
              'Incidents & Case Management',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
            ),
            SizedBox(height: 4),
            Text(
              'Track behaviour, welfare, safeguarding, safety and operational incidents through resolution.',
            ),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => onNavigate('dashboard'),
            child: const Text('Dashboard'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('students'),
            child: const Text('Students'),
          ),
          OutlinedButton(
            onPressed: () => onNavigate('communication'),
            child: const Text('Communication'),
          ),
        ],
      ),
    ],
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note);
  final String label, value, note;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 185,
    child: Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _Register extends StatelessWidget {
  const _Register({
    required this.rows,
    required this.selectedId,
    required this.category,
    required this.status,
    required this.severity,
    required this.onQuery,
    required this.onCategory,
    required this.onStatus,
    required this.onSeverity,
    required this.onSelect,
  });
  final List<PrincipalIncident> rows;
  final String selectedId, category, status, severity;
  final ValueChanged<String> onQuery,
      onCategory,
      onStatus,
      onSeverity,
      onSelect;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Case register',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const Text('Search and filter incidents requiring school follow-up.'),
          const SizedBox(height: 12),
          TextField(
            onChanged: onQuery,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search case, student, class...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Drop(category, principalIncidentCategories, onCategory),
              _Drop(status, principalIncidentStatuses, onStatus),
              _Drop(severity, principalIncidentSeverities, onSeverity),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No cases match these filters.')),
            ),
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: e.id == selectedId
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onSelect(e.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              e.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Chip(label: Text(e.severity.label)),
                          ],
                        ),
                        Text(
                          e.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('${e.person} · ${e.context}'),
                        Text(
                          '${e.category.label} · ${e.reportedAt}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Chip(label: Text(e.status.label)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Drop extends StatelessWidget {
  const _Drop(this.value, this.values, this.changed);
  final String value;
  final List<String> values;
  final ValueChanged<String> changed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [
        for (final v in values) DropdownMenuItem(value: v, child: Text(v)),
      ],
      onChanged: (v) {
        if (v != null) changed(v);
      },
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.item,
    required this.permissions,
    required this.note,
    required this.saving,
    required this.onSaveNote,
    required this.onInvestigating,
    required this.onMonitoring,
    required this.onResolve,
    required this.onNavigate,
  });
  final PrincipalIncident item;
  final PrincipalIncidentPermissions permissions;
  final TextEditingController note;
  final bool saving;
  final VoidCallback onSaveNote, onInvestigating, onMonitoring, onResolve;
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
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
                      '${item.id} · ${item.category.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Text('${item.person} · ${item.context}'),
                  ],
                ),
              ),
              Chip(label: Text(item.severity.label)),
            ],
          ),
          if (item.isRestricted) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                principalIncidentRestrictedBoundary,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Case summary',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(item.summary),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Meta('Status', item.status.label),
              _Meta('Case owner', item.owner),
              _Meta('Reported by', item.reportedBy),
              _Meta('Location', item.location),
              _Meta('Guardian contact', item.guardianContact.label),
              _Meta('Evidence / files', '${item.evidenceCount}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next action',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(item.nextAction),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Principal case note',
              border: OutlineInputBorder(),
              hintText: 'Add an internal action, finding or follow-up note...',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: saving || !permissions.canAddInternalNote
                    ? null
                    : onSaveNote,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save note'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('communication'),
                child: const Text('Contact / follow up'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: saving || !permissions.canChangeCaseStatus
                    ? null
                    : onInvestigating,
                child: const Text('Investigating'),
              ),
              OutlinedButton(
                onPressed: saving || !permissions.canChangeCaseStatus
                    ? null
                    : onMonitoring,
                child: const Text('Monitoring'),
              ),
              FilledButton(
                onPressed: saving || !permissions.canChangeCaseStatus
                    ? null
                    : onResolve,
                child: const Text('Resolve case'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

class _Activity extends StatelessWidget {
  const _Activity({required this.events});
  final List<PrincipalIncidentAuditEvent> events;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        const Text('Recorded case activity'),
        if (events.isEmpty) const Text('No case activity recorded yet.'),
        for (final e in events)
          ListTile(
            title: Text(e.note ?? e.action),
            subtitle: Text('${e.actorMembershipId} ? ${e.createdAt}'),
          ),
      ],
    ),
  );
}

class _Ai extends StatelessWidget {
  const _Ai({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Principal AI case insight',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(principalIncidentAiInsight),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('ai'),
                child: const Text('Ask Principal AI'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('attendance'),
                child: const Text('Review attendance'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('students'),
                child: const Text('Open students'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Governance extends StatelessWidget {
  const _Governance();
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Case governance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10),
          Text(
            'CONFIDENTIALITY',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(principalIncidentRestrictedBoundary),
          SizedBox(height: 10),
          Text('AUDIT TRAIL', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(principalIncidentAuditBoundary),
          SizedBox(height: 10),
          Text('HUMAN DECISION', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(principalIncidentAiBoundary),
          SizedBox(height: 10),
          Text('AUTHORITY', style: TextStyle(fontWeight: FontWeight.w900)),
          Text(principalIncidentAuthorityBoundary),
        ],
      ),
    ),
  );
}
