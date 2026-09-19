import 'package:flutter/material.dart';

import '../data/principal_incidents_demo_data.dart';
import '../data/principal_incidents_repository.dart';
import '../domain/principal_incidents_models.dart';

class PrincipalIncidentsPage extends StatefulWidget {
  const PrincipalIncidentsPage({super.key, required this.repository, required this.onNavigate, this.onMutationQueued});

  final PrincipalIncidentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalIncidentsPage> createState() => _PrincipalIncidentsPageState();
}

class _PrincipalIncidentsPageState extends State<PrincipalIncidentsPage> {
  final _noteController = TextEditingController();
  PrincipalIncidentsSnapshot? _snapshot;
  String? _error;
  String _selectedId = 'INC-2402';
  String _query = '';
  String _category = 'All categories';
  String _status = 'All statuses';
  String _severity = 'All severities';
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _noteController.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.cases.any((e) => e.id == _selectedId) && snapshot.cases.isNotEmpty) _selectedId = snapshot.cases.first.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  List<PrincipalIncident> _filtered(PrincipalIncidentsSnapshot snapshot) {
    final q = _query.trim().toLowerCase();
    return snapshot.cases.where((item) {
      final haystack = '${item.id} ${item.title} ${item.category.label} ${item.person} ${item.context}'.toLowerCase();
      return (q.isEmpty || haystack.contains(q)) &&
          (_category == 'All categories' || item.category.label == _category) &&
          (_status == 'All statuses' || item.status.label == _status) &&
          (_severity == 'All severities' || item.severity.label == _severity);
    }).toList(growable: false);
  }

  PrincipalIncident _selected(PrincipalIncidentsSnapshot snapshot) => snapshot.cases.firstWhere((e) => e.id == _selectedId, orElse: () => snapshot.cases.first);

  Future<void> _saveNote() async {
    if (_saving || _snapshot == null) return;
    setState(() => _saving = true);
    final result = await widget.repository.saveNote(incidentId: _selected(_snapshot!).id, note: _noteController.text);
    if (!mounted) return;
    if (result.success) {
      _noteController.clear();
      widget.onMutationQueued?.call();
      await _load();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _changeStatus(PrincipalIncidentStatus status) async {
    if (_saving || _snapshot == null) return;
    setState(() => _saving = true);
    final result = await widget.repository.changeStatus(incidentId: _selected(_snapshot!).id, status: status);
    if (!mounted) return;
    if (result.success) {
      widget.onMutationQueued?.call();
      await _load();
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 40), const SizedBox(height: 8), const Text('Could not load incidents.'), TextButton(onPressed: _load, child: const Text('Retry'))]));
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());
    final selected = _selected(snapshot);
    final filtered = _filtered(snapshot);

    return ListView(padding: const EdgeInsets.all(20), children: [
      _Header(onNavigate: widget.onNavigate),
      const SizedBox(height: 16),
      _Kpis(snapshot: snapshot),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final list = _CaseList(
          cases: filtered,
          selectedId: selected.id,
          query: _query,
          category: _category,
          status: _status,
          severity: _severity,
          onQuery: (v) => setState(() => _query = v),
          onCategory: (v) => setState(() => _category = v),
          onStatus: (v) => setState(() => _status = v),
          onSeverity: (v) => setState(() => _severity = v),
          onSelect: (id) { _noteController.clear(); setState(() => _selectedId = id); },
        );
        final detail = _CaseDetail(
          item: selected,
          noteController: _noteController,
          saving: _saving,
          permissions: snapshot.permissions,
          onSaveNote: _saveNote,
          onInvestigating: () => _changeStatus(PrincipalIncidentStatus.investigating),
          onMonitoring: () => _changeStatus(PrincipalIncidentStatus.monitoring),
          onResolve: () => _changeStatus(PrincipalIncidentStatus.resolved),
          onNavigate: widget.onNavigate,
        );
        return constraints.maxWidth >= 980
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: list), const SizedBox(width: 16), Expanded(flex: 6, child: detail)])
            : Column(children: [list, const SizedBox(height: 16), detail]);
      }),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final activity = const _ActivityCard();
        final ai = _AiCard(onNavigate: widget.onNavigate);
        return constraints.maxWidth >= 900
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Expanded(child: activity), const SizedBox(width: 16), Expanded(child: ai)])
            : Column(children: [activity, const SizedBox(height: 16), ai]);
      }),
      const SizedBox(height: 16),
      const _Governance(),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, spacing: 16, children: [
        const SizedBox(width: 680, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PRINCIPAL · INCIDENTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          SizedBox(height: 4), Text('Incidents & Case Management', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
          SizedBox(height: 4), Text('Track behaviour, welfare, safeguarding, safety and operational incidents through resolution.'),
        ])),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
          OutlinedButton(onPressed: () => onNavigate('students'), child: const Text('Students')),
          OutlinedButton(onPressed: () => onNavigate('communication'), child: const Text('Communication')),
        ]),
      ]);
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalIncidentsSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        _Kpi('Open cases', '${snapshot.openCases}', 'Across all categories'),
        _Kpi('High priority', '${snapshot.highPriority}', 'Needs leadership attention'),
        _Kpi('Safeguarding', '${snapshot.safeguarding}', 'Restricted access'),
        _Kpi('Guardian contact', '${snapshot.awaitingGuardian}', 'Pending follow-up'),
        const _Kpi('Resolved this term', '$principalIncidentResolvedThisTerm', 'Prototype total'),
      ]);
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.note);
  final String label, value, note;
  @override
  Widget build(BuildContext context) => SizedBox(width: 185, child: Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), Text(note, style: Theme.of(context).textTheme.bodySmall)]))));
}

