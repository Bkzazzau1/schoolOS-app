import 'package:flutter/material.dart';

import '../data/administrator_lifecycle_repository.dart';
import '../domain/administrator_students_models.dart';

class LifecycleRequestChoice {
  const LifecycleRequestChoice({
    required this.student,
    required this.workflow,
    required this.toClass,
    required this.note,
  });

  final AdministratorStudentRecord student;
  final String workflow;
  final String toClass;
  final String note;
}

Future<LifecycleRequestChoice?> askLifecycleRequest(
  BuildContext context,
  List<AdministratorStudentRecord> students,
) =>
    showDialog<LifecycleRequestChoice>(
      context: context,
      builder: (context) => _RequestDialog(students: students),
    );

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.students});

  final List<AdministratorStudentRecord> students;

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _toClass = TextEditingController();
  final _note = TextEditingController();
  AdministratorStudentRecord? _student;
  String _workflow = AdministratorLifecycleRepository.requestable.first;

  @override
  void dispose() {
    _toClass.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _needsDestination =>
      _workflow == 'Class change' || _workflow == 'Promotion';

  @override
  Widget build(BuildContext context) {
    final ready = _student != null &&
        (!_needsDestination || _toClass.text.trim().isNotEmpty);
    return AlertDialog(
      title: const Text('New student progression / lifecycle change'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AdministratorStudentRecord>(
                key: const ValueKey('lifecycle-student'),
                initialValue: _student,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: [
                  for (final s in widget.students)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        '${s.name} · ${s.className}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _student = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: const ValueKey('lifecycle-workflow'),
                initialValue: _workflow,
                decoration: const InputDecoration(labelText: 'What is changing'),
                items: [
                  for (final w in AdministratorLifecycleRepository.requestable)
                    DropdownMenuItem(value: w, child: Text(w)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _workflow = v;
                    if (!_needsDestination) _toClass.clear();
                  });
                },
              ),
              if (_workflow == 'Repeat') ...[
                const SizedBox(height: 10),
                const Text(
                  'Repeat keeps the pupil in the same class for a new enrollment period. It is an academic progression decision and requires academic approval before completion.',
                ),
              ],
              if (_needsDestination) ...[
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('lifecycle-to-class'),
                  controller: _toClass,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Moves to which class',
                    hintText: 'For example JSS 2A',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('lifecycle-note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: _workflow == 'Transfer out'
                      ? 'Where the student is going (optional)'
                      : 'Note (optional)',
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
          key: const ValueKey('lifecycle-start'),
          onPressed: ready
              ? () => Navigator.pop(
                    context,
                    LifecycleRequestChoice(
                      student: _student!,
                      workflow: _workflow,
                      toClass: _toClass.text.trim(),
                      note: _note.text.trim(),
                    ),
                  )
              : null,
          child: const Text('Start change'),
        ),
      ],
    );
  }
}

Future<String?> askApprover(
  BuildContext context, {
  required String studentName,
  required String workflow,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ApproverDialog(
        studentName: studentName,
        workflow: workflow,
      ),
    );

class _ApproverDialog extends StatefulWidget {
  const _ApproverDialog({
    required this.studentName,
    required this.workflow,
  });

  final String studentName;
  final String workflow;

  @override
  State<_ApproverDialog> createState() => _ApproverDialogState();
}

class _ApproverDialogState extends State<_ApproverDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Process ${widget.workflow.toLowerCase()} for ${widget.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.workflow} is an academic decision. Administration only processes it once academic leadership has approved it.',
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('lifecycle-approver'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Approved by (name and role)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('lifecycle-approver-confirm'),
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _name.text.trim()),
            child: Text('Process ${widget.workflow.toLowerCase()}'),
          ),
        ],
      );
}
