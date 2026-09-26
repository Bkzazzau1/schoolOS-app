import 'package:flutter/material.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/bank_widgets.dart' show describeBankError;
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';

/// Where a parent pays: the FAMILY's account, shown once, however many children there are.
///
/// It is the school's own account, issued or recorded by the school's finance side; SchoolOS does not receive or hold
/// the payment. What it looks like depends on the bank, so the screen shows whatever the bank gave (the number under
/// the bank's own word for it, and any extra facts to quote) instead of assuming one format. It needs the school's
/// server: without one it says so, and never shows a number it made up.
class FamilyPaymentAccountsCard extends StatefulWidget {
  const FamilyPaymentAccountsCard({super.key, required this.membership, required this.onCopy});

  final SchoolMembership membership;
  final Future<void> Function(String value, String label) onCopy;

  @override
  State<FamilyPaymentAccountsCard> createState() => _FamilyPaymentAccountsCardState();
}

class _FamilyPaymentAccountsCardState extends State<FamilyPaymentAccountsCard> {
  FamilyFeesApi? _api;
  Future<List<MyFamily>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = FamilyFeesScope.maybeOf(context);
    if (api != _api || (_future == null && api != null)) {
      _api = api;
      _future = api?.myFamilies(widget.membership);
    }
  }

  void _retry() {
    final next = _api?.myFamilies(widget.membership);
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Your family\'s payment account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              'One account for the whole family, however many children you have. It is the school\'s own account: your payment goes '
              'straight to the school, and SchoolOS does not receive or hold it.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _body(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_api == null) {
      return const _Note(
        key: ValueKey('family-account-no-server'),
        text: 'Payment accounts come from your school\'s server, and this device is not connected to one, so no account can be shown. '
            'Nothing is made up here.',
      );
    }
    return FutureBuilder<List<MyFamily>>(
      future: _future,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        if (state.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Note(key: const ValueKey('family-account-error'), text: describeBankError(state.error!)),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          );
        }
        final families = [for (final f in state.data ?? const <MyFamily>[]) if (f.accounts.isNotEmpty) f];
        if (families.isEmpty) {
          return const _Note(
            key: ValueKey('family-account-none'),
            text: 'The school has not set up a payment account for your family yet. It appears here as soon as the Finance Office does. '
                'Until then, please ask the school where to pay.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final family in families) ...[
              if (families.length > 1) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(family.displayName, style: const TextStyle(fontWeight: FontWeight.w900))),
              for (final account in family.accounts) Padding(padding: const EdgeInsets.only(bottom: 10), child: _AccountTile(account: account, onCopy: widget.onCopy)),
            ],
          ],
        );
      },
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.onCopy});

  final FamilyPayAccount account;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    return Container(
      key: ValueKey('family-account-${account.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(account.bankLabel, style: const TextStyle(fontWeight: FontWeight.w900))),
              if (account.isTest)
                const Chip(label: Text('Test account'), visualDensity: VisualDensity.compact, backgroundColor: Color(0xFFFFF3CD)),
            ],
          ),
          if (account.canPay) ...[
            const SizedBox(height: 6),
            Text(account.numberLabel, style: muted),
            Row(
              children: [
                Expanded(
                  child: SelectableText(account.accountNumber, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
                IconButton(
                  tooltip: 'Copy ${account.numberLabel.toLowerCase()}',
                  onPressed: () => onCopy(account.accountNumber, account.numberLabel),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            if (account.accountName.isNotEmpty) Text('Account name: ${account.accountName}'),
            for (final detail in account.details)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(child: Text('${detail.label}: ${detail.value}')),
                    IconButton(
                      tooltip: 'Copy ${detail.label.toLowerCase()}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onCopy(detail.value, detail.label),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            if (account.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(account.note, style: muted)),
            if (account.isResting) Padding(padding: const EdgeInsets.only(top: 6), child: Text(account.statusLabel, style: muted)),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              account.isPaused
                  ? 'The school has paused this account. Please contact the Finance Office before paying.'
                  : 'The school is still setting this account up. Its number will appear here when it is ready.',
              style: TextStyle(color: account.isPaused ? const Color(0xFFB3261E) : scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(height: 1.4)),
      );
}
