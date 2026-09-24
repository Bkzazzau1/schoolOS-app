import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/appearance/school_logo.dart';
import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_scope.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../../sync_center/presentation/sync_center_page.dart';
import '../data/student_cbt_repository.dart';
import '../data/student_repository.dart';

class _StudentNavItem {
  const _StudentNavItem(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

const _studentNavigation = <_StudentNavItem>[
  _StudentNavItem('profile', 'My profile', Icons.badge_outlined),
  _StudentNavItem('performance', 'Performance', Icons.insights_rounded),
  _StudentNavItem('cbt', 'CBT', Icons.quiz_outlined),
  _StudentNavItem('planner', 'Study plan', Icons.checklist_rounded),
];

class StudentWorkspacePage extends StatefulWidget {
  const StudentWorkspacePage({
    super.key,
    required this.membership,
    required this.localDatabase,
    required this.schoolSession,
  });
  final SchoolMembership membership;
  final LocalDatabase localDatabase;
  final SchoolSessionController schoolSession;
  @override
  State<StudentWorkspacePage> createState() => _StudentWorkspacePageState();
}

class _StudentWorkspacePageState extends State<StudentWorkspacePage>
    with SyncRefresh<StudentWorkspacePage> {
  late final StudentRepository _repository;
  late final StudentCbtRepository _cbtRepository;
  Map<String, Object?> _state = {};
  Timer? _timer;
  String _activeKey = 'profile';
  bool _busy = true;
  String? _error;
  int _pendingSyncCount = 0;
  final _task = TextEditingController();
  bool get _demo => !LocalDatabase.blockDemoSeeds;
  bool get _submitted => _state['submitted'] == true;
  int get _remaining => _state['deadline'] == null
      ? 600
      : DateTime.parse(
          _state['deadline']! as String,
        ).difference(DateTime.now()).inSeconds.clamp(0, 600);

  Map<String, Object?> get _canonicalProfile {
    final raw = _state['canonicalProfile'];
    return raw is Map ? Map<String, Object?>.from(raw) : const {};
  }

  List<Map<String, Object?>> get _enrollmentHistory => [
        for (final item in (_canonicalProfile['enrollmentHistory'] as List? ?? const []))
          if (item is Map) Map<String, Object?>.from(item),
      ];

  List<Map<String, Object?>> get _progressionHistory => [
        for (final item in (_canonicalProfile['progressionHistory'] as List? ?? const []))
          if (item is Map) Map<String, Object?>.from(item),
      ];

  _StudentNavItem get _activeItem => _studentNavigation.firstWhere(
        (item) => item.key == _activeKey,
        orElse: () => _studentNavigation.first,
      );

  List<StudentCbtAvailableSet> _cbtSets = const [];
  bool _cbtLoading = true;
  String? _cbtError;
  String? _cbtBusySetId;
  String? _openSetId;

  int _remainingFor(StudentCbtAvailableSet available) {
    final deadline = available.deadline;
    if (deadline == null) return 0;
    return deadline.difference(DateTime.now()).inSeconds.clamp(0, 24 * 60 * 60);
  }

  @override
  void initState() {
    super.initState();
    _repository = StudentRepository(
      database: widget.localDatabase,
      session: widget.schoolSession,
      membership: widget.membership,
    );
    _cbtRepository = StudentCbtRepository(
      localDatabase: widget.localDatabase,
      schoolSession: widget.schoolSession,
    );
    _run(() async {});
    _loadCbtSets();
    _refreshPendingCount();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_busy && _state['deadline'] != null && !_submitted) {
        if (_remaining == 0) {
          _run(_repository.submit);
        } else {
          setState(() {});
        }
      }
      final openId = _openSetId;
      if (openId != null && _cbtBusySetId == null) {
        StudentCbtAvailableSet? open;
        for (final set in _cbtSets) {
          if (set.set.id == openId) open = set;
        }
        if (open != null && open.started && !open.submitted) {
          if (_remainingFor(open) == 0) {
            _runCbt(openId, () => _cbtRepository.submit(openId));
          } else {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void onSynced() {
    _refreshPendingCount();
    _loadCbtSets();
    _reloadWorkspaceState();
  }

  Future<void> _reloadWorkspaceState() async {
    try {
      final state = await _repository.load();
      if (mounted) setState(() => _state = state);
    } catch (_) {
      // The existing workspace error state is reserved for explicit user actions.
    }
  }

  void _refreshPendingCount() {
    final count = widget.localDatabase.pendingCount(tenantId: widget.membership.schoolId);
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _openSyncCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SyncCenterPage(localDatabase: widget.localDatabase, membership: widget.membership),
      ),
    );
    _refreshPendingCount();
  }

  Future<void> _switchSchool(SchoolMembership membership) async {
    if (membership.id == widget.membership.id || _busy) return;
    await widget.schoolSession.selectSchool(membership);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DashboardPage(
          membership: membership,
          localDatabase: widget.localDatabase,
          schoolSession: widget.schoolSession,
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      final state = await _repository.load();
      if (mounted) setState(() => _state = state);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save or load your work. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _refreshPendingCount();
  }

  Future<void> _loadCbtSets() async {
    setState(() => _cbtLoading = true);
    try {
      final sets = await _cbtRepository.loadAvailableSets();
      if (mounted) {
        setState(() {
          _cbtSets = sets;
          _cbtError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cbtError = 'Could not load your class CBTs. Please retry.');
    } finally {
      if (mounted) setState(() => _cbtLoading = false);
    }
  }

  Future<void> _runCbt(String setId, Future<void> Function() action) async {
    setState(() {
      _cbtBusySetId = setId;
      _cbtError = null;
    });
    try {
      await action();
      final sets = await _cbtRepository.loadAvailableSets();
      if (mounted) setState(() => _cbtSets = sets);
    } catch (_) {
      if (mounted) setState(() => _cbtError = 'Could not save your CBT progress. Please retry.');
    } finally {
      if (mounted) setState(() => _cbtBusySetId = null);
    }
    _refreshPendingCount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _task.dispose();
    super.dispose();
  }

  List<Map<String, Object?>> get _tasks => [
    for (final item in (_state['tasks'] as List? ?? []))
      Map<String, Object?>.from(item as Map),
  ];

  void _select(String key) {
    if (!_studentNavigation.any((item) => item.key == key) || key == _activeKey) return;
    setState(() => _activeKey = key);
  }

  Widget _sectionHeader({required String title, required String description}) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STUDENT PORTAL · ${_activeItem.label.toUpperCase()}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
        ),
      ],
    ),
  );

  String _dateLabel(Object? raw) {
    if (raw is! String || raw.isEmpty) return '—';
    final value = DateTime.tryParse(raw);
    if (value == null) return raw;
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _progressionLabel(Map<String, Object?> event) {
    final workflow = event['workflow'] as String? ?? 'Class update';
    final from = event['fromClass'] as String? ?? '';
    final to = event['toClass'] as String? ?? '';
    if (from.isNotEmpty && to.isNotEmpty) return '$workflow · $from → $to';
    if (from.isNotEmpty) return '$workflow · $from';
    if (to.isNotEmpty) return '$workflow · $to';
    return workflow;
  }

  Widget _profile() {
    final profile = _canonicalProfile;
    if (profile.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          _sectionHeader(
            title: 'My student record',
            description: 'Your official identity, current class and class history come from the canonical SchoolOS roster.',
          ),
          const _SectionCard(
            title: 'Waiting for canonical profile',
            subtitle: 'The device has not received your private server profile yet.',
            child: Text('Connect and sync. SchoolOS will never substitute demo student details for a real signed-in pupil.'),
          ),
        ],
      );
    }

    final status = profile['status'] as String? ?? 'unknown';
    final className = profile['className'] as String? ?? 'No active class';
    final section = profile['academicSection'] as String? ?? '—';
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _sectionHeader(
          title: 'My student record',
          description: 'Read-only facts from your canonical school record. Current class is determined only by your active enrollment.',
        ),
        _SectionCard(
          title: profile['name'] as String? ?? 'Student',
          subtitle: '${profile['admissionNumber'] ?? '—'} · ${profile['studentId'] ?? '—'}',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoTile(label: 'Current class', value: className),
              _InfoTile(label: 'Section', value: section),
              _InfoTile(label: 'Status', value: status),
              _InfoTile(label: 'Date of birth', value: _dateLabel(profile['dateOfBirth'])),
              _InfoTile(label: 'Gender', value: profile['gender'] as String? ?? '—'),
              _InfoTile(label: 'Primary guardian', value: profile['primaryGuardian'] as String? ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Class & enrollment history',
          subtitle: 'Old placements are preserved. Promotion or class movement creates history instead of overwriting the previous class.',
          child: _enrollmentHistory.isEmpty
              ? const Text('No canonical enrollment history has synced yet.')
              : Column(
                  children: [
                    for (final item in _enrollmentHistory)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item['status'] == 'active'
                              ? Icons.school_rounded
                              : Icons.history_rounded,
                        ),
                        title: Text(
                          item['className'] as String? ?? 'Class',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${item['academicSection'] ?? '—'} · ${_dateLabel(item['startedAt'])} → ${item['endedAt'] == null ? 'Current' : _dateLabel(item['endedAt'])}',
                        ),
                        trailing: Chip(label: Text(item['status'] as String? ?? 'unknown')),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Progression decisions',
          subtitle: 'Promotion, class change, transfer and graduation decisions are preserved with their approval state.',
          child: _progressionHistory.isEmpty
              ? const Text('No progression decision has been recorded yet.')
              : Column(
                  children: [
                    for (final event in _progressionHistory)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.trending_up_rounded),
                        title: Text(
                          _progressionLabel(event),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${event['status'] ?? 'unknown'} · ${_dateLabel(event['completedAt'] ?? event['requestedAt'])}${(event['approvedBy'] as String? ?? '').isEmpty ? '' : ' · Approved by ${event['approvedBy']}'}',
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _performance() => ListView(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
    children: [
      _sectionHeader(
        title: 'My performance',
        description: 'Evidence from your own real records, clearly marked when it is only a sample.',
      ),
      _SectionCard(
        title: 'Term results',
        subtitle: !_demo
            ? 'Connected to your school\'s real records.'
            : 'Sample term results · Demo data, not official school marks.',
        child: !_demo
            ? const Text('Your school results are not connected yet. No official marks are available here.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in const {
                    'Mathematics': 78,
                    'English': 84,
                    'Basic Science': 81,
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                          SizedBox(
                            width: 140,
                            child: LinearProgressIndicator(value: entry.value / 100),
                          ),
                          const SizedBox(width: 10),
                          Text('${entry.value}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Text(
                    'Study focus: practise fractions and algebra. Ask your teacher about topics you find difficult.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'CBT practice result',
        subtitle: 'Your saved practice attempt, for your own review only.',
        child: Text(
          _submitted
              ? '${_state['score']} / ${studentPracticeQuestions.length} correct · Practice only'
              : 'Complete the maths practice to see your score.',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );

  Widget _classCbts() {
    if (_cbtLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }
    return _SectionCard(
      title: 'My class CBTs',
      subtitle: 'Real practice tests your teacher has published for your class, with a real timer and real questions.',
      child: _cbtError != null
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_cbtError!),
              trailing: TextButton(onPressed: _loadCbtSets, child: const Text('Retry')),
            )
          : _cbtSets.isEmpty
              ? Text(
                  'No CBT has been published for your class yet.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final available in _cbtSets) ...[
                      _cbtSetCard(available),
                      if (available != _cbtSets.last) const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }

  Widget _cbtSetCard(StudentCbtAvailableSet available) {
    final scheme = Theme.of(context).colorScheme;
    final set = available.set;
    final busy = _cbtBusySetId == set.id;
    final open = _openSetId == set.id;
    final answers = available.answers;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(set.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
            '${set.questionCount} questions · ${set.durationMinutes} minutes',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (available.submitted)
            _StatusChip(label: 'Submitted · Score ${available.score}/${set.questionCount}', tone: scheme.primaryContainer, onTone: scheme.onPrimaryContainer)
          else if (!available.started)
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      await _runCbt(set.id, () => _cbtRepository.startAttempt(set.id));
                      if (mounted) setState(() => _openSetId = set.id);
                    },
              child: const Text('Start CBT'),
            )
          else if (!open)
            OutlinedButton(
              onPressed: () => setState(() => _openSetId = set.id),
              child: Text('Resume · ${_remainingFor(available) ~/ 60}:${(_remainingFor(available) % 60).toString().padLeft(2, '0')} left'),
            )
          else ...[
            Text(
              'Time left: ${_remainingFor(available) ~/ 60}:${(_remainingFor(available) % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < set.items.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${i + 1}. ${set.items[i].prompt}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    for (var j = 0; j < set.items[i].options.length; j++)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                          onPressed: busy || _remainingFor(available) == 0
                              ? null
                              : () => _runCbt(set.id, () => _cbtRepository.answer(set.id, i, j)),
                          child: Text('${answers[i] == j ? '✓ ' : ''}${set.items[i].options[j]}'),
                        ),
                      ),
                  ],
                ),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Submit CBT?'),
                          content: Text(
                            '${answers.where((a) => a == null).length} unanswered questions. You cannot change answers after submitting.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Continue working'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await _runCbt(set.id, () => _cbtRepository.submit(set.id));
                      }
                    },
              child: const Text('Submit CBT'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cbt() {
    final answers = List<int?>.from(
      _state['answers'] as List? ??
          List<int?>.filled(studentPracticeQuestions.length, null),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _sectionHeader(
          title: 'CBT Practice',
          description: 'Real, teacher-published tests, plus optional sample questions for extra practice.',
        ),
        _classCbts(),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Practice questions',
          subtitle: !_demo
              ? 'Not offered outside demo mode.'
              : 'Sample questions, not assigned by a teacher · 5 questions · 10 minutes · This is not an official exam.',
          child: !_demo
              ? const Text('Ask your teacher for a real, published CBT.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_state['deadline'] == null)
                      FilledButton(
                        onPressed: _busy ? null : () => _run(_repository.startPractice),
                        child: const Text('Start practice'),
                      )
                    else ...[
                      Text(
                        _submitted
                            ? 'Submitted · Score: ${_state['score']}/5'
                            : 'Time left: ${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < studentPracticeQuestions.length; i++)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${i + 1}. ${studentPracticeQuestions[i].prompt}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              for (var j = 0; j < studentPracticeQuestions[i].options.length; j++)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                                    onPressed: _busy || _submitted || _remaining == 0
                                        ? null
                                        : () => _run(() => _repository.answer(i, j)),
                                    child: Text(
                                      '${answers[i] == j ? '✓ ' : ''}${studentPracticeQuestions[i].options[j]}',
                                    ),
                                  ),
                                ),
                              if (_submitted) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Correct answer: ${studentPracticeQuestions[i].options[studentPracticeQuestions[i].correct]}. ${studentPracticeQuestions[i].explanation}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (!_submitted)
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Submit practice?'),
                                      content: Text(
                                        '${answers.where((a) => a == null).length} unanswered questions. You cannot change answers after submitting.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Continue working'),
                                        ),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Submit'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && mounted) {
                                    await _run(_repository.submit);
                                  }
                                },
                          child: const Text('Finish practice'),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _planner() => ListView(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
    children: [
      _sectionHeader(
        title: 'My study plan',
        description: 'Personal reminders saved on this device. These are not teacher-assigned homework.',
      ),
      _SectionCard(
        title: 'Study tasks',
        subtitle: 'Add a reminder for yourself and check it off when done.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _task,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Study task', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_task.text.trim().isEmpty) return;
                          final tasks = _tasks
                            ..add({'title': _task.text.trim(), 'done': false});
                          _run(() async {
                            await _repository.saveTasks(tasks);
                            _task.clear();
                          });
                        },
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No study tasks yet.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              )
            else
              for (var i = 0; i < _tasks.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tasks[i]['title']! as String),
                  value: _tasks[i]['done'] == true,
                  onChanged: _busy
                      ? null
                      : (done) {
                          final tasks = _tasks;
                          tasks[i]['done'] = done;
                          _run(() => _repository.saveTasks(tasks));
                        },
                  secondary: IconButton(
                    tooltip: 'Delete task',
                    onPressed: _busy
                        ? null
                        : () {
                            final tasks = _tasks..removeAt(i);
                            _run(() => _repository.saveTasks(tasks));
                          },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
          ],
        ),
      ),
    ],
  );

  Widget _content() => switch (_activeKey) {
    'profile' => _profile(),
    'cbt' => _cbt(),
    'planner' => _planner(),
    _ => _performance(),
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 700 ? _phone() : _wide(constraints),
  );

  Widget _body(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_busy || _cbtBusySetId != null) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: ListTile(
            tileColor: Theme.of(context).colorScheme.errorContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(_error!),
            trailing: TextButton(
              onPressed: _busy ? null : () => _run(() async {}),
              child: const Text('Retry'),
            ),
          ),
        ),
      Expanded(
        child: Padding(
          key: const ValueKey('student-workspace-content'),
          padding: const EdgeInsets.all(20),
          child: _error == null ? _content() : const SizedBox.shrink(),
        ),
      ),
    ],
  );

  Widget _phone() => Scaffold(
    appBar: AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.membership.schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Text('Student Portal', style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        if (widget.schoolSession.canSwitchSchool)
          _SchoolSwitcherButton(memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
        NotificationsBell(membership: widget.membership),
        IconButton(
          tooltip: _pendingSyncCount == 0 ? 'Sync Center' : 'Sync Center · $_pendingSyncCount pending',
          onPressed: _openSyncCenter,
          icon: Badge(
            isLabelVisible: _pendingSyncCount > 0,
            label: Text('$_pendingSyncCount'),
            child: const Icon(Icons.cloud_sync_outlined),
          ),
        ),
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Student menu',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
      ],
    ),
    endDrawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(title: Text('Student Portal', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Learning workspace')),
            const Divider(),
            for (final item in _studentNavigation)
              ListTile(
                selected: item.key == _activeKey,
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () {
                  Navigator.of(context).pop();
                  _select(item.key);
                },
              ),
          ],
        ),
      ),
    ),
    body: Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(_activeItem.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        Expanded(child: _body(context)),
      ],
    ),
  );

