import 'package:flutter/material.dart';

import '../../../core/sync/sync_scope.dart';
import '../../../shared/models/school_membership.dart';
import '../../administrator/domain/administrator_students_models.dart';
import '../data/bad_debt_classification_repository.dart';
import '../data/transfer_verify_associations_api.dart';
import '../domain/bad_debt_classification_models.dart';
import 'bad_debt_money.dart';
import 'publish_transfer_verify_dialog.dart';
import 'transfer_verify_associations_page.dart';

/// A school's own Bad Debt Classification workspace - classify, edit while
/// unpublished, resolve, and (owner only) publish to TransferVerify. Nothing
/// here is visible to any other school; see PublishTransferVerifyDialog for
/// the one explicit boundary-crossing action.
class BadDebtClassificationPage extends StatefulWidget {
  const BadDebtClassificationPage({super.key, required this.repository, required this.membership});

  final BadDebtClassificationRepository repository;
  final SchoolMembership membership;

  @override
  State<BadDebtClassificationPage> createState() => _BadDebtClassificationPageState();
}

class _BadDebtClassificationPageState extends State<BadDebtClassificationPage> with SyncRefresh<BadDebtClassificationPage> {
  late Future<BadDebtClassificationSnapshot> _future;
  String _filter = 'Open';
  String? _notice;

