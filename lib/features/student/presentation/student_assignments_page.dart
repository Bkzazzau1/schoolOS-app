import 'package:flutter/material.dart';

import '../data/student_assignment_repository.dart';

class StudentAssignmentsPage extends StatefulWidget {
  const StudentAssignmentsPage({
    super.key,
    required this.repository,
    required this.onMutationQueued,
  });

  final StudentAssignmentRepository repository;
  final VoidCallback onMutationQueued;

  @override
  State<StudentAssignmentsPage> createState() => _StudentAssignmentsPageState();
}

class _StudentAssignmentsPageState extends State<StudentAssignmentsPage> {
  late Future<List<StudentAssignmentItem>> _future;
  String? _notice;
  bool _noticeSuccess = false;
  bool _busy = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  Future<void> _reload() async {
    final items = await widget.repository.load();
    if (!mounted) return;
    setState(() => _future = Future.value(items));
  }

  Future<void> _open(StudentAssignmentItem item) async {
    final assignment = item.assignment;
    final existing = item.submission;
    final response = TextEditingController(text: existing?.responseText ?? '');
    final canEdit = assignment.open && (existing?.canEdit ?? true);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(assignment.title),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${assignment.className} · ${assignment.subject} · ${_typeLabel(assignment.type)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('Due ${_dateLabel(assignment.dueAt)} · ${assignment.maximumScore} marks · revision ${assignment.publicationRevision}'),
                if (assignment.topic.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Curriculum topic: ${assignment.topic}'),
                ],
                const Divider(height: 24),
                const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                SelectableText(assignment.instructions),
                const SizedBox(height: 16),
                TextField(
                  controller: response,
                  enabled: canEdit,
                  minLines: 7,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'My response',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 12),
                  _SubmissionEvidence(submission: existing),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canEdit)
            OutlinedButton(
              onPressed: () => Navigator.pop(context, 'draft'),
              child: const Text('Save draft'),
            ),
          if (canEdit)
            FilledButton(
              onPressed: () => Navigator.pop(context, 'submit'),
              child: Text(existing?.state == StudentAssignmentSubmissionState.returned ? 'Resubmit' : 'Submit'),
            ),
        ],
      ),
    );

    if (action == null) {
      response.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final result = action == 'submit'
          ? await widget.repository.submit(assignment, response.text)
          : await widget.repository.saveDraft(assignment, response.text);
      if (!mounted) return;
      setState(() {
        _notice = result.message;
        _noticeSuccess = result.success;
      });
      if (result.success) {
        widget.onMutationQueued();
        await _reload();
      }
    } finally {
      response.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _matchesFilter(StudentAssignmentItem item) {
    final submission = item.submission;
    return switch (_filter) {
      'todo' => item.assignment.open &&
          (submission == null ||
              submission.state == StudentAssignmentSubmissionState.draft ||
              submission.state == StudentAssignmentSubmissionState.returned),
      'submitted' => submission?.state == StudentAssignmentSubmissionState.submitted ||
          submission?.state == StudentAssignmentSubmissionState.queued,
      'graded' => submission?.state == StudentAssignmentSubmissionState.graded,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentAssignmentItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Could not load school assignments.'));
        }
        final all = snapshot.data!;
        final items = all.where(_matchesFilter).toList(growable: false);
        final due = all.where((item) => _matchesFilterForTodo(item)).length;
        final submitted = all.where((item) {
          final state = item.submission?.state;
          return state == StudentAssignmentSubmissionState.submitted ||
              state == StudentAssignmentSubmissionState.queued;
        }).length;
        final graded = all.where((item) => item.submission?.state == StudentAssignmentSubmissionState.graded).length;
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Text(
                  'STUDENT PORTAL · ASSIGNMENTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                ),
                const SizedBox(height: 5),
                const Text('School assignments', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  'Teacher-issued classwork and homework. This is separate from your private Study Plan.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (_notice != null) ...[
                  const SizedBox(height: 14),
                  _Notice(message: _notice!, success: _noticeSuccess),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Kpi(label: 'To do / revise', value: '$due'),
                    _Kpi(label: 'Submitted / queued', value: '$submitted'),
                    _Kpi(label: 'Graded', value: '$graded'),
                    _Kpi(label: 'Published to me', value: '${all.length}'),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in const [
                      ('all', 'All'),
                      ('todo', 'To do'),
                      ('submitted', 'Submitted'),
                      ('graded', 'Graded'),
                    ])
                      ChoiceChip(
                        label: Text(filter.$2),
                        selected: _filter == filter.$1,
                        onSelected: (_) => setState(() => _filter = filter.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        all.isEmpty
                            ? 'No Teacher assignment has been published to your frozen recipient roster yet.'
                            : 'No assignments match this filter.',
                      ),
                    ),
                  )
                else
                  for (final item in items) ...[
                    _AssignmentCard(item: item, onOpen: () => _open(item)),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 8),
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Offline rule: saving or submitting on this device creates queued work. “Queued” never means the school server received it. Server-confirmed submission time determines whether work is late.',
                    ),
                  ),
                ),
              ],
            ),
            if (_busy)
              const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
          ],
        );
      },
    );
  }

  bool _matchesFilterForTodo(StudentAssignmentItem item) {
    final state = item.submission?.state;
    return item.assignment.open &&
        (state == null ||
            state == StudentAssignmentSubmissionState.draft ||
            state == StudentAssignmentSubmissionState.returned);
  }

  String _dateLabel(String raw) {
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String raw) => switch (raw) {
        'classwork' => 'Classwork',
        'project' => 'Project',
        'revision' => 'Revision',
        _ => 'Homework',
      };
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.item, required this.onOpen});
  final StudentAssignmentItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final assignment = item.assignment;
    final submission = item.submission;
    final label = submission == null
        ? (assignment.open ? 'Not started' : 'Closed')
        : _submissionLabel(submission.state);
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(assignment.open ? Icons.assignment_outlined : Icons.inventory_2_outlined),
        ),
        title: Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${assignment.className} · ${assignment.subject}\nDue ${_date(assignment.dueAt)} · ${assignment.maximumScore} marks${submission?.isLate == true ? ' · Late' : ''}',
        ),
        isThreeLine: true,
        trailing: Chip(label: Text(label)),
        onTap: onOpen,
      ),
    );
  }

  static String _submissionLabel(StudentAssignmentSubmissionState state) => switch (state) {
        StudentAssignmentSubmissionState.draft => 'Draft',
        StudentAssignmentSubmissionState.queued => 'Queued',
        StudentAssignmentSubmissionState.submitted => 'Submitted',
        StudentAssignmentSubmissionState.returned => 'Returned',
        StudentAssignmentSubmissionState.graded => 'Graded',
      };

  static String _date(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) return raw.isEmpty ? '—' : raw;
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _SubmissionEvidence extends StatelessWidget {
  const _SubmissionEvidence({required this.submission});
  final StudentAssignmentSubmission submission;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = switch (submission.state) {
      StudentAssignmentSubmissionState.draft => 'Private draft${submission.pendingSync ? ' · sync pending' : ''}',
      StudentAssignmentSubmissionState.queued => 'Queued · not server-acknowledged',
      StudentAssignmentSubmissionState.submitted => 'Server-confirmed submitted',
      StudentAssignmentSubmissionState.returned => 'Returned for revision',
      StudentAssignmentSubmissionState.graded => 'Graded',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (submission.submittedAt != null) Text('Submitted: ${submission.submittedAt}'),
          if (submission.isLate) const Text('Late status: server-derived'),
          if (submission.feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Teacher feedback: ${submission.feedback}'),
          ],
          if (submission.score != null)
            Text('Score: ${submission.score}'),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
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
