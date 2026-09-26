import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/payment_models.dart';
import 'bank_widgets.dart';

// Every dialog here owns its own text boxes (in its State), so they are disposed by the framework only
// once the dialog has finished animating away - never while it is still on screen.

/// Search the school's students by name, code or admission number. [suggestions] are the students the
/// matching engine already thought of, offered first.
Future<StudentHit?> pickStudent(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  List<MatchCandidate> suggestions = const [],
}) =>
    showDialog<StudentHit>(
      context: context,
      builder: (_) => _StudentPicker(api: api, membership: membership, suggestions: suggestions),
    );

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.api, required this.membership, required this.suggestions});

  final BankConnectApi api;
  final SchoolMembership membership;
  final List<MatchCandidate> suggestions;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  final _query = TextEditingController();
  List<StudentHit> _hits = const [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 2) {
      setState(() => _error = 'Type at least two letters.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final hits = await widget.api.searchStudents(widget.membership, _query.text);
      if (mounted) setState(() => _hits = hits);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Choose a student'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.suggestions.isNotEmpty) ...[
                const Text('Suggested by the payment', style: TextStyle(fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in widget.suggestions)
                      ActionChip(
                        label: Text('${c.studentName} (${c.studentCode})'),
                        onPressed: () => Navigator.of(context).pop(
                          StudentHit(
                            id: c.studentId, name: c.studentName, studentCode: c.studentCode, admissionNumber: '',
                            className: c.className, status: c.studentStatus,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _query,
                autofocus: widget.suggestions.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Name, student code or admission number',
                  suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                ),
              ),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E)))),
              if (_searching) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final hit in _hits)
                      ListTile(title: Text(hit.name), subtitle: Text(hit.subtitle), onTap: () => Navigator.of(context).pop(hit)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      );
}

/// A note is required for anything that changes what a payment means; the server insists too.
Future<String?> askNote(BuildContext context, {required String title, required String hint, required String action}) =>
    showDialog<String>(context: context, builder: (_) => _NoteDialog(title: title, hint: hint, action: action));

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.hint, required this.action});

  final String title;
  final String hint;
  final String action;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _note,
          maxLength: 500,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.hint),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: _note.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_note.text.trim()),
            child: Text(widget.action),
          ),
        ],
      );
}

typedef AssignChoice = ({StudentHit student, String? purpose, String note});

/// Give the whole payment to one student.
Future<AssignChoice?> askAssign(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  required BankPayment payment,
}) =>
    showDialog<AssignChoice>(
      context: context,
      builder: (_) => _AssignDialog(api: api, membership: membership, payment: payment),
    );

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({required this.api, required this.membership, required this.payment});

  final BankConnectApi api;
  final SchoolMembership membership;
  final BankPayment payment;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  final _note = TextEditingController();
  StudentHit? _student;
  String? _purpose;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final picked = await pickStudent(
      context, api: widget.api, membership: widget.membership, suggestions: widget.payment.candidates,
    );
    if (picked != null && mounted) setState(() => _student = picked);
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final top = payment.candidates.isEmpty ? null : payment.candidates.first;
    final student = _student;
    return AlertDialog(
      title: const Text('Assign to a student'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${formatMoneyMinor(payment.amountMinor, currency: payment.currency)} from ${payment.senderTitle}'),
            const SizedBox(height: 12),
            if (student != null) Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (student != null) Text(student.subtitle),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_search_outlined),
              label: Text(student == null ? 'Choose a student' : 'Choose a different student'),
              onPressed: _choose,
            ),
            if (top != null && student == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Best guess: ${top.studentName} (${top.score}%)', style: const TextStyle(color: Color(0xFF5F6B7A))),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _purpose,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Paid for'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('What the account collects')),
                for (final e in bankPurposes.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
              ],
              onChanged: (value) => setState(() => _purpose = value),
            ),
            TextField(controller: _note, maxLength: 500, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: student == null
              ? null
              : () => Navigator.of(context).pop((student: student, purpose: _purpose, note: _note.text.trim())),
          child: const Text('Assign'),
        ),
      ],
    );
  }
}

typedef SplitPart = ({String studentId, int amountMinor, String? purpose});
typedef SplitChoice = ({List<SplitPart> parts, String note});

/// Share the payment between several students. The parts may add up to less than the payment (the
/// rest stays open) but never to more.
Future<SplitChoice?> askSplit(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  required BankPayment payment,
}) =>
    showDialog<SplitChoice>(
      context: context,
      builder: (_) => _SplitDialog(api: api, membership: membership, payment: payment),
    );

class _SplitDialog extends StatefulWidget {
  const _SplitDialog({required this.api, required this.membership, required this.payment});

  final BankConnectApi api;
  final SchoolMembership membership;
  final BankPayment payment;

  @override
  State<_SplitDialog> createState() => _SplitDialogState();
}

class _SplitDialogState extends State<_SplitDialog> {
  static const _maxParts = 6;

  final _students = <StudentHit?>[null, null];
  final _amounts = [TextEditingController(), TextEditingController()];
  final _note = TextEditingController();

  @override
  void dispose() {
    for (final c in [..._amounts, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _total => _amounts.fold(0, (sum, c) => sum + (parseNairaToMinor(c.text) ?? 0));

  bool get _valid =>
      _students.every((s) => s != null) &&
      _amounts.every((c) => (parseNairaToMinor(c.text) ?? 0) > 0) &&
      _total <= widget.payment.amountMinor;

  Future<void> _choose(int index) async {
    final picked = await pickStudent(
      context, api: widget.api, membership: widget.membership, suggestions: widget.payment.candidates,
    );
    if (picked != null && mounted) setState(() => _students[index] = picked);
  }

  void _submit() {
    final parts = <SplitPart>[
      for (var i = 0; i < _amounts.length; i++)
        (studentId: _students[i]!.id, amountMinor: parseNairaToMinor(_amounts[i].text) ?? 0, purpose: null),
    ];
    Navigator.of(context).pop((parts: parts, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final over = _total > payment.amountMinor;
    return AlertDialog(
      title: const Text('Split between students'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment: ${formatMoneyMinor(payment.amountMinor, currency: payment.currency)}'),
            const SizedBox(height: 8),
            for (var i = 0; i < _amounts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _choose(i),
                        child: Text(_students[i]?.name ?? 'Choose student', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _amounts[i],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (₦)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _amounts.length >= _maxParts
                  ? null
                  : () => setState(() {
                        _students.add(null);
                        _amounts.add(TextEditingController());
                      }),
              icon: const Icon(Icons.add),
              label: const Text('Add another student'),
            ),
            Text(
              'Allocated ${formatMoneyMinor(_total)} of ${formatMoneyMinor(payment.amountMinor)}'
              '${over ? ' - more than the payment' : _total < payment.amountMinor ? ' - the rest stays open' : ''}',
              style: TextStyle(color: over ? const Color(0xFFB3261E) : const Color(0xFF5F6B7A)),
            ),
            TextField(controller: _note, maxLength: 500, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _valid ? _submit : null, child: const Text('Split')),
      ],
    );
  }
}
