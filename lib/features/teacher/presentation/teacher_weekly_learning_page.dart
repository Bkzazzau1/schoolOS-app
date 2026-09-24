import 'package:flutter/material.dart';

import '../data/teacher_weekly_learning_demo_data.dart';
import '../data/teacher_weekly_learning_repository.dart';
import '../domain/teacher_weekly_learning_models.dart';

class TeacherWeeklyLearningPage extends StatefulWidget {
  const TeacherWeeklyLearningPage({
    super.key,
    required this.repository,
    required this.onNavigate,
    required this.onMutationQueued,
  });

  final TeacherWeeklyLearningRepository repository;
  final ValueChanged<String> onNavigate;
  final VoidCallback onMutationQueued;

  @override
  State<TeacherWeeklyLearningPage> createState() =>
      _TeacherWeeklyLearningPageState();
}

class _TeacherWeeklyLearningPageState extends State<TeacherWeeklyLearningPage> {
  final _next = TextEditingController();
  final _support = TextEditingController();
  final _note = TextEditingController();

  TeacherWeeklyLearningSnapshot? _snapshot;
  TeacherWeeklyLearningUpdate? _working;
  String? _selectedId;
  String? _notice;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _next.dispose();
    _support.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snapshot = await widget.repository.load();
      if (!mounted) return;
      TeacherWeeklyLearningUpdate? selected;
      if (snapshot.canonical) {
        final wanted = _selectedId;
        if (wanted != null) {
          for (final item in snapshot.updates) {
            if (item.id == wanted) {
              selected = item;
              break;
            }
          }
        }
        selected ??= snapshot.updates.isEmpty ? null : snapshot.updates.first;
      } else {
        selected = snapshot.update;
      }
      setState(() {
        _snapshot = snapshot;
        _working = selected;
        _selectedId = selected?.id;
        _loading = false;
        _error = null;
      });
      _syncControllers();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Weekly learning data could not be loaded.';
      });
    }
  }

  void _syncControllers() {
    final update = _working;
    if (update == null) {
      _next.clear();
      _support.clear();
      _note.clear();
      return;
    }
    final subject = update.subjectUpdate;
    _next.text = subject?.next ?? '';
    _support.text = subject?.support ?? '';
    _note.text = update.note;
  }

  void _select(TeacherWeeklyLearningUpdate update) {
    setState(() {
      _selectedId = update.id;
      _working = update;
      _notice = null;
    });
    _syncControllers();
  }

  TeacherWeeklyLearningUpdate _edited(TeacherWeeklyLearningUpdate base) {
    if (base.subjects.isEmpty) return base.copyWith(note: _note.text.trim());
    final subject = base.subjects.first.copyWith(
      next: _next.text.trim(),
      support: _support.text.trim(),
    );
    return base.copyWith(
      subjects: [subject, ...base.subjects.skip(1)],
      note: _note.text.trim(),
    );
  }

  Future<void> _save() async {
    final update = _working;
    if (update == null || _busy) return;
    setState(() => _busy = true);
    final result = await widget.repository.saveDraft(_edited(update));
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
      if (result.update != null) {
        _working = result.update;
        _selectedId = result.update!.id;
      }
    });
    if (result.success && _snapshot?.canonical == true) await _load();
  }

  Future<void> _publish() async {
    final update = _working;
    if (update == null || _busy) return;
    setState(() => _busy = true);
    final result = await widget.repository.queuePublication(_edited(update));
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
      if (result.update != null) {
        _working = result.update;
        _selectedId = result.update!.id;
      }
    });
    if (result.success && _snapshot?.canonical == true) await _load();
  }

  Future<void> _newCanonicalReport() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.canonical || snapshot.options.isEmpty) {
      setState(() {
        _notice = 'No current Teacher class-subject assignment is available.';
      });
      return;
    }
    final draft = await showDialog<_NewWeeklyDraft>(
      context: context,
      builder: (_) => _NewWeeklyDialog(options: snapshot.options),
    );
    if (draft == null || !mounted) return;

    final end = draft.weekStart.add(const Duration(days: 6));
    final startIso = _isoDate(draft.weekStart);
    final endIso = _isoDate(end);
    final update = TeacherWeeklyLearningUpdate(
      id: 'weekly|${draft.option.classSubjectId}|$startIso',
      className: draft.option.className,
      week: '$startIso – $endIso',
      subjects: [
        TeacherWeeklySubjectUpdate(
          subject: draft.option.subject,
          planned: '',
          covered: '',
          next: '',
          evidence: '',
          support: '',
        ),
      ],
      note: '',
      state: TeacherWeeklyPublicationState.draft,
      version: 0,
      classSubjectId: draft.option.classSubjectId,
      termId: draft.option.termId,
      term: draft.option.term,
      weekStart: startIso,
      weekEnd: endIso,
      currentTeacherAuthorized: true,
    );
    setState(() => _busy = true);
    final result = await widget.repository.saveDraft(update);
    if (!mounted) return;
    if (result.success) widget.onMutationQueued();
    setState(() {
      _busy = false;
      _notice = result.message;
      if (result.update != null) _selectedId = result.update!.id;
    });
    if (result.success) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Weekly learning data is unavailable.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    return snapshot.canonical
        ? _buildCanonical(context, snapshot)
        : _buildDemo(context, snapshot);
  }

  Widget _buildCanonical(
    BuildContext context,
    TeacherWeeklyLearningSnapshot snapshot,
  ) {
    final update = _working;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        final content = <Widget>[
          _Header(onNavigate: widget.onNavigate, canonical: true),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _Notice(_notice!),
          ],
          const SizedBox(height: 16),
          _CanonicalSummary(updates: snapshot.updates),
          const SizedBox(height: 16),
          if (update == null)
            _CanonicalEmpty(
              hasAssignments: snapshot.options.isNotEmpty,
              onCreate: _busy ? null : _newCanonicalReport,
            )
          else ...[
            if (compact) ...[
              _ReportList(
                updates: snapshot.updates,
                selectedId: update.id,
                onSelect: _select,
                onCreate: _busy ? null : _newCanonicalReport,
              ),
              const SizedBox(height: 16),
              _CanonicalEditor(
                update: update,
                next: _next,
                support: _support,
                note: _note,
                busy: _busy,
                onSave: _save,
                onPublish: _publish,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _ReportList(
                      updates: snapshot.updates,
                      selectedId: update.id,
                      onSelect: _select,
                      onCreate: _busy ? null : _newCanonicalReport,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: _CanonicalEditor(
                      update: update,
                      next: _next,
                      support: _support,
                      note: _note,
                      busy: _busy,
                      onSave: _save,
                      onPublish: _publish,
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 16),
          const _CanonicalBoundary(),
        ];
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          ),
        );
      },
    );
  }

  Widget _buildDemo(
    BuildContext context,
    TeacherWeeklyLearningSnapshot snapshot,
  ) {
    final update = _working ?? snapshot.update;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onNavigate: widget.onNavigate, canonical: false),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _Notice(_notice!),
          ],
          const SizedBox(height: 16),
          const _FlowCard(),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Subjects this week',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  for (final subject in update.subjects)
                    ListTile(
                      title: Text(subject.subject),
                      subtitle: Text('${subject.covered}\n${subject.evidence}'),
                      isThreeLine: true,
                      trailing: subject.linkedPlanId == null
                          ? null
                          : Text('From ${subject.linkedPlanId}'),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Parent preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(update.note),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy || !update.teacherEditable ? null : _save,
                        child: const Text('Save draft'),
                      ),
                      FilledButton(
                        onPressed:
                            _busy || !update.teacherEditable ? null : _publish,
                        child: const Text('Publish weekly update'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${update.completionPercent}% with coverage notes · ${teacherWeeklyPublicationLabel(update.state)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _DemoBoundary(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNavigate, required this.canonical});

  final ValueChanged<String> onNavigate;
  final bool canonical;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TEACHER PORTAL · WEEKLY LEARNING UPDATE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Weekly Learning Progress',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  canonical
                      ? 'Lesson delivery creates the facts. You add the next focus, support guidance and parent note, then publish one subject/week snapshot.'
                      : 'Turn approved lesson plans into one parent-ready weekly update without rewriting the same work.',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onNavigate('lesson-plans'),
                child: const Text('Lesson Plans'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('syllabus'),
                child: const Text('Syllabus'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('assignments'),
                child: const Text('Assignments'),
              ),
              OutlinedButton(
                onPressed: () => onNavigate('messages'),
                child: const Text('Messages'),
              ),
            ],
          ),
        ],
      );
}

