import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../data/bank_connect_api.dart';
import '../domain/bank_labels.dart';
import '../domain/payment_models.dart';
import 'bank_widgets.dart';
import 'payment_decision_dialogs.dart';

/// Opens one payment: the evidence, what has been decided, and what a person can decide now.
/// Returns true if anything about the payment was changed, so the list behind it can refresh.
Future<bool> showPaymentDetail(
  BuildContext context, {
  required BankConnectApi api,
  required SchoolMembership membership,
  required String paymentId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scroll) => _PaymentDetail(api: api, membership: membership, paymentId: paymentId, scroll: scroll),
      ),
    ) ??
    false;

class _PaymentDetail extends StatefulWidget {
  const _PaymentDetail({required this.api, required this.membership, required this.paymentId, required this.scroll});

  final BankConnectApi api;
  final SchoolMembership membership;
  final String paymentId;
  final ScrollController scroll;

  @override
  State<_PaymentDetail> createState() => _PaymentDetailState();
}

class _PaymentDetailState extends State<_PaymentDetail> {
  /// Statuses a person has already decided: only these can be reopened (the server agrees).
  static const _reopenable = {'matched', 'partially_matched', 'unrelated_income', 'duplicate', 'reversed', 'refunded', 'investigating'};

  BankPayment? _payment;
  String? _error;
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payment = await widget.api.payment(widget.membership, widget.paymentId);
      if (mounted) setState(() => _payment = payment);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _decide(
    String action, {
    String? studentId,
    String? purpose,
    List<SplitPart>? split,
    String note = '',
  }) async {
    final payment = _payment!;
    setState(() => _busy = true);
    try {
      final updated = await widget.api.decide(
        widget.membership, payment.id,
        action: action, expectedStatus: payment.status, studentId: studentId, purpose: purpose, split: split, note: note,
      );
      if (!mounted) return;
      setState(() {
        _payment = updated;
        _changed = true;
      });
      showBankMessage(context, 'Saved.');
    } catch (error) {
      if (!mounted) return;
      showBankMessage(context, describeBankError(error));
      await _load(); // a colleague may have got there first: show what is true now
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    final choice = await askAssign(context, api: widget.api, membership: widget.membership, payment: _payment!);
    if (choice != null) await _decide('assign', studentId: choice.student.id, purpose: choice.purpose, note: choice.note);
  }

  Future<void> _split() async {
    final choice = await askSplit(context, api: widget.api, membership: widget.membership, payment: _payment!);
    if (choice != null) await _decide('split', split: choice.parts, note: choice.note);
  }

  Future<void> _withNote(String action, String title, String hint, String button) async {
    final note = await askNote(context, title: title, hint: hint, action: button);
    if (note != null) await _decide(action, note: note);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final p = _payment;
    if (p == null) {
      return _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator());
    }
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                formatMoneyMinor(p.amountMinor, currency: p.currency),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            PaymentStatusChip(p.status),
          ],
        ),
        if (p.isSandbox) const Padding(padding: EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerLeft, child: SandboxTag())),
        const SizedBox(height: 8),
        _fact('From', p.senderTitle),
        if (p.senderAccountMask.isNotEmpty || p.senderBank.isNotEmpty) _fact('Sender account', '${p.senderBank} ${p.senderAccountMask}'.trim()),
        _fact('Into', '${p.bankName} ${p.maskedAccountNumber}'.trim()),
        _fact('Date', whenLabel(p.transactionDate)),
        if (p.transactionReference.isNotEmpty) _fact('Reference', p.transactionReference),
        if (p.narration.isNotEmpty) _fact('Narration', p.narration),
        const SizedBox(height: 12),
        if (p.isCredit) _actions(p),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        ..._allocations(p),
        ..._evidence(p),
        ..._history(p),
      ],
    );
  }

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFF5F6B7A)))), Expanded(child: Text(value))],
        ),
      );

  Widget _actions(BankPayment p) {
    final final_ = p.status == 'reversed' || p.status == 'refunded';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!final_) FilledButton(onPressed: _busy ? null : _assign, child: const Text('Assign to a student')),
        if (!final_) OutlinedButton(onPressed: _busy ? null : _split, child: const Text('Split')),
        if (!final_ && p.status != 'unrelated_income')
          OutlinedButton(
            onPressed: _busy ? null : () => _withNote('unrelated_income', 'Not school fees', 'What is this money for?', 'Save'),
            child: const Text('Not school fees'),
          ),
        if (!final_ && p.status != 'investigating')
          OutlinedButton(
            onPressed: _busy ? null : () => _withNote('investigate', 'Look into this later', 'What needs checking?', 'Set aside'),
            child: const Text('Look into it'),
          ),
        if (!final_ && p.status != 'duplicate')
          OutlinedButton(
            onPressed: _busy ? null : () => _withNote('duplicate', 'Mark as a duplicate', 'Why is this a duplicate?', 'Save'),
            child: const Text('Duplicate'),
          ),
        if (!final_)
          PopupMenuButton<String>(
            tooltip: 'More',
            enabled: !_busy,
            onSelected: (value) => value == 'reversed'
                ? _withNote('reversed', 'Money returned by the bank', 'What happened?', 'Mark reversed')
                : _withNote('refunded', 'Refunded to the sender', 'Who was it refunded to, and why?', 'Mark refunded'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reversed', child: Text('The bank reversed it')),
              PopupMenuItem(value: 'refunded', child: Text('We refunded it')),
            ],
          ),
        if (_reopenable.contains(p.status))
          TextButton(
            onPressed: _busy ? null : () => _withNote('reopen', 'Reopen for review', 'Why is this being reopened?', 'Reopen'),
            child: const Text('Reopen'),
          ),
      ],
    );
  }

  List<Widget> _allocations(BankPayment p) {
    final active = p.activeAllocations;
    if (active.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Text('Allocated to', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      for (final a in active)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${a.studentName} (${a.studentCode})'),
          subtitle: Text('${purposeLabel(a.purpose)} · ${a.source == 'auto' ? 'matched automatically' : 'assigned by a person'}'),
          trailing: Text(formatMoneyMinor(a.amountMinor)),
        ),
      if (p.allocatedMinor < p.amountMinor)
        Text('${formatMoneyMinor(p.amountMinor - p.allocatedMinor)} is still unallocated.', style: const TextStyle(color: Color(0xFF8A6D00))),
    ];
  }

  List<Widget> _evidence(BankPayment p) {
    if (!p.isCredit || (p.candidates.isEmpty && p.notes.isEmpty)) return const [];
    return [
      const SizedBox(height: 16),
      const Text('What SchoolOS saw', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      for (final note in p.notes) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note)),
      for (final c in p.candidates)
        Card(
          margin: const EdgeInsets.only(top: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.studentName} (${c.studentCode}) - ${c.score}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (c.className.isNotEmpty) Text(c.className, style: const TextStyle(color: Color(0xFF5F6B7A))),
                for (final s in c.signals) Text('• ${s.detail} (+${s.points})'),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _history(BankPayment p) {
    if (p.decisions.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      for (final d in p.decisions)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(decisionActionLabel(d.action)),
          subtitle: Text('${d.actorName} · ${whenLabel(d.at)}${d.note.isEmpty ? '' : '\n${d.note}'}'),
          isThreeLine: d.note.isNotEmpty,
        ),
    ];
  }
}
