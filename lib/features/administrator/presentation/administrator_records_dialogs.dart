import 'package:flutter/material.dart';

import '../data/administrator_records_repository.dart';

class NewDocumentChoice {
  const NewDocumentChoice({required this.owner, required this.document, required this.kind});

  final String owner;
  final String document;
  final String kind;
}

/// Asks whose document, which document and what kind. Returns null when cancelled.
/// The dialog owns and disposes its own text box.
Future<NewDocumentChoice?> askNewDocument(BuildContext context) => showDialog<NewDocumentChoice>(
      context: context,
      builder: (context) => const _NewDocumentDialog(),
    );

class _NewDocumentDialog extends StatefulWidget {
  const _NewDocumentDialog();

  @override
  State<_NewDocumentDialog> createState() => _NewDocumentDialogState();
}

class _NewDocumentDialogState extends State<_NewDocumentDialog> {
  final _owner = TextEditingController();
  String _document = AdministratorRecordsRepository.documentTypes.first;
  String _kind = AdministratorRecordsRepository.kinds.first;

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Track a document'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                isExpanded: true,
                  key: const ValueKey('record-kind'),
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Whose document'),
                  items: [for (final k in AdministratorRecordsRepository.kinds) DropdownMenuItem(value: k, child: Text(k))],
                  onChanged: (v) => setState(() => _kind = v ?? _kind),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('record-owner'),
                  controller: _owner,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'A student, a family or a staff member'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('record-document'),
                  initialValue: _document,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Document'),
                  items: [for (final d in AdministratorRecordsRepository.documentTypes) DropdownMenuItem(value: d, child: Text(d))],
                  onChanged: (v) => setState(() => _document = v ?? _document),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('record-add'),
            onPressed: _owner.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, NewDocumentChoice(owner: _owner.text.trim(), document: _document, kind: _kind)),
            child: const Text('Track document'),
          ),
        ],
      );
}
