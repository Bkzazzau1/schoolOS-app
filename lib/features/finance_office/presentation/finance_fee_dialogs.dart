import 'package:flutter/material.dart';

import '../../administrator/domain/administrator_students_models.dart';
import '../data/finance_billing.dart';
import '../domain/finance_ledger_models.dart';

// Each dialog owns and disposes its own text boxes (disposing them from the caller is too early, while the dialog fades).

/// Edits a section's charges for a term. Returns the new list, or null when cancelled.
Future<List<FeeItem>?> askFeeItems(BuildContext context, {required String section, required String term, required List<FeeItem> items}) =>
    showDialog<List<FeeItem>>(
      context: context,
      builder: (context) => _FeeItemsDialog(section: section, term: term, items: items),
    );

class _Row {
  _Row(String name, String amount)
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _FeeItemsDialog extends StatefulWidget {
  const _FeeItemsDialog({required this.section, required this.term, required this.items});

  final String section;
  final String term;
  final List<FeeItem> items;

  @override
  State<_FeeItemsDialog> createState() => _FeeItemsDialogState();
}

class _FeeItemsDialogState extends State<_FeeItemsDialog> {
  late final List<_Row> _rows = [for (final i in widget.items) _Row(i.name, '${i.amount}')];

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  int get _total => _rows.fold(0, (n, r) => n + (int.tryParse(r.amount.text.trim()) ?? 0));

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.section} fees · ${widget.term}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            key: ValueKey('fee-name-$i'),
                            controller: _rows[i].name,
                            decoration: const InputDecoration(labelText: 'Charge', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: ValueKey('fee-amount-$i'),
                            controller: _rows[i].amount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Amount (₦)', isDense: true),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: _rows.length <= 1
                              ? null
                              : () => setState(() {
                                    _rows.removeAt(i).dispose();
                                  }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('fee-add'),
                    onPressed: () => setState(() => _rows.add(_Row('', ''))),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a charge'),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total per student: ₦$_total', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('fee-save'),
            onPressed: () => Navigator.pop(context, [
              for (final r in _rows) FeeItem(name: r.name.text, amount: int.tryParse(r.amount.text.trim()) ?? 0),
            ]),
            child: const Text('Save fees'),
          ),
        ],
      );
}

class PaymentChoice {
  const PaymentChoice({required this.amount, required this.method, required this.reference, required this.note});

  final int amount;
  final String method;
  final String reference;
  final String note;
}

/// Asks for a payment received for [student], who still owes [balance]. Returns null when cancelled.
Future<PaymentChoice?> askPayment(BuildContext context, {required AdministratorStudentRecord student, required int balance}) =>
    showDialog<PaymentChoice>(
      context: context,
      builder: (context) => _PaymentDialog(student: student, balance: balance),
    );

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.student, required this.balance});

  final AdministratorStudentRecord student;
  final int balance;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = paymentMethods.first;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.trim().replaceAll(',', ''));

  @override
  Widget build(BuildContext context) {
    final ok = (_value ?? 0) > 0 && (_method == 'Cash' || _reference.text.trim().isNotEmpty);
    return AlertDialog(
      title: Text('Payment for ${widget.student.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.student.className} · still owes ₦${widget.balance}'),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('payment-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Amount received (₦)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('payment-method'),
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'How it was paid'),
                items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
                onChanged: (v) => setState(() => _method = v ?? _method),
              ),
              if (_method != 'Cash') ...[
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('payment-reference'),
                  controller: _reference,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: _method == 'POS' ? 'POS reference' : 'Bank reference'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('payment-note'),
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const ValueKey('payment-record'),
          onPressed: ok
              ? () => Navigator.pop(
                    context,
                    PaymentChoice(amount: _value!, method: _method, reference: _reference.text.trim(), note: _note.text.trim()),
                  )
              : null,
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}
