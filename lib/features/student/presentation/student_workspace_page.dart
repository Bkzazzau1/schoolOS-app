import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/database/local_database.dart';
import '../../../core/tenancy/school_session_controller.dart';
import '../../../shared/models/school_membership.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../data/student_cbt_repository.dart';
import '../data/student_repository.dart';

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

class _StudentWorkspacePageState extends State<StudentWorkspacePage> {
  late final StudentRepository _repository;
  late final StudentCbtRepository _cbtRepository;
  Map<String, Object?> _state = {};
  Timer? _timer;
  int _tab = 0;
  bool _busy = true;
  String? _error;
  final _task = TextEditingController();
  bool get _demo => !LocalDatabase.blockDemoSeeds;
  bool get _submitted => _state['submitted'] == true;
  int get _remaining => _state['deadline'] == null
      ? 600
      : DateTime.parse(
          _state['deadline']! as String,
        ).difference(DateTime.now()).inSeconds.clamp(0, 600);

  // Real, teacher-published CBTs for this student's real class.
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

  Widget _performance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('My performance', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      if (!_demo)
        const Text(
          'Your school results are not connected yet. No official marks are available here.',
        ),
      if (_demo) ...[
        const Text(
          'Sample term results · Demo data, not official school marks',
        ),
        for (final entry in {
          'Mathematics': 78,
          'English': 84,
          'Basic Science': 81,
        }.entries)
          Card(
            child: ListTile(
              title: Text(entry.key),
              subtitle: LinearProgressIndicator(value: entry.value / 100),
              trailing: Text('${entry.value}%'),
            ),
          ),
        const Text(
          'Study focus: practise fractions and algebra. Ask your teacher about topics you find difficult.',
        ),
      ],
      const SizedBox(height: 24),
      Text(
        'CBT practice result',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text(
        _submitted
            ? '${_state['score']} / ${studentPracticeQuestions.length} correct · Practice only'
            : 'Complete the maths practice to see your score.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('My class CBTs', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
          'Real practice tests your teacher has published for your class, with a real timer and real questions.',
        ),
        const SizedBox(height: 8),
        if (_cbtError != null)
          ListTile(
            title: Text(_cbtError!),
            trailing: TextButton(onPressed: _loadCbtSets, child: const Text('Retry')),
          )
        else if (_cbtSets.isEmpty)
          const Text('No CBT has been published for your class yet.')
        else
          for (final available in _cbtSets) _cbtSetCard(available),
      ],
    );
  }

  Widget _cbtSetCard(StudentCbtAvailableSet available) {
    final set = available.set;
    final busy = _cbtBusySetId == set.id;
    final open = _openSetId == set.id;
    final answers = available.answers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(set.title, style: Theme.of(context).textTheme.titleMedium),
            Text('${set.questionCount} questions · ${set.durationMinutes} minutes'),
            const SizedBox(height: 8),
            if (available.submitted)
              Text('Submitted · Score: ${available.score}/${set.questionCount}')
            else if (!available.started)
              FilledButton(
                onPressed: busy ? null : () async {
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
              ),
              for (var i = 0; i < set.items.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${i + 1}. ${set.items[i].prompt}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (var j = 0; j < set.items[i].options.length; j++)
                          OutlinedButton(
                            onPressed: busy || _remainingFor(available) == 0
                                ? null
                                : () => _runCbt(set.id, () => _cbtRepository.answer(set.id, i, j)),
                            child: Text('${answers[i] == j ? '✓ ' : ''}${set.items[i].options[j]}'),
                          ),
                      ],
                    ),
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
      ),
    );
  }

  Widget _cbt() {
    final answers = List<int?>.from(
      _state['answers'] as List? ??
          List<int?>.filled(studentPracticeQuestions.length, null),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _classCbts(),
        const Divider(height: 32),
        if (!_demo)
          const Text(
            'Sample practice questions are not offered outside demo mode. Ask your teacher for a real, published CBT.',
          )
        else ...[
          Text(
            'Practice questions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Sample questions, not assigned by a teacher. 5 questions · 10 minutes · One saved attempt. Answers save on this device. This is not an official exam.',
          ),
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
          ),
          for (var i = 0; i < studentPracticeQuestions.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${i + 1}. ${studentPracticeQuestions[i].prompt}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (
                      var j = 0;
                      j < studentPracticeQuestions[i].options.length;
                      j++
                    )
                      OutlinedButton(
                        onPressed: _busy || _submitted || _remaining == 0
                            ? null
                            : () => _run(() => _repository.answer(i, j)),
                        child: Text(
                          '${answers[i] == j ? '✓ ' : ''}${studentPracticeQuestions[i].options[j]}',
                        ),
                      ),
                    if (_submitted)
                      Text(
                        'Correct answer: ${studentPracticeQuestions[i].options[studentPracticeQuestions[i].correct]}. ${studentPracticeQuestions[i].explanation}',
                      ),
                  ],
                ),
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
      ],
    );
  }

  Widget _planner() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('My study plan', style: Theme.of(context).textTheme.headlineSmall),
      const Text(
        'Personal reminders saved on this device. These are not teacher-assigned homework.',
      ),
      TextField(
        controller: _task,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Study task'),
      ),
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
        child: const Text('Add task'),
      ),
      for (var i = 0; i < _tasks.length; i++)
        CheckboxListTile(
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
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Student · ${widget.membership.schoolName}'),
      actions: [
        if (widget.schoolSession.canSwitchSchool)
          PopupMenuButton<SchoolMembership>(
            tooltip: 'Switch school',
            onSelected: (membership) async {
              if (_busy) return;
              await widget.schoolSession.selectSchool(membership);
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => DashboardPage(
                    membership: membership,
                    localDatabase: widget.localDatabase,
                    schoolSession: widget.schoolSession,
                  ),
                ),
              );
            },
            itemBuilder: (_) => [
              for (final m in widget.schoolSession.memberships)
                PopupMenuItem(
                  value: m,
                  child: Text('${m.schoolName} · ${m.roleLabel}'),
                ),
            ],
          ),
      ],
    ),
    body: SingleChildScrollView(
      key: ValueKey(_tab),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('My student workspace'),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              title: Text(_error!),
              trailing: TextButton(
                onPressed: _busy ? null : () => _run(() async {}),
                child: const Text('Retry'),
              ),
            ),
          const SizedBox(height: 16),
          if (_error == null)
            switch (_tab) {
              0 => _performance(),
              1 => _cbt(),
              _ => _planner(),
            },
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (tab) => setState(() => _tab = tab),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.insights), label: 'Performance'),
        NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'CBT'),
        NavigationDestination(icon: Icon(Icons.checklist), label: 'Study plan'),
      ],
    ),
  );
}
