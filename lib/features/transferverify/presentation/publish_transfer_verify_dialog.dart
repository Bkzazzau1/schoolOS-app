import 'package:flutter/material.dart';

import '../data/bad_debt_classification_repository.dart';
import '../domain/bad_debt_classification_models.dart';
import 'bad_debt_money.dart';

/// The one explicit confirmation screen between a private classification and
/// TransferVerify. Nothing here reaches another school yet (no association
/// scope exists to choose from), but the owner still sees exactly what they
/// are about to mark eligible for future network discovery, and must pick a
/// factual, neutral reason - never an accusation.
class PublishTransferVerifyDialog extends StatefulWidget {
  const PublishTransferVerifyDialog({super.key, required this.repository, required this.item});

  final BadDebtClassificationRepository repository;
  final BadDebtClassification item;

  @override
  State<PublishTransferVerifyDialog> createState() => _PublishTransferVerifyDialogState();
}

class _PublishTransferVerifyDialogState extends State<PublishTransferVerifyDialog> {
  TransferVerifyPublicationReason? _reason;
  final _note = TextEditingController();
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Choose a reason for publishing this case.');
      return;
    }
    if (!_confirmed) {
      setState(() => _error = 'Confirm you have reviewed this case before publishing it.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.repository.publish(widget.item, reason: reason, note: _note.text);
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
    final item = widget.item;
    return AlertDialog(
      title: const Text('Publish to TransferVerify'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This case becomes eligible for TransferVerify to make discoverable to other schools - but only once you '
                'choose a Proprietor Association to publish it to. No association network is connected yet, so this proves '
                'the review-and-approve step now, before anything can reach another school.',
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Status: ${item.status.label}'),
                    Text('Outstanding: ${badDebtMoney(item.outstandingAmountMinor)}'),
                    if (item.reason.trim().isNotEmpty) Text('Recorded reason: ${item.reason}'),
                    Text('Classified by ${item.classifiedByName}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TransferVerifyPublicationReason>(
                isExpanded: true,
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'Reason for publishing'),
                items: [
                  for (final option in TransferVerifyPublicationReason.all)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Factual detail only - never an accusation.'),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _confirmed,
                onChanged: (value) => setState(() => _confirmed = value ?? false),
                title: const Text('I have reviewed this case and confirm it should be published.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _publish,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Publish'),
        ),
      ],
    );
  }
}
