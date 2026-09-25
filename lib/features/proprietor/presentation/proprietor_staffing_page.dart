import 'package:flutter/material.dart';

import '../../principal/domain/class_teacher_models.dart';
import '../../principal/domain/principal_assignments_models.dart';
import '../data/proprietor_staffing_repository.dart';

class ProprietorStaffingPage extends StatefulWidget {
  const ProprietorStaffingPage({
    super.key,
    required this.repository,
    this.onMutationQueued,
  });

  final ProprietorStaffingRepository repository;
  final VoidCallback? onMutationQueued;

  @override
  State<ProprietorStaffingPage> createState() => _ProprietorStaffingPageState();
}

class _ProprietorStaffingPageState extends State<ProprietorStaffingPage> {
  late Future<ProprietorStaffingSnapshot> _future;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  void _report(ProprietorStaffingActionResult result) {
    if (!mounted) return;
    setState(() {
      _notice = result.message;
      _noticeSuccess = result.success;
    });
    if (result.success) {
      widget.onMutationQueued?.call();
      _reload();
    }
  }

  Future<void> _addAssignment(ProprietorStaffingSnapshot snapshot) async {
    final unassigned = snapshot.unassigned;
    if (unassigned.isEmpty || snapshot.teachers.isEmpty) return;
    final picked = await showDialog<(PrincipalUnassignedSubject, PrincipalAssignmentTeacher)>(
      context: context,
      builder: (context) => _AssignDialog(unassigned: unassigned, teachers: snapshot.teachers),
    );
    if (picked == null) return;
    final (subject, teacher) = picked;
    _report(await widget.repository.addAssignment(
      className: subject.className,
      subject: subject.subject,
      teacherId: teacher.id,
      periodsPerWeek: subject.periods,
    ));
  }

  Future<void> _transfer(ProprietorStaffingSnapshot snapshot, PrincipalTeachingAssignment assignment) async {
    final others = snapshot.teachers.where((t) => t.id != assignment.teacherId).toList();
    if (others.isEmpty) return;
    final result = await showDialog<(PrincipalAssignmentTeacher, String)>(
      context: context,
      builder: (context) => _TransferDialog(assignment: assignment, teachers: others),
    );
    if (result == null) return;
    final (teacher, reason) = result;
    _report(await widget.repository.transferAssignment(
      assignmentId: assignment.id,
      newTeacherId: teacher.id,
      reason: reason,
    ));
  }

