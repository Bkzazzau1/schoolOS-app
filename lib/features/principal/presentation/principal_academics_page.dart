import 'package:flutter/material.dart';

import '../../administrator/data/administrator_academics_repository.dart';
import '../../administrator/domain/administrator_academics_models.dart';
import '../data/principal_academics_demo_data.dart';
import '../data/principal_academics_repository.dart';
import '../domain/principal_academics_models.dart';

class PrincipalAcademicsPage extends StatefulWidget {
  const PrincipalAcademicsPage({
    super.key,
    required this.repository,
    required this.classes,
    required this.onNavigate,
  });

  final PrincipalAcademicsRepository repository;

  /// Shared with the Administrator workspace. Reading is open to any role;
  /// saving a class is too, now, but only this Principal's own Secondary -
  /// see AdministratorAcademicsRepository.saveClass.
  final AdministratorAcademicsRepository classes;
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

  AdministratorAcademicsSnapshot? _classesSnapshot;
  String? _classesError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadClasses();
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

  Future<void> _loadClasses() async {
    try {
      final snapshot = await widget.classes.load();
      if (!mounted) return;
      setState(() {
        _classesSnapshot = snapshot;
        _classesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _classesError = '$error');
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
                ? Column(children: [_curriculumControl(context, snapshot.classes), const SizedBox(height: 12), _assessmentReadiness(context, snapshot.classes)])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _curriculumControl(context, snapshot.classes)),
                    const SizedBox(width: 14),
                    Expanded(child: _assessmentReadiness(context, snapshot.classes)),
                  ]),
            const SizedBox(height: 16),
            _classworkOversight(context, snapshot.classwork),
            const SizedBox(height: 16),
            _classRosterCard(context),
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

