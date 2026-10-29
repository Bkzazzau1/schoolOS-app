import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../shared/models/school_membership.dart';
import '../../bankconnect/presentation/bank_widgets.dart' show describeBankError;
import '../../familyfees/data/family_fees_api.dart';
import '../../familyfees/domain/family_fees_models.dart';
import '../domain/verified_payment_receipt_pdf.dart';

/// What Smart Money Collection has actually verified for this family - read straight from the same
/// virtual-account ledger Finance Office's own Collections screen reads, never from a locally-editable
/// number. Deliberately its own card, separate from "Your children" below: that card is the school's
/// manual fee ledger, a different record the school keeps by hand. The two are never added together here,
/// because nothing proves they do not already overlap - combining them could double-count a payment that
/// is also recorded manually. If a figure here ever disagrees with the manual record, Finance Office's own
/// Collections screen is correct for what it covers.
class VerifiedCollectionsCard extends StatefulWidget {
  const VerifiedCollectionsCard({super.key, required this.membership});

  final SchoolMembership membership;

  @override
  State<VerifiedCollectionsCard> createState() => _VerifiedCollectionsCardState();
}

class _FamilyCollections {
  const _FamilyCollections(this.family, this.payments);
  final MyFamily family;
  final List<FamilyVerifiedPayment> payments;
}

class _VerifiedCollectionsCardState extends State<VerifiedCollectionsCard> {
  FamilyFeesApi? _api;
  Future<List<_FamilyCollections>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = FamilyFeesScope.maybeOf(context);
    if (api != _api || (_future == null && api != null)) {
      _api = api;
      _future = api == null ? null : _load(api);
    }
  }

  Future<List<_FamilyCollections>> _load(FamilyFeesApi api) async {
    final families = await api.myFamilies(widget.membership);
    final result = <_FamilyCollections>[];
    for (final family in families) {
      result.add(_FamilyCollections(family, await api.payments(widget.membership, family.id)));
    }
    return result;
  }

  void _retry() {
    final api = _api;
    setState(() => _future = api == null ? null : _load(api));
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
            const Text('Verified Smart Money Collection', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              'Confirmed transfers into your family\'s own account above, and what they were put towards. This is separate from '
              'your school\'s own manual fee record below - the two are never added together here.',
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
        key: ValueKey('verified-collections-no-server'),
        text: 'Verified collections come from your school\'s server, and this device is not connected to one, so nothing can be shown here.',
      );
    }
    return FutureBuilder<List<_FamilyCollections>>(
      future: _future,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        if (state.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Note(key: const ValueKey('verified-collections-error'), text: describeBankError(state.error!)),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          );
        }
        final families = state.data ?? const <_FamilyCollections>[];
        if (families.isEmpty) {
          return const _Note(
            key: ValueKey('verified-collections-none'),
            text: 'No family account has been set up yet, so there is nothing to verify here.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final each in families) ...[
              if (families.length > 1) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(each.family.displayName, style: const TextStyle(fontWeight: FontWeight.w900))),
              _PositionSummary(position: each.family.position),
              const SizedBox(height: 10),
              _PaymentsList(payments: each.payments, schoolName: widget.membership.schoolName, familyName: each.family.displayName),
              if (each != families.last) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _PositionSummary extends StatelessWidget {
  const _PositionSummary({required this.position});
  final FamilyPosition position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget metric(String label, int amountMinor) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(_money(amountMinor), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          metric('Paid (verified)', position.paidMinor),
          metric('Outstanding', position.outstandingMinor),
          if (position.creditMinor > 0) metric('Credit held', position.creditMinor),
        ],
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.payments, required this.schoolName, required this.familyName});
  final List<FamilyVerifiedPayment> payments;
  final String schoolName;
  final String familyName;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _Note(
        key: ValueKey('verified-collections-no-payments'),
        text: 'No transfer into this account has been confirmed yet. One appears here as soon as the provider confirms it.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final payment in payments)
          Container(
            key: ValueKey('verified-payment-${payment.transactionId}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: payment.countsTowardBalance ? scheme.surfaceContainerLow : scheme.errorContainer.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(payment.dateLabel, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(_money(payment.amountMinor), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                Text('${payment.provider} · ${payment.reference}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  payment.statusLabel,
                  style: TextStyle(fontWeight: FontWeight.w700, color: payment.countsTowardBalance ? scheme.primary : scheme.error),
                ),
                if (payment.countsTowardBalance) ...[
                  for (final allocation in payment.allocations)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${allocation.studentName} · ${allocation.item} · ${_money(allocation.amountMinor)}'),
                    ),
                  if (payment.creditMinor > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Held as family credit · ${_money(payment.creditMinor)}')),
                  if (payment.unappliedMinor > 0)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('Not yet applied · ${_money(payment.unappliedMinor)}', style: TextStyle(color: scheme.error))),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Printing.layoutPdf(
                        onLayout: (format) => buildVerifiedPaymentReceiptPdf(payment: payment, schoolName: schoolName, familyName: familyName),
                        name: 'Receipt - $familyName - ${payment.dateLabel}',
                      ),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Download receipt'),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('This payment no longer counts toward your balance.'),
                  ),
              ],
            ),
          ),
      ],
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

String _money(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    out.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) out.write(',');
  }
  return '${negative ? '-' : ''}₦$out';
}
