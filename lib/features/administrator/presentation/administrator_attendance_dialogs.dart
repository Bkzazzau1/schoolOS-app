import 'package:flutter/material.dart';

import '../domain/administrator_students_models.dart';

/// Asks which student. Used to check a student in by hand and to identify a scan the device could not match.
/// Returns null when cancelled.
Future<AdministratorStudentRecord?> askStudent(
  BuildContext context, {
  required String title,
  required String action,
  required List<AdministratorStudentRecord> students,
  String? explanation,
}) =>
    showDialog<AdministratorStudentRecord>(
      context: context,
      builder: (context) => _StudentDialog(title: title, action: action, students: students, explanation: explanation),
    );

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({required this.title, required this.action, required this.students, this.explanation});

  final String title;
  final String action;
  final List<AdministratorStudentRecord> students;
  final String? explanation;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  AdministratorStudentRecord? _student;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.explanation != null) ...[Text(widget.explanation!), const SizedBox(height: 12)],
              if (widget.students.isEmpty)
                const Text('Every student already has an attendance record today.')
              else
                DropdownButtonFormField<AdministratorStudentRecord>(
                  key: const ValueKey('attendance-student'),
                  initialValue: _student,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: [
                    for (final s in widget.students)
                      DropdownMenuItem(value: s, child: Text('${s.name} · ${s.className}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _student = v),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('attendance-student-confirm'),
            onPressed: _student == null ? null : () => Navigator.pop(context, _student),
            child: Text(widget.action),
          ),
        ],
      );
}