  Widget _kpis(BuildContext context, bool compact, int? schoolAverage, int? syllabus, int? assessments, int behind, int watch) {
    final data = [
      ('School average', schoolAverage == null ? 'Not recorded' : '$schoolAverage%', 'Across classes with recorded assessments'),
      ('Syllabus coverage', syllabus == null ? 'Not recorded' : '$syllabus%', 'Classes with an approved scheme uploaded'),
      ('Assessment completion', assessments == null ? 'Not recorded' : '$assessments%', 'CA/tests entered'),
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
        const Text('Sample analysis'),
        const SizedBox(height: 8),
        const Text('Not available yet. An AI brief needs real assessment and syllabus evidence across enough classes to summarise; ask Principal AI directly once more classes have recorded evidence.'),
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
                  Text('Average ${_averageLabel(row)}'),
                  Text('Attendance ${row.attendance}%'),
                  Text('Syllabus ${_syllabusLabel(row)}'),
                  Text('Assessments ${row.assessments}%'),
                  Text('${row.trend >= 0 ? '+' : ''}${row.trend}%'),
                ]),
              ])
            : Row(children: [
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${row.students} students · ${row.teachers} teachers', style: Theme.of(context).textTheme.bodySmall)])),
                Expanded(child: Text(_averageLabel(row))),
                Expanded(child: Text('${row.attendance}%')),
                Expanded(child: Text(_syllabusLabel(row))),
                Expanded(child: Text('${row.assessments}%')),
                Expanded(child: Text('${row.trend >= 0 ? '+' : ''}${row.trend}%')),
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: _statusChip(context, row.status))),
              ]),
      ),
    );
  }

  String _averageLabel(PrincipalAcademicClass row) => row.status == PrincipalAcademicStatus.notEvaluated ? 'Not evaluated' : '${row.average}%';

  String _syllabusLabel(PrincipalAcademicClass row) => row.hasSyllabusScheme ? '${row.syllabus}%' : 'No scheme uploaded';

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
            Text(_averageLabel(row), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const Text('Current academic average'),
            const SizedBox(height: 14),
            _metric('Attendance', row.attendance),
            row.hasSyllabusScheme
                ? _metric('Syllabus coverage', row.syllabus)
                : const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Syllabus coverage: no approved scheme of work has been uploaded for this class yet.')),
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
            if (subjects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Not available yet. No real assessment records a subject, only a class and a title, so there is no real way to break performance down by subject school-wide.'),
              ),
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
            if (risks.isEmpty)
              const Padding(
                padding: EdgeInsets.all(4),
                child: Text('Not available yet. Flagging a genuine academic risk needs human judgement over a pattern; nothing in the app infers one automatically. Use the class list above to review each class\'s real figures directly.'),
              ),
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

  Widget _curriculumControl(BuildContext context, List<PrincipalAcademicClass> classes) {
    final withScheme = classes.where((c) => c.hasSyllabusScheme).toList();
    final behind = withScheme.where((c) => c.syllabusBehind).length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Curriculum control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Principal oversight should focus on whether classes are moving through the approved scheme of work at a healthy pace, not forcing every teacher into identical daily progress.'),
          const SizedBox(height: 14),
          _controlGrid([
            ('APPROVED SCHEME UPLOADED', '${withScheme.length} of ${classes.length} classes'),
            ('BEHIND ON A TOPIC', '$behind class${behind == 1 ? '' : 'es'}'),
            ('NO SCHEME YET', '${classes.length - withScheme.length} class${classes.length - withScheme.length == 1 ? '' : 'es'}'),
          ]),
        ]),
      ),
    );
  }

  Widget _assessmentReadiness(BuildContext context, List<PrincipalAcademicClass> classes) {
    final withEvidence = classes.where((c) => c.status != PrincipalAcademicStatus.notEvaluated).length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Assessment readiness', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Track whether teachers have created assessments and entered scores for each class. Submission review and score-correction workflows are not recorded anywhere yet.'),
          const SizedBox(height: 14),
          _controlGrid([
            ('CLASSES WITH ASSESSMENTS', '$withEvidence of ${classes.length}'),
            ('CLASSES WITH NONE YET', '${classes.length - withEvidence} of ${classes.length}'),
          ]),
        ]),
      ),
    );
  }

  Widget _classworkOversight(
    BuildContext context,
    List<PrincipalClassworkOversight> assignments,
  ) {
    final published = assignments.where((item) => item.state == 'published').length;
    final drafts = assignments.where((item) => item.state == 'draft').length;
    final totalRecipients = assignments.fold<int>(0, (sum, item) => sum + item.totalStudents);
    final submitted = assignments.fold<int>(0, (sum, item) => sum + item.submissions);
    final marked = assignments.fold<int>(0, (sum, item) => sum + item.marked);
    final late = assignments.fold<int>(0, (sum, item) => sum + item.lateSubmissions);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Secondary assignment & classwork oversight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Current-term assignments, submissions and late work.',
            ),
            const SizedBox(height: 14),
            _controlGrid([
              ('PUBLISHED', '$published'),
              ('TEACHER DRAFTS', '$drafts'),
              ('SUBMITTED', '$submitted / $totalRecipients'),
              ('GRADED', '$marked'),
              ('LATE', '$late'),
            ]),
            const SizedBox(height: 14),
            if (assignments.isEmpty)
              const Text('No Secondary assignments have synced for the active term yet.')
            else
              for (final item in assignments.take(10)) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
                  title: Text(item.title.isEmpty ? 'Untitled assignment' : item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${item.className} · ${item.subject} · ${item.teacher}\n'
                    '${item.submissions}/${item.totalStudents} submitted · ${item.marked} graded · ${item.lateSubmissions} late · due ${_dateTimeLabel(item.dueAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Chip(label: Text(_assignmentStateLabel(item.state))),
                ),
                if (item != assignments.take(10).last) const Divider(height: 1),
              ],
          ],
        ),
      ),
    );
  }

  String _assignmentStateLabel(String state) => switch (state) {
        'published' => 'Published',
        'closed' => 'Closed',
        _ => 'Teacher draft',
      };

  String _dateTimeLabel(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _controlGrid(List<(String, String)> items) => Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [for (final item in items) SizedBox(width: 125, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)), Text(item.$2, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]))],
      );

  Widget _classRosterCard(BuildContext context) {
    final secondary = (_classesSnapshot?.classes ?? const <AdministratorAcademicClass>[])
        .where((row) => row.section.trim().toLowerCase() == 'secondary')
        .toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Secondary classes', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Add or rename the classes students are placed into, e.g. "1A", "1B".'),
                ]),
              ),
              FilledButton.icon(
                onPressed: () => _editClass(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New class'),
              ),
            ]),
            const SizedBox(height: 12),
            if (_classesError != null) Text(_classesError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_classesError == null && _classesSnapshot == null) const LinearProgressIndicator(),
            if (_classesSnapshot != null && secondary.isEmpty)
              const Padding(padding: EdgeInsets.all(4), child: Text('No Secondary classes yet.')),
            for (final row in secondary)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Code ${row.code}${row.stream.isEmpty ? '' : ' · Stream ${row.stream}'}${row.isActive ? '' : ' · Inactive'}'),
                trailing: TextButton(onPressed: () => _editClass(row), child: const Text('Edit')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editClass([AdministratorAcademicClass? existing]) async {
    final snapshot = _classesSnapshot;
    if (snapshot == null) return;
    final name = TextEditingController(text: existing?.name ?? '');
    final code = TextEditingController(text: existing?.code ?? '');
    final order = TextEditingController(text: '${existing?.levelOrder ?? 1}');
    final stream = TextEditingController(text: existing?.stream ?? '');
    var nextClassId = existing?.nextClassId ?? '';
    var terminal = existing?.isTerminal ?? false;
    var active = existing?.isActive ?? true;
    final secondaryClasses = snapshot.classes.where((row) => row.section.trim().toLowerCase() == 'secondary').toList();
    final result = await showDialog<AdministratorAcademicClass>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'New Secondary class' : 'Edit Secondary class'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Class name', hintText: '1A'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Class code', hintText: 'JSS1A'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Progression order'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stream,
                    decoration: const InputDecoration(labelText: 'Stream (optional)', hintText: 'A'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: nextClassId,
                    decoration: const InputDecoration(labelText: 'Default next class'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('None')),
                      for (final item in secondaryClasses.where((item) => item.id != existing?.id))
                        DropdownMenuItem(value: item.id, child: Text(item.name)),
                    ],
                    onChanged: terminal ? null : (value) => setState(() => nextClassId = value ?? ''),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Terminal class'),
                    subtitle: const Text('Graduation is allowed only from a terminal class.'),
                    value: terminal,
                    onChanged: (value) => setState(() {
                      terminal = value;
                      if (terminal) nextClassId = '';
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active class'),
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final levelOrder = int.tryParse(order.text.trim());
                if (name.text.trim().isEmpty || code.text.trim().isEmpty || levelOrder == null || levelOrder < 1) {
                  return;
                }
                Navigator.pop(
                  context,
                  AdministratorAcademicClass(
                    id: existing?.id ?? AdministratorAcademicsRepository.newId(),
                    code: code.text.trim(),
                    name: name.text.trim(),
                    section: 'Secondary',
                    levelOrder: levelOrder,
                    stream: stream.text.trim(),
                    nextClassId: nextClassId,
                    isTerminal: terminal,
                    isActive: active,
                    campusId: existing?.campusId ?? '',
                    pendingSync: true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    code.dispose();
    order.dispose();
    stream.dispose();
    if (result == null) return;
    try {
      await widget.classes.saveClass(result);
      await _loadClasses();
    } catch (error) {
      if (!mounted) return;
      setState(() => _classesError = '$error');
    }
  }

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
