import 'package:flutter/material.dart';

import '../../../core/media/media_api.dart';
import '../../../core/media/presentation/media_attachments_panel.dart';
import '../../../core/sync/sync_scope.dart';
import '../../proprietor/presentation/owner_dialogs.dart';
import '../data/administrator_records_repository.dart';
import '../domain/administrator_records_models.dart';
import 'administrator_records_dialogs.dart';

/// Which of the shared media service's document categories a record uses - the records office tracks the same
/// document record whichever it belongs to, but the school's own Staff onboarding documents already use
/// "staff_document" (owner_staff_profiles_page.dart), so a staff record here uses that same category rather
/// than a second one meaning the same thing.
String _categoryFor(AdministratorDocumentRecord record) => switch (record.kind) {
      'Staff' => 'staff_document',
      'Family' => 'admission_document',
      _ => 'student_document',
    };

class AdministratorRecordsPage extends StatefulWidget {
  const AdministratorRecordsPage({
    super.key,
    required this.schoolName,
    required this.repository,
  });

  final String schoolName;
  final AdministratorRecordsRepository repository;

  @override
  State<AdministratorRecordsPage> createState() =>
      _AdministratorRecordsPageState();
}

class _AdministratorRecordsPageState extends State<AdministratorRecordsPage> with SyncRefresh<AdministratorRecordsPage> {
  @override
  void onSynced() => _load();

  bool _loading = true;
  String? _error;
  List<AdministratorDocumentRecord> _records = const [];
  AdministratorRecordsPermissions? _permissions;

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

  Future<void> _finish(AdministratorRecordActionResult result) async {
    _say(result.message);
    if (result.success) await _load();
  }

  Future<void> _newDocument() async {
    final choice = await askNewDocument(context);
    if (choice == null) return;
    await _finish(await widget.repository.add(owner: choice.owner, document: choice.document, kind: choice.kind));
  }

  Future<void> _review(AdministratorDocumentRecord record) async {
    if (!(_permissions?.canReviewRestrictedMetadata ?? false)) return;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(record.document),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Record owner', value: record.recordOwner),
                _ReviewRow(label: 'Kind', value: record.kind),
                _ReviewRow(label: 'Status', value: record.status.label),
                _ReviewRow(label: 'Received', value: record.received),
                _ReviewRow(label: 'Visibility', value: record.visibility),
                if (record.history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('History', style: TextStyle(fontWeight: FontWeight.w900)),
                  for (final h in record.history)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${(h['at'] as String? ?? '').split('T').first} · ${h['action']}${(h['note'] as String? ?? '').isEmpty ? '' : ': ${h['note']}'}'),
                    ),
                ],
                const SizedBox(height: 12),
                const Text('Attached files', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text(
                  'Attaching a file here never moves this document to received or verified by itself - the office still does that step.',
                  style: TextStyle(color: Color(0xFF5F6B7A)),
                ),
                const SizedBox(height: 8),
                _attachments(record),
                const SizedBox(height: 12),
                const _BoundaryBox(text: administratorRecordsVisibilityBoundary),
                const SizedBox(height: 8),
                const _BoundaryBox(text: administratorRecordsReviewBoundary),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          for (final a in AdministratorRecordsRepository.actionsFor(record.status))
            FilledButton(
              key: ValueKey('record-action-$a'),
              onPressed: () => Navigator.of(context).pop(a),
              child: Text(a),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    var note = '';
    if (action == 'Send back' || action == 'Reopen') {
      final reason = await askReason(
        context,
        title: '$action: ${record.document}',
        action: action,
        label: 'Why (required)',
      );
      if (reason == null) return;
      note = reason;
    }
    await _finish(await widget.repository.act(record, action, note: note));
  }

  /// The real files attached to this document record - SchoolOS's shared media service (docs/MEDIA.md), the
  /// same one Gallery and staff onboarding documents already use. Online only: without a school server there is
  /// nowhere a real file could live, so nothing is offered here.
  Widget _attachments(AdministratorDocumentRecord record) {
    final api = MediaScope.maybeOf(context);
    final queue = MediaScope.queueOf(context);
    if (api == null || queue == null) {
      return const Text('Attaching a real file needs your school\'s server.', style: TextStyle(color: Color(0xFF5F6B7A)));
    }
    final canReview = _permissions?.canReviewRestrictedMetadata ?? false;
    return MediaAttachmentsPanel(
      api: api,
      queue: queue,
      membership: widget.repository.activeMembership,
      ownerType: 'administrator_document_record',
      ownerId: record.id,
      canContribute: canReview,
      canManage: canReview,
      emptyLabel: 'No files attached yet.',
      tileSize: 84,
      options: [
        MediaAttachmentOption(
          label: 'Attach a file',
          category: _categoryFor(record),
          mediaType: 'document',
          icon: Icons.upload_file_outlined,
          allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        ),
      ],
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
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? 28 : 16),
          children: [
            _Header(schoolName: widget.schoolName),
            if (_permissions?.canReviewRestrictedMetadata ?? false) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('record-new'),
                  onPressed: _newDocument,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Track a document'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (wide)
              _WideRegister(
                records: _records,
                canReview: _permissions?.canReviewRestrictedMetadata ?? false,
                onReview: _review,
              )
            else
              _CompactRegister(
                records: _records,
                canReview: _permissions?.canReviewRestrictedMetadata ?? false,
                onReview: _review,
              ),
            const SizedBox(height: 14),
            _Summary(records: _records),
            const SizedBox(height: 14),
            const _BoundaryBox(text: administratorRecordsVisibilityBoundary),
          ],
        );
      },
    );
  }
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
          'ADMINISTRATION · RECORDS OFFICE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 5),
        Text(
          'Records & Documents',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Track official student, family and staff documents and their verification status. · $schoolName',
        ),
      ],
    );
  }
}

