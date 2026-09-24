import 'package:flutter/material.dart';

import '../data/principal_class_teachers_repository.dart';

class PrincipalClassTeachersPage extends StatefulWidget {
  const PrincipalClassTeachersPage({
    super.key,
    required this.repository,
    this.onMutationQueued,
  });

  final PrincipalClassTeachersRepository repository;
  final VoidCallback? onMutationQueued;

  @override
  State<PrincipalClassTeachersPage> createState() => _PrincipalClassTeachersPageState();
}

class _PrincipalClassTeachersPageState extends State<PrincipalClassTeachersPage> {
  late Future<PrincipalClassTeachersSnapshot> _future;
  String? _notice;
  bool _noticeSuccess = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  void _reload() => setState(() => _future = widget.repository.load());

  Future<void> _assign(PrincipalClassTeachersSnapshot snapshot, String classId, String className) async {
    final teacher = await showDialog<({String id, String name})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Class teacher for $className'),
        children: [
          for (final teacher in snapshot.teachers)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(teacher),
              child: Text(teacher.name),
            ),
          if (snapshot.teachers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('No Secondary teacher with a linked account is available yet.'),
            ),
        ],
      ),
    );
    if (teacher == null) return;
    final result = await widget.repository.assign(
      classId: classId,
      className: className,
      section: 'Secondary',
      sessionId: snapshot.activeSessionId,
      sessionName: snapshot.activeSessionName,
      teacherId: teacher.id,
      teacherName: teacher.name,
    );
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrincipalClassTeachersSnapshot>(
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
                const Text('Could not load class teachers.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final data = snapshot.requireData;
        if (!data.permissions.canManage) {
          return const Center(child: Text('Class-teacher assignment requires Principal access.'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Class Teachers', style: Theme.of(context).textTheme.headlineMedium),
            const Text('Secondary only. Proprietor manages this school-wide, separately.'),
            const SizedBox(height: 16),
            if (_notice != null) ...[
              Text(
                _notice!,
                style: TextStyle(
                  color: _noticeSuccess ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (data.activeSessionId.isEmpty)
              const Text('No active academic session, so a class teacher cannot be assigned yet.')
            else
              for (final entry in data.classOptions.entries)
                Card(
                  child: ListTile(
                    title: Text(entry.value),
                    subtitle: Text(
                      data.forClass(entry.key) == null
                          ? 'No class teacher assigned for ${data.activeSessionName}'
                          : 'Class teacher: ${data.forClass(entry.key)!.teacherName}',
                    ),
                    trailing: TextButton(
                      onPressed: () => _assign(data, entry.key, entry.value),
                      child: Text(data.forClass(entry.key) == null ? 'Assign' : 'Change'),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