  Widget _wide(BoxConstraints constraints) {
    final extended = constraints.maxWidth >= 1180;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Container(
              width: extended ? 260 : 88,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: extended
                        ? ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SchoolLogo(schoolName: widget.membership.schoolName),
                            title: const Text('SchoolOS', style: TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('Student Portal'),
                          )
                        : SchoolLogo(schoolName: widget.membership.schoolName),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in _studentNavigation)
                          ListTile(
                            selected: item.key == _activeKey,
                            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                            leading: Icon(item.icon),
                            title: extended ? Text(item.label) : null,
                            onTap: () => _select(item.key),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Student Workspace', style: TextStyle(fontWeight: FontWeight.w900)),
                              Text(_activeItem.label),
                            ],
                          ),
                        ),
                        if (widget.schoolSession.canSwitchSchool)
                          _SchoolSwitcherButton(memberships: widget.schoolSession.memberships, onSelected: _switchSchool),
                        const SizedBox(width: 8),
                        NotificationsBell(membership: widget.membership),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: _openSyncCenter,
                          icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                          label: Text(_pendingSyncCount == 0 ? 'Synced' : '$_pendingSyncCount pending'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _body(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolSwitcherButton extends StatelessWidget {
  const _SchoolSwitcherButton({required this.memberships, required this.onSelected});

  final List<SchoolMembership> memberships;
  final ValueChanged<SchoolMembership> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SchoolMembership>(
        tooltip: 'Switch school',
        onSelected: onSelected,
        icon: const Icon(Icons.swap_horiz_rounded),
        itemBuilder: (_) => [
          for (final membership in memberships)
            PopupMenuItem(
              value: membership,
              child: Text('${membership.schoolName} · ${membership.roleLabel}'),
            ),
        ],
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone, required this.onTone});

  final String label;
  final Color tone;
  final Color onTone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: onTone),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: onTone)),
          ],
        ),
      );
}
