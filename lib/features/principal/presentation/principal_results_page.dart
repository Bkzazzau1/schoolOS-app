import 'package:flutter/material.dart';

import '../data/principal_results_demo_data.dart';
import '../data/principal_results_repository.dart';
import '../domain/principal_results_models.dart';

class PrincipalResultsPage extends StatefulWidget {
  const PrincipalResultsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    this.onMutationQueued,
  });

  final PrincipalResultsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalResultsPage> createState() => _PrincipalResultsPageState();
}

class _PrincipalResultsPageState extends State<PrincipalResultsPage> {
  final _commentController = TextEditingController(text: principalDefaultComment);
  PrincipalResultsSnapshot? _snapshot;
  String? _error;
  String _classFilter = 'All classes';
  String _releaseFilter = 'All states';
  String _query = '';
  String _selectedStudentId = 'STU-003';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      final selected = snapshot.students.where((row) => row.id == _selectedStudentId).firstOrNull;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (selected == null && snapshot.students.isNotEmpty) {
          _selectedStudentId = snapshot.students.first.id;
        }
      });
      final current = snapshot.students.where((row) => row.id == _selectedStudentId).firstOrNull;
      if (current != null) {
        _commentController.text = current.principalComment ?? principalDefaultComment;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<PrincipalClassResult> _filteredClasses(PrincipalResultsSnapshot snapshot) {
    final query = _query.trim().toLowerCase();
    return snapshot.classes.where((row) {
      final matchesClass = _classFilter == 'All classes' || row.className == _classFilter;
      final matchesRelease = _releaseFilter == 'All states' || row.release.label == _releaseFilter;
      final matchesQuery = query.isEmpty || row.className.toLowerCase().contains(query);
      return matchesClass && matchesRelease && matchesQuery;
    }).toList(growable: false);
  }

  List<PrincipalStudentResult> _visibleStudents(PrincipalResultsSnapshot snapshot) {
    final filtered = snapshot.students.where((row) => _classFilter == 'All classes' || row.className == _classFilter).toList(growable: false);
    return filtered.isEmpty ? snapshot.students : filtered;
  }

  PrincipalStudentResult _selected(PrincipalResultsSnapshot snapshot) => snapshot.students.firstWhere(
        (row) => row.id == _selectedStudentId,
        orElse: () => snapshot.students.first,
      );

  void _selectStudent(PrincipalStudentResult student) {
    setState(() => _selectedStudentId = student.id);
    _commentController.text = student.principalComment ?? principalDefaultComment;
  }

  Future<void> _review(PrincipalReportReviewAction action) async {
    final snapshot = _snapshot;
    if (snapshot == null || _saving) return;
    setState(() => _saving = true);
    if (action == PrincipalReportReviewAction.returnWithComment && _commentController.text.trim().isEmpty) {
      _commentController.text = principalReturnComment;
    }
    final result = await widget.repository.reviewReport(
      studentId: _selected(snapshot).id,
      action: action,
      comment: _commentController.text,
    );
    if (!mounted) return;
    await _load();
    widget.onMutationQueued?.call();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<void> _openPrintPreview(PrincipalStudentResult student) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Print-ready report preview'),
            leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _OfficialReportPaper(student: student, principalComment: _commentController.text),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'This is the complete native print-ready report. The OS printer/PDF adapter remains a separate platform integration so report governance is not tied to one plugin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text('Could not load Results & Reports.', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]),
        ),
      );
    }
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    final selected = _selected(snapshot);
    final classes = _filteredClasses(snapshot);
    final students = _visibleStudents(snapshot);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(onNavigate: widget.onNavigate),
        const SizedBox(height: 16),
        _Kpis(snapshot: snapshot),
        const SizedBox(height: 16),
        _ClassSummary(
          rows: classes,
          query: _query,
          classFilter: _classFilter,
          releaseFilter: _releaseFilter,
          onQueryChanged: (value) => setState(() => _query = value),
          onClassChanged: (value) => setState(() => _classFilter = value),
          onReleaseChanged: (value) => setState(() => _releaseFilter = value),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final list = _StudentReportList(students: students, selectedId: selected.id, onSelected: _selectStudent);
          final controls = _ReviewControls(
            student: selected,
            controller: _commentController,
            saving: _saving,
            canReview: snapshot.permissions.canReviewReports,
            onReturn: () => _review(PrincipalReportReviewAction.returnWithComment),
            onApprove: () => _review(PrincipalReportReviewAction.approve),
            onPrint: () => _openPrintPreview(selected),
          );
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: list), const SizedBox(width: 16), Expanded(flex: 6, child: controls)])
              : Column(children: [list, const SizedBox(height: 16), controls]);
        }),
        const SizedBox(height: 16),
        _OfficialReportPaper(student: selected, principalComment: _commentController.text),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final ai = _AiInsight(onNavigate: widget.onNavigate);
          const control = _ReportControl();
          if (constraints.maxWidth >= 900) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ai), const SizedBox(width: 16), const Expanded(child: control)]);
          }
          return Column(children: [ai, const SizedBox(height: 16), control]);
        }),
        const SizedBox(height: 12),
        const _Boundary(text: principalResultsAuthorityBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalResultsReleaseBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalResultsScoreBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalResultsIdentityBoundary),
        const SizedBox(height: 8),
        const _Boundary(text: principalResultsOfflineBoundary),
      ],
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PRINCIPAL · RESULTS & REPORTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              SizedBox(height: 4),
              Text('Results & Reports', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
              SizedBox(height: 4),
              Text('Review school-wide results, approve report cards, monitor release status and prepare official reports.'),
            ]),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            OutlinedButton(onPressed: () => onNavigate('academics'), child: const Text('Academics')),
            OutlinedButton(onPressed: () => onNavigate('approvals'), child: const Text('Approvals')),
          ]),
        ],
      );
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.snapshot});
  final PrincipalResultsSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        _Kpi(label: 'School average', value: '${snapshot.schoolAverage}%', note: 'Current term prototype'),
        _Kpi(label: 'Pass rate', value: '${snapshot.passRate}%', note: 'Across tracked classes'),
        _Kpi(label: 'Reports ready', value: '${snapshot.reportsReady}', note: 'Prepared report cards'),
        _Kpi(label: 'Awaiting approval', value: '${snapshot.pendingApproval}', note: 'Principal action needed'),
        _Kpi(label: 'Released classes', value: '${snapshot.releasedClasses}', note: 'Parent/student visible'),
      ]);
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.note});
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 185,
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              Text(note, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class _ClassSummary extends StatelessWidget {
  const _ClassSummary({
    required this.rows,
    required this.query,
    required this.classFilter,
    required this.releaseFilter,
    required this.onQueryChanged,
    required this.onClassChanged,
    required this.onReleaseChanged,
  });
  final List<PrincipalClassResult> rows;
  final String query;
  final String classFilter;
  final String releaseFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onReleaseChanged;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Class result summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Compare completion, performance and report-release state.'),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: 240, child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search class...', border: OutlineInputBorder()), onChanged: onQueryChanged)),
              SizedBox(width: 190, child: DropdownButtonFormField<String>(initialValue: classFilter, decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()), items: [for (final value in principalResultsClassFilters) DropdownMenuItem(value: value, child: Text(value))], onChanged: (value) { if (value != null) onClassChanged(value); })),
              SizedBox(width: 210, child: DropdownButtonFormField<String>(initialValue: releaseFilter, decoration: const InputDecoration(labelText: 'Release state', border: OutlineInputBorder()), items: [for (final value in principalResultsReleaseFilters) DropdownMenuItem(value: value, child: Text(value))], onChanged: (value) { if (value != null) onReleaseChanged(value); })),
            ]),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No classes match the current filters.')))
            else
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 860) {
                  return Column(children: [for (final row in rows) _ClassCard(row: row)]);
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Class')), DataColumn(label: Text('Students')), DataColumn(label: Text('Average')), DataColumn(label: Text('Pass rate')), DataColumn(label: Text('Highest')), DataColumn(label: Text('Lowest')), DataColumn(label: Text('Scores complete')), DataColumn(label: Text('Reports ready')), DataColumn(label: Text('Trend')), DataColumn(label: Text('Release')),
                    ],
                    rows: [for (final row in rows) DataRow(cells: [
                      DataCell(Text(row.className, style: const TextStyle(fontWeight: FontWeight.w800))), DataCell(Text('${row.students}')), DataCell(Text('${row.average}%')), DataCell(Text('${row.passRate}%')), DataCell(Text('${row.highest}%')), DataCell(Text('${row.lowest}%')), DataCell(Text('${row.complete}%')), DataCell(Text('${row.reportsReady}/${row.students}')), DataCell(Text('${row.trend > 0 ? '+' : ''}${row.trend}%')), DataCell(_ReleaseChip(state: row.release)),
                    ])],
                  ),
                );
              }),
          ]),
        ),
      );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.row});
  final PrincipalClassResult row;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(row.className, style: const TextStyle(fontWeight: FontWeight.w900))), _ReleaseChip(state: row.release)]),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [Text('${row.students} students'), Text('Avg ${row.average}%'), Text('Pass ${row.passRate}%'), Text('Complete ${row.complete}%'), Text('Ready ${row.reportsReady}/${row.students}'), Text('Trend ${row.trend > 0 ? '+' : ''}${row.trend}%')]),
        ]),
      );
}

