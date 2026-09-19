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
  State<PrincipalAssignmentsPage> createState() => _PrincipalAssignmentsPageState();
}

class _PrincipalAssignmentsPageState extends State<PrincipalAssignmentsPage> {
  PrincipalAssignmentsSnapshot? _snapshot;
  String? _error;
  String _query = '';
  String _classFilter = 'All classes';
  String _newClass = 'JSS 2B';
  String _newSubject = 'Mathematics';
  String _newTeacher = 'TCH-001';
  int _periods = 5;
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
        final qualified = snapshot.teachers.where((t) => t.canTeach(_newSubject)).toList();
        if (qualified.isNotEmpty && !qualified.any((t) => t.id == _newTeacher)) {
          _newTeacher = qualified.first.id;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  PrincipalAssignmentTeacher? _teacherById(String id) {
    final snapshot = _snapshot;
    if (snapshot == null) return null;
    for (final teacher in snapshot.teachers) {
      if (teacher.id == id) return teacher;
    }
    return null;
  }

  Future<void> _addAssignment() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.repository.addAssignment(
      className: _newClass,
      subject: _newSubject,
      teacherId: _newTeacher,
      periodsPerWeek: _periods,
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
        .where((teacher) => teacher.id != assignment.teacherId && teacher.canTeach(assignment.subject))
        .toList(growable: false);

    bool newStaff = false;
    String existingId = candidates.isEmpty ? '' : candidates.first.id;
    final nameController = TextEditingController();
    final departmentController = TextEditingController();
    final reasonController = TextEditingController();

    final shouldTransfer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Transfer ${assignment.className} · ${assignment.subject}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current teacher: ${_teacherById(assignment.teacherId)?.name ?? assignment.teacherId}'),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Existing staff'), icon: Icon(Icons.badge_outlined)),
                      ButtonSegment(value: true, label: Text('New staff'), icon: Icon(Icons.person_add_alt_1_outlined)),
                    ],
                    selected: {newStaff},
                    onSelectionChanged: (selection) => setDialogState(() => newStaff = selection.first),
                  ),
                  const SizedBox(height: 14),
                  if (!newStaff)
                    _dropdown<String>(
                      label: 'Receiving teacher',
                      current: existingId.isEmpty ? null : existingId,
                      items: candidates
                          .map((teacher) => DropdownMenuItem<String>(
                                value: teacher.id,
                                child: Text('${teacher.name} · ${teacher.weeklyPeriods} periods'),
                              ))
                          .toList(growable: false),
                      onChanged: (value) => setDialogState(() => existingId = value ?? ''),
                    )
                  else ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'New staff name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department / unit',
                        hintText: 'Optional — Pending onboarding if blank',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A provisional teaching target will be created. The staff account must later be linked through onboarding.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
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
                  const Text('Records inherited by the receiving teacher', style: TextStyle(fontWeight: FontWeight.w900)),
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
                  Text(principalTransferPrivacyBoundary, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: (!newStaff && existingId.isEmpty) ? null : () => Navigator.pop(dialogContext, true),
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
      existingTeacherId: newStaff ? null : existingId,
      newStaffName: newStaff ? nameController.text : null,
      newStaffDepartment: newStaff ? departmentController.text : null,
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
            Text(_error!),
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
          final matchesQuery = '${assignment.className} ${assignment.subject} ${teacher?.name ?? ''}'
              .toLowerCase()
              .contains(_query.toLowerCase());
          final matchesClass = _classFilter == 'All classes' || assignment.className == _classFilter;
          return matchesQuery && matchesClass;
        }).toList(growable: false);
        final unassigned = principalUnassignedSubjects
            .where((gap) => !snapshot.assignments.any(
                  (assignment) => assignment.className == gap.className && assignment.subject == gap.subject,
                ))
            .toList(growable: false);
        final heavy = snapshot.teachers.where((teacher) => teacher.weeklyPeriods > 24).length;
        final qualified = snapshot.teachers.where((teacher) => teacher.canTeach(_newSubject)).toList(growable: false);

        return ListView(
          padding: EdgeInsets.all(compact ? 14 : 24),
          children: [
            _header(context, compact),
            const SizedBox(height: 16),
            _scopeBanner(context),
            const SizedBox(height: 14),
            _sectionCards(context, compact),
            const SizedBox(height: 14),
            _kpis(context, compact, snapshot.assignments.length, unassigned.length, snapshot.teachers.length, heavy),
            const SizedBox(height: 18),
            compact
                ? Column(children: [
                    _assignmentForm(context, qualified),
                    const SizedBox(height: 12),
                    _unassignedCard(context, unassigned),
                  ])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _assignmentForm(context, qualified)),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: _unassignedCard(context, unassigned)),
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
        OutlinedButton(onPressed: () => widget.onNavigate('dashboard'), child: const Text('Dashboard')),
        OutlinedButton(onPressed: () => widget.onNavigate('teachers'), child: const Text('Teachers')),
        OutlinedButton(onPressed: () => widget.onNavigate('timetable'), child: const Text('Timetable')),
      ],
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRINCIPAL · SECONDARY SCHOOL', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Teaching Assignments', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Assign, transfer and hand over class-subject responsibilities inside the authorized Secondary section.'),
      ],
    );
    return compact
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), actions])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
  }

  Widget _scopeBanner(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ACTIVE LEADERSHIP SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Secondary School', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Text('Kaduna Campus · Principal: Mr. Ibrahim Danladi'),
              const SizedBox(height: 8),
              Text(principalAssignmentScopeBoundary, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );

  Widget _sectionCards(BuildContext context, bool compact) {
    const sections = [
      ('NURSERY', 'Nursery / Early Years', 'Head Teacher', 'Mrs. Mary Daniel', '3 configured classes', false),
      ('PRIMARY', 'Primary School', 'Headmistress', 'Mrs. Hauwa Sule', '6 configured classes', false),
      ('SECONDARY', 'Secondary School', 'Principal', 'Mr. Ibrahim Danladi', '6 configured classes', true),
    ];
    final cards = sections
        .map((section) => Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(section.$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${section.$3} · ${section.$4}'),
                    Text(section.$5, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      section.$6 ? 'Your active scope' : 'Managed by ${section.$3}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: section.$6 ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ))
        .toList(growable: false);
    return compact
        ? Column(children: cards)
        : Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card))]);
  }

  Widget _kpis(BuildContext context, bool compact, int assigned, int unassigned, int teachers, int heavy) {
    final rows = [
      ('Assigned class-subjects', '$assigned', 'Current records'),
      ('Unassigned', '$unassigned', 'Requires section leader action'),
      ('Secondary teachers', '$teachers', 'Available in this scope'),
      ('Heavy workload', '$heavy', 'Above 24 periods/week'),
    ];
    final cards = rows
        .map((row) => Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.$1),
                    const SizedBox(height: 4),
                    Text(row.$2, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text(row.$3, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ))
        .toList(growable: false);
    return compact
        ? Wrap(spacing: 8, runSpacing: 8, children: [for (final card in cards) SizedBox(width: 165, child: card)])
        : Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card))]);
  }

  Widget _assignmentForm(BuildContext context, List<PrincipalAssignmentTeacher> qualified) {
    final teacherValue = qualified.any((teacher) => teacher.id == _newTeacher)
        ? _newTeacher
        : (qualified.isEmpty ? null : qualified.first.id);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Assign teacher', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Text('Create a class-subject teaching responsibility.'),
            const SizedBox(height: 14),
            _dropdown<String>(
              label: 'Class',
              current: _newClass,
              items: principalAssignmentClasses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _newClass = value ?? _newClass),
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Subject',
              current: _newSubject,
              items: principalAssignmentSubjects.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) {
                if (value == null) return;
                final matches = _snapshot!.teachers.where((teacher) => teacher.canTeach(value)).toList();
                setState(() {
                  _newSubject = value;
                  if (matches.isNotEmpty) _newTeacher = matches.first.id;
                });
              },
            ),
            const SizedBox(height: 10),
            _dropdown<String>(
              label: 'Qualified teacher',
              current: teacherValue,
              items: qualified
                  .map((teacher) => DropdownMenuItem(value: teacher.id, child: Text('${teacher.name} · ${teacher.weeklyPeriods} periods')))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _newTeacher = value ?? _newTeacher),
            ),
            const SizedBox(height: 10),
            _dropdown<int>(
              label: 'Periods / week',
              current: _periods,
              items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (value) => setState(() => _periods = value ?? _periods),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving || qualified.isEmpty ? null : _addAssignment,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(_saving ? 'Saving…' : 'Assign teacher'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unassignedCard(BuildContext context, List<PrincipalUnassignedSubject> unassigned) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unassigned subjects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('These need a teacher before timetable completion.'),
              const SizedBox(height: 10),
              if (unassigned.isEmpty) const Text('No unassigned prototype subjects remain.'),
              for (final item in unassigned)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.className} · ${item.subject}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.periods} periods/week'),
                  trailing: const Text('Assign →'),
                  onTap: () {
                    final matches = _snapshot!.teachers.where((teacher) => teacher.canTeach(item.subject)).toList();
                    setState(() {
                      _newClass = item.className;
                      _newSubject = item.subject;
                      _periods = item.periods;
                      if (matches.isNotEmpty) _newTeacher = matches.first.id;
                    });
                  },
                ),
            ],
          ),
        ),
      );

  Widget _assignmentTable(BuildContext context, bool compact, List<PrincipalTeachingAssignment> assignments) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current teaching assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('Transfer a responsibility without deleting its previous teacher or history.'),
              const SizedBox(height: 12),
              if (compact)
                Column(children: [_searchField(), const SizedBox(height: 8), _classFilterField()])
              else
                Row(children: [
                  Expanded(child: _searchField()),
                  const SizedBox(width: 8),
                  SizedBox(width: 190, child: _classFilterField()),
                ]),
              const SizedBox(height: 12),
              for (final assignment in assignments) _assignmentRow(context, assignment, compact),
              if (assignments.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No assignments match this filter.')),
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
          const DropdownMenuItem(value: 'All classes', child: Text('All classes')),
          for (final item in principalAssignmentClasses) DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (value) => setState(() => _classFilter = value ?? 'All classes'),
      );

  Widget _assignmentRow(BuildContext context, PrincipalTeachingAssignment assignment, bool compact) {
    final teacher = _teacherById(assignment.teacherId);
    final status = teacher != null && teacher.weeklyPeriods > 24 ? 'Heavy' : 'Balanced';
    final content = [
      _cell('Class', assignment.className),
      _cell('Subject', assignment.subject, sub: teacher?.department),
      _cell(
        'Teacher',
        teacher?.name ?? assignment.teacherId,
        sub: teacher?.provisional == true ? 'Provisional · onboarding link pending' : null,
      ),
      _cell('Periods', '${assignment.periodsPerWeek}/week'),
      _cell('Load', '${teacher?.weeklyPeriods ?? 0} periods · $status'),
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

  Widget _cell(String label, String value, {String? sub}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );

  Widget _transferHistory(BuildContext context, PrincipalAssignmentsSnapshot snapshot) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transfer & handover history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Text('Every change preserves the previous assignment version and the receiver’s teaching-record access grant.'),
              const SizedBox(height: 10),
              if (snapshot.transfers.isEmpty) const Text('No assignment transfers recorded yet.'),
              for (final transfer in snapshot.transfers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.swap_horiz_rounded)),
                  title: Text('${transfer.className} · ${transfer.subject}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
              const Text('SECTION GOVERNANCE RULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Leadership is separated by academic section', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                'Proprietor / Authorized Owner → Creates sections & appoints leaders → '
                'Principal / Headmaster / Headmistress → Assigns teachers inside own section',
              ),
              const SizedBox(height: 8),
              Text(principalAssignmentScopeBoundary, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(principalTransferPrivacyBoundary, style: Theme.of(context).textTheme.bodySmall),
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
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: current,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
