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
        final availableSubjects = _availableSubjects(snapshot, _newClass);
        if (!availableSubjects.contains(_newSubject)) {
          _newSubject = availableSubjects.firstOrNull ?? '';
        }
        final qualified = snapshot.teachers
            .where((teacher) => teacher.canTeach(_newSubject))
            .toList();
        if (!qualified.any((teacher) => teacher.id == _newTeacher)) {
          _newTeacher = qualified.firstOrNull?.id ?? '';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  List<String> _availableSubjects(
    PrincipalAssignmentsSnapshot snapshot,
    String className,
  ) =>
      snapshot.unassigned
          .where((item) => item.className == className)
          .map((item) => item.subject)
          .toSet()
          .toList()
        ..sort();

  PrincipalUnassignedSubject? _selectedOffering(
    PrincipalAssignmentsSnapshot snapshot,
  ) =>
      snapshot.unassigned
          .where(
            (item) =>
                item.className == _newClass && item.subject == _newSubject,
          )
          .firstOrNull;

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  PrincipalAssignmentTeacher? _teacherById(String id) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    return snapshot.teachers.where((teacher) => teacher.id == id).firstOrNull;
  }

  Future<void> _addAssignment() async {
    final snapshot = _snapshot;
    if (_saving || snapshot == null) return;
    final offering = _selectedOffering(snapshot);
    if (offering == null) {
      _show('Choose an unassigned class-subject from the canonical curriculum.');
      return;
    }
    setState(() => _saving = true);
    final result = await widget.repository.addAssignment(
      className: offering.className,
      subject: offering.subject,
      teacherId: _newTeacher,
      periodsPerWeek: offering.periods,
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
      _show('Onboard another Secondary teacher before transferring this responsibility.');
      return;
    }
    var receivingId = candidates.first.id;
    final reasonController = TextEditingController();
    final shouldTransfer = await showDialog<bool>(
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
                  _dropdown<String>(
                    label: 'Receiving teacher',
                    current: receivingId,
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
                      () => receivingId = value ?? receivingId,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Transfer reason',
                      hintText: 'Why is this responsibility being handed over?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Access rule',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Only a real staff record can receive teaching responsibility. If that staff member has not finished Teacher-account onboarding, the responsibility is preserved but private Teacher access waits until the account is linked.',
                  ),
                  const SizedBox(height: 12),
                  for (final item in principalTransferRecordScope)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 17),
                          const SizedBox(width: 7),
                          Expanded(child: Text(item)),
                        ],
                      ),
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
              onPressed: reasonController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Transfer work'),
            ),
          ],
        ),
      ),
    );
    if (shouldTransfer != true || !mounted) return;
    final result = await widget.repository.transferAssignment(
      assignmentId: assignment.id,
      existingTeacherId: receivingId,
      reason: reasonController.text,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final assignments = snapshot.assignments.where((assignment) {
          final teacher = _teacherById(assignment.teacherId);
          final matchesQuery =
              '${assignment.className} ${assignment.subject} ${teacher?.name ?? ''}'
                  .toLowerCase()
                  .contains(_query.toLowerCase());
          final matchesClass = _classFilter == 'All classes' ||
              assignment.className == _classFilter;
          return matchesQuery && matchesClass;
        }).toList(growable: false);
        final heavy = snapshot.teachers
            .where((teacher) => teacher.weeklyPeriods > 24)
            .length;
        final qualified = snapshot.teachers
            .where((teacher) => teacher.canTeach(_newSubject))
            .toList(growable: false);

        return ListView(
          padding: EdgeInsets.all(compact ? 14 : 24),
          children: [
            _header(context, compact),
            const SizedBox(height: 16),
            _scopeBanner(context),
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
                      _assignmentForm(context, snapshot, qualified),
                      const SizedBox(height: 12),
                      _unassignedCard(context, snapshot.unassigned),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _assignmentForm(context, snapshot, qualified),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: _unassignedCard(context, snapshot.unassigned),
                      ),
                    ],
                  ),
            const SizedBox(height: 18),
            _assignmentTable(context, compact, assignments),
            const SizedBox(height: 18),
            _transferHistory(context, snapshot),
            const SizedBox(height: 18),
            _governance(context),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, bool compact) {
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => widget.onNavigate('dashboard'),
          child: const Text('Dashboard'),
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
          'Assign real Secondary curriculum responsibilities to real staff. Class-subject and period requirements come from the canonical curriculum.',
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

  Widget _scopeBanner(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACTIVE LEADERSHIP SCOPE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Secondary School',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                principalAssignmentScopeBoundary,
                style: Theme.of(context).textTheme.bodySmall,
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
      ('Assigned class-subjects', '$assigned', 'Canonical responsibilities'),
      ('Unassigned', '$unassigned', 'Curriculum gaps'),
      ('Secondary teachers', '$teachers', 'Real staff directory'),
      ('Heavy workload', '$heavy', 'Above 24 periods/week'),
    ];
    final cards = rows
        .map(
          (row) => Card(
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
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(row.$3, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        )
        .toList(growable: false);
    return compact
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final card in cards) SizedBox(width: 165, child: card)],
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

  Widget _assignmentForm(
    BuildContext context,
    PrincipalAssignmentsSnapshot snapshot,
    List<PrincipalAssignmentTeacher> qualified,
  ) {
    final subjects = _availableSubjects(snapshot, _newClass);
    final teacherValue = qualified.any((teacher) => teacher.id == _newTeacher)
        ? _newTeacher
        : qualified.firstOrNull?.id;
    final offering = _selectedOffering(snapshot);
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
            const Text('Choose an unassigned item from the canonical curriculum.'),
            const SizedBox(height: 14),
            _dropdown<String>(
              label: 'Class',
              current: _newClass.isEmpty ? null : _newClass,
              items: [
                for (final item in snapshot.classOptions)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) {
                if (value == null) return;
                final nextSubjects = _availableSubjects(snapshot, value);
                setState(() {
                  _newClass = value;
                  _newSubject = nextSubjects.firstOrNull ?? '';
                });
              },
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Unassigned subject',
              current: subjects.contains(_newSubject) ? _newSubject : null,
              items: [
                for (final item in subjects)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) {
                if (value == null) return;
                final matches = snapshot.teachers
                    .where((teacher) => teacher.canTeach(value))
                    .toList();
                setState(() {
                  _newSubject = value;
                  _newTeacher = matches.firstOrNull?.id ?? '';
                });
              },
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Receiving teacher',
              current: teacherValue,
              items: [
                for (final teacher in qualified)
                  DropdownMenuItem(
                    value: teacher.id,
                    child: Text(
                      '${teacher.name} · ${teacher.weeklyPeriods} periods/week',
                    ),
                  ),
              ],
              onChanged: (value) => setState(
                () => _newTeacher = value ?? _newTeacher,
              ),
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Periods / week',
                border: OutlineInputBorder(),
              ),
              child: Text(
                offering == null
                    ? 'Choose a curriculum item'
                    : '${offering.periods} · controlled by Subjects & Curriculum',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving || offering == null || qualified.isEmpty
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
                'Curriculum gaps',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const Text('Every item below is a real unassigned Secondary class-subject.'),
              const SizedBox(height: 10),
              if (unassigned.isEmpty)
                const Text('Every active Secondary class-subject has a teacher.'),
              for (final item in unassigned)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.className} · ${item.subject}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${item.periods} periods/week'),
                  trailing: const Text('Assign →'),
                  onTap: () {
                    final matches = _snapshot!.teachers
                        .where((teacher) => teacher.canTeach(item.subject))
                        .toList();
                    setState(() {
                      _newClass = item.className;
                      _newSubject = item.subject;
                      _newTeacher = matches.firstOrNull?.id ?? '';
                    });
                  },
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
                'A queued responsibility is not Teacher access until the server confirms it.',
              ),
              const SizedBox(height: 12),
              if (compact)
                Column(
                  children: [
                    _searchField(),
                    const SizedBox(height: 8),
                    _classFilterField(),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 8),
                    SizedBox(width: 190, child: _classFilterField()),
                  ],
                ),
              const SizedBox(height: 12),
              for (final assignment in assignments)
                _assignmentRow(context, assignment, compact),
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No teaching assignments match this filter.'),
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
        onChanged: (value) => setState(
          () => _classFilter = value ?? 'All classes',
        ),
      );

  Widget _assignmentRow(
    BuildContext context,
    PrincipalTeachingAssignment assignment,
    bool compact,
  ) {
    final teacher = _teacherById(assignment.teacherId);
    final load = teacher?.weeklyPeriods ?? 0;
    final content = [
      _cell('Class', assignment.className),
      _cell('Subject', assignment.subject),
      _cell('Teacher', teacher?.name ?? assignment.teacherId),
      _cell('Periods', '${assignment.periodsPerWeek}/week'),
      _cell(
        'Access',
        assignment.pendingSync
            ? 'Queued'
            : assignment.accessReady
                ? 'Teacher linked'
                : 'Awaiting onboarding',
        sub: '$load periods total',
      ),
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
                    onPressed: assignment.pendingSync
                        ? null
                        : () => _openTransfer(assignment),
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
                  onPressed: assignment.pendingSync
                      ? null
                      : () => _openTransfer(assignment),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer'),
                ),
              ],
            ),
    );
  }

  Widget _cell(String label, String value, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );

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
                'Historical handovers from the earlier assignment workflow remain visible here; canonical reassignments are also retained server-side as append-only assignment events.',
              ),
              const SizedBox(height: 10),
              if (snapshot.transfers.isEmpty)
                const Text('No legacy handover records are stored on this device.'),
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
                    '${transfer.reason}',
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
                'SECTION GOVERNANCE RULE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Curriculum and teaching responsibility are separate authorities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Administrator → maintains subject catalog and class curriculum. '
                'Principal → assigns real teachers to Secondary class-subjects. '
                'Teacher → receives only server-confirmed responsibilities.',
              ),
              const SizedBox(height: 8),
              Text(
                principalAssignmentScopeBoundary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                principalTransferPrivacyBoundary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  static Widget _dropdown<T>({
    required String label,
    required T? current,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: current,
          isExpanded: true,
          items: items,
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
