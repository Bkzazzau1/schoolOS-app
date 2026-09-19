import 'package:flutter/material.dart';

import '../data/principal_academics_demo_data.dart';
import '../data/principal_academics_repository.dart';
import '../domain/principal_academics_models.dart';

class PrincipalAcademicsPage extends StatefulWidget {
  const PrincipalAcademicsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
  });

  final PrincipalAcademicsRepository repository;
  final ValueChanged<String> onNavigate;

  @override
  State<PrincipalAcademicsPage> createState() => _PrincipalAcademicsPageState();
}

class _PrincipalAcademicsPageState extends State<PrincipalAcademicsPage> {
  PrincipalAcademicsSnapshot? _snapshot;
  String? _error;
  String _query = '';
  String _level = 'All levels';
  String _status = 'All statuses';
  String _selectedClass = 'JSS 2B';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.classes.any((row) => row.name == _selectedClass) && snapshot.classes.isNotEmpty) {
          _selectedClass = snapshot.classes.first.name;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  PrincipalAcademicClass? _selected(PrincipalAcademicsSnapshot snapshot) {
    for (final row in snapshot.classes) {
      if (row.name == _selectedClass) return row;
    }
    return snapshot.classes.isEmpty ? null : snapshot.classes.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final filtered = snapshot.classes
            .where((row) => row.matches(query: _query, levelFilter: _level, statusFilter: _status))
            .toList(growable: false);
        final selected = _selected(snapshot);
        final schoolAverage = principalSchoolAverage(snapshot.classes);
        final syllabusAverage = principalSyllabusAverage(snapshot.classes);
        final assessmentAverage = principalAssessmentAverage(snapshot.classes);
        final behind = snapshot.classes.where((row) => row.status == PrincipalAcademicStatus.behind).length;
        final watch = snapshot.classes.where((row) => row.status == PrincipalAcademicStatus.watch).length;

        return ListView(
          padding: EdgeInsets.all(compact ? 14 : 24),
          children: [
            _header(context, compact),
            const SizedBox(height: 16),
            _kpis(context, compact, schoolAverage, syllabusAverage, assessmentAverage, behind, watch),
            const SizedBox(height: 16),
            _aiBrief(context, compact),
            const SizedBox(height: 16),
            compact
                ? Column(children: [
                    _classPanel(context, true, filtered),
                    const SizedBox(height: 12),
                    if (selected != null) _classDetail(context, selected),
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 7, child: _classPanel(context, false, filtered)),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: selected == null ? const SizedBox.shrink() : _classDetail(context, selected)),
                  ]),
            const SizedBox(height: 16),
            compact
                ? Column(children: [
                    _subjectPanel(context, snapshot.subjects),
                    const SizedBox(height: 12),
                    _riskPanel(context, snapshot.risks),
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _subjectPanel(context, snapshot.subjects)),
                    const SizedBox(width: 14),
                    Expanded(child: _riskPanel(context, snapshot.risks)),
                  ]),
            const SizedBox(height: 16),
            compact
                ? Column(children: [_curriculumControl(context), const SizedBox(height: 12), _assessmentReadiness(context)])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _curriculumControl(context)),
                    const SizedBox(width: 14),
                    Expanded(child: _assessmentReadiness(context)),
                  ]),
            const SizedBox(height: 14),
            _scopeBoundary(context),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, bool compact) {
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRINCIPAL · ACADEMICS', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text('Academic Command Centre', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Monitor school-wide learning performance, curriculum pace, assessment completion and academic risk.'),
    ]);
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Teachers')),
      OutlinedButton(onPressed: () => widget.onNavigate('results'), child: const Text('Results & Reports')),
      OutlinedButton(onPressed: () => widget.onNavigate('approvals'), child: const Text('Approvals')),
      OutlinedButton(onPressed: () => widget.onNavigate('dashboard'), child: const Text('Dashboard')),
    ]);
    return compact
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
  }

  Widget _kpis(BuildContext context, bool compact, int schoolAverage, int syllabus, int assessments, int behind, int watch) {
    final data = [
      ('School average', '$schoolAverage%', 'Across monitored classes'),
      ('Syllabus coverage', '$syllabus%', 'Current term average'),
      ('Assessment completion', '$assessments%', 'CA/tests entered'),
      ('Classes behind', '$behind', 'Needs intervention'),
      ('Classes on watch', '$watch', 'Monitor closely'),
    ];
    final cards = data
        .map((row) => Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.$1),
                  const SizedBox(height: 4),
                  Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                  Text(row.$3, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ))
        .toList(growable: false);
    return compact
        ? Wrap(spacing: 8, runSpacing: 8, children: [for (final card in cards) SizedBox(width: 165, child: card)])
        : Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card))]);
  }

  Widget _aiBrief(BuildContext context, bool compact) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: compact
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_aiBadge(), const SizedBox(height: 10), _aiContent(context)])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_aiBadge(), const SizedBox(width: 14), Expanded(child: _aiContent(context))]),
        ),
      );

  Widget _aiBadge() => const CircleAvatar(radius: 24, child: Text('AI', style: TextStyle(fontWeight: FontWeight.w900)));

  Widget _aiContent(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Principal AI Academic Brief', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const Text('Prototype analysis'),
        const SizedBox(height: 8),
        const Text(principalAcademicsAiBrief),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(onPressed: () => widget.onNavigate('ai'), child: const Text('Ask Principal AI')),
          OutlinedButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Review teachers')),
        ]),
      ]);

  Widget _classPanel(BuildContext context, bool compact, List<PrincipalAcademicClass> rows) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Class academic health', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Text('Performance, attendance, syllabus pace and assessment completion.'),
            const SizedBox(height: 12),
            compact
                ? Column(children: [_searchField(), const SizedBox(height: 8), _levelFilter(), const SizedBox(height: 8), _statusFilter()])
                : Row(children: [Expanded(child: _searchField()), const SizedBox(width: 8), SizedBox(width: 140, child: _levelFilter()), const SizedBox(width: 8), SizedBox(width: 150, child: _statusFilter())]),
            const SizedBox(height: 12),
            if (rows.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No classes match this filter.')),
            for (final row in rows) _classRow(context, row, compact),
          ]),
        ),
      );

  Widget _searchField() => TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search class or issue...', border: OutlineInputBorder()),
        onChanged: (value) => setState(() => _query = value),
      );

  Widget _levelFilter() => InputDecorator(
        decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _level,
            items: [for (final item in principalAcademicLevels) DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (value) => setState(() => _level = value ?? 'All levels'),
          ),
        ),
      );

  Widget _statusFilter() => InputDecorator(
        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _status,
            items: [for (final item in principalAcademicStatuses) DropdownMenuItem(value: item, child: Text(item))],
            onChanged: (value) => setState(() => _status = value ?? 'All statuses'),
          ),
        ),
      );

  Widget _classRow(BuildContext context, PrincipalAcademicClass row, bool compact) {
    final selected = row.name == _selectedClass;
    return InkWell(
      onTap: () => setState(() => _selectedClass = row.name),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45) : null,
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: compact
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900))), _statusChip(context, row.status)]),
                Text('${row.students} students · ${row.teachers} teachers', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 6, children: [
                  Text('Average ${row.average}%'),
                  Text('Attendance ${row.attendance}%'),
                  Text('Syllabus ${row.syllabus}%'),
                  Text('Assessments ${row.assessments}%'),
                  Text('${row.trend >= 0 ? '+' : ''}${row.trend}%', style: TextStyle(fontWeight: FontWeight.w800, color: row.trend < 0 ? Theme.of(context).colorScheme.error : null)),
                ]),
              ])
            : Row(children: [
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${row.students} students · ${row.teachers} teachers', style: Theme.of(context).textTheme.bodySmall)])),
                Expanded(child: Text('${row.average}%')),
                Expanded(child: Text('${row.attendance}%')),
                Expanded(child: Text('${row.syllabus}%')),
                Expanded(child: Text('${row.assessments}%')),
                Expanded(child: Text('${row.trend >= 0 ? '+' : ''}${row.trend}%', style: TextStyle(fontWeight: FontWeight.w800, color: row.trend < 0 ? Theme.of(context).colorScheme.error : null))),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(context, row.status))),
              ]),
      ),
    );
  }

  Widget _statusChip(BuildContext context, PrincipalAcademicStatus status) => Chip(label: Text(status.label));

  Widget _classDetail(BuildContext context, PrincipalAcademicClass row) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SELECTED CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(row.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(row.concern),
            const SizedBox(height: 14),
            Text('${row.average}%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const Text('Current academic average'),
            const SizedBox(height: 14),
            _metric('Attendance', row.attendance),
            _metric('Syllabus coverage', row.syllabus),
            _metric('Assessment completion', row.assessments),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              _miniMetric('Students', '${row.students}'),
              _miniMetric('Teachers', '${row.teachers}'),
              _miniMetric('Trend', '${row.trend >= 0 ? '+' : ''}${row.trend}%'),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonal(onPressed: () => widget.onNavigate('results'), child: const Text('Open results')),
              OutlinedButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Review teachers')),
              OutlinedButton(onPressed: () => widget.onNavigate('communication'), child: const Text('Send instruction')),
            ]),
          ]),
        ),
      );

  Widget _metric(String label, int value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(label)), Text('$value%', style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: value / 100),
        ]),
      );

  Widget _miniMetric(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]);

  Widget _subjectPanel(BuildContext context, List<PrincipalSubjectPerformance> subjects) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Subject performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('School-level subject averages against academic targets.'),
            const SizedBox(height: 12),
            for (final subject in subjects)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w800)), Text('Target ${subject.target}% · syllabus ${subject.syllabus}%', style: Theme.of(context).textTheme.bodySmall)])), Text('${subject.average}%', style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(width: 10), Text('${subject.trend >= 0 ? '+' : ''}${subject.trend}%'), const SizedBox(width: 8), _statusChip(context, subject.status)]),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(value: subject.average / 100),
                ]),
              ),
          ]),
        ),
      );

  Widget _riskPanel(BuildContext context, List<PrincipalAcademicRisk> risks) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('Academic risk queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text('Issues requiring leadership attention.')])), TextButton(onPressed: () => widget.onNavigate('ai'), child: const Text('Analyse with AI'))]),
            const SizedBox(height: 8),
            for (final risk in risks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Chip(label: Text(risk.severity)),
                title: Text(risk.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(risk.detail),
                trailing: TextButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Review')),
              ),
          ]),
        ),
      );

  Widget _curriculumControl(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Curriculum control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Principal oversight should focus on whether classes are moving through the approved scheme of work at a healthy pace, not forcing every teacher into identical daily progress.'),
            const SizedBox(height: 14),
            _controlGrid([('ON / ABOVE PACE', '4 classes'), ('WATCH', '1 class'), ('BEHIND', '1 class')]),
          ]),
        ),
      );

  Widget _assessmentReadiness(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assessment readiness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('Track whether teachers have created assessments, completed score entry and submitted work early enough for review before reports are released.'),
            const SizedBox(height: 14),
            _controlGrid([('COMPLETE', '84%'), ('PENDING REVIEW', '7 items'), ('SCORE CORRECTIONS', '2 requests')]),
          ]),
        ),
      );

  Widget _controlGrid(List<(String, String)> items) => Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [for (final item in items) SizedBox(width: 125, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), Text(item.$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]))],
      );

  Widget _scopeBoundary(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.verified_user_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(principalAcademicsScopeBoundary, style: Theme.of(context).textTheme.bodySmall)),
          ]),
        ),
      );
}