  static const _filters = <String>['Open', 'All', 'Outstanding', 'Recovery in progress', 'Bad debt', 'Resolved', 'Published'];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.load();
  }

  @override
  void onSynced() => _reload();

  void _reload() => setState(() { _future = widget.repository.load(); });

  List<BadDebtClassification> _visible(BadDebtClassificationSnapshot data) {
    return switch (_filter) {
      'Open' => data.open,
      'Outstanding' => [for (final i in data.items) if (i.status == BadDebtStatus.outstanding) i],
      'Recovery in progress' => [for (final i in data.items) if (i.status == BadDebtStatus.recoveryInProgress) i],
      'Bad debt' => [for (final i in data.items) if (i.status == BadDebtStatus.badDebt) i],
      'Resolved' => [for (final i in data.items) if (i.status == BadDebtStatus.resolved) i],
      'Published' => data.published,
      _ => data.items,
    };
  }

  Future<void> _openClassifyDialog(BadDebtClassificationSnapshot data) async {
    final students = await widget.repository.students();
    if (!mounted) return;
    final result = await showDialog<BadDebtClassificationActionResult>(
      context: context,
      builder: (_) => _ClassifyDialog(repository: widget.repository, students: students),
    );
    if (result != null) {
      setState(() => _notice = result.message);
      if (result.success) _reload();
    }
  }

  Future<void> _advance(BadDebtClassification item, BadDebtStatus status) async {
    final result = await widget.repository.advanceStatus(item, status);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) _reload();
  }

  Future<void> _resolve(BadDebtClassification item) async {
    final note = await showDialog<String>(context: context, builder: (_) => const _ResolveDialog());
    if (note == null) return;
    final result = await widget.repository.resolve(item, note: note);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) _reload();
  }

  Future<void> _publish(BadDebtClassification item) async {
    final result = await showDialog<BadDebtClassificationActionResult>(
      context: context,
      builder: (_) => PublishTransferVerifyDialog(
        repository: widget.repository,
        item: item,
        membership: widget.membership,
        associationsApi: TransferVerifyAssociationsScope.maybeOf(context),
      ),
    );
    if (result != null) {
      setState(() => _notice = result.message);
      if (result.success) _reload();
    }
  }

  void _openAssociations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Proprietor Associations')),
          body: TransferVerifyAssociationsPage(
            api: TransferVerifyAssociationsScope.maybeOf(context),
            membership: widget.membership,
          ),
        ),
      ),
    );
  }

  Future<void> _withdraw(BadDebtClassification item) async {
    final result = await widget.repository.withdrawPublication(item);
    if (!mounted) return;
    setState(() => _notice = result.message);
    if (result.success) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BadDebtClassificationSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 42),
                  const SizedBox(height: 12),
                  const Text('Could not load bad debt classifications.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final items = _visible(data);
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRANSFERVERIFY', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                      const SizedBox(height: 6),
                      Text('Bad Debt Classification', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text(
                        "This school's own private record of unresolved balances. Nothing here is visible to any other "
                        'school unless you explicitly publish a bad-debt case to TransferVerify.',
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _filter,
                        decoration: const InputDecoration(labelText: 'Filter'),
                        items: [for (final f in _filters) DropdownMenuItem(value: f, child: Text(f))],
                        onChanged: (value) { if (value != null) setState(() => _filter = value); },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openAssociations,
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('Associations'),
                    ),
                    FilledButton.icon(
                      onPressed: data.permissions.canClassify ? () => _openClassifyDialog(data) : null,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Classify a bad debt'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!data.permissions.canClassify)
              const _Notice(text: 'Only the owner, or someone the owner has specifically authorized, can classify or edit a bad debt.'),
            if (_notice != null) ...[
              const SizedBox(height: 10),
              _Notice(text: _notice!),
            ],
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(24), child: Text('Nothing matches this filter.')))
            else
              for (final item in items) ...[
                _ClassificationCard(
                  item: item,
                  permissions: data.permissions,
                  onAdvance: (status) => _advance(item, status),
                  onResolve: () => _resolve(item),
                  onPublish: () => _publish(item),
                  onWithdraw: () => _withdraw(item),
                ),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(14)),
        child: Text(text),
      );
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({
    required this.item,
    required this.permissions,
    required this.onAdvance,
    required this.onResolve,
    required this.onPublish,
    required this.onWithdraw,
  });

  final BadDebtClassification item;
  final BadDebtClassificationPermissions permissions;
  final ValueChanged<BadDebtStatus> onAdvance;
  final VoidCallback onResolve;
  final VoidCallback onPublish;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Classified by ${item.classifiedByName} · ${_date(item.classifiedAt)}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(badDebtMoney(item.outstandingAmountMinor), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(item.status.label)),
                if (item.pendingSync) const Chip(label: Text('Syncing…')),
                if (item.publishedToTransferVerify)
                  Chip(
                    avatar: const Icon(Icons.public, size: 16),
                    label: const Text('Published to TransferVerify'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (item.reason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Reason: ${item.reason}'),
            ],
            if (item.notes.trim().isNotEmpty) Text('Notes: ${item.notes}'),
            if (item.status == BadDebtStatus.resolved && item.resolutionNote.trim().isNotEmpty)
              Text('Resolution: ${item.resolutionNote}'),
            if (item.publishedToTransferVerify && item.publicationReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Published reason: ${item.publicationReason!.label}', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (permissions.canClassify && item.isEditable) ...[
                  if (item.status == BadDebtStatus.outstanding)
                    OutlinedButton(onPressed: () => onAdvance(BadDebtStatus.recoveryInProgress), child: const Text('Mark recovery in progress')),
                  if (item.status != BadDebtStatus.badDebt)
                    OutlinedButton(onPressed: () => onAdvance(BadDebtStatus.badDebt), child: const Text('Classify as bad debt')),
                  OutlinedButton(onPressed: onResolve, child: const Text('Resolve')),
                ],
                if (permissions.canPublish && item.status == BadDebtStatus.badDebt && !item.publishedToTransferVerify)
                  FilledButton.icon(onPressed: onPublish, icon: const Icon(Icons.public, size: 18), label: const Text('Publish to TransferVerify')),
                if (permissions.canPublish && item.publishedToTransferVerify)
                  OutlinedButton.icon(onPressed: onWithdraw, icon: const Icon(Icons.public_off, size: 18), label: const Text('Withdraw publication')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    final local = d.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _ClassifyDialog extends StatefulWidget {
  const _ClassifyDialog({required this.repository, required this.students});

  final BadDebtClassificationRepository repository;
  final List<AdministratorStudentRecord> students;

  @override
  State<_ClassifyDialog> createState() => _ClassifyDialogState();
}

class _ClassifyDialogState extends State<_ClassifyDialog> {
  final _formKey = GlobalKey<FormState>();
  AdministratorStudentRecord? _student;
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _evidence = TextEditingController();
  final _classifiedBy = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _notes.dispose();
    _evidence.dispose();
    _classifiedBy.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final student = _student;
    if (student == null) {
      setState(() => _error = 'Choose a student.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final naira = int.tryParse(_amount.text) ?? -1;
    final result = await widget.repository.classify(
      studentId: student.id,
      studentName: student.name,
      outstandingAmountMinor: naira * 100,
      classifiedByName: _classifiedBy.text,
      reason: _reason.text,
      notes: _notes.text,
      evidenceReference: _evidence.text,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _submitting = false;
        _error = result.message;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Classify a bad debt'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This stays private to this school until you explicitly publish it later.'),
                const SizedBox(height: 14),
                DropdownButtonFormField<AdministratorStudentRecord>(
                  isExpanded: true,
                  initialValue: _student,
                  decoration: const InputDecoration(labelText: 'Student'),
                  items: [
                    for (final s in widget.students) DropdownMenuItem(value: s, child: Text('${s.name} · ${s.className}')),
                  ],
                  onChanged: (value) => setState(() => _student = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Outstanding amount (₦)'),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0 ? 'Enter an amount above zero' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _classifiedBy, decoration: const InputDecoration(labelText: 'Your name'), validator: _required),
                const SizedBox(height: 12),
                TextFormField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason')),
                const SizedBox(height: 12),
                TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 12),
                TextFormField(controller: _evidence, decoration: const InputDecoration(labelText: 'Evidence reference (optional)')),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog();

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve this classification'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Resolution note', hintText: 'For example: the family paid the balance in full.'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_note.text), child: const Text('Mark resolved')),
      ],
    );
  }
}