class _StudentReportList extends StatelessWidget {
  const _StudentReportList({required this.students, required this.selectedId, required this.onSelected});
  final List<PrincipalStudentResult> students;
  final String selectedId;
  final ValueChanged<PrincipalStudentResult> onSelected;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Student report cards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Select a student to review the official report preview.'),
            const SizedBox(height: 12),
            for (final student in students) ...[
              Material(
                color: student.id == selectedId ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelected(student),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      SizedBox(width: 70, child: Text(student.id, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(student.name, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${student.className} · Avg ${student.average}% · Attendance ${student.attendance}%', style: Theme.of(context).textTheme.bodySmall)])),
                      const SizedBox(width: 8),
                      _ReleaseChip(state: student.displayStatus),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ]),
        ),
      );
}

class _ReviewControls extends StatelessWidget {
  const _ReviewControls({
    required this.student,
    required this.controller,
    required this.saving,
    required this.canReview,
    required this.onReturn,
    required this.onApprove,
    required this.onPrint,
  });
  final PrincipalStudentResult student;
  final TextEditingController controller;
  final bool saving;
  final bool canReview;
  final VoidCallback onReturn;
  final VoidCallback onApprove;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SELECTED REPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)), Text(student.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)), Text('${student.className} · ${student.id}')])),
              _ReleaseChip(state: student.displayStatus),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Metric(label: 'Average', value: '${student.average}%'),
              _Metric(label: 'Position', value: student.position),
              _Metric(label: 'Attendance', value: '${student.attendance}%'),
            ]),
            const SizedBox(height: 14),
            TextField(controller: controller, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Principal comment', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(onPressed: saving || !canReview ? null : onReturn, icon: const Icon(Icons.undo_rounded), label: const Text('Return with comment')),
              FilledButton.icon(onPressed: saving || !canReview ? null : onApprove, icon: const Icon(Icons.check_circle_outline_rounded), label: Text(saving ? 'Saving...' : 'Approve report')),
              OutlinedButton.icon(onPressed: onPrint, icon: const Icon(Icons.print_outlined), label: const Text('Print / Save as PDF')),
            ]),
            const SizedBox(height: 10),
            const Text("Approval here represents the Principal's review step. School identity/letterhead remains centrally managed and read-only in this role."),
            if (student.lastReviewedAt != null) ...[
              const SizedBox(height: 10),
              Text('Last reviewed ${student.lastReviewedAt} · ${student.lastReviewedByMembershipId ?? 'Principal'}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        width: 145,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))]),
      );
}