  Future<void> _assignClassTeacher(ProprietorStaffingSnapshot snapshot, String classId, String className, String section) async {
    final teacher = await showDialog<PrincipalAssignmentTeacher>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Class teacher for $className'),
        children: [
          for (final teacher in snapshot.teachers)
            SimpleDialogOption(onPressed: () => Navigator.of(context).pop(teacher), child: Text(teacher.name)),
          if (snapshot.teachers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('No teacher with a linked account is available yet.'),
            ),
        ],
      ),
    );
    if (teacher == null) return;
    _report(await widget.repository.assignClassTeacher(
      classId: classId,
      className: className,
      section: section,
      teacherId: teacher.id,
      teacherName: teacher.name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProprietorStaffingSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load staffing.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        if (!data.permissions.canManage) {
          return const Center(child: Text('Staffing requires Proprietor access.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staffing', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('School-wide teaching assignments and class teachers, every section.'),
              const SizedBox(height: 16),
              if (_notice != null) ...[
                Text(
                  _notice!,
                  style: TextStyle(color: _noticeSuccess ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Teaching Assignments', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
                          TextButton(
                            onPressed: data.unassigned.isEmpty ? null : () => _addAssignment(data),
                            child: const Text('+ Assign'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (data.assignments.isEmpty)
                        const Text('No teaching assignments yet.')
                      else
                        for (final assignment in data.assignments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${assignment.className} · ${assignment.subject}'),
                            subtitle: Text(
                              '${data.teachers.where((t) => t.id == assignment.teacherId).map((t) => t.name).firstOrDefault('Unlinked teacher')} · '
                              '${assignment.periodsPerWeek} periods/week',
                            ),
                            trailing: TextButton(onPressed: () => _transfer(data, assignment), child: const Text('Transfer')),
                          ),
                      if (data.unassigned.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text('${data.unassigned.length} curriculum subject(s) still need a teacher.', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Class Teachers', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 8),
                      if (data.activeSessionId.isEmpty)
                        const Text('No active academic session, so a class teacher cannot be assigned yet.')
                      else if (data.classOptions.isEmpty)
                        const Text('No active classes yet.')
                      else
                        for (final className in data.classOptions)
                          _ClassTeacherRow(
                            className: className,
                            current: data.classTeachers.where((c) => c.className == className).firstOrDefaultNull(),
                            onAssign: () => _assignClassTeacherByName(data, className),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignClassTeacherByName(ProprietorStaffingSnapshot data, String className) async {
    final existing = data.classTeachers.where((c) => c.className == className).firstOrDefaultNull();
    final classId = existing?.classId ?? data.curriculumRequirements.firstWhere((c) => c.className == className, orElse: () => const PrincipalCurriculumRequirement(id: '', sessionId: '', classId: '', className: '', subjectId: '', subject: '', requirement: 'compulsory', periodsPerWeek: 1, isActive: true)).classId;
    if (classId.isEmpty) {
      _report(const ProprietorStaffingActionResult(success: false, message: 'This class has no curriculum configured yet, so its id could not be resolved.'));
      return;
    }
    final section = existing?.section ?? '';
    await _assignClassTeacher(data, classId, className, section);
  }
}

class _ClassTeacherRow extends StatelessWidget {
  const _ClassTeacherRow({required this.className, required this.current, required this.onAssign});
  final String className;
  final ClassTeacherAssignment? current;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(className),
        subtitle: Text(current == null ? 'No class teacher assigned' : 'Class teacher: ${current!.teacherName}'),
        trailing: TextButton(onPressed: onAssign, child: Text(current == null ? 'Assign' : 'Change')),
      );
}

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.unassigned, required this.teachers});
  final List<PrincipalUnassignedSubject> unassigned;
  final List<PrincipalAssignmentTeacher> teachers;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late PrincipalUnassignedSubject _subject = widget.unassigned.first;
  late PrincipalAssignmentTeacher _teacher = widget.teachers.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Assign teaching'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PrincipalUnassignedSubject>(
                initialValue: _subject,
                decoration: const InputDecoration(labelText: 'Class · Subject'),
                items: [
                  for (final item in widget.unassigned)
                    DropdownMenuItem(value: item, child: Text('${item.className} · ${item.subject}')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _subject = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PrincipalAssignmentTeacher>(
                initialValue: _teacher,
                decoration: const InputDecoration(labelText: 'Teacher'),
                items: [
                  for (final item in widget.teachers) DropdownMenuItem(value: item, child: Text(item.name)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _teacher = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop((_subject, _teacher)), child: const Text('Assign')),
        ],
      );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.assignment, required this.teachers});
  final PrincipalTeachingAssignment assignment;
  final List<PrincipalAssignmentTeacher> teachers;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late PrincipalAssignmentTeacher _teacher = widget.teachers.first;
  final _reasonController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _error = 'Add a transfer reason.');
      return;
    }
    Navigator.of(context).pop((_teacher, _reasonController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Transfer ${widget.assignment.className} · ${widget.assignment.subject}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<PrincipalAssignmentTeacher>(
                initialValue: _teacher,
                decoration: const InputDecoration(labelText: 'New teacher'),
                items: [
                  for (final item in widget.teachers) DropdownMenuItem(value: item, child: Text(item.name)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _teacher = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(controller: _reasonController, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Transfer')),
        ],
      );
}

extension _FirstOrDefault<T> on Iterable<T> {
  T firstOrDefault(T fallback) {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : fallback;
  }

  T? firstOrDefaultNull() {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
