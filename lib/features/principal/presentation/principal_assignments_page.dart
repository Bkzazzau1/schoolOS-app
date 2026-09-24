import 'package:flutter/material.dart';

import '../data/principal_assignments_demo_data.dart';
import '../data/principal_assignments_repository.dart';
import '../domain/principal_assignments_models.dart';

class PrincipalAssignmentsPage extends StatefulWidget {
  const PrincipalAssignmentsPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final PrincipalAssignmentsRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<PrincipalAssignmentsPage> createState() =>
      _PrincipalAssignmentsPageState();
}

class _PrincipalAssignmentsPageState extends State<PrincipalAssignmentsPage> {
  PrincipalAssignmentsSnapshot? _snapshot;
  String? _error;
  String _query = '';
  String _classFilter = 'All classes';
  String _newClass = '';
  String _newSubject = '';
  String _newTeacher = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
        if (!snapshot.classOptions.contains(_newClass)) {
          _newClass = snapshot.classOptions.firstOrNull ?? '';
        }
        _repairAssignmentChoices(snapshot);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _repairAssignmentChoices(PrincipalAssignmentsSnapshot snapshot) {
    final requirements = snapshot.curriculumForClass(_newClass);
    if (!requirements.any((item) => item.subject == _newSubject)) {
      _newSubject = requirements.firstOrNull?.subject ?? '';
    }
    if (!snapshot.teachers.any((item) => item.id == _newTeacher)) {
      _newTeacher = snapshot.teachers.firstOrNull?.id ?? '';
    }
  }

  List<PrincipalCurriculumRequirement> _requirementsForNewClass() =>
      _snapshot?.curriculumForClass(_newClass) ?? const [];

  PrincipalCurriculumRequirement? get _selectedRequirement {
    for (final item in _requirementsForNewClass()) {
      if (item.subject == _newSubject) return item;
    }
    return null;
  }

