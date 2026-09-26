import 'package:flutter/material.dart';

import '../../bankconnect/presentation/bank_widgets.dart';
import '../domain/mandate_labels.dart';

/// Shown where there is no school server: a mandate, a provider credential and a debit only exist on the server, so nothing is faked.
class MandatesNoServerNotice extends StatelessWidget {
  const MandatesNoServerNotice({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFF5F6B7A)),
              SizedBox(height: 12),
              Text('Mandates & Direct Debit needs your school\'s server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text(
                'Connecting the school\'s Remita or Lendsqr account, a payer\'s authority to debit their account, and every debit all happen on the '
                'SchoolOS server, so that no credential or bank account number is ever kept on a phone. This app is running without a school '
                'server, so there are no providers, mandates or debits to show. A debit is never queued on a phone as though it had happened.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class MandateStatusChip extends StatelessWidget {
  const MandateStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: mandateStatusLabel(status), color: mandateStatusColor(status));
}

class BatchStatusChip extends StatelessWidget {
  const BatchStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: batchStatusLabel(status), color: batchStatusColor(status));
}

class DebitStatusChip extends StatelessWidget {
  const DebitStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: debitStatusLabel(status), color: debitStatusColor(status));
}

class EligibilityChip extends StatelessWidget {
  const EligibilityChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: eligibilityLabel(status), color: eligibilityColor(status));
}

class TransactionStatusChip extends StatelessWidget {
  const TransactionStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: transactionStatusLabel(status), color: transactionStatusColor(status));
}

/// A label and a value on one line.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Color(0xFF5F6B7A)))),
            Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          ],
        ),
      );
}

/// One number on the overview.
class CountTile extends StatelessWidget {
  const CountTile({super.key, required this.label, required this.value, this.tileKey, this.warn = false});

  final String label;
  final String value;
  final Key? tileKey;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
        key: tileKey,
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warn ? const Color(0xFFFFF4E5) : const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: warn ? const Color(0xFF8A6D00) : null)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFF5F6B7A), fontSize: 12)),
          ],
        ),
      );
}

/// Asks first, in words. Returns whether the person said yes.
Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String action, bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)) : null,
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// Asks for a reason (a rejection or a cancellation). Returns the trimmed reason, or null if cancelled.
Future<String?> askReason(BuildContext context, {required String title, required String hint, required String action, int minWords = 3}) =>
    showDialog<String>(context: context, builder: (_) => _ReasonDialog(title: title, hint: hint, action: action, minWords: minWords));

/// Owns its text controller, so the controller goes only when the dialog has really left the screen: disposing one the moment the dialog is
/// popped would leave the closing animation drawing a text field whose controller is gone.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.hint, required this.action, required this.minWords});

  final String title;
  final String hint;
  final String action;
  final int minWords;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.split(' ').where((w) => w.isNotEmpty).length < widget.minWords) {
      setState(() => _problem = 'Say why, in a few words, so the person who prepared it knows what to change.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(key: const ValueKey('reason-field'), controller: _controller, maxLines: 3, maxLength: 500, decoration: InputDecoration(hintText: widget.hint, errorText: _problem)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const ValueKey('reason-confirm'), onPressed: _confirm, child: Text(widget.action)),
        ],
      );
}

/// One value a [FieldsDialog] asks for.
class DialogField {
  const DialogField({required this.name, required this.label, required this.fieldKey, this.secret = false, this.decimal = false, this.numeric = false, this.helper = '', this.initial = ''});

  final String name;
  final String label;
  final Key fieldKey;

  /// Typed hidden (a credential or a one-time password).
  final bool secret;
  final bool decimal;
  final bool numeric;
  final String helper;
  final String initial;
}

/// A dialog that asks for a few values and pops a map of what was typed (or null if cancelled). It owns its text controllers and clears them
/// when it leaves the screen, so what was typed - a credential, a one-time password - is not kept anywhere.
class FieldsDialog extends StatefulWidget {
  const FieldsDialog({super.key, required this.title, required this.fields, required this.action, required this.confirmKey, this.intro = ''});

  final String title;
  final String intro;
  final List<DialogField> fields;
  final String action;
  final Key confirmKey;

  @override
  State<FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<FieldsDialog> {
  late final Map<String, TextEditingController> _controllers = {for (final f in widget.fields) f.name: TextEditingController(text: f.initial)};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.intro.isNotEmpty) ...[Text(widget.intro), const SizedBox(height: 12)],
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: f.fieldKey,
                    controller: _controllers[f.name],
                    obscureText: f.secret,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: f.decimal ? const TextInputType.numberWithOptions(decimal: true) : (f.numeric ? TextInputType.number : null),
                    decoration: InputDecoration(labelText: f.label, helperText: f.helper.isEmpty ? null : f.helper, border: const OutlineInputBorder()),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: widget.confirmKey, onPressed: () => Navigator.pop(context, {for (final e in _controllers.entries) e.key: e.value.text.trim()}), child: Text(widget.action)),
        ],
      );
}
