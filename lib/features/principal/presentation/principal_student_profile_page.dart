import 'package:flutter/material.dart';

import '../data/principal_students_demo_data.dart';
import '../data/principal_students_repository.dart';
import '../domain/principal_students_models.dart';

class PrincipalStudentProfilePage extends StatefulWidget {
  const PrincipalStudentProfilePage({
    super.key,
    required this.studentId,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final String studentId;
  final PrincipalStudentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<PrincipalStudentProfilePage> createState() => _PrincipalStudentProfilePageState();
}

class _PrincipalStudentProfilePageState extends State<PrincipalStudentProfilePage> {
  PrincipalStudentProfile? _profile;
  String? _error;
  int _tab = 0;
  final _noteController = TextEditingController();
  final _destinationController = TextEditingController();
  final _reasonController = TextEditingController();
  String _lifecycleAction = 'Promote';
  String _effectiveSession = '2026/2027';
  bool _savingNote = false;
  bool _savingLifecycle = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _destinationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.loadProfile(widget.studentId);
      final note = await widget.repository.loadLeadershipNote(widget.studentId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _noteController.text = note;
        _error = profile == null ? 'Student is outside the active Secondary leadership scope.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _saveNote() async {
    if (_savingNote) return;
    setState(() => _savingNote = true);
    final result = await widget.repository.saveLeadershipNote(studentId: widget.studentId, note: _noteController.text);
    if (!mounted) return;
    setState(() => _savingNote = false);
    _show(result.message);
    if (result.success) widget.onMutationQueued();
  }

  Future<void> _saveLifecycle() async {
    if (_savingLifecycle) return;
    setState(() => _savingLifecycle = true);
    final result = await widget.repository.createLifecycleProposal(
      studentId: widget.studentId,
      actionType: _lifecycleAction,
      nextClassOrDestination: _destinationController.text,
      effectiveSession: _effectiveSession,
      reason: _reasonController.text,
    );
    if (!mounted) return;
    setState(() => _savingLifecycle = false);
    _show(result.message);
    if (result.success) {
      widget.onMutationQueued();
      _destinationController.clear();
      _reasonController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    final profile = _profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 860;
      final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(context, profile, compact),
        const SizedBox(height: 14),
        _tabs(context),
        const SizedBox(height: 14),
        _tabContent(context, profile),
      ]);
      return ListView(
        padding: EdgeInsets.all(compact ? 14 : 24),
        children: [
          if (compact) body else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 4, child: body), const SizedBox(width: 16), SizedBox(width: 300, child: _sideCard(context, profile))]),
          if (compact) ...[const SizedBox(height: 14), _sideCard(context, profile)],
        ],
      );
    });
  }

  Widget _header(BuildContext context, PrincipalStudentProfile profile, bool compact) {
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton(onPressed: () => widget.onNavigate('students'), child: const Text('Students')),
      OutlinedButton(onPressed: () => widget.onNavigate('results'), child: const Text('Results')),
      OutlinedButton(onPressed: () => widget.onNavigate('attendance'), child: const Text('Attendance')),
      OutlinedButton(onPressed: () => widget.onNavigate('communication'), child: const Text('Contact guardian')),
    ]);
    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PRINCIPAL · SECONDARY STUDENT', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(profile.summary.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      Text('${profile.summary.id} · ${profile.summary.className} · ${profile.summary.risk.label}'),
      const SizedBox(height: 4),
      Text('Secondary leadership can review academic, attendance, intervention and approved administrative context.', style: Theme.of(context).textTheme.bodySmall),
    ]);
    return compact ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 10), actions]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
  }

  Widget _tabs(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < principalStudentProfileTabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(principalStudentProfileTabs[i]), selected: _tab == i, onSelected: (_) => setState(() => _tab = i)),
            ),
        ]),
      );

  Widget _tabContent(BuildContext context, PrincipalStudentProfile profile) => switch (_tab) {
        0 => _overview(context, profile),
        1 => _academics(context, profile),
        2 => _attendance(context, profile),
        3 => _family(context, profile),
        4 => _schoolLife(context, profile),
        5 => _services(context, profile),
        6 => _history(context, profile),
        7 => _status(context, profile),
        8 => _documents(context, profile),
        9 => _timeline(context, profile),
        _ => _notes(context),
      };

  Widget _card(String title, String subtitle, List<Widget> children) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(subtitle),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      );

  Widget _overview(BuildContext context, PrincipalStudentProfile p) => _card('Overview', 'Identity, leadership context and current student state.', [
        _row('Admission number', p.admissionNo),
        _row('Class teacher', p.classTeacher),
        _row('Campus', p.campus),
        _row('Admission date', p.admissionDate),
        _row('Date of birth', p.dateOfBirth),
        _row('Gender', p.gender),
        _row('House', p.house),
        const Divider(),
        Text('Principal attention', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(p.summary.concern),
        const SizedBox(height: 10),
        Text(principalStudentAiBoundary, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _academics(BuildContext context, PrincipalStudentProfile p) => _card('Academics', 'Current subject evidence. Results remain governed by the dedicated result workflow.', [
        _metric('Overall average', p.summary.average),
        for (final subject in p.subjects) ListTile(contentPadding: EdgeInsets.zero, title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: LinearProgressIndicator(value: subject.score / 100), trailing: Text('${subject.score}% · ${subject.trend}')),
      ]);

  Widget _attendance(BuildContext context, PrincipalStudentProfile p) => _card('Attendance', 'Attendance evidence should be reviewed in context; absence must not be used to infer family or medical cause.', [
        _metric('Attendance rate', p.summary.attendance),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final item in p.attendanceSummary) Chip(label: Text('${item.label}: ${item.value}'))]),
      ]);

  Widget _family(BuildContext context, PrincipalStudentProfile p) => _card('Family', 'Authorized guardian relationship and family-account context.', [
        _row('Primary guardian', p.summary.guardian),
        _row('Guardian phone', p.guardianPhone),
        _row('Family account', p.familyAccountId),
        const SizedBox(height: 8),
        Text('Sibling links remain separate student records and must not merge one child’s academic or safeguarding record into another.', style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _schoolLife(BuildContext context, PrincipalStudentProfile p) => _card('School Life', 'Activities, awards and house participation.', [
        _row('House', p.house),
        const SizedBox(height: 8),
        const Text('Activities', style: TextStyle(fontWeight: FontWeight.w900)),
        for (final item in p.activities) ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.groups_outlined), title: Text(item)),
        const Text('Awards', style: TextStyle(fontWeight: FontWeight.w900)),
        if (p.awards.isEmpty) const Text('No award recorded in this profile sample.'),
        for (final item in p.awards) ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.emoji_events_outlined), title: Text(item)),
      ]);

  Widget _services(BuildContext context, PrincipalStudentProfile p) => _card('School services & health boundary', 'Operational relationships and minimum-necessary safety information only.', [
        _row('Transport', p.transport),
        _row('Meals & Cafeteria', p.meals),
        _row('Boarding', p.boarding),
        _row('Medical instruction', p.medicalInstruction),
        _row('Health record', p.healthRecordLabel),
        _row('Fee visibility', p.feeVisibility),
        const SizedBox(height: 8),
        Text(principalStudentHealthBoundary, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _history(BuildContext context, PrincipalStudentProfile p) => _card('Enrollment & promotion history', 'Track progression without rewriting prior records.', [
        _row('Previous school', p.previousSchool),
        const SizedBox(height: 8),
        for (final item in p.promotionHistory) ListTile(contentPadding: EdgeInsets.zero, title: Text('${item.session} · ${item.className}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(item.note), trailing: Text(item.outcome)),
        const SizedBox(height: 8),
        Text(principalStudentLifecycleBoundary, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _status(BuildContext context, PrincipalStudentProfile p) => _card('Status, transfer & class-change workflow', 'Create a governed proposal; do not silently rewrite the active enrollment record.', [
        _row('Current enrollment', _enrollmentLabel(p.enrollmentStatus)),
        _row('Current class', p.summary.className),
        _row('Admission number', p.admissionNo),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Action type', border: OutlineInputBorder()),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _lifecycleAction, items: [for (final item in principalStudentLifecycleActions) DropdownMenuItem(value: item, child: Text(item))], onChanged: (value) => setState(() => _lifecycleAction = value ?? _lifecycleAction))),
        ),
        const SizedBox(height: 10),
        TextField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Next class / destination', hintText: 'e.g. JSS 3A or receiving school', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Effective session', border: OutlineInputBorder()),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: _effectiveSession, items: const [DropdownMenuItem(value: '2026/2027', child: Text('2026/2027')), DropdownMenuItem(value: '2027/2028', child: Text('2027/2028'))], onChanged: (value) => setState(() => _effectiveSession = value ?? _effectiveSession))),
        ),
        const SizedBox(height: 10),
        TextField(controller: _reasonController, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason / approval context', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _savingLifecycle ? null : _saveLifecycle, icon: const Icon(Icons.approval_outlined), label: Text(_savingLifecycle ? 'Saving…' : 'Create governed proposal')),
        const SizedBox(height: 10),
        Text(principalStudentLifecycleBoundary, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _documents(BuildContext context, PrincipalStudentProfile p) => _card('Documents & records', 'This profile shows document labels and role visibility, not unrestricted file contents.', [
        for (final doc in p.documents) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.description_outlined), title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(doc.visibility), trailing: Text(doc.status)),
      ]);

  Widget _timeline(BuildContext context, PrincipalStudentProfile p) => _card('Student timeline', 'Important events across learning, attendance and school life.', [
        for (final item in p.timeline) ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text(item.date.split(' ').first)), title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${item.detail}\n${item.visibility}')),
      ]);

  Widget _notes(BuildContext context) => _card('Leadership note', 'Internal professional note. Not automatically visible to parents or students.', [
        TextField(controller: _noteController, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Add factual follow-up, support or intervention context', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: _savingNote ? null : _saveNote, icon: const Icon(Icons.save_outlined), label: Text(_savingNote ? 'Saving…' : 'Save leadership note')),
        const SizedBox(height: 10),
        Text(principalStudentNoteBoundary, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _sideCard(BuildContext context, PrincipalStudentProfile p) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('STUDENT ID PREVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            CircleAvatar(radius: 34, child: Text(_initials(p.summary.name), style: const TextStyle(fontWeight: FontWeight.w900))),
            const SizedBox(height: 10),
            Text(p.summary.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(p.admissionNo),
            Text(p.summary.className),
            const Divider(height: 24),
            _row('Average', '${p.summary.average}%'),
            _row('Attendance', '${p.summary.attendance}%'),
            _row('Trend', '${p.summary.trend > 0 ? '+' : ''}${p.summary.trend}%'),
            _row('Incidents', '${p.summary.incidents}'),
            _row('Interventions', '${p.summary.interventions}'),
            const SizedBox(height: 8),
            Text('Stable admission identifier; not reused after withdrawal, transfer or graduation.', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _metric(String label, int value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(label)), Text('$value%', style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 5), LinearProgressIndicator(value: value / 100)]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 150, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(value))]),
      );

  String _enrollmentLabel(PrincipalStudentEnrollmentStatus status) => switch (status) {
        PrincipalStudentEnrollmentStatus.active => 'Active',
        PrincipalStudentEnrollmentStatus.transferPending => 'Transfer pending',
        PrincipalStudentEnrollmentStatus.withdrawn => 'Withdrawn',
        PrincipalStudentEnrollmentStatus.alumni => 'Alumni',
      };

  String _initials(String name) => name.split(' ').where((part) => part.isNotEmpty).take(2).map((part) => part[0]).join().toUpperCase();
}