class _OfficialReportPaper extends StatelessWidget {
  const _OfficialReportPaper({required this.student, required this.principalComment});
  final PrincipalStudentResult student;
  final String principalComment;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CircleAvatar(radius: 30, child: Text(principalReportLogoText, style: TextStyle(fontWeight: FontWeight.w900))),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(principalReportSchoolName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                Text(principalReportMotto, style: TextStyle(fontWeight: FontWeight.w700)),
                Text(principalReportAddress),
                Text('$principalReportPhone · $principalReportEmail · $principalReportWebsite'),
                Text('Branches: Kaduna Campus · Zaria Campus'),
              ])),
              const SizedBox(width: 8),
              const Text(principalReportRegistration, style: TextStyle(fontSize: 11)),
            ]),
            const Divider(height: 28),
            const Center(child: Column(children: [Text('OFFICIAL STUDENT REPORT CARD', style: TextStyle(fontWeight: FontWeight.w900)), Text(principalReportTerm, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _Meta(label: 'Student', value: student.name), _Meta(label: 'Student ID', value: student.id), _Meta(label: 'Class', value: student.className), _Meta(label: 'Average', value: '${student.average}%'), _Meta(label: 'Position', value: student.position), _Meta(label: 'Attendance', value: '${student.attendance}%'),
            ]),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [DataColumn(label: Text('Subject')), DataColumn(label: Text('CA')), DataColumn(label: Text('Exam')), DataColumn(label: Text('Total')), DataColumn(label: Text('Grade')), DataColumn(label: Text('Remark'))],
                rows: [for (final row in principalReportSubjects) DataRow(cells: [DataCell(Text(row.subject)), DataCell(Text('${row.ca}')), DataCell(Text('${row.exam}')), DataCell(Text('${row.total}')), DataCell(Text(row.grade)), DataCell(Text(row.remark))])],
              ),
            ),
            const SizedBox(height: 14),
            _CommentBox(label: "Teacher's Comment", text: student.teacherComment),
            const SizedBox(height: 8),
            _CommentBox(label: "Principal's Comment", text: principalComment.trim().isEmpty ? principalDefaultComment : principalComment.trim()),
            const SizedBox(height: 8),
            const Wrap(spacing: 10, runSpacing: 10, children: [_Meta(label: 'Conduct', value: 'Very Good'), _Meta(label: 'Punctuality', value: 'Good')]),
            const SizedBox(height: 22),
            const Wrap(spacing: 22, runSpacing: 18, alignment: WrapAlignment.spaceBetween, children: [
              _Signature(label: 'Class / Subject Teacher', value: 'Authorized Teacher'),
              _Signature(label: 'Principal', value: principalReportPrincipalName),
              _Signature(label: 'Date Issued', value: principalReportDateIssued),
            ]),
            const SizedBox(height: 18),
            const Text('Generated from SchoolOS · Valid subject to school approval and authorized signature.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
          ]),
        ),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        width: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
      );
}