class _CaseList extends StatelessWidget {
  const _CaseList({required this.cases, required this.selectedId, required this.query, required this.category, required this.status, required this.severity, required this.onQuery, required this.onCategory, required this.onStatus, required this.onSeverity, required this.onSelect});
  final List<PrincipalIncident> cases;
  final String selectedId, query, category, status, severity;
  final ValueChanged<String> onQuery, onCategory, onStatus, onSeverity, onSelect;

  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Case register', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        const Text('Search and filter incidents requiring school follow-up.'), const SizedBox(height: 12),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search case, student, class...', border: OutlineInputBorder()), onChanged: onQuery),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Drop(value: category, values: principalIncidentCategories, onChanged: onCategory),
          _Drop(value: status, values: principalIncidentStatuses, onChanged: onStatus),
          _Drop(value: severity, values: principalIncidentSeverities, onChanged: onSeverity),
        ]), const SizedBox(height: 10),
        if (cases.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No cases match these filters.'))),
        for (final item in cases) Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: item.id == selectedId ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => onSelect(item.id), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(item.id, style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), _Chip(item.severity.label)]),
          const SizedBox(height: 4), Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${item.person} · ${item.context}'), Text('${item.category.label} · ${item.reportedAt}', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 6), _Chip(item.status.label),
        ]))))),
      ])));
}

class _Drop extends StatelessWidget {
  const _Drop({required this.value, required this.values, required this.onChanged});
  final String value; final List<String> values; final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: value, decoration: const InputDecoration(border: OutlineInputBorder()), items: [for (final v in values) DropdownMenuItem(value: v, child: Text(v))], onChanged: (v) { if (v != null) onChanged(v); }));
}

class _CaseDetail extends StatelessWidget {
  const _CaseDetail({required this.item, required this.noteController, required this.saving, required this.permissions, required this.onSaveNote, required this.onInvestigating, required this.onMonitoring, required this.onResolve, required this.onNavigate});
  final PrincipalIncident item; final TextEditingController noteController; final bool saving; final PrincipalIncidentPermissions permissions; final VoidCallback onSaveNote, onInvestigating, onMonitoring, onResolve; final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item.id} · ${item.category.label}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)), Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)), Text('${item.person} · ${item.context}') ])), _Chip(item.severity.label)]),
        if (item.isRestricted) ...[const SizedBox(height: 12), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.error), borderRadius: BorderRadius.circular(12)), child: const Text(principalIncidentRestrictedBoundary, style: TextStyle(fontWeight: FontWeight.w700)))],
        const SizedBox(height: 14), const Text('Case summary', style: TextStyle(fontWeight: FontWeight.w900)), Text(item.summary), const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Meta('Status', item.status.label), _Meta('Case owner', item.owner), _Meta('Reported by', item.reportedBy), _Meta('Location', item.location), _Meta('Guardian contact', item.guardianContact.label), _Meta('Evidence / files', '${item.evidenceCount}'),
        ]), const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Next action', style: TextStyle(fontWeight: FontWeight.w900)), Text(item.nextAction)])),
        const SizedBox(height: 14), TextField(controller: noteController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Principal case note', hintText: 'Add an internal action, finding or follow-up note...', border: OutlineInputBorder())),
        const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: saving || !permissions.canAddInternalNote ? null : onSaveNote, icon: const Icon(Icons.save_outlined), label: Text(saving ? 'Saving...' : 'Save note')),
          OutlinedButton(onPressed: () => onNavigate('communication'), child: const Text('Contact / follow up')),
        ]), const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: saving || !permissions.canChangeCaseStatus ? null : onInvestigating, child: const Text('Investigating')),
          OutlinedButton(onPressed: saving || !permissions.canChangeCaseStatus ? null : onMonitoring, child: const Text('Monitoring')),
          FilledButton(onPressed: saving || !permissions.canChangeCaseStatus ? null : onResolve, child: const Text('Resolve case')),
        ]),
      ])));
}

class _Meta extends StatelessWidget { const _Meta(this.label, this.value); final String label, value; @override Widget build(BuildContext context) => SizedBox(width: 180, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]))); }
class _Chip extends StatelessWidget { const _Chip(this.text); final String text; @override Widget build(BuildContext context) => Chip(label: Text(text)); }

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();
  @override Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Recent case activity', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), const SizedBox(height: 10), for (final item in principalIncidentActivity) ListTile(contentPadding: EdgeInsets.zero, leading: Text(item.time, style: const TextStyle(fontWeight: FontWeight.w800)), title: Text(item.text))])));
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.onNavigate}); final ValueChanged<String> onNavigate;
  @override Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Principal AI case insight', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), const SizedBox(height: 8), const Text(principalIncidentAiInsight), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Principal AI')), OutlinedButton(onPressed: () => onNavigate('attendance'), child: const Text('Review attendance')), OutlinedButton(onPressed: () => onNavigate('students'), child: const Text('Open students'))])])));
}

class _Governance extends StatelessWidget {
  const _Governance();
  @override Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Case governance', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)), SizedBox(height: 10), Text('CONFIDENTIALITY', style: TextStyle(fontWeight: FontWeight.w900)), Text(principalIncidentRestrictedBoundary), SizedBox(height: 10), Text('AUDIT TRAIL', style: TextStyle(fontWeight: FontWeight.w900)), Text(principalIncidentAuditBoundary), SizedBox(height: 10), Text('HUMAN DECISION', style: TextStyle(fontWeight: FontWeight.w900)), Text(principalIncidentAiBoundary), SizedBox(height: 10), Text('AUTHORITY', style: TextStyle(fontWeight: FontWeight.w900)), Text(principalIncidentAuthorityBoundary)])));
}
