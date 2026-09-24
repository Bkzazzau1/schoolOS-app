import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../data/administrator_academics_repository.dart';
import '../data/administrator_students_repository.dart';
import '../domain/administrator_academics_models.dart';
import '../domain/administrator_students_models.dart';

class AdministratorAcademicsPage extends StatefulWidget {
  const AdministratorAcademicsPage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.students,
    required this.onChanged,
  });

  final String schoolName;
  final AdministratorAcademicsRepository repository;
  final AdministratorStudentsRepository students;
  final VoidCallback onChanged;

  @override
  State<AdministratorAcademicsPage> createState() =>
      _AdministratorAcademicsPageState();
}

class _AdministratorAcademicsPageState extends State<AdministratorAcademicsPage>
    with SyncRefresh<AdministratorAcademicsPage> {
  bool _loading = true;
  String? _error;
  AdministratorAcademicsSnapshot? _snapshot;
  List<AdministratorStudentRecord> _students = const [];
  String? _fromSessionId;
  String? _toSessionId;
  String? _sourceClassId;
  String? _batchId;
  final Map<String, String> _outcomes = {};
  final Map<String, String> _targets = {};
  final Map<String, bool> _packs = {};

  static const _outcomeLabels = <String, String>{
    'hold': 'Hold',
    'promote': 'Promote',
    'repeat': 'Repeat',
    'transfer_out': 'Transfer out',
    'graduate': 'Graduate',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onSynced() => _load(preserveSelection: true);

  Future<void> _load({bool preserveSelection = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.repository.load();
      final studentSnapshot = await widget.students.load();
      if (!mounted) return;
      final oldFrom = _fromSessionId;
      final oldTo = _toSessionId;
      final oldClass = _sourceClassId;
      setState(() {
        _snapshot = snapshot;
        _students = studentSnapshot.students;
        _loading = false;
        _fromSessionId = preserveSelection &&
                snapshot.sessions.any((item) => item.id == oldFrom)
            ? oldFrom
            : snapshot.activeSession?.id ?? snapshot.sessions.firstOrNull?.id;
        _toSessionId = preserveSelection &&
                snapshot.sessions.any((item) => item.id == oldTo)
            ? oldTo
            : _suggestDestinationSession(snapshot, _fromSessionId);
        _sourceClassId = preserveSelection &&
                snapshot.classes.any((item) => item.id == oldClass)
            ? oldClass
            : snapshot.classes.where((item) => item.isActive).firstOrNull?.id;
      });
      _restoreMatchingBatch();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  String? _suggestDestinationSession(
    AdministratorAcademicsSnapshot snapshot,
    String? fromId,
  ) {
    if (fromId == null) return null;
    final from = snapshot.sessions.where((item) => item.id == fromId).firstOrNull;
    if (from == null) return null;
    final later = snapshot.sessions
        .where(
          (item) =>
              item.id != fromId &&
              item.startsOn.compareTo(from.startsOn) > 0 &&
              !item.isClosed,
        )
        .toList()
      ..sort((a, b) => a.startsOn.compareTo(b.startsOn));
    return later.firstOrNull?.id;
  }

  AdministratorProgressionBatch? _matchingBatch(
    AdministratorAcademicsSnapshot snapshot,
  ) =>
      snapshot.batches
          .where(
            (item) =>
                item.fromSessionId == _fromSessionId &&
                item.toSessionId == _toSessionId &&
                item.sourceClassId == _sourceClassId &&
                item.status != 'cancelled',
          )
          .firstOrNull;

  void _restoreMatchingBatch() {
    final snapshot = _snapshot;
    if (snapshot == null ||
        _fromSessionId == null ||
        _toSessionId == null ||
        _sourceClassId == null) {
      return;
    }
    final batch = _matchingBatch(snapshot);
    _outcomes.clear();
    _targets.clear();
    _packs.clear();
    if (batch == null) {
      _batchId = AdministratorAcademicsRepository.newId();
      return;
    }
    _batchId = batch.id;
    for (final decision in batch.decisions) {
      _outcomes[decision.studentId] = decision.outcome;
      _targets[decision.studentId] = decision.targetClassId;
      _packs[decision.studentId] = decision.recordsPackReady;
    }
  }

  AdministratorAcademicClass? get _sourceClass {
    final snapshot = _snapshot;
    final id = _sourceClassId;
    if (snapshot == null || id == null) return null;
    return snapshot.classes.where((item) => item.id == id).firstOrNull;
  }

  List<AdministratorStudentRecord> get _sourceStudents {
    final source = _sourceClass;
    if (source == null) return const [];
    final values = _students
        .where(
          (student) =>
              student.status == AdministratorStudentStatus.active &&
              student.className.trim().toLowerCase() ==
                  source.name.trim().toLowerCase(),
        )
        .toList();
    values.sort((a, b) => a.name.compareTo(b.name));
    return values;
  }

  String _outcomeFor(AdministratorStudentRecord student) =>
      _outcomes[student.id] ?? 'hold';

  String _targetFor(AdministratorStudentRecord student) {
    final explicit = _targets[student.id];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return _sourceClass?.nextClassId ?? '';
  }

  void _resetBatchSelection() {
    setState(() {
      _batchId = AdministratorAcademicsRepository.newId();
      _outcomes.clear();
      _targets.clear();
      _packs.clear();
    });
    _restoreMatchingBatch();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _applicationBlockReason(AdministratorAcademicsSnapshot snapshot) {
    final fromId = _fromSessionId;
    final toId = _toSessionId;
    final classId = _sourceClassId;
    if (fromId == null || toId == null || classId == null) {
      return 'Choose source session, destination session and source class.';
    }
    final from = snapshot.sessions.where((item) => item.id == fromId).firstOrNull;
    final to = snapshot.sessions.where((item) => item.id == toId).firstOrNull;
    final source = snapshot.classes.where((item) => item.id == classId).firstOrNull;
    if (from == null || to == null || source == null) {
      return 'Sync the selected academic structure before applying progression.';
    }
    if (from.pendingSync) {
      return 'Sync the source session first. A queued session state is not enough to apply progression.';
    }
    if (!from.isClosed) {
      return 'Close the source academic session before applying end-of-session progression.';
    }
    if (to.pendingSync) {
      return 'Sync the destination session before applying progression.';
    }
    if (to.isClosed) {
      return 'The destination academic session is closed.';
    }
    if (source.pendingSync) {
      return 'Sync the source class structure before applying progression.';
    }
    final batch = _matchingBatch(snapshot);
    if (batch?.pendingSync == true) {
      return 'Sync the saved progression review before applying it.';
    }
    for (final student in _sourceStudents) {
      if (_outcomeFor(student) != 'promote') continue;
      final targetId = _targetFor(student);
      final target = snapshot.classes.where((item) => item.id == targetId).firstOrNull;
      if (target == null || target.pendingSync) {
        return 'Sync every promotion target class before applying progression.';
      }
    }
    return null;
  }

  Future<void> _saveBatch({required bool apply}) async {
    final snapshot = _snapshot;
    final source = _sourceClass;
    final fromId = _fromSessionId;
    final toId = _toSessionId;
    final students = _sourceStudents;
    if (snapshot == null || source == null || fromId == null || toId == null) {
      _say('Choose a source session, destination session and class first.');
      return;
    }
    if (fromId == toId) {
      _say('Source and destination session must be different.');
      return;
    }
    if (students.isEmpty) {
      _say('There are no active students in ${source.name}.');
      return;
    }
    if (apply) {
      final blocked = _applicationBlockReason(snapshot);
      if (blocked != null) {
        _say(blocked);
        return;
      }
    }

    final decisions = <AdministratorProgressionDecision>[];
    var hasHold = false;
    for (final student in students) {
      final outcome = _outcomeFor(student);
      if (outcome == 'hold') hasHold = true;
      decisions.add(
        AdministratorProgressionDecision(
          studentId: student.id,
          studentName: student.name,
          outcome: outcome,
          targetClassId: outcome == 'promote' ? _targetFor(student) : '',
          recordsPackReady: outcome == 'transfer_out'
              ? (_packs[student.id] ?? false)
              : false,
          note: '',
        ),
      );
    }
    if (apply && hasHold) {
      _say('Resolve every Hold decision before applying the batch.');
      return;
    }
    if (apply &&
        decisions.any(
          (item) => item.outcome == 'promote' && item.targetClassId.isEmpty,
        )) {
      _say('Every promoted student needs a destination class.');
      return;
    }
    if (apply &&
        decisions.any(
          (item) => item.outcome == 'transfer_out' && !item.recordsPackReady,
        )) {
      _say('Every transfer-out decision needs its records pack marked ready.');
      return;
    }

    var approvedBy = '';
    if (apply) {
      final value = await _askAcademicApprover();
      if (value == null) return;
      approvedBy = value;
    }

    final batch = AdministratorProgressionBatch(
      id: _batchId ?? AdministratorAcademicsRepository.newId(),
      fromSessionId: fromId,
      toSessionId: toId,
      sourceClassId: source.id,
      status: apply ? 'applied' : 'review',
      approvedBy: approvedBy,
      note: '',
      decisions: decisions,
      pendingSync: true,
    );
    await widget.repository.saveBatch(batch);
    widget.onChanged();
    await _load(preserveSelection: true);
    _say(
      apply
          ? 'Progression application queued. Student classes change only after server confirmation.'
          : 'Progression review saved to the sync queue.',
    );
  }

  Future<String?> _askAcademicApprover() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Academic approval'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bulk progression is an academic decision. Administration can process it only after an authorized academic leader approves the class decisions.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Approved by (name and role)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Queue for application'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _editSession([AdministratorAcademicSession? existing]) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final starts = TextEditingController(text: existing?.startsOn ?? '');
    final ends = TextEditingController(text: existing?.endsOn ?? '');
    var status = existing?.status ?? 'planned';
    final result = await showDialog<AdministratorAcademicSession>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            existing == null ? 'New academic session' : 'Edit academic session',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Session name',
                      hintText: '2026/2027',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: '2026-2027',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: starts,
                    decoration: const InputDecoration(
                      labelText: 'Starts on',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ends,
                    decoration: const InputDecoration(
                      labelText: 'Ends on',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'planned', child: Text('Planned')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty ||
                    code.text.trim().isEmpty ||
                    starts.text.trim().isEmpty ||
                    ends.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  AdministratorAcademicSession(
                    id: existing?.id ?? AdministratorAcademicsRepository.newId(),
                    code: code.text.trim(),
                    name: name.text.trim(),
                    startsOn: starts.text.trim(),
                    endsOn: ends.text.trim(),
                    status: status,
                    pendingSync: true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    starts.dispose();
    ends.dispose();
    if (result == null) return;
    await widget.repository.saveSession(result);
    widget.onChanged();
    await _load(preserveSelection: true);
  }

  Future<void> _editTerm([AdministratorAcademicTerm? existing]) async {
    final snapshot = _snapshot;
    if (snapshot == null || snapshot.sessions.isEmpty) return;
    var sessionId =
        existing?.sessionId ?? _fromSessionId ?? snapshot.sessions.first.id;
    final code = TextEditingController(text: existing?.code ?? 'T1');
    final name = TextEditingController(text: existing?.name ?? 'First Term');
    final sequence = TextEditingController(text: '${existing?.sequence ?? 1}');
    final starts = TextEditingController(text: existing?.startsOn ?? '');
    final ends = TextEditingController(text: existing?.endsOn ?? '');
    var status = existing?.status ?? 'planned';
    final result = await showDialog<AdministratorAcademicTerm>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'New academic term' : 'Edit academic term'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: sessionId,
                    decoration: const InputDecoration(labelText: 'Academic session'),
                    items: [
                      for (final item in snapshot.sessions)
                        DropdownMenuItem(value: item.id, child: Text(item.name)),
                    ],
                    onChanged: (value) =>
                        setState(() => sessionId = value ?? sessionId),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Term name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sequence,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sequence'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: starts,
                    decoration: const InputDecoration(
                      labelText: 'Starts on',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ends,
                    decoration: const InputDecoration(
                      labelText: 'Ends on',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'planned', child: Text('Planned')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final order = int.tryParse(sequence.text.trim());
                if (name.text.trim().isEmpty ||
                    code.text.trim().isEmpty ||
                    order == null ||
                    order < 1 ||
                    starts.text.trim().isEmpty ||
                    ends.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  context,
                  AdministratorAcademicTerm(
                    id: existing?.id ?? AdministratorAcademicsRepository.newId(),
                    sessionId: sessionId,
                    code: code.text.trim(),
                    name: name.text.trim(),
                    sequence: order,
                    startsOn: starts.text.trim(),
                    endsOn: ends.text.trim(),
                    status: status,
                    pendingSync: true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
    sequence.dispose();
    starts.dispose();
    ends.dispose();
    if (result == null) return;
    await widget.repository.saveTerm(result);
    widget.onChanged();
    await _load(preserveSelection: true);
  }

  Future<void> _editClass([AdministratorAcademicClass? existing]) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final name = TextEditingController(text: existing?.name ?? '');
    final code = TextEditingController(text: existing?.code ?? '');
    final section = TextEditingController(text: existing?.section ?? 'Primary');
    final order = TextEditingController(text: '${existing?.levelOrder ?? 1}');
    final stream = TextEditingController(text: existing?.stream ?? '');
    var nextClassId = existing?.nextClassId ?? '';
    var terminal = existing?.isTerminal ?? false;
    var active = existing?.isActive ?? true;
    final result = await showDialog<AdministratorAcademicClass>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'New class' : 'Edit class structure'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Class name',
                      hintText: 'Primary 4A',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Class code',
                      hintText: 'PRI4A',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: section,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      hintText: 'Primary / Secondary',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Progression order'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stream,
                    decoration: const InputDecoration(
                      labelText: 'Stream (optional)',
                      hintText: 'A',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: nextClassId,
                    decoration: const InputDecoration(labelText: 'Default next class'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('None')),
                      for (final item
                          in snapshot.classes.where((item) => item.id != existing?.id))
                        DropdownMenuItem(value: item.id, child: Text(item.name)),
                    ],
                    onChanged: terminal
                        ? null
                        : (value) =>
                            setState(() => nextClassId = value ?? ''),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Terminal class'),
                    subtitle: const Text(
                      'Graduation is allowed only from a terminal class.',
                    ),
                    value: terminal,
                    onChanged: (value) => setState(() {
                      terminal = value;
                      if (terminal) nextClassId = '';
                    }),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active class'),
                    value: active,
                    onChanged: (value) => setState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final levelOrder = int.tryParse(order.text.trim());
                if (name.text.trim().isEmpty ||
                    code.text.trim().isEmpty ||
                    section.text.trim().isEmpty ||
                    levelOrder == null ||
                    levelOrder < 1) {
                  return;
                }
                Navigator.pop(
                  context,
                  AdministratorAcademicClass(
                    id: existing?.id ?? AdministratorAcademicsRepository.newId(),
                    code: code.text.trim(),
                    name: name.text.trim(),
                    section: section.text.trim(),
                    levelOrder: levelOrder,
                    stream: stream.text.trim(),
                    nextClassId: nextClassId,
                    isTerminal: terminal,
                    isActive: active,
                    pendingSync: true,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    code.dispose();
    section.dispose();
    order.dispose();
    stream.dispose();
    if (result == null) return;
    await widget.repository.saveClass(result);
    widget.onChanged();
    await _load(preserveSelection: true);
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
    final snapshot = _snapshot!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _header(snapshot),
        const SizedBox(height: 18),
        _sessionsCard(snapshot),
        const SizedBox(height: 16),
        _termsCard(snapshot),
        const SizedBox(height: 16),
        _classesCard(snapshot),
        const SizedBox(height: 16),
        _progressionCard(snapshot),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _header(AdministratorAcademicsSnapshot snapshot) {
    final activeSession = snapshot.activeSession;
    final activeTerm =
        activeSession == null ? null : snapshot.activeTermFor(activeSession.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION · ACADEMIC STRUCTURE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Sessions, Terms, Classes & Progression',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.schoolName} · ${activeSession?.name ?? 'No active session'}${activeTerm == null ? '' : ' · ${activeTerm.name}'}',
        ),
        const SizedBox(height: 10),
        const _Boundary(
          text:
              'Class progression is canonical and append-only. A bulk batch is not applied merely because it is queued on this device; server confirmation is the authority.',
        ),
      ],
    );
  }

  Widget _sessionsCard(AdministratorAcademicsSnapshot snapshot) => _SectionCard(
        title: 'Academic sessions',
        subtitle: 'Only one session can be active for a school at a time.',
        action: FilledButton.icon(
          onPressed: () => _editSession(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New session'),
        ),
        child: snapshot.sessions.isEmpty
            ? const Text('No academic sessions configured yet.')
            : Column(
                children: [
                  for (final item in snapshot.sessions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month_outlined),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${item.startsOn} → ${item.endsOn} · ${item.code}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StateChip(label: item.status, pending: item.pendingSync),
                          IconButton(
                            onPressed: () => _editSession(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );

  Widget _termsCard(AdministratorAcademicsSnapshot snapshot) => _SectionCard(
        title: 'Terms',
        subtitle:
            'Terms are ordered inside a session and their dates must stay within the session.',
        action: FilledButton.tonalIcon(
          onPressed: snapshot.sessions.isEmpty ? null : () => _editTerm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New term'),
        ),
        child: snapshot.terms.isEmpty
            ? const Text('No terms configured yet.')
            : Column(
                children: [
                  for (final item in snapshot.terms)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${item.sequence}')),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('${item.startsOn} → ${item.endsOn}'),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StateChip(label: item.status, pending: item.pendingSync),
                          IconButton(
                            onPressed: () => _editTerm(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );

  Widget _classesCard(AdministratorAcademicsSnapshot snapshot) => _SectionCard(
        title: 'Class progression structure',
        subtitle:
            'Order classes once, then define the normal next-class route. Repeat never uses the next-class route.',
        action: FilledButton.tonalIcon(
          onPressed: () => _editClass(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New class'),
        ),
        child: snapshot.classes.isEmpty
            ? const Text('No canonical classes configured yet.')
            : Column(
                children: [
                  for (final item in snapshot.classes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${item.levelOrder}')),
                      title: Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${item.section}${item.stream.isEmpty ? '' : ' · Stream ${item.stream}'} · ${item.isTerminal ? 'Terminal class' : _nextClassLabel(snapshot, item)}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.pendingSync) const Chip(label: Text('Queued')),
                          if (!item.isActive) const Chip(label: Text('Inactive')),
                          IconButton(
                            onPressed: () => _editClass(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );

  String _nextClassLabel(
    AdministratorAcademicsSnapshot snapshot,
    AdministratorAcademicClass item,
  ) {
    if (item.nextClassId.isEmpty) return 'Next class not set';
    final next = snapshot.classes
        .where((candidate) => candidate.id == item.nextClassId)
        .firstOrNull;
    return next == null ? 'Next class pending sync' : 'Next: ${next.name}';
  }

  Widget _progressionCard(AdministratorAcademicsSnapshot snapshot) {
    final sourceStudents = _sourceStudents;
    final matchingBatch = _matchingBatch(snapshot);
    final applyBlocked = _applicationBlockReason(snapshot);
    return _SectionCard(
      title: 'Bulk class progression',
      subtitle:
          'Review every pupil individually. Hold blocks application; Transfer requires records pack; Graduate is server-limited to terminal classes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _fromSessionId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'From session'),
                  items: [
                    for (final item in snapshot.sessions)
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _fromSessionId = value;
                      _toSessionId = _suggestDestinationSession(snapshot, value);
                    });
                    _resetBatchSelection();
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _toSessionId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To session'),
                  items: [
                    for (final item
                        in snapshot.sessions.where((item) => item.id != _fromSessionId))
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _toSessionId = value);
                    _resetBatchSelection();
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _sourceClassId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Source class'),
                  items: [
                    for (final item in snapshot.classes.where((item) => item.isActive))
                      DropdownMenuItem(value: item.id, child: Text(item.name)),
                  ],
                  onChanged: (value) {
                    setState(() => _sourceClassId = value);
                    _resetBatchSelection();
                  },
                ),
              ];
              if (constraints.maxWidth < 800) {
                return Column(
                  children: [
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: field,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (final field in fields)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: field,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (matchingBatch != null) _BatchStateBanner(batch: matchingBatch),
          if (matchingBatch != null) const SizedBox(height: 12),
          if (applyBlocked != null && matchingBatch?.isApplied != true) ...[
            _Boundary(text: applyBlocked),
            const SizedBox(height: 12),
          ],
          if (sourceStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No active pupils match the selected canonical class on this device.',
              ),
            )
          else ...[
            for (final student in sourceStudents)
              _studentDecisionRow(snapshot, student),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: matchingBatch?.isApplied == true ||
                          matchingBatch?.queuedForApply == true
                      ? null
                      : () => _saveBatch(apply: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save review'),
                ),
                FilledButton.icon(
                  onPressed: matchingBatch?.isApplied == true ||
                          matchingBatch?.queuedForApply == true ||
                          applyBlocked != null
                      ? null
                      : () => _saveBatch(apply: true),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Apply progression'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _studentDecisionRow(
    AdministratorAcademicsSnapshot snapshot,
    AdministratorStudentRecord student,
  ) {
    final outcome = _outcomeFor(student);
    final source = _sourceClass;
    final canGraduate = source?.isTerminal ?? false;
    final promoteTargets = snapshot.classes
        .where(
          (item) =>
              item.isActive &&
              source != null &&
              item.levelOrder > source.levelOrder,
        )
        .toList();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${student.id} · ${student.className}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final controls = Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    initialValue: outcome,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Decision',
                      isDense: true,
                    ),
                    items: [
                      for (final entry in _outcomeLabels.entries)
                        if (entry.key != 'graduate' || canGraduate)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                    ],
                    onChanged: (value) =>
                        setState(() => _outcomes[student.id] = value ?? 'hold'),
                  ),
                ),
                if (outcome == 'promote')
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _targetFor(student).isEmpty ? null : _targetFor(student),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Moves to',
                        isDense: true,
                      ),
                      items: [
                        for (final item in promoteTargets)
                          DropdownMenuItem(value: item.id, child: Text(item.name)),
                      ],
                      onChanged: (value) =>
                          setState(() => _targets[student.id] = value ?? ''),
                    ),
                  ),
                if (outcome == 'transfer_out')
                  FilterChip(
                    selected: _packs[student.id] ?? false,
                    onSelected: (value) =>
                        setState(() => _packs[student.id] = value),
                    label: const Text('Records pack ready'),
                  ),
              ],
            );
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [identity, const SizedBox(height: 10), controls],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 14),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BatchStateBanner extends StatelessWidget {
  const _BatchStateBanner({required this.batch});
  final AdministratorProgressionBatch batch;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = batch.isApplied
        ? (
            Icons.check_circle_rounded,
            'Server confirmed: this batch has been applied.'
          )
        : batch.queuedForApply
            ? (
                Icons.cloud_upload_outlined,
                'Application queued. Student classes have not been confirmed changed yet.'
              )
            : batch.pendingSync
                ? (
                    Icons.cloud_upload_outlined,
                    'Review changes are queued for sync.'
                  )
                : (
                    Icons.fact_check_outlined,
                    'Server-confirmed ${batch.status} batch.'
                  );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.pending});
  final String label;
  final bool pending;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: pending ? const Icon(Icons.cloud_upload_outlined, size: 16) : null,
        label: Text(pending ? '$label · queued' : label),
      );
}

class _Boundary extends StatelessWidget {
  const _Boundary({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
