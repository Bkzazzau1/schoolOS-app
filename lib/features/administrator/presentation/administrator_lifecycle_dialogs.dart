import 'package:flutter/material.dart';

import '../data/administrator_lifecycle_repository.dart';
import '../domain/administrator_students_models.dart';

// Each dialog owns and disposes its own text boxes (disposing them from the caller is too early, while the dialog fades).

class LifecycleRequestChoice {
  const LifecycleRequestChoice({required this.student, required this.workflow, required this.toClass, required this.note});

  final AdministratorStudentRecord student;
  final String workflow;
  final String toClass;
  final String note;
}

/// Asks which student, what kind of change, and where they move to. Returns null when cancelled.
Future<LifecycleRequestChoice?> askLifecycleRequest(BuildContext context, List<AdministratorStudentRecord> students) =>
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

  bool get _movesClass => _workflow != 'Transfer out';

  @override
  Widget build(BuildContext context) {
    final ready = _student != null && (!_movesClass || _toClass.text.trim().isNotEmpty);
    return AlertDialog(
      title: const Text('New student change'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                    DropdownMenuItem(value: s, child: Text('${s.name} · ${s.className}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _student = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('lifecycle-workflow'),
                initialValue: _workflow,
                decoration: const InputDecoration(labelText: 'What is changing'),
                items: [
                  for (final w in AdministratorLifecycleRepository.requestable) DropdownMenuItem(value: w, child: Text(w)),
                ],
                onChanged: (v) => setState(() => _workflow = v ?? _workflow),
              ),
              if (_movesClass) ...[
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('lifecycle-to-class'),
                  controller: _toClass,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Moves to which class', hintText: 'For example JSS 2A'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('lifecycle-note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: _movesClass ? 'Note (optional)' : 'Where the student is going (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('lifecycle-start'),
          onPressed: ready
              ? () => Navigator.pop(
                    context,
                    LifecycleRequestChoice(student: _student!, workflow: _workflow, toClass: _toClass.text.trim(), note: _note.text.trim()),
                  )
              : null,
          child: const Text('Start change'),
        ),
      ],
    );
  }
}

/// Asks who approved a promotion. Returns null when cancelled, otherwise a non-empty name.
Future<String?> askApprover(BuildContext context, {required String studentName}) => showDialog<String>(
      context: context,
      builder: (context) => _ApproverDialog(studentName: studentName),
    );

class _ApproverDialog extends StatefulWidget {
  const _ApproverDialog({required this.studentName});

  final String studentName;

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
        title: Text('Process promotion for ${widget.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A promotion is an academic decision. Administration only processes it once academic leadership has approved it.',
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('lifecycle-approver'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Approved by (name and role)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('lifecycle-approver-confirm'),
            onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, _name.text.trim()),
            child: const Text('Process promotion'),
          ),
        ],
      );
}
