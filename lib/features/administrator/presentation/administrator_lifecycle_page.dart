import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../alumni/data/alumni_server_api.dart';
import '../../alumni/presentation/alumni_management_page.dart';
import '../../proprietor/presentation/owner_dialogs.dart';
import '../data/administrator_lifecycle_repository.dart';
import '../data/administrator_students_repository.dart';
import '../domain/administrator_lifecycle_models.dart';
import '../domain/administrator_students_models.dart';
import 'administrator_lifecycle_dialogs.dart';

class AdministratorLifecyclePage extends StatefulWidget {
  const AdministratorLifecyclePage({
    super.key,
    required this.schoolName,
    required this.repository,
    required this.students,
  });

  final String schoolName;
  final AdministratorLifecycleRepository repository;
  final AdministratorStudentsRepository students;

  @override
  State<AdministratorLifecyclePage> createState() =>
      _AdministratorLifecyclePageState();
}

class _AdministratorLifecyclePageState
    extends State<AdministratorLifecyclePage> with SyncRefresh<AdministratorLifecyclePage> {
  @override
  void onSynced() => _load();

  List<AdministratorStudentRecord> _students = const [];
  bool _loading = true;
  String? _error;
  List<AdministratorLifecycleRecord> _records = const [];
  AdministratorLifecyclePermissions? _permissions;

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
      final students = (await widget.students.load()).students;
      if (!mounted) return;
      setState(() {
        _students = students;
        _records = snapshot.records;
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

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finish(AdministratorLifecycleActionResult result) async {
    _say(result.message);
    if (result.success) await _load();
  }

  Future<void> _newChange() async {
    final active = [
      for (final s in _students)
        if (s.status != AdministratorStudentStatus.transferredOut) s,
    ];
    final choice = await askLifecycleRequest(context, active);
    if (choice == null) return;
    await _finish(await widget.repository.request(
      student: choice.student,
      workflow: choice.workflow,
      toClass: choice.toClass,
      note: choice.note,
    ));
  }

  Future<void> _openRecord(AdministratorLifecycleRecord record) async {
    if (!(_permissions?.canOpenOperationalReview ?? false)) return;
    final history = _records
        .where(
          (r) =>
              r.student == record.student &&
              r.status == AdministratorLifecycleStatus.completed &&
              r.id != record.id,
        )
        .toList();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record.studentName} · ${record.student}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Workflow', value: record.workflow),
                _DetailRow(label: 'Change', value: record.change),
                _DetailRow(label: 'Status', value: record.status.label),
                if (record.approvedBy.isNotEmpty)
                  _DetailRow(label: 'Approved by', value: record.approvedBy),
                if (record.note.isNotEmpty)
                  _DetailRow(label: 'Note', value: record.note),
                if (record.isTransferOut && record.isPending)
                  _DetailRow(
                    label: 'Records pack',
                    value: record.recordsPackReady ? 'Ready' : 'Not ready yet',
                  ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Earlier changes',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  for (final h in history)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${h.workflow}: ${h.change}'),
                    ),
                ],
                if (record.isAcademicProgression) ...[
                  const SizedBox(height: 12),
                  _BoundaryBox(
                    text:
                        '${record.workflow} is an academic decision. Administration can process an approved decision, but cannot create or override it from this lifecycle desk.',
                  ),
                ],
                const SizedBox(height: 12),
                const _BoundaryBox(text: administratorLifecycleAuthorityBoundary),
                const SizedBox(height: 8),
                const _BoundaryBox(text: administratorLifecycleHistoryBoundary),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (record.isPending && !record.isAlumni) ...[
            TextButton(
              key: const ValueKey('lifecycle-cancel'),
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel change'),
            ),
            if (record.isTransferOut && !record.recordsPackReady)
              FilledButton(
                key: const ValueKey('lifecycle-pack'),
                onPressed: () => Navigator.of(context).pop('pack'),
                child: const Text('Records pack ready'),
              ),
            if (!record.isTransferOut || record.recordsPackReady)
              FilledButton(
                key: const ValueKey('lifecycle-complete'),
                onPressed: () => Navigator.of(context).pop('complete'),
                child: const Text('Complete'),
              ),
          ],
        ],
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'pack':
        await _finish(await widget.repository.markRecordsPackReady(record));
      case 'complete':
        String approvedBy = '';
        if (record.isAcademicProgression) {
          final name = await askApprover(
            context,
            studentName: record.studentName,
            workflow: record.workflow,
          );
          if (name == null) return;
          approvedBy = name;
        }
        await _finish(
          await widget.repository.complete(record, approvedBy: approvedBy),
        );
      case 'cancel':
        final reason = await askReason(
          context,
          title: 'Cancel this change for ${record.studentName}?',
          action: 'Cancel change',
          label: 'Reason (optional)',
        );
        if (reason == null) return;
        await _finish(await widget.repository.cancel(record, reason));
    }
  }

  Future<void> _openAlumniManagement() async {
    final api = AlumniServerScope.maybeOf(context);
    if (api == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${widget.schoolName} · Alumni Management')),
          body: AlumniManagementPage(
            manager: api.activeMembership,
            api: api,
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

    final alumniApi = AlumniServerScope.maybeOf(context);
    final access = AccessScope.maybeOf(context);
    final canManageAlumni = alumniApi != null &&
        (access == null ||
            !access.known ||
            access.allows('administrator.alumni'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(schoolName: widget.schoolName),
            if (_permissions?.canOpenOperationalReview ?? false) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('lifecycle-new'),
                  onPressed: _newChange,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New student change'),
                ),
              ),
            ],
            if (canManageAlumni) ...[
              const SizedBox(height: 16),
              _AlumniLifecycleCard(onOpen: _openAlumniManagement),
            ],
            const SizedBox(height: 18),
            if (wide)
              _WideRegister(
                records: _records,
                canOpen: _permissions?.canOpenOperationalReview ?? false,
                onOpen: _openRecord,
              )
            else
              _CompactRegister(
                records: _records,
                canOpen: _permissions?.canOpenOperationalReview ?? false,
                onOpen: _openRecord,
              ),
            const SizedBox(height: 16),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: _BoundaryBox(text: administratorLifecycleAuthorityBoundary),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: _BoundaryBox(text: administratorLifecycleHistoryBoundary),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlumniLifecycleCard extends StatelessWidget {
  const _AlumniLifecycleCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 30),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alumni transition & verification',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Create a separate Alumni membership from an existing Student account, review former-student evidence, and verify or return profiles for correction. Historical Student records are not overwritten.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Open Alumni'),
              ),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.schoolName});
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION · STUDENT LIFECYCLE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Class Progression, Transfers & Status',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Process promotion, repeat, class movement and exit workflows while preserving every historical enrollment. · $schoolName',
        ),
      ],
    );
  }
}