  PrincipalAssignmentTeacher? _teacherById(String id) {
    for (final teacher in _snapshot?.teachers ?? const []) {
      if (teacher.id == id) return teacher;
    }
    return null;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addAssignment() async {
    if (_saving) return;
    final requirement = _selectedRequirement;
    if (requirement == null || _newTeacher.isEmpty) {
      _show('Choose a curriculum subject and an activated Teacher account.');
      return;
    }
    setState(() => _saving = true);
    final result = await widget.repository.addAssignment(
      className: requirement.className,
      subject: requirement.subject,
      teacherId: _newTeacher,
      periodsPerWeek: requirement.periodsPerWeek,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _show(result.message);
    if (result.success) {
      widget.onMutationQueued();
      await _load();
    }
  }

  Future<void> _openTransfer(PrincipalTeachingAssignment assignment) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final candidates = snapshot.teachers
        .where((teacher) => teacher.id != assignment.teacherId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      _show(
        'No other activated Teacher account is available. Complete staff onboarding before transferring this responsibility.',
      );
      return;
    }

    String teacherId = candidates.first.id;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Transfer ${assignment.className} · ${assignment.subject}'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current teacher: ${_teacherById(assignment.teacherId)?.name ?? assignment.teacherId}',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: teacherId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Receiving Teacher account',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final teacher in candidates)
                        DropdownMenuItem(
                          value: teacher.id,
                          child: Text(
                            '${teacher.name} · ${teacher.weeklyPeriods} periods/week',
                          ),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => teacherId = value ?? teacherId,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Handover reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Records inherited by the receiving teacher',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  for (final item in principalTransferRecordScope)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 7),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    principalTransferPrivacyBoundary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transfer work'),
            ),
          ],
        ),
      ),
    );
    final reasonText = reason.text;
    reason.dispose();
    if (confirmed != true || !mounted) return;
    final result = await widget.repository.transferAssignment(
      assignmentId: assignment.id,
      existingTeacherId: teacherId,
      reason: reasonText,
    );
    if (!mounted) return;
    _show(result.message);
    if (result.success) {
      widget.onMutationQueued();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) return const Center(child: CircularProgressIndicator());

    final filtered = snapshot.assignments.where((assignment) {
      final teacher = _teacherById(assignment.teacherId);
      final text =
          '${assignment.className} ${assignment.subject} ${teacher?.name ?? ''}'
              .toLowerCase();
      return text.contains(_query.toLowerCase()) &&
          (_classFilter == 'All classes' || assignment.className == _classFilter);
    }).toList(growable: false);
    final heavy = snapshot.teachers.where((teacher) => teacher.weeklyPeriods > 24).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.all(compact ? 14 : 24),
            children: [
              _header(context, compact),
              const SizedBox(height: 16),
              _scopeBanner(context, snapshot),
              const SizedBox(height: 14),
              _kpis(
                context,
                compact,
                snapshot.assignments.length,
                snapshot.unassigned.length,
                snapshot.teachers.length,
                heavy,
              ),
              const SizedBox(height: 18),
              compact
                  ? Column(
                      children: [
                        _assignmentForm(context),
                        const SizedBox(height: 12),
                        _unassignedCard(context, snapshot.unassigned),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _assignmentForm(context)),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: _unassignedCard(context, snapshot.unassigned),
                        ),
                      ],
                    ),
              const SizedBox(height: 18),
              _assignmentTable(context, compact, filtered),
              const SizedBox(height: 18),
              _transferHistory(context, snapshot),
              const SizedBox(height: 18),
              _governance(context),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool compact) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRINCIPAL · SECONDARY SCHOOL',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Teaching Assignments',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Assign real Teacher accounts only to class-subjects already defined in the canonical active curriculum.',
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => widget.onNavigate('academics'),
          child: const Text('Academics'),
        ),
        OutlinedButton(
          onPressed: () => widget.onNavigate('teachers'),
          child: const Text('Teachers'),
        ),
        OutlinedButton(
          onPressed: () => widget.onNavigate('timetable'),
          child: const Text('Timetable'),
        ),
      ],
    );
    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: title), actions],
          );
  }

  Widget _scopeBanner(
    BuildContext context,
    PrincipalAssignmentsSnapshot snapshot,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CANONICAL ASSIGNMENT SCOPE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Secondary School',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                snapshot.activeSessionId.isEmpty
                    ? 'No active academic session has synced yet. Teaching assignments remain unavailable until the academic structure is ready.'
                    : 'Active session: ${snapshot.activeSessionId}. $principalAssignmentScopeBoundary',
              ),
              const SizedBox(height: 6),
              const Text(
                'Teacher qualification-to-subject evidence is not yet a canonical SchoolOS model. Assignment authority stays with the Principal; SchoolOS does not invent qualification claims.',
              ),
            ],
          ),
        ),
      );

  Widget _kpis(
    BuildContext context,
    bool compact,
    int assigned,
    int unassigned,
    int teachers,
    int heavy,
  ) {
    final rows = [
      ('Assigned class-subjects', '$assigned'),
      ('Unassigned curriculum', '$unassigned'),
      ('Activated teachers', '$teachers'),
      ('Heavy workload', '$heavy'),
    ];
    final cards = [
      for (final row in rows)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.$1),
                const SizedBox(height: 4),
                Text(
                  row.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
    return compact
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final card in cards) SizedBox(width: 170, child: card)],
          )
        : Row(
            children: [
              for (final card in cards)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: card,
                  ),
                ),
            ],
          );
  }

  Widget _assignmentForm(BuildContext context) {
    final snapshot = _snapshot!;
    final requirements = _requirementsForNewClass();
    final selected = _selectedRequirement;
    final teacherValue = snapshot.teachers.any((t) => t.id == _newTeacher)
        ? _newTeacher
        : snapshot.teachers.firstOrNull?.id;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign teacher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Text(
              'Class, subject and weekly periods come from the active curriculum.',
            ),
            const SizedBox(height: 14),
            _dropdown<String>(
              label: 'Class',
              current: _newClass.isEmpty ? null : _newClass,
              items: [
                for (final item in snapshot.classOptions)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) => setState(() {
                _newClass = value ?? '';
                final items = snapshot.curriculumForClass(_newClass);
                _newSubject = items.firstOrNull?.subject ?? '';
              }),
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Curriculum subject',
              current: requirements.any((e) => e.subject == _newSubject)
                  ? _newSubject
                  : null,
              items: [
                for (final item in requirements)
                  DropdownMenuItem(
                    value: item.subject,
                    child: Text(
                      '${item.subject} · ${item.requirement} · ${item.periodsPerWeek}/week',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _newSubject = value ?? ''),
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Activated Teacher account',
              current: teacherValue,
              items: [
                for (final teacher in snapshot.teachers)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      '${teacher.name} · ${teacher.weeklyPeriods} periods/week',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _newTeacher = value ?? ''),
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Periods / week',
                border: OutlineInputBorder(),
              ),
              child: Text(
                selected == null
                    ? 'Choose a curriculum subject'
                    : '${selected.periodsPerWeek} · controlled by class curriculum',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving || selected == null || teacherValue == null
                  ? null
                  : _addAssignment,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(_saving ? 'Saving…' : 'Assign teacher'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unassignedCard(
    BuildContext context,
    List<PrincipalUnassignedSubject> unassigned,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unassigned curriculum',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Real active class-subject requirements that still need a teacher.',
              ),
              const SizedBox(height: 10),
              if (unassigned.isEmpty)
                const Text('Every active curriculum requirement has a teacher.'),
              for (final item in unassigned.take(12))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.className} · ${item.subject}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${item.periods} periods/week'),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: () => setState(() {
                    _newClass = item.className;
                    _newSubject = item.subject;
                  }),
                ),
            ],
          ),
        ),
      );

  Widget _assignmentTable(
    BuildContext context,
    bool compact,
    List<PrincipalTeachingAssignment> assignments,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current teaching assignments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Text(
                'A transfer preserves the previous teacher assignment as canonical history.',
              ),
              const SizedBox(height: 12),
              compact
                  ? Column(
                      children: [
                        _searchField(),
                        const SizedBox(height: 8),
                        _classFilterField(),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _searchField()),
                        const SizedBox(width: 8),
                        SizedBox(width: 190, child: _classFilterField()),
                      ],
                    ),
              const SizedBox(height: 12),
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No assignments match this filter.'),
                ),
              for (final assignment in assignments)
                _assignmentRow(context, assignment, compact),
            ],
          ),
        ),
      );

  Widget _assignmentRow(
    BuildContext context,
    PrincipalTeachingAssignment assignment,
    bool compact,
  ) {
    final teacher = _teacherById(assignment.teacherId);
    final content = [
      _cell('Class', assignment.className),
      _cell('Subject', assignment.subject),
      _cell('Teacher', teacher?.name ?? assignment.teacherId),
      _cell('Periods', '${assignment.periodsPerWeek}/week'),
      _cell('Load', '${teacher?.weeklyPeriods ?? 0} periods/week'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...content,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openTransfer(assignment),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Transfer work'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                for (final item in content) Expanded(child: item),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _openTransfer(assignment),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
              ],
            ),
    );
  }

  Widget _transferHistory(
    BuildContext context,
    PrincipalAssignmentsSnapshot snapshot,
  ) =>
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transfer & handover history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Text(
                'Server-validated history of canonical teacher changes.',
              ),
              const SizedBox(height: 10),
              if (snapshot.transfers.isEmpty)
                const Text('No assignment transfers recorded yet.'),
              for (final transfer in snapshot.transfers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.swap_horiz_rounded),
                  ),
                  title: Text(
                    '${transfer.className} · ${transfer.subject}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_teacherById(transfer.fromTeacherId)?.name ?? transfer.fromTeacherId} → '
                    '${_teacherById(transfer.toTeacherId)?.name ?? transfer.toTeacherId}\n'
                    '${transfer.reason}\nVersion ${transfer.previousAssignmentVersion} → ${transfer.newAssignmentVersion}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
        ),
      );

  Widget _governance(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ASSIGNMENT AUTHORITY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(principalAssignmentScopeBoundary),
              const SizedBox(height: 8),
              Text(
                principalTransferPrivacyBoundary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  Widget _searchField() => TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search class, subject or teacher...',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value),
      );

  Widget _classFilterField() => _dropdown<String>(
        label: 'Class',
        current: _classFilter,
        items: [
          const DropdownMenuItem(
            value: 'All classes',
            child: Text('All classes'),
          ),
          for (final item in _snapshot!.classOptions)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) =>
            setState(() => _classFilter = value ?? 'All classes'),
      );

  Widget _cell(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  static Widget _dropdown<T>({
    required String label,
    required T? current,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
