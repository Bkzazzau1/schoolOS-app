import 'package:flutter/material.dart';

import '../../bankconnect/domain/bank_labels.dart';
import '../domain/collection_models.dart';

/// A reason a person types, with a button that stays off until there is enough of one. Used to override a family's eligibility and to
/// reject a batch: both need a reason the school can read later. Returns the text, or null if cancelled.
Future<String?> askForReason(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  int minWords = 1,
  String label = 'Reason',
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(title: title, message: message, action: action, minWords: minWords, label: label),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.action, required this.minWords, required this.label});

  final String title;
  final String message;
  final String action;
  final int minWords;
  final String label;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _enough => _text.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >= widget.minWords;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reason-field'),
              controller: _text,
              maxLines: 3,
              maxLength: 300,
              decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('reason-confirm'),
            onPressed: _enough ? () => Navigator.of(context).pop(_text.text.trim()) : null,
            child: Text(widget.action),
          ),
        ],
      );
}

/// The families the school's policy asks the approver to approve one by one. All must be ticked before the batch can be approved.
Future<List<String>?> askManualApprovals(BuildContext context, List<BatchItem> items) => showDialog<List<String>>(
      context: context,
      builder: (_) => _ManualApprovalDialog(items: items),
    );

class _ManualApprovalDialog extends StatefulWidget {
  const _ManualApprovalDialog({required this.items});

  final List<BatchItem> items;

  @override
  State<_ManualApprovalDialog> createState() => _ManualApprovalDialogState();
}

class _ManualApprovalDialogState extends State<_ManualApprovalDialog> {
  final Set<String> _ticked = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Approve these families one by one'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('These families still owe for an earlier term, and the school\'s policy asks you to approve each one for a new account.'),
              for (final i in widget.items)
                CheckboxListTile(
                  key: ValueKey('approve-${i.id}'),
                  value: _ticked.contains(i.id),
                  onChanged: (v) => setState(() => v == true ? _ticked.add(i.id) : _ticked.remove(i.id)),
                  title: Text(i.familyName),
                  subtitle: Text('Earlier balance ${formatMoneyMinor(i.previousArrearsMinor)} · to collect ${formatMoneyMinor(i.proposedCollectionMinor)}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('manual-approve-all'),
            onPressed: _ticked.length == widget.items.length ? () => Navigator.of(context).pop(_ticked.toList()) : null,
            child: const Text('Approve Generation'),
          ),
        ],
      );
}

/// Where the arrears policy lets a person choose: which earlier balances go into this family's collection target.
Future<List<String>?> chooseArrearsDialog(BuildContext context, BatchItem item) => showDialog<List<String>>(
      context: context,
      builder: (_) => _ArrearsDialog(item: item),
    );

class _ArrearsDialog extends StatefulWidget {
  const _ArrearsDialog({required this.item});

  final BatchItem item;

  @override
  State<_ArrearsDialog> createState() => _ArrearsDialogState();
}

class _ArrearsDialogState extends State<_ArrearsDialog> {
  late final Set<String> _ticked = {...widget.item.customArrearsReceivableIds};

  @override
  Widget build(BuildContext context) {
    final rows = widget.item.arrearsBreakdown;
    final total = rows.where((r) => _ticked.contains('${r['receivableId']}')).fold<int>(0, (sum, r) => sum + (r['outstandingMinor'] as int? ?? 0));
    return AlertDialog(
      title: Text('Earlier balances: ${widget.item.familyName}'),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text('Choose which earlier balances go into this family\'s collection target. What the family owes does not change: the ones you leave out are still owed.'),
            for (final r in rows)
              CheckboxListTile(
                key: ValueKey('balance-${r['receivableId']}'),
                value: _ticked.contains('${r['receivableId']}'),
                onChanged: (v) => setState(() => v == true ? _ticked.add('${r['receivableId']}') : _ticked.remove('${r['receivableId']}')),
                title: Text('${r['label'] ?? 'Balance'} · ${r['period'] ?? ''}'),
                subtitle: Text('Due ${r['dueDate'] ?? ''}'),
                secondary: Text(formatMoneyMinor(r['outstandingMinor'] as int? ?? 0)),
              ),
            const SizedBox(height: 8),
            Text('Carried into the target: ${formatMoneyMinor(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(key: const ValueKey('save-balances'), onPressed: () => Navigator.of(context).pop(_ticked.toList()), child: const Text('Save')),
      ],
    );
  }
}

/// Record the payer's BVN or NIN (Monnify needs one before it will make an account). Write-only: it is sent to the server once, sealed
/// there, and never shown again. Returns `(bvn, nin)`, or null if cancelled.
Future<(String, String)?> askPayerIdentity(BuildContext context, {required String familyName, required bool hasOnFile}) =>
    showDialog<(String, String)>(context: context, builder: (_) => _IdentityDialog(familyName: familyName, hasOnFile: hasOnFile));

class _IdentityDialog extends StatefulWidget {
  const _IdentityDialog({required this.familyName, required this.hasOnFile});

  final String familyName;
  final bool hasOnFile;

  @override
  State<_IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<_IdentityDialog> {
  final _bvn = TextEditingController();
  final _nin = TextEditingController();

  @override
  void dispose() {
    _bvn.dispose();
    _nin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Payer identity: ${widget.familyName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.hasOnFile
                  ? 'An identity number is on file. Enter a new one only to replace it. It is never shown.'
                  : 'The provider needs the family payer\'s BVN or NIN before it will make an account. Enter one.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('identity-bvn'),
              controller: _bvn,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: const InputDecoration(labelText: 'BVN (11 digits)', border: OutlineInputBorder()),
            ),
            TextField(
              key: const ValueKey('identity-nin'),
              controller: _nin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: const InputDecoration(labelText: 'NIN (11 digits)', border: OutlineInputBorder()),
            ),
            const Text('It goes to the school\'s server over a secure connection and is stored encrypted. It cannot be read back.', style: TextStyle(fontSize: 12, color: Color(0xFF5F6B7A))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('identity-save'), onPressed: () => Navigator.of(context).pop((_bvn.text.trim(), _nin.text.trim())), child: const Text('Save')),
        ],
      );
}
