import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bad_debt_classification_repository.dart';
import '../data/transfer_verify_associations_api.dart';
import '../domain/association_models.dart';
import '../domain/bad_debt_classification_models.dart';
import 'bad_debt_money.dart';

/// The one explicit confirmation screen between a private classification and
/// TransferVerify. The owner sees exactly what they are about to mark
/// eligible for network discovery, must pick a factual, neutral reason -
/// never an accusation - and, when connected to a school server, explicitly
/// chooses which association(s) this publishes to (never all of them, and
/// never guessed) from this school's own active memberships.
class PublishTransferVerifyDialog extends StatefulWidget {
  const PublishTransferVerifyDialog({
    super.key,
    required this.repository,
    required this.item,
    required this.membership,
    this.associationsApi,
  });

  final BadDebtClassificationRepository repository;
  final BadDebtClassification item;
  final SchoolMembership membership;

  /// Null on demo data, or whenever there is no connected school server -
  /// association scope then stays unselectable, honestly.
  final TransferVerifyAssociationsApi? associationsApi;

  @override
  State<PublishTransferVerifyDialog> createState() => _PublishTransferVerifyDialogState();
}

class _PublishTransferVerifyDialogState extends State<PublishTransferVerifyDialog> {
  TransferVerifyPublicationReason? _reason;
  final _note = TextEditingController();
  bool _confirmed = false;
  bool _submitting = false;
  String? _error;
  final _selectedAssociationIds = <String>{};
  Future<List<SchoolAssociationMembershipRecord>>? _activeMemberships;

  @override
  void initState() {
    super.initState();
    final api = widget.associationsApi;
    if (api != null) {
      _activeMemberships = api.myMemberships(widget.membership).then(
            (items) => [for (final item in items) if (item.isActive) item],
          );
    }
  }

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
    final result = await widget.repository.publish(
      widget.item,
      reason: reason,
      note: _note.text,
      associationIds: _selectedAssociationIds.toList(),
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
                'This makes the case eligible for TransferVerify to surface to other schools - but only within the '
                'association(s) you choose below. Nothing is discoverable outside them.',
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
              const SizedBox(height: 14),
              _buildAssociationScope(context),
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

  Widget _buildAssociationScope(BuildContext context) {
    final future = _activeMemberships;
    if (future == null) {
      return const _ScopeNotice(
        text: 'No association network is connected here (this device is running in demo mode), so this proves the '
            'review-and-approve step now, before anything could reach another school.',
      );
    }
    return FutureBuilder<List<SchoolAssociationMembershipRecord>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
        }
        final memberships = snapshot.data ?? const [];
        if (memberships.isEmpty) {
          return const _ScopeNotice(
            text: "Your school has not joined a Proprietor Association yet, so this still proves the review-and-approve "
                'step, without reaching another school. Join one from TransferVerify → Associations first.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Publish to which association(s)?', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            for (final row in memberships)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _selectedAssociationIds.contains(row.associationId),
                title: Text(row.associationName),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selectedAssociationIds.add(row.associationId);
                  } else {
                    _selectedAssociationIds.remove(row.associationId);
                  }
                }),
              ),
          ],
        );
      },
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
        child: Text(text),
      );
}