class _WideRegister extends StatelessWidget {
  const _WideRegister({
    required this.records,
    required this.canOpen,
    required this.onOpen,
  });

  final List<AdministratorLifecycleRecord> records;
  final bool canOpen;
  final ValueChanged<AdministratorLifecycleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const _LifecycleRow(
              header: true,
              values: ['ID', 'Student', 'Workflow', 'Change', 'Status'],
            ),
            for (final record in records)
              _LifecycleDataRow(
                record: record,
                canOpen: canOpen,
                onOpen: () => onOpen(record),
              ),
          ],
        ),
      ),
    );
  }
}

class _LifecycleRow extends StatelessWidget {
  const _LifecycleRow({required this.header, required this.values});

  final bool header;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final style = header
        ? const TextStyle(fontWeight: FontWeight.w900)
        : const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          for (final value in values)
            Expanded(child: Text(value, style: style)),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _LifecycleDataRow extends StatelessWidget {
  const _LifecycleDataRow({
    required this.record,
    required this.canOpen,
    required this.onOpen,
  });

  final AdministratorLifecycleRecord record;
  final bool canOpen;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              record.id,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(child: Text(record.studentName)),
          Expanded(child: Text(record.workflow)),
          Expanded(child: Text(record.change)),
          Expanded(
            child: Text(
              record.status.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: canOpen ? onOpen : null,
              child: const Text('Open'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRegister extends StatelessWidget {
  const _CompactRegister({
    required this.records,
    required this.canOpen,
    required this.onOpen,
  });

  final List<AdministratorLifecycleRecord> records;
  final bool canOpen;
  final ValueChanged<AdministratorLifecycleRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final record in records)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.studentName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Text(record.id),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(record.workflow),
                  const SizedBox(height: 3),
                  Text(record.change),
                  const SizedBox(height: 6),
                  Text(
                    record.status.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: canOpen ? () => onOpen(record) : null,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryBox extends StatelessWidget {
  const _BoundaryBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}