class _CanonicalSummary extends StatelessWidget {
  const _CanonicalSummary({required this.updates});
  final List<TeacherWeeklyLearningUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final published = updates.where((item) => item.serverPublished).length;
    final queued = updates.where((item) => item.queued).length;
    final drafts = updates
        .where((item) => item.state == TeacherWeeklyPublicationState.draft)
        .length;
    final delivered = updates.fold<int>(
      0,
      (sum, item) => sum + item.deliveredLessons,
    );
    final values = [
      ('Reports', '${updates.length}', 'subject/week records'),
      ('Draft', '$drafts', 'Teacher editable'),
      ('Queued', '$queued', 'not published'),
      ('Published', '$published', '$delivered delivered lesson evidence item(s)'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in values)
          SizedBox(
            width: 215,
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1),
                    const SizedBox(height: 4),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(item.$3),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.updates,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
  });

  final List<TeacherWeeklyLearningUpdate> updates;
  final String selectedId;
  final ValueChanged<TeacherWeeklyLearningUpdate> onSelect;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Weekly subject reports',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'New subject/week report',
                  ),
                ],
              ),
              const Text(
                'One record per assigned ClassSubject and academic week.',
              ),
              const SizedBox(height: 10),
              for (final item in updates)
                ListTile(
                  selected: item.id == selectedId,
                  onTap: () => onSelect(item),
                  title: Text(
                    '${item.className} · ${item.subjectUpdate?.subject ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(item.week),
                  trailing: Chip(
                    label: Text(teacherWeeklyPublicationLabel(item.state)),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _CanonicalEditor extends StatelessWidget {
  const _CanonicalEditor({
    required this.update,
    required this.next,
    required this.support,
    required this.note,
    required this.busy,
    required this.onSave,
    required this.onPublish,
  });

  final TeacherWeeklyLearningUpdate update;
  final TextEditingController next;
  final TextEditingController support;
  final TextEditingController note;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final subject = update.subjectUpdate;
    final editable = update.teacherEditable;
    final status = update.pendingSync && update.queued
        ? 'QUEUED · NOT PUBLISHED'
        : update.pendingSync
            ? 'LOCAL CHANGES · SYNC PENDING'
            : teacherWeeklyPublicationLabel(update.state).toUpperCase();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${update.className} · ${subject?.subject ?? ''}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('${update.week} · ${update.term}'),
                    ],
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Server-derived learning facts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _Fact(label: 'Approved plans', value: '${update.approvedPlans}'),
            _Fact(label: 'Delivered lessons', value: '${update.deliveredLessons}'),
            _Fact(label: 'Planned topics', value: subject?.planned ?? '—'),
            _Fact(label: 'Covered topics', value: subject?.covered ?? '—'),
            _Fact(label: 'Evidence', value: subject?.evidence ?? '—'),
            if (update.attendanceTotal > 0)
              _Fact(
                label: 'Attendance evidence',
                value:
                    '${update.attendancePresent}/${update.attendanceTotal} present · ${update.attendanceLate} late · ${update.attendanceAbsent} absent · ${update.attendanceExcused} excused',
              ),
            const SizedBox(height: 16),
            TextField(
              controller: next,
              enabled: editable,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Next learning focus',
                hintText: 'What should the class focus on next?',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: support,
              enabled: editable,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Support / home practice guidance',
                hintText: 'Optional factual support guidance for families',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              enabled: editable,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Parent note',
                hintText: 'Short parent-facing context for this subject/week',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy || !editable ? null : onSave,
                  child: const Text('Save draft'),
                ),
                FilledButton(
                  onPressed: busy || !editable || update.deliveredLessons < 1
                      ? null
                      : onPublish,
                  child: const Text('Publish weekly update'),
                ),
              ],
            ),
            if (!editable) ...[
              const SizedBox(height: 10),
              Text(
                update.queued
                    ? 'Publication is queued locally. Families do not see it until the server accepts and freezes the snapshot.'
                    : update.serverPublished
                        ? 'This published family snapshot is historical and cannot be silently rewritten.'
                        : 'This report is not editable by the current Teacher authority.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(value.isEmpty ? '—' : value)),
          ],
        ),
      );
}

