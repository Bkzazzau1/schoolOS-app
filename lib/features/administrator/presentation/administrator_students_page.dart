import 'package:flutter/material.dart';

import '../data/administrator_students_demo_data.dart';
import '../data/administrator_students_repository.dart';
import '../domain/administrator_students_models.dart';

class AdministratorStudentsPage extends StatefulWidget {
  const AdministratorStudentsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.onRegisterStudent,
  });

  final String schoolName;
  final AdministratorStudentsRepository repository;
  final VoidCallback onRegisterStudent;

  @override
  State<AdministratorStudentsPage> createState() =>
      _AdministratorStudentsPageState();
}

class _AdministratorStudentsPageState extends State<AdministratorStudentsPage> {
  List<AdministratorStudentRecord> _students = const [];
  AdministratorStudentsPermissions? _permissions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _students = snapshot.students;
        _permissions = snapshot.permissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  void _openStudent(AdministratorStudentRecord student) {
    if (!(_permissions?.canOpenOperationalSummary ?? false)) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text('${student.id} · ${student.className}'),
                const SizedBox(height: 18),
                _DetailRow(label: 'Primary guardian', value: student.primaryGuardian),
                _DetailRow(label: 'Status', value: student.status.label),
                _DetailRow(
                  label: 'Website Open destination',
                  value: student.leadershipDestination,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(administratorStudentProfileBoundary),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(wide ? 28 : 16),
            children: [
              _Header(
                schoolName: widget.schoolName,
                canRegister: _permissions?.canViewDirectory ?? false,
                onRegisterStudent: widget.onRegisterStudent,
              ),
              const SizedBox(height: 18),
              _DirectoryCard(
                students: _students,
                wide: wide,
                onOpen: _openStudent,
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _TaskCard(
                        title: 'Family-account tasks',
                        tasks: administratorFamilyTasks,
                        footer: administratorFamilyBoundary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: _TaskCard(
                        title: 'Record quality',
                        tasks: administratorRecordQualityTasks,
                      ),
                    ),
                  ],
                )
              else ...[
                const _TaskCard(
                  title: 'Family-account tasks',
                  tasks: administratorFamilyTasks,
                  footer: administratorFamilyBoundary,
                ),
                const SizedBox(height: 16),
                const _TaskCard(
                  title: 'Record quality',
                  tasks: administratorRecordQualityTasks,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.schoolName,
    required this.canRegister,
    required this.onRegisterStudent,
  });

  final String schoolName;
  final bool canRegister;
  final VoidCallback onRegisterStudent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMINISTRATION · STUDENT RECORDS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Students & Families',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Search, review and maintain student and guardian records across all school sections. · $schoolName',
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: canRegister ? onRegisterStudent : null,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Register student'),
        ),
      ],
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.students,
    required this.wide,
    required this.onOpen,
  });

  final List<AdministratorStudentRecord> students;
  final bool wide;
  final ValueChanged<AdministratorStudentRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student directory',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('Operational record view for administration.'),
            const SizedBox(height: 16),
            if (wide) _wideTable(context) else _phoneList(context),
          ],
        ),
      ),
    );
  }

  Widget _wideTable(BuildContext context) {
    return Column(
      children: [
        const _DirectoryRow(
          header: true,
          id: 'ID',
          student: 'Student',
          className: 'Class',
          guardian: 'Primary guardian',
          status: 'Status',
        ),
        for (final student in students)
          _DirectoryRow(
            id: student.id,
            student: student.name,
            className: student.className,
            guardian: student.primaryGuardian,
            status: student.status.label,
            warning: student.status == AdministratorStudentStatus.transferPending,
            onOpen: () => onOpen(student),
          ),
      ],
    );
  }

  Widget _phoneList(BuildContext context) {
    return Column(
      children: [
        for (final student in students)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _StatusChip(status: student.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${student.id} · ${student.className}'),
                  const SizedBox(height: 4),
                  Text(student.primaryGuardian),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => onOpen(student),
                      child: const Text('Open'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    this.header = false,
    required this.id,
    required this.student,
    required this.className,
    required this.guardian,
    required this.status,
    this.warning = false,
    this.onOpen,
  });

  final bool header;
  final String id;
  final String student;
  final String className;
  final String guardian;
  final String status;
  final bool warning;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: header ? FontWeight.w900 : FontWeight.w500,
      fontSize: header ? 12 : 14,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(id, style: style)),
          Expanded(flex: 3, child: Text(student, style: style)),
          Expanded(flex: 2, child: Text(className, style: style)),
          Expanded(flex: 3, child: Text(guardian, style: style)),
          Expanded(
            flex: 2,
            child: header
                ? Text(status, style: style)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusChip(
                      status: warning
                          ? AdministratorStudentStatus.transferPending
                          : AdministratorStudentStatus.active,
                    ),
                  ),
          ),
          SizedBox(
            width: 70,
            child: header
                ? Text('Action', style: style)
                : TextButton(onPressed: onOpen, child: const Text('Open')),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AdministratorStudentStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status.label),
      avatar: Icon(
        status == AdministratorStudentStatus.transferPending
            ? Icons.schedule_rounded
            : Icons.check_circle_outline_rounded,
        size: 16,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.title, required this.tasks, this.footer});

  final String title;
  final List<AdministratorStudentTask> tasks;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text('Sample counts only: not yet wired to the real student and record registers.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(task.detail),
                  ],
                ),
              ),
            if (footer != null) ...[
              const Divider(),
              Text(footer!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
