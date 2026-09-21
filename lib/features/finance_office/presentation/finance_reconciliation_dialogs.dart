import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_students_models.dart';
import '../../proprietor/domain/concession_request.dart';
import '../data/finance_reconciliation.dart';

// Each dialog owns and disposes its own text boxes (disposing them from the caller is too early, while the dialog fades).

class BankLineChoice {
  const BankLineChoice({required this.date, required this.amount, required this.reference, required this.narration});

  final DateTime date;
  final int amount;
  final String reference;
  final String narration;
}

/// Asks for a line from the bank statement. Returns null when cancelled.
Future<BankLineChoice?> askBankLine(BuildContext context) => showDialog<BankLineChoice>(
      context: context,
      builder: (context) => const _BankLineDialog(),
    );

class _BankLineDialog extends StatefulWidget {
  const _BankLineDialog();

  @override
  State<_BankLineDialog> createState() => _BankLineDialogState();
}

class _BankLineDialogState extends State<_BankLineDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _narration = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _narration.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.trim().replaceAll(',', ''));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Statement line'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('bank-amount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Amount (₦)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('bank-reference'),
                  controller: _reference,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Reference on the statement'),
                ),
                const SizedBox(height: 10),
                TextField(controller: _narration, decoration: const InputDecoration(labelText: 'Narration (optional)')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2026, 1, 1),
                          lastDate: DateTime(2028, 12, 31),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('bank-add'),
            onPressed: (_value ?? 0) > 0 && _reference.text.trim().isNotEmpty
                ? () => Navigator.pop(
                      context,
                      BankLineChoice(date: _date, amount: _value!, reference: _reference.text.trim(), narration: _narration.text.trim()),
                    )
                : null,
            child: const Text('Add line'),
          ),
        ],
      );
}

/// Asks which student a statement line is for. Only students who still owe are offered. Returns null when cancelled.
Future<AdministratorStudentRecord?> askStatementStudent(
  BuildContext context, {
  required BankLine line,
  required List<AdministratorStudentRecord> students,
}) =>
    showDialog<AdministratorStudentRecord>(
      context: context,
      builder: (context) => _StatementStudentDialog(line: line, students: students),
    );

class _StatementStudentDialog extends StatefulWidget {
  const _StatementStudentDialog({required this.line, required this.students});

  final BankLine line;
  final List<AdministratorStudentRecord> students;

  @override
  State<_StatementStudentDialog> createState() => _StatementStudentDialogState();
}

class _StatementStudentDialogState extends State<_StatementStudentDialog> {
  AdministratorStudentRecord? _student;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Who paid ${formatNaira(widget.line.amount)}?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reference ${widget.line.reference}${widget.line.narration.isEmpty ? '' : ' · ${widget.line.narration}'}. Choose the student only if you are sure.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdministratorStudentRecord>(
                key: const ValueKey('statement-student'),
                initialValue: _student,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Student'),
                items: [
                  for (final s in widget.students) DropdownMenuItem(value: s, child: Text('${s.name} · ${s.className}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _student = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('statement-student-confirm'),
            onPressed: _student == null ? null : () => Navigator.pop(context, _student),
            child: const Text('Record payment'),
          ),
        ],
      );
}
