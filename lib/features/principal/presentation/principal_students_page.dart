import 'package:flutter/material.dart';

import '../data/principal_students_demo_data.dart';
import '../data/principal_students_repository.dart';
import '../domain/principal_students_models.dart';
import 'principal_student_profile_page.dart';

class PrincipalStudentsPage extends StatefulWidget {
  const PrincipalStudentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final PrincipalStudentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<PrincipalStudentsPage> createState() => _PrincipalStudentsPageState();
}

class _PrincipalStudentsPageState extends State<PrincipalStudentsPage> {
  PrincipalStudentsSnapshot? _snapshot;
  String? _error;
  String _query = '';
  String _classFilter = 'All classes';
  String _riskFilter = 'All statuses';
  String _selectedId = 'STU-003';
  final _noteController = TextEditingController();
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.students.any((item) => item.id == _selectedId) && snapshot.students.isNotEmpty) {
          _selectedId = snapshot.students.first.id;
        }
      });
      _noteController.text = await widget.repository.loadLeadershipNote(_selectedId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  PrincipalStudentSummary get _selected => _snapshot!.students.firstWhere((item) => item.id == _selectedId);

  Future<void> _select(PrincipalStudentSummary student) async {
    setState(() => _selectedId = student.id);
    _noteController.text = await widget.repository.loadLeadershipNote(student.id);
    if (mounted) setState(() {});
  }

  Future<void> _saveNote() async {
    if (_savingNote) return;
    setState(() => _savingNote = true);
    final result = await widget.repository.saveLeadershipNote(studentId: _selectedId, note: _noteController.text);
    if (!mounted) return;
    setState(() => _savingNote = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) widget.onMutationQueued();
  }

  Future<void> _openProfile(PrincipalStudentSummary student) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${student.name} · Student Profile')),
        body: PrincipalStudentProfilePage(
          studentId: student.id,
          repository: widget.repository,
          onNavigate: (key) {
            Navigator.of(context).pop();
            widget.onNavigate(key);
          },
          onMutationQueued: widget.onMutationQueued,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    final filtered = snapshot.students.where((student) {
      final q = _query.toLowerCase();
      final queryMatch = '${student.name} ${student.id} ${student.className} ${student.risk.label}'.toLowerCase().contains(q);
      final classMatch = _classFilter == 'All classes' || student.className == _classFilter;
      final riskMatch = _riskFilter == 'All statuses' || student.risk.label == _riskFilter;
      return queryMatch && classMatch && riskMatch;
    }).toList(growable: false);

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      return ListView(
        padding: EdgeInsets.all(compact ? 14 : 24),
        children: [
          _header(context, compact),
          const SizedBox(height: 16),
          _kpis(context, compact, snapshot.students),
          const SizedBox(height: 18),
          compact
              ? Column(children: [_directory(context, filtered, true), const SizedBox(height: 14), _selectedCard(context, _selected)])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _directory(context, filtered, false)), const SizedBox(width: 14), Expanded(flex: 2, child: _selectedCard(context, _selected))]),
          const SizedBox(height: 18),
          compact
              ? Column(children: [_priorityQueue(context), const SizedBox(height: 14), _aiCard(context)])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: _priorityQueue(context)), const SizedBox(width: 14), Expanded(child: _aiCard(context))]),
          const SizedBox(height: 16),
          Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Text('$principalStudentsScopeBoundary\n\n$principalStudentAiBoundary', style: Theme.of(context).textTheme.bodySmall))),
        ],
      );
    });
  }

  Widget _header(BuildContext context, bool compact) {
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton(onPressed: () => widget.onNavigate('dashboard'), child: const Text('Dashboard')),
      OutlinedButton(onPressed: () => widget.onNavigate('academics'), child: const Text('Academics')),
      OutlinedButton(onPressed: () => widget.onNavigate('results'), child: const Text('Results & Reports')),
    ]);
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRINCIPAL · STUDENTS', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('Student Oversight', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const Text('Section-wide academic, attendance, behaviour and intervention oversight.'),
    ]);
    return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 10), actions]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
  }

  Widget _kpis(BuildContext context, bool compact, List<PrincipalStudentSummary> students) {
    final data = [
      ('Active students', '438', 'Current Secondary section'),
      ('At risk', '${students.where((s) => s.risk == PrincipalStudentRisk.atRisk).length}', 'Prototype flagged students'),
      ('Watch list', '${students.where((s) => s.risk == PrincipalStudentRisk.watch).length}', 'Needs monitoring'),
      ('Attendance risk', '${students.where((s) => s.attendance < 85).length}', 'Below 85%'),
      ('Behaviour flags', '${students.where((s) => s.behaviour == PrincipalStudentBehaviour.needsAttention).length}', 'Needs attention'),
    ];
    final cards = data.map((row) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.$1), const SizedBox(height: 4), Text(row.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text(row.$3, style: Theme.of(context).textTheme.bodySmall)]))));
    return compact ? Wrap(spacing: 8, runSpacing: 8, children: [for (final card in cards) SizedBox(width: 160, child: card)]) : Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card))]);
  }

  Widget _directory(BuildContext context, List<PrincipalStudentSummary> students, bool compact) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Student directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Search, review quickly, or open the complete student record.'),
            const SizedBox(height: 12),
            if (compact)
              Column(children: [_search(), const SizedBox(height: 8), _classFilterWidget(), const SizedBox(height: 8), _riskFilterWidget()])
            else
              Row(children: [Expanded(child: _search()), const SizedBox(width: 8), SizedBox(width: 160, child: _classFilterWidget()), const SizedBox(width: 8), SizedBox(width: 160, child: _riskFilterWidget())]),
            const SizedBox(height: 12),
            for (final student in students) _studentRow(context, student),
            if (students.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No students match this filter.')),
          ]),
        ),
      );

  Widget _search() => TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search student, ID or class...', border: OutlineInputBorder()), onChanged: (value) => setState(() => _query = value));

  Widget _classFilterWidget() => InputDecorator(
        decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _classFilter, items: [for (final item in principalStudentClasses) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) => setState(() => _classFilter = value ?? 'All classes'))),
      );

  Widget _riskFilterWidget() => InputDecorator(
        decoration: const InputDecoration(labelText: 'Risk', border: OutlineInputBorder()),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _riskFilter, items: [for (final item in principalStudentRiskFilters) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) => setState(() => _riskFilter = value ?? 'All statuses'))),
      );

  Widget _studentRow(BuildContext context, PrincipalStudentSummary student) {
    final selected = student.id == _selectedId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45) : null, border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _select(student), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          SizedBox(width: 68, child: Text(student.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(student.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${student.className} · Avg ${student.average}% · Attendance ${student.attendance}%', style: Theme.of(context).textTheme.bodySmall)])),
          SizedBox(width: 70, child: Text('${student.trend > 0 ? '+' : ''}${student.trend}%', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          Chip(label: Text(student.risk.label)),
        ])))),
        IconButton(tooltip: 'Open full student profile', onPressed: () => _openProfile(student), icon: const Icon(Icons.open_in_new_rounded)),
      ]),
    );
  }

  Widget _selectedCard(BuildContext context, PrincipalStudentSummary student) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(student.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))), Chip(label: Text(student.risk.label))]),
            Text(student.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text('${student.className} · ${student.guardian}'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _smallMetric('Average', '${student.average}%'),
              _smallMetric('Attendance', '${student.attendance}%'),
              _smallMetric('Trend', '${student.trend > 0 ? '+' : ''}${student.trend}%'),
              _smallMetric('Incidents', '${student.incidents}'),
            ]),
            const SizedBox(height: 12),
            const Text('Principal attention', style: TextStyle(fontWeight: FontWeight.w900)),
            Text(student.concern),
            const SizedBox(height: 10),
            _line('Behaviour', student.behaviour.label),
            _line('Interventions', '${student.interventions}'),
            _line('Guardian', student.guardian),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonal(onPressed: () => _openProfile(student), child: const Text('Open full profile')),
              OutlinedButton(onPressed: () => widget.onNavigate('results'), child: const Text('Results')),
              OutlinedButton(onPressed: () => widget.onNavigate('attendance'), child: const Text('Attendance')),
              OutlinedButton(onPressed: () => widget.onNavigate('incidents'), child: const Text('Incidents')),
              OutlinedButton(onPressed: () => widget.onNavigate('communication'), child: const Text('Contact guardian')),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _noteController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Principal note', hintText: 'Add an internal intervention or follow-up note...', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _savingNote ? null : _saveNote, icon: const Icon(Icons.save_outlined), label: Text(_savingNote ? 'Saving…' : 'Save note')),
            const SizedBox(height: 8),
            Text(principalStudentNoteBoundary, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _priorityQueue(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Priority intervention queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            _priority('At risk', 'Yusuf Bello · JSS 2B', 'Attendance 79%, average 48%, two incidents. Coordinate teacher + guardian intervention.', 'Start follow-up', 'communication'),
            _priority('Watch', 'Ibrahim Sani · JSS 2A', 'Recent performance decline despite acceptable attendance. Review assessment pattern.', 'Review performance', 'results'),
            _priority('Stable', 'Abdullahi Umar · SS 1A', 'Overall stable but below target in Physics and Further Mathematics.', 'Check class context', 'academics'),
          ]),
        ),
      );

  Widget _priority(String risk, String title, String detail, String action, String route) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Text(risk.substring(0, 1))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(detail),
        trailing: TextButton(onPressed: () => widget.onNavigate(route), child: Text(action)),
      );

  Widget _aiCard(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [CircleAvatar(child: Text('AI')), SizedBox(width: 10), Expanded(child: Text('Principal AI student insight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
            const SizedBox(height: 12),
            const Text('The strongest combined prototype review signal is in JSS 2B. Academic decline and attendance weakness are appearing together, so intervention should consider both learning support and attendance follow-up rather than treating the issues separately.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => widget.onNavigate('ai'), child: const Text('Ask Principal AI')), OutlinedButton(onPressed: () => widget.onNavigate('academics'), child: const Text('Open class analysis'))]),
          ]),
        ),
      );

  Widget _smallMetric(String label, String value) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]));

  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(value))]));
}
