import 'package:flutter/material.dart';

import '../data/teacher_assignment_demo_data.dart';
import '../data/teacher_assignment_repository.dart';
import '../domain/teacher_assignment_models.dart';

class TeacherAssignmentsPage extends StatefulWidget {
  const TeacherAssignmentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherAssignmentRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  late Future<TeacherAssignmentSnapshot> _future;
  TeacherAssignmentSnapshot? _snapshot;
  TeacherAssignment? _draft;
  String _query = '';
  String? _notice;
  bool _noticeSuccess = false;
  bool _busy = false;

  final _title = TextEditingController();
  final _instructions = TextEditingController();
  final _dueDate = TextEditingController();
  final _maximumScore = TextEditingController();
  TeacherAssignmentType _type = TeacherAssignmentType.homework;
  String _classSubjectId = '';
  String _topicId = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void dispose() {
    _title.dispose();
    _instructions.dispose();
    _dueDate.dispose();
    _maximumScore.dispose();
    super.dispose();
  }

  void _hydrate(TeacherAssignmentSnapshot snapshot, {bool force = false}) {
    if (_snapshot != null && !force) return;
    _snapshot = snapshot;
    _draft = snapshot.draft;
    _title.text = snapshot.draft.title;
    _instructions.text = snapshot.draft.instructions;
    _dueDate.text = snapshot.draft.dueDate;
    _maximumScore.text = '${snapshot.draft.maximumScore}';
    _type = snapshot.draft.type;
    _classSubjectId = snapshot.draft.classSubjectId;
    _topicId = snapshot.draft.topicId;
  }