class _WideRegister extends StatelessWidget {
  const _WideRegister({
    required this.records,
    required this.canReview,
    required this.onReview,
  });

  final List<AdministratorDocumentRecord> records;
  final bool canReview;
  final ValueChanged<AdministratorDocumentRecord> onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const _HeaderRow(),
            for (final record in records)
              _DocumentRow(
                record: record,
                canReview: canReview,
                onReview: () => onReview(record),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w900);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Document', style: style)),
          Expanded(flex: 2, child: Text('Record owner', style: style)),
          Expanded(child: Text('Status', style: style)),
          Expanded(child: Text('Received', style: style)),
          Expanded(child: Text('Visibility', style: style)),
          SizedBox(width: 88),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.record,
    required this.canReview,
    required this.onReview,
  });

  final AdministratorDocumentRecord record;
  final bool canReview;
  final VoidCallback onReview;

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
            flex: 2,
            child: Text(record.document, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          Expanded(flex: 2, child: Text(record.recordOwner)),
          Expanded(
            child: Text(
              record.status.label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: record.needsAttention
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          Expanded(child: Text(record.received)),
          Expanded(child: Text(record.visibility)),
          SizedBox(
            width: 88,
            child: TextButton(
              key: ValueKey('review-${record.id}'),
              onPressed: canReview ? onReview : null,
              child: const Text('Review'),
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
    required this.canReview,
    required this.onReview,
  });

  final List<AdministratorDocumentRecord> records;
  final bool canReview;
  final ValueChanged<AdministratorDocumentRecord> onReview;

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
                  Text(record.document, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(record.recordOwner),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      Text(
                        record.status.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: record.needsAttention
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                      Text('Received: ${record.received}'),
                      Text(record.visibility),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: ValueKey('review-${record.id}'),
                      onPressed: canReview ? () => onReview(record) : null,
                      child: const Text('Review'),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.records});
  final List<AdministratorDocumentRecord> records;

  @override
  Widget build(BuildContext context) {
    final verified = records
        .where((item) => item.status == AdministratorRecordStatus.verified)
        .length;
    final attention = records.where((item) => item.needsAttention).length;
    final draft = records
        .where((item) => item.status == AdministratorRecordStatus.draft)
        .length;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Text('$verified verified', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('$attention pending/missing', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('$draft draft', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${records.length} restricted records'),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
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
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
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
