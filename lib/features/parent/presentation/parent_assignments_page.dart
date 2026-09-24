import 'package:flutter/material.dart';

import '../data/parent_assignments_repository.dart';

class ParentAssignmentsPage extends StatefulWidget {
  const ParentAssignmentsPage({super.key, required this.repository});

  final ParentAssignmentsRepository repository;

  @override
  State<ParentAssignmentsPage> createState() => _ParentAssignmentsPageState();
}

class _ParentAssignmentsPageState extends State<ParentAssignmentsPage> {
  late Future<List<ParentAssignment>> _future;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  bool _matches(ParentAssignment assignment) => switch (_filter) {
        'open' => assignment.state == 'published',
        'graded' => assignment.recipients.any(
            (recipient) => assignment.submissionFor(recipient.studentId)?.state == 'graded',
          ),
        'attention' => assignment.recipients.any((recipient) {
            final submission = assignment.submissionFor(recipient.studentId);
            return submission == null ||
                submission.state == 'returned' ||
                submission.isLate;
          }),
        _ => true,
      };

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ParentAssignment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load family assignments.'));
          }
          final all = snapshot.data!;
          final assignments = all.where(_matches).toList(growable: false);
          final linked = <String>{
            for (final assignment in all)
              for (final recipient in assignment.recipients) recipient.studentId,
          };
          final graded = all.fold<int>(
            0,
            (sum, assignment) =>
                sum + assignment.submissions.where((item) => item.state == 'graded').length,
          );
          final returned = all.fold<int>(
            0,
            (sum, assignment) =>
                sum + assignment.submissions.where((item) => item.state == 'returned').length,
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'FAMILY PORTAL · ASSIGNMENTS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Assignments',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                'Read-only visibility for school-issued work sent to your linked children. Private Student drafts are never shown here.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Kpi(label: 'Linked recipients', value: '${linked.length}'),
                  _Kpi(
                    label: 'Open assignments',
                    value: '${all.where((item) => item.state == 'published').length}',
                  ),
                  _Kpi(label: 'Graded responses', value: '$graded'),
                  _Kpi(label: 'Returned for revision', value: '$returned'),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in const [
                    ('all', 'All'),
                    ('open', 'Open'),
                    ('attention', 'Needs attention'),
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
              if (assignments.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('No linked-child assignments match this view.'),
                  ),
                )
              else
                for (final assignment in assignments) ...[
                  _AssignmentCard(assignment: assignment),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Family boundary: this screen receives only recipient snapshots for children linked to this guardian account. It never exposes another learner, the class recipient roster, or unfinished Student drafts.',
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final ParentAssignment assignment;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text('${assignment.className} · ${assignment.subject} · ${_typeLabel(assignment.type)}'),
                    ],
                  ),
                  Chip(label: Text(assignment.state == 'closed' ? 'Closed' : 'Open')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Due ${_dateLabel(assignment.dueAt)} · ${assignment.maximumScore} marks · publication revision ${assignment.publicationRevision}',
              ),
              if (assignment.topic.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Topic: ${assignment.topic}'),
              ],
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w800)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(assignment.instructions),
                    ),
                  ),
                ],
              ),
              const Divider(),
              for (final recipient in assignment.recipients) ...[
                _RecipientRow(
                  recipient: recipient,
                  submission: assignment.submissionFor(recipient.studentId),
                  maximumScore: assignment.maximumScore,
                ),
                if (recipient != assignment.recipients.last) const Divider(height: 12),
              ],
            ],
          ),
        ),
      );

  static String _typeLabel(String value) => switch (value) {
        'classwork' => 'Classwork',
        'project' => 'Project',
        'revision' => 'Revision',
        _ => 'Homework',
      };

  static String _dateLabel(String raw) {
    final value = DateTime.tryParse(raw);
    if (value == null) return raw.isEmpty ? '—' : raw;
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.submission,
    required this.maximumScore,
  });

  final ParentAssignmentRecipient recipient;
  final ParentAssignmentSubmission? submission;
  final int maximumScore;

  @override
  Widget build(BuildContext context) {
    final item = submission;
    final status = item == null
        ? 'Not submitted'
        : switch (item.state) {
            'returned' => 'Returned for revision',
            'graded' => 'Graded',
            _ => 'Submitted',
          };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
      title: Text(recipient.studentName, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        [
          recipient.admissionNumber,
          status,
          if (item?.isLate == true) 'Late',
          if (item?.score != null) 'Score ${item!.score}/$maximumScore',
          if (item?.feedback.isNotEmpty == true) 'Feedback: ${item!.feedback}',
        ].where((value) => value.isNotEmpty).join(' · '),
      ),
      trailing: Chip(label: Text(status)),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 190,
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