class _CommentBox extends StatelessWidget {
  const _CommentBox({required this.label, required this.text});
  final String label;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(text)]),
      );
}

class _Signature extends StatelessWidget {
  const _Signature({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 12), const Divider()]),
      );
}

class _AiInsight extends StatelessWidget {
  const _AiInsight({required this.onNavigate});
  final ValueChanged<String> onNavigate;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Principal AI result insight', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 6),
            const Text('JSS 2B remains the clearest academic concern: average 61%, negative trend and incomplete result/report preparation. Before release, verify whether the decline is concentrated in specific subjects and whether attendance is materially contributing.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => onNavigate('ai'), child: const Text('Ask Principal AI')), OutlinedButton(onPressed: () => onNavigate('academics'), child: const Text('Open academic analysis'))]),
            const SizedBox(height: 10),
            const Text(principalResultsAiBoundary, style: TextStyle(fontSize: 12)),
          ]),
        ),
      );
}

class _ReportControl extends StatelessWidget {
  const _ReportControl();
  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Report control', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            SizedBox(height: 10),
            _Step(number: '1', text: 'Teachers prepare scores, comments and student reports.'),
            _Step(number: '2', text: 'Principal reviews exceptions, comments and release readiness.'),
            _Step(number: '3', text: 'Approved reports can be prepared for printing/PDF on official letterhead.'),
            _Step(number: '4', text: 'Release to parents/students remains a controlled school action.'),
          ]),
        ),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final String number;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 13, child: Text(number, style: const TextStyle(fontSize: 11))), const SizedBox(width: 9), Expanded(child: Text(text))]),
      );
}

class _ReleaseChip extends StatelessWidget {
  const _ReleaseChip({required this.state});
  final PrincipalResultReleaseState state;
  @override
  Widget build(BuildContext context) => Chip(label: Text(state.label), visualDensity: VisualDensity.compact);
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
        child: Text(text),
      );
}
