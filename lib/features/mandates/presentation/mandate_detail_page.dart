import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/domain/bank_labels.dart';
import '../../bankconnect/presentation/bank_widgets.dart';
import '../data/mandates_api.dart';
import '../domain/mandate_labels.dart';
import '../domain/mandate_models.dart';
import 'mandate_widgets.dart';

/// One mandate as staff see it: who, which provider, the bank and the MASKED account, whether it can be debited now and if not why, how
/// the payer activates it, and its history. It never shows a full account number: the server never sends one.
class MandateDetailPage extends StatefulWidget {
  const MandateDetailPage({super.key, required this.api, required this.membership, required this.mandateId, required this.permissions});

  final MandatesApi api;
  final SchoolMembership membership;
  final String mandateId;
  final MandatePermissions permissions;

  @override
  State<MandateDetailPage> createState() => _MandateDetailPageState();
}

class _MandateDetailPageState extends State<MandateDetailPage> {
  Mandate? _mandate;
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
      final mandate = await widget.api.mandate(widget.membership, widget.mandateId);
      if (mounted) setState(() => _mandate = mandate);
    } catch (error) {
      if (mounted) setState(() => _error = describeBankError(error));
    }
  }

  Future<void> _run(Future<Mandate> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      final next = await action();
      if (!mounted) return;
      setState(() {
        _mandate = next;
        _changed = true;
      });
      if (done != null) showBankMessage(context, done);
    } catch (error) {
      if (mounted) showBankMessage(context, describeBankError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _mandate;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(m == null ? 'Mandate' : '${m.familyName} - ${m.providerName}')),
        body: m == null
            ? (_error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
            : _body(m),
      ),
    );
  }

  Widget _body(Mandate m) {
    final can = widget.permissions.canManage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(spacing: 8, runSpacing: 4, children: [
          MandateStatusChip(m.status),
          if (m.isPrimary) const StatusChip(label: 'Primary', color: Color(0xFF3B5BA5)),
          StatusChip(label: mandateEnvironmentLabel(m.environment), color: const Color(0xFF3B5BA5)),
          if (m.isSandbox) const SandboxTag(),
        ]),
        const SizedBox(height: 12),
        BankSection(
          title: 'The mandate',
          child: Column(children: [
            FactRow('Family', '${m.familyName} (${m.familyCode})'),
            FactRow('Payer', m.payer.name),
            FactRow('Provider', m.providerName),
            FactRow('Bank', m.bankName.isEmpty ? m.bankCode : m.bankName),
            FactRow('Account', m.accountMask),
            if (m.maximumAmountMinor != null) FactRow('Most it allows', '${formatMoneyMinor(m.maximumAmountMinor!)}${m.maximumNote.isEmpty ? '' : ' - ${m.maximumNote}'}'),
            if (m.startDate != null) FactRow('Runs', '${shortDate(m.startDate)} to ${shortDate(m.endDate)}'),
            if (m.mandateCode.isNotEmpty) FactRow('Mandate code', m.mandateCode),
            if (m.providerCustomerRef.isNotEmpty) FactRow('Customer id', m.providerCustomerRef),
            if (m.providerStatus.isNotEmpty) FactRow('Provider says', m.providerStatus),
            FactRow('Authorisation', m.consentAt == null ? consentRouteLabel(m.consentRoute) : 'Given ${shortDateTime(m.consentAt)} (${m.consentChannel == 'payer_app' ? 'by the payer in the app' : 'with the provider'})'),
          ]),
        ),
        BankSection(
          title: 'Can it be debited now?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.debitReady ? 'Yes: the provider can be asked to debit it.' : 'No. ${m.debitReadyReason}', key: const ValueKey('debit-ready')),
              if (m.activatedAt != null) Text('Activated ${shortDateTime(m.activatedAt)}.', style: const TextStyle(color: Color(0xFF5F6B7A))),
              if (m.debitReadyAt != null && !m.debitReady) Text('Expected to be debit-ready from ${shortDateTime(m.debitReadyAt)}.', style: const TextStyle(color: Color(0xFF5F6B7A))),
            ],
          ),
        ),
        if (m.waitingForPayer || m.status == 'draft') _waiting(m),
        if (m.failureCode.isNotEmpty) BankSection(title: 'What went wrong', child: Text(bankErrorLabel(m.failureCode))),
        if (can) _actions(m),
        BankSection(
          title: 'History',
          child: Column(children: [
            for (final e in m.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.kind == 'status_changed' ? '${mandateStatusLabel(e.from)} to ${mandateStatusLabel(e.to)}' : mandateEventLabel(e.kind)),
                subtitle: Text('${shortDateTime(e.at)}${e.actor.isEmpty ? '' : ' - ${e.actor}'}'),
              ),
            if (m.history.isEmpty) const Text('Nothing yet.'),
          ]),
        ),
      ],
    );
  }

  Widget _waiting(Mandate m) {
    final a = m.activation;
    return BankSection(
      title: m.status == 'pending_consent' ? 'Waiting for the payer' : 'How the payer activates it',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.status == 'pending_consent')
            const Text('The payer has to review and authorise this mandate themselves in the app. Nobody at the school can do it for them, and nothing has been sent to the provider yet.'),
          if (m.status == 'draft') const Text('The provider has not been asked to make this mandate yet.'),
          if (m.status == 'pending_activation') ...[
            if (a.note.isNotEmpty) Text(a.note),
            if (a.isTransfer)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Activation transfer${a.transferAmountMinor == null ? '' : ' of ${formatMoneyMinor(a.transferAmountMinor!)}'} from the account to ${a.transferBank} ${a.transferAccount}.',
                  key: const ValueKey('transfer-note'),
                ),
              ),
            if (a.deadline != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Deadline: ${shortDateTime(a.deadline)}', key: const ValueKey('deadline'), style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ],
      ),
    );
  }

  Widget _actions(Mandate m) {
    final live = m.isLive;
    return BankSection(
      title: 'Actions',
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        OutlinedButton(key: const ValueKey('refresh'), onPressed: _busy ? null : () => _run(() => widget.api.refreshMandate(widget.membership, m.id), done: 'Asked the provider.'), child: const Text('Ask the provider now')),
        if (m.waitingForPayer)
          OutlinedButton(key: const ValueKey('resend'), onPressed: _busy ? null : () => _run(() => widget.api.resendActivation(widget.membership, m.id), done: 'The payer was reminded.'), child: const Text('Resend the payer\'s instructions')),
        if (m.status == 'draft' && (m.consentAt != null || m.consentRoute == 'provider'))
          OutlinedButton(key: const ValueKey('retry-setup'), onPressed: _busy ? null : () => _run(() => widget.api.retrySetup(widget.membership, m.id)), child: const Text('Ask the provider again')),
        if (m.status == 'active' || m.status == 'pending_provider_setup')
          OutlinedButton(
            key: const ValueKey('suspend'),
            onPressed: _busy
                ? null
                : () async {
                    if (await confirmAction(context, title: 'Suspend this mandate?', message: 'No debit is made on it while it is suspended.', action: 'Suspend')) {
                      await _run(() => widget.api.suspendMandate(widget.membership, m.id));
                    }
                  },
            child: const Text('Suspend'),
          ),
        if (m.status == 'suspended') OutlinedButton(key: const ValueKey('reactivate'), onPressed: _busy ? null : () => _run(() => widget.api.reactivateMandate(widget.membership, m.id)), child: const Text('Reactivate')),
        if (live && !m.isPrimary) OutlinedButton(key: const ValueKey('primary'), onPressed: _busy ? null : () => _run(() => widget.api.makePrimary(widget.membership, m.id), done: 'It is now the primary mandate.'), child: const Text('Make primary')),
        if (live)
          TextButton(
            key: const ValueKey('cancel'),
            onPressed: _busy
                ? null
                : () async {
                    final reason = await askReason(context, title: 'Cancel this mandate?', hint: 'Why is it being cancelled?', action: 'Cancel the mandate', minWords: 2);
                    if (reason != null) await _run(() => widget.api.cancelMandate(widget.membership, m.id, reason: reason));
                  },
            child: const Text('Cancel the mandate', style: TextStyle(color: Color(0xFFB3261E))),
          ),
      ]),
    );
  }
}