class _CanonicalEmpty extends StatelessWidget {
  const _CanonicalEmpty({required this.hasAssignments, required this.onCreate});
  final bool hasAssignments;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.auto_stories_outlined, size: 44),
              const SizedBox(height: 10),
              Text(
                hasAssignments
                    ? 'No weekly subject report has been created yet.'
                    : 'No canonical class-subject assignment has synced for this Teacher yet.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: hasAssignments ? onCreate : null,
                icon: const Icon(Icons.add),
                label: const Text('New weekly subject report'),
              ),
            ],
          ),
        ),
      );
}

class _FlowCard extends StatelessWidget {
  const _FlowCard();

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Teacher does the work once',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in teacherWeeklyFlow)
                    SizedBox(
                      width: 210,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(item.$2),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _CanonicalBoundary extends StatelessWidget {
  const _CanonicalBoundary();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly learning evidence boundary',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                'Planned topics, delivered lessons, curriculum completion and attendance evidence come from canonical academic records. The Teacher may add next-focus and support context, but cannot rewrite those facts here.',
              ),
              SizedBox(height: 6),
              Text(
                'Queued does not mean published. Only a server-published snapshot becomes family-visible, and that snapshot is preserved as historical evidence.',
              ),
            ],
          ),
        ),
      );
}

