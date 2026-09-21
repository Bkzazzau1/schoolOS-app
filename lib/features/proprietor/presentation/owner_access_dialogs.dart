import 'package:flutter/material.dart';

import '../domain/owner_access_models.dart';

String formatDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)}, $hour:$minute';
}

/// What the owner decided in the grant or block dialog.
class OverrideChoice {
  const OverrideChoice({this.immediately = false, this.expiresAt, this.note = ''});

  final bool immediately;
  final DateTime? expiresAt;
  final String note;
}

/// Asks how to give someone an activity. Warns first when it shows money or personal data.
Future<OverrideChoice?> askGrant(BuildContext context, {required AccessActivity activity, required String personName}) {
  return showDialog<OverrideChoice>(
    context: context,
    builder: (_) => _OverrideDialog(
      title: 'Give $personName ${activity.label}?',
      confirm: 'Give access',
      warning: activity.sensitive
          ? '${activity.label} shows money or personal information. Only give it to someone you trust with it.'
          : null,
      block: false,
    ),
  );
}

/// Asks how to take an activity from someone.
Future<OverrideChoice?> askBlock(BuildContext context, {required AccessActivity activity, required String personName}) {
  return showDialog<OverrideChoice>(
    context: context,
    builder: (_) => _OverrideDialog(
      title: 'Take ${activity.label} from $personName?',
      confirm: 'Take it away',
      block: true,
    ),
  );
}

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({required this.title, required this.confirm, required this.block, this.warning});

  final String title;
  final String confirm;
  final bool block;
  final String? warning;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  final _note = TextEditingController();
  bool _immediately = false;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      // Ends at the close of that day.
      setState(() => _expiresAt = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.warning != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.warning!),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.block) ...[
              RadioGroup<bool>(
                groupValue: _immediately,
                onChanged: (value) => setState(() => _immediately = value ?? false),
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      title: Text('After they next sync'),
                      subtitle: Text('Their app first sends any work they have not sent. Recommended.'),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      title: Text('Right now'),
                      subtitle: Text('Work they have not sent for it may be lost.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _note,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Note for them (optional)'),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(_expiresAt == null ? 'No end date' : 'Ends ${formatDate(_expiresAt!)}'),
                ),
                TextButton(onPressed: _pickDate, child: Text(_expiresAt == null ? 'Set an end date' : 'Change')),
                if (_expiresAt != null)
                  IconButton(
                    tooltip: 'Remove the end date',
                    onPressed: () => setState(() => _expiresAt = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            OverrideChoice(immediately: _immediately, expiresAt: _expiresAt, note: _note.text.trim()),
          ),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// Which person gets an activity, and how the person who has it hands it over.
class ReassignChoice {
  const ReassignChoice({required this.toMembershipId, required this.immediately, required this.note});

  final String toMembershipId;
  final bool immediately;
  final String note;
}

Future<ReassignChoice?> askReassign(
  BuildContext context, {
  required AccessActivity activity,
  required PersonAccess from,
  required List<PersonAccess> candidates,
}) {
  return showDialog<ReassignChoice>(
    context: context,
    builder: (_) => _ReassignDialog(activity: activity, from: from, candidates: candidates),
  );
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.activity, required this.from, required this.candidates});

  final AccessActivity activity;
  final PersonAccess from;
  final List<PersonAccess> candidates;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  final _note = TextEditingController();
  String? _to;
  bool _immediately = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Move ${widget.activity.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From ${widget.from.displayName} to:'),
            const SizedBox(height: 8),
            if (widget.candidates.isEmpty)
              const Text('Everyone who could have it already does.')
            else
              DropdownButtonFormField<String>(
                initialValue: _to,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Person'),
                items: [
                  for (final p in widget.candidates)
                    DropdownMenuItem(value: p.membershipId, child: Text('${p.displayName} · ${roleLabel(p.role)}')),
                ],
                onChanged: (value) => setState(() => _to = value),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _immediately,
              onChanged: (value) => setState(() => _immediately = value),
              title: const Text('Take it from them right now'),
              subtitle: const Text('Otherwise after they next sync, so their unsent work is kept.'),
            ),
            TextField(
              controller: _note,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _to == null
              ? null
              : () => Navigator.of(context).pop(
                    ReassignChoice(toMembershipId: _to!, immediately: _immediately, note: _note.text.trim()),
                  ),
          child: const Text('Move it'),
        ),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, {required String title, required String message, required String action}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