  Future<void> _reload({bool resetEditor = false}) async {
    final snapshot = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _snapshot = null;
      _hydrate(snapshot, force: true);
      _future = Future.value(snapshot);
      if (resetEditor) {
        _draft = snapshot.draft;
      }
    });
  }

  TeacherAssignmentOption? get _selectedOption {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final option in snapshot.options) {
      if (option.classSubjectId == _classSubjectId) return option;
    }
    return null;
  }

  TeacherAssignment _editorDraft() {
    final current = _draft ?? _snapshot!.draft;
    final option = _selectedOption;
    return current.copyWith(
      title: _title.text.trim(),
      className: option?.className ?? current.className,
      subject: option?.subject ?? current.subject,
      classSubjectId: option?.classSubjectId ?? current.classSubjectId,
      termId: option?.termId ?? current.termId,
      term: option?.term ?? current.term,
      topicId: _topicId,
      topic: option?.topics
              .where((item) => item.id == _topicId)
              .map((item) => item.title)
              .firstOrNull ??
          '',
      type: _type,
      instructions: _instructions.text.trim(),
      dueDate: _dueDate.text.trim(),
      maximumScore: int.tryParse(_maximumScore.text) ?? 0,
    );
  }

  Future<void> _act(
    Future<TeacherAssignmentActionResult> Function() action, {
    bool resetEditor = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) return;
      setState(() {
        _notice = result.message;
        _noticeSuccess = result.success;
        if (result.assignment != null) _draft = result.assignment;
      });
      if (result.success) {
        widget.onMutationQueued();
        await _reload(resetEditor: resetEditor);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDraft() =>
      _act(() => widget.repository.saveDraft(_editorDraft()));

  Future<void> _publish() => _act(
        () => widget.repository.queuePublication(_editorDraft()),
        resetEditor: true,
      );

  void _generateWithAi() {
    setState(() {
      _instructions.text = teacherAssignmentAiInstruction;
      _notice =
          'Teacher AI draft inserted. Review it before saving; AI does not publish or grade work.';
      _noticeSuccess = true;
    });
  }

  Future<void> _revise(TeacherAssignment assignment) async {
    final title = TextEditingController(text: assignment.title);
    final instructions = TextEditingController(text: assignment.instructions);
    final dueAt = TextEditingController(text: assignment.dueDate);
    final revised = await showDialog<TeacherAssignment>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revise published assignment'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Recipient roster, subject, type, topic and maximum score stay frozen. This creates a new learner-facing revision only after server acknowledgement.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructions,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueAt,
                  decoration: const InputDecoration(
                    labelText: 'Due date/time (ISO 8601)',
                    hintText: '2026-09-30T16:00:00+01:00',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              assignment.copyWith(
                title: title.text.trim(),
                instructions: instructions.text.trim(),
                dueDate: dueAt.text.trim(),
              ),
            ),
            child: const Text('Queue revision'),
          ),
        ],
      ),
    );
    title.dispose();
    instructions.dispose();
    dueAt.dispose();
    if (revised != null) {
      await _act(() => widget.repository.revise(revised));
    }
  }

  Future<void> _close(TeacherAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close assignment?'),
        content: const Text(
          'Closing stops new Student submissions and preserves the assignment as historical evidence.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Queue closure'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _act(() => widget.repository.close(assignment));
    }
  }

  Future<void> _mark(TeacherAssignmentSubmission submission) async {
    final score = TextEditingController(
      text: submission.score == null ? '' : '${submission.score}',
    );
    final feedback = TextEditingController(text: submission.feedback);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${submission.studentName} · ${submission.title}'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${submission.className} · ${submission.subject} · ${teacherSubmissionStateLabel(submission.state)}${submission.isLate ? ' · Late' : ''}',
                ),
                const SizedBox(height: 12),
                SelectableText(submission.responseText),
                const SizedBox(height: 16),
                TextField(
                  controller: score,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Score / ${submission.maximumScore}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feedback,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Teacher feedback',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'return'),
            child: const Text('Return for revision'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'grade'),
            child: const Text('Queue grade'),
          ),
        ],
      ),
    );
    if (action == 'grade') {
      final value = double.tryParse(score.text.trim());
      if (value == null) {
        setState(() {
          _notice = 'Enter a valid numeric score before grading.';
          _noticeSuccess = false;
        });
      } else {
        await _act(
          () => widget.repository.gradeSubmission(
            submission,
            score: value,
            feedback: feedback.text,
          ),
        );
      }
    } else if (action == 'return') {
      await _act(
        () => widget.repository.returnSubmission(
          submission,
          feedback: feedback.text,
        ),
      );
    }
    score.dispose();
    feedback.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherAssignmentSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Unable to load assignments.'));
        }
        _hydrate(snapshot.data!);
        final data = _snapshot ?? snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(onNavigate: widget.onNavigate),
                      if (_notice != null) ...[
                        const SizedBox(height: 14),
                        _Notice(message: _notice!, success: _noticeSuccess),
                      ],
                      const SizedBox(height: 18),
                      _kpis(data, wide),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _editorCard(data)),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _markingCard(data)),
                          ],
                        )
                      else ...[
                        _editorCard(data),
                        const SizedBox(height: 16),
                        _markingCard(data),
                      ],
                      const SizedBox(height: 18),
                      _libraryCard(data),
                      const SizedBox(height: 18),
                      _boundaries(),
                    ],
                  ),
                ),
                if (_busy)
                  const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
              ],
            );
          },
        );
      },
    );
  }

  Widget _kpis(TeacherAssignmentSnapshot data, bool wide) {
    final published = data.assignments.where((item) => item.serverPublished).toList();
    final submitted = published.fold<int>(0, (sum, item) => sum + item.submissions);
    final recipients = published.fold<int>(0, (sum, item) => sum + item.totalStudents);
    final unmarked = data.submissions.where((item) => item.state == TeacherSubmissionState.submitted).length;
    final late = published.fold<int>(0, (sum, item) => sum + item.lateSubmissions);
    final rate = recipients == 0 ? 0 : ((submitted / recipients) * 100).round();
    final values = <(String, String, String)>[
      ('Published', '${published.length}', 'Server-confirmed assignments'),
      ('Pending marking', '$unmarked', 'Submitted learner responses'),
      ('Submission rate', '$rate%', '$submitted of $recipients recipients'),
      ('Late submissions', '$late', 'Server-derived timestamps'),
    ];
    return GridView.count(
      crossAxisCount: wide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: wide ? 2.1 : 1.5,
      children: [
        for (final item in values)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$1),
                  Text(item.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text(item.$3, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _editorCard(TeacherAssignmentSnapshot data) {
    final draft = _draft ?? data.draft;
    final editable = draft.state == TeacherAssignmentState.draft && !draft.pendingSync;
    final options = data.options;
    final selected = _selectedOption;
    final topics = selected?.topics ?? const <TeacherAssignmentTopic>[];
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create assignment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Draft against one canonical class-subject and active term.'),
                    ],
                  ),
                ),
                Chip(label: Text(data.canonical ? 'CANONICAL' : 'DEMO')),
              ],
            ),
            const SizedBox(height: 14),
            if (data.canonical && options.isEmpty)
              const _InfoBox(
                title: 'No current Teaching Assignment',
                body: 'This Teacher membership has no active canonical class-subject to receive assignment authoring authority.',
              )
            else ...[
              if (data.canonical)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: options.any((item) => item.classSubjectId == _classSubjectId)
                      ? _classSubjectId
                      : null,
                  decoration: const InputDecoration(labelText: 'Class · Subject', border: OutlineInputBorder()),
                  items: [
                    for (final option in options)
                      DropdownMenuItem(value: option.classSubjectId, child: Text('${option.label} · ${option.term}')),
                  ],
                  onChanged: editable
                      ? (value) => setState(() {
                            _classSubjectId = value ?? '';
                            _topicId = '';
                          })
                      : null,
                )
              else
                Text('Class: ${draft.className}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<TeacherAssignmentType>(
                      isExpanded: true,
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: [
                        for (final item in TeacherAssignmentType.values)
                          DropdownMenuItem(value: item, child: Text(teacherAssignmentTypeLabel(item))),
                      ],
                      onChanged: editable ? (value) => setState(() => _type = value!) : null,
                    ),
                  ),
                  if (topics.isNotEmpty)
                    SizedBox(
                      width: 300,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: topics.any((item) => item.id == _topicId) ? _topicId : '',
                        decoration: const InputDecoration(labelText: 'Curriculum topic (optional)', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('No linked topic')),
                          for (final topic in topics)
                            DropdownMenuItem(value: topic.id, child: Text(topic.title)),
                        ],
                        onChanged: editable ? (value) => setState(() => _topicId = value ?? '') : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: editable,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructions,
                enabled: editable,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 290,
                    child: TextField(
                      controller: _dueDate,
                      enabled: editable,
                      decoration: const InputDecoration(
                        labelText: 'Due date/time (ISO 8601)',
                        hintText: '2026-09-30T16:00:00+01:00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: _maximumScore,
                      enabled: editable,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Maximum score', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: editable ? _generateWithAi : null,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Draft with Teacher AI'),
                  ),
                  OutlinedButton(onPressed: editable ? _saveDraft : null, child: const Text('Save draft')),
                  FilledButton(onPressed: editable ? _publish : null, child: const Text('Publish assignment')),
                ],
              ),
              if (draft.pendingSync) ...[
                const SizedBox(height: 10),
                const Text(
                  'Queued locally · not server-acknowledged. Sync before the next lifecycle action.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _markingCard(TeacherAssignmentSnapshot data) {
    final queue = data.submissions
        .where((item) => item.state == TeacherSubmissionState.submitted || item.state == TeacherSubmissionState.graded)
        .toList(growable: false);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Marking queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                Chip(label: Text('${queue.where((item) => item.state == TeacherSubmissionState.submitted).length} pending')),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Only Student-submitted work is visible here; private drafts are excluded.'),
            const SizedBox(height: 12),
            if (queue.isEmpty)
              const Text('No submitted work is waiting for review.')
            else
              for (final submission in queue.take(8)) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(submission.studentName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                    '${submission.title} · ${submission.isLate ? 'Late · ' : ''}${teacherSubmissionStateLabel(submission.state)}${submission.pendingSync ? ' · sync pending' : ''}',
                  ),
                  trailing: TextButton(
                    onPressed: submission.pendingSync ? null : () => _mark(submission),
                    child: Text(submission.state == TeacherSubmissionState.graded ? 'Review' : 'Mark'),
                  ),
                ),
                const Divider(height: 1),
              ],
            const SizedBox(height: 14),
            const _InfoBox(
              title: 'Teacher confirms every mark',
              body: 'AI may assist with suggestions, but the server accepts only an explicit Teacher grade or return-for-revision action.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _libraryCard(TeacherAssignmentSnapshot data) {
    final filtered = data.assignments.where((item) => item.matches(_query)).toList(growable: false);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assignment library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('Canonical publication, recipient and marking evidence.'),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No assignments match this view.')),
              )
            else
              for (final assignment in filtered)
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ListTile(
                      title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        '${assignment.className} · ${assignment.subject.isEmpty ? teacherAssignmentTypeLabel(assignment.type) : assignment.subject} · Due ${_dateLabel(assignment.dueDate)}\n'
                        '${assignment.submissions}/${assignment.totalStudents} submitted · ${assignment.marked} graded · ${assignment.lateSubmissions} late · revision ${assignment.publicationRevision}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(label: Text(teacherAssignmentStateLabel(assignment.state))),
                          if (assignment.canRevise)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'revise') _revise(assignment);
                                if (value == 'close') _close(assignment);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'revise', child: Text('Create revision')),
                                PopupMenuItem(value: 'close', child: Text('Close assignment')),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _boundaries() => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assignment controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              SizedBox(height: 10),
              Text(teacherAssignmentPublishBoundary),
              SizedBox(height: 8),
              Text(teacherAssignmentMarkingBoundary),
              SizedBox(height: 8),
              Text(teacherAssignmentEvidenceBoundary),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate});
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TEACHER · ASSIGNMENTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              Text('Assignments', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Text('Create, publish, collect, return and grade school-issued work.'),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => onNavigate('classes'), child: const Text('My Classes')),
              OutlinedButton(onPressed: () => onNavigate('dashboard'), child: const Text('Dashboard')),
            ],
          ),
        ],
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.success});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body),
          ],
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