class _DemoBoundary extends StatelessWidget {
  const _DemoBoundary();

  @override
  Widget build(BuildContext context) => const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Standalone demo content remains local. In a connected school, weekly learning is subject-scoped, evidence-derived and server-published before families can see it.',
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
}

class _NewWeeklyDraft {
  const _NewWeeklyDraft({required this.option, required this.weekStart});
  final TeacherWeeklyLearningOption option;
  final DateTime weekStart;
}

class _NewWeeklyDialog extends StatefulWidget {
  const _NewWeeklyDialog({required this.options});
  final List<TeacherWeeklyLearningOption> options;

  @override
  State<_NewWeeklyDialog> createState() => _NewWeeklyDialogState();
}

class _NewWeeklyDialogState extends State<_NewWeeklyDialog> {
  late TeacherWeeklyLearningOption _option = widget.options.first;
  late DateTime _weekStart = _currentMonday();

  @override
  Widget build(BuildContext context) {
    final weeks = List.generate(
      6,
      (index) => _currentMonday().subtract(Duration(days: index * 7)),
    );
    return AlertDialog(
      title: const Text('New weekly subject report'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _option.classSubjectId,
              decoration: const InputDecoration(labelText: 'Assigned subject'),
              items: [
                for (final item in widget.options)
                  DropdownMenuItem(
                    value: item.classSubjectId,
                    child: Text(item.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _option = widget.options.firstWhere(
                    (item) => item.classSubjectId == value,
                  );
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _isoDate(_weekStart),
              decoration: const InputDecoration(
                labelText: 'Academic week starting Monday',
              ),
              items: [
                for (final week in weeks)
                  DropdownMenuItem(
                    value: _isoDate(week),
                    child: Text(
                      '${_isoDate(week)} – ${_isoDate(week.add(const Duration(days: 6)))}',
                    ),
                  ),
              ],
              onChanged: (value) {
                final parsed = value == null ? null : DateTime.tryParse(value);
                if (parsed != null) setState(() => _weekStart = parsed);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Term: ${_option.term}'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _NewWeeklyDraft(option: _option, weekStart: _weekStart),
          ),
          child: const Text('Create draft'),
        ),
      ],
    );
  }
}

DateTime _currentMonday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
