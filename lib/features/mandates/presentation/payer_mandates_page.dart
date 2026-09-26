import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_widgets.dart';

/// The payer's own Direct Debit: the school, the bank, the MASKED account, the provider and what the mandate is, in words they read before they
/// authorise it themselves. Nobody at the school can authorise for them, and it is never called active until the provider says it can be debited.
///
/// Online only: the payer's authority, the bank's one-time password and the provider's answer all live on the server.
class PayerMandatesPage extends StatefulWidget {
  const PayerMandatesPage({super.key, required this.membership});

  final SchoolMembership membership;

  @override
  State<PayerMandatesPage> createState() => _PayerMandatesPageState();
}

class _PayerMandatesPageState extends State<PayerMandatesPage> {
  List<Mandate>? _mandates;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mandates == null && _error == null) _load();
  }

  Future<void> _load() async {
    final api = MandatesScope.maybeOf(context);
    if (api == null) return;
    try {
      final mandates = await api.myMandates(widget.membership);
      if (!mounted) return;
      setState(() {
        _mandates = mandates;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = MandatesScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Direct Debit')),
      body: api == null
          ? const MandatesNoServerNotice()
          : (_mandates == null
              ? (_error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_mandates!.isEmpty) const BankSection(title: 'No direct debit', child: Text('The school has not set up a direct debit for you. If it does, you will be asked to review and authorise it here first.')),
                      for (final m in _mandates!) _card(api, m),
                    ],
                  ),
                )),
    );
  }

  Widget _card(MandatesApi api, Mandate m) => Card(
        key: ValueKey('payer-${m.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Direct Debit Mandate', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            FactRow('School', m.schoolName),
            FactRow('For', m.familyName),
            FactRow('Bank', m.bankName.isEmpty ? m.bankCode : m.bankName),
            FactRow('Account', m.accountMask),
            if (m.maximumAmountMinor != null) FactRow('Maximum debit', '${formatMoneyMinor(m.maximumAmountMinor!)}${m.maximumNote.isEmpty ? '' : ' - ${m.maximumNote}'}'),
            FactRow('Provider', m.providerName),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [MandateStatusChip(m.status), if (m.isSandbox) const SandboxTag()]),
            const SizedBox(height: 8),
            Text(
              m.debitReady ? 'Active: the school can debit this account for approved school fees.' : 'Not active yet. Nothing can be debited from your account until your bank has activated it and the provider says it is ready.',
              key: ValueKey('payer-state-${m.id}'),
            ),
            if (m.consentRequired) _authorise(api, m),
            if (m.status == 'pending_activation') _activate(api, m),
            if (m.isLive)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: ValueKey('payer-cancel-${m.id}'),
                  onPressed: () async {
                    if (await confirmAction(context, title: 'Cancel this direct debit?', message: 'The school will no longer be able to debit this account.', action: 'Cancel the direct debit', danger: true)) {
                      await _act(() => api.cancelMyMandate(widget.membership, m.id, reason: 'The payer withdrew their authority.'));
                    }
                  },
                  child: const Text('Cancel this direct debit', style: TextStyle(color: Color(0xFFB3261E))),
                ),
              ),
          ]),
        ),
      );

  Future<void> _act(Future<Mandate> Function() action, {String? done}) async {
    try {
      await action();
      if (mounted && done != null) showBankMessage(context, done);
      await _load();
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    }
  }

  Widget _authorise(MandatesApi api, Mandate m) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF4F6F8), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Please read this before you authorise', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(m.consentText, key: ValueKey('consent-text-${m.id}')),
            const SizedBox(height: 10),
            FilledButton(
              key: ValueKey('authorise-${m.id}'),
              onPressed: () => _act(() => api.authorise(widget.membership, m.id, consentTextHash: m.consentTextHash), done: 'You authorised this direct debit.'),
              child: const Text('Review and Authorise'),
            ),
          ]),
        ),
      );

  Widget _activate(MandatesApi api, Mandate m) {
    final a = m.activation;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Activate it', style: TextStyle(fontWeight: FontWeight.w700)),
        if (a.note.isNotEmpty) Text(a.note),
        if (a.isTransfer)
          Text('Transfer${a.transferAmountMinor == null ? '' : ' ${formatMoneyMinor(a.transferAmountMinor!)}'} from this account to ${a.transferBank} ${a.transferAccount}.', key: ValueKey('payer-transfer-${m.id}')),
        if (a.deadline != null) Text('Do this by ${shortDateTime(a.deadline)}.', key: ValueKey('payer-deadline-${m.id}'), style: const TextStyle(fontWeight: FontWeight.w700)),
        if (a.formUrl.isNotEmpty) Text('Or print and sign the mandate form and take it to your bank: ${a.formUrl}'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (a.canActivateInApp) OutlinedButton(key: ValueKey('activate-${m.id}'), onPressed: () => _otp(api, m), child: const Text('Activate with a one-time password')),
          OutlinedButton(key: ValueKey('refresh-${m.id}'), onPressed: () => _act(() => api.refreshMyMandate(widget.membership, m.id), done: 'Checked with the provider.'), child: const Text('Check its status')),
        ]),
      ]),
    );
  }

  Future<void> _otp(MandatesApi api, Mandate m) async {
    final List<ActivationField> fields;
    try {
      fields = await api.requestActivation(widget.membership, m.id);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
      return;
    }
    if (!mounted) return;
    final answers = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => FieldsDialog(
        title: 'Enter what your bank sent you',
        fields: [for (final f in fields) DialogField(name: f.name, label: f.label.isEmpty ? f.name : f.label, fieldKey: ValueKey('activation-${f.name}'), secret: true, numeric: true, helper: f.description)],
        action: 'Activate',
        confirmKey: const ValueKey('activation-confirm'),
      ),
    );
    if (answers == null || !mounted) return;
    await _act(() => api.confirmActivation(widget.membership, m.id, answers: answers), done: 'Checked with your bank.');
    answers.clear();
  }
}
