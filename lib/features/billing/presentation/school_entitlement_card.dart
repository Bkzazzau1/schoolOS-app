import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exceptions.dart';
import '../data/billing_repository.dart';
import '../domain/billing_invoice.dart';
import '../domain/school_entitlement_summary.dart';

/// This specific school's own subscription and premium-entitlement status - never the
/// organization-wide [OrganizationSubscriptionCard]'s accessMode, which must not be read as
/// proof that this particular school has paid. Open to any proprietor/administrator who can
/// reach it; the payment action only ever appears when the server says this viewer has
/// billing authority for the school's organization.
class SchoolEntitlementCard extends StatefulWidget {
  const SchoolEntitlementCard({
    super.key,
    required this.schoolId,
    required this.repository,
  });

  final String schoolId;
  final BillingRepository repository;

  @override
  State<SchoolEntitlementCard> createState() => _SchoolEntitlementCardState();
}

class _SchoolEntitlementCardState extends State<SchoolEntitlementCard> {
  SchoolEntitlementSummary? _summary;
  String? _error;
  bool _loading = true;
  bool _payBusy = false;
  BillingPaymentAttempt? _pendingAttempt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SchoolEntitlementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schoolId != widget.schoolId) _load();
  }

  // Never cached: a viewer who paid moments ago, or whose school was just suspended, must
  // always see the server's current answer, not a stale in-memory one from before a payment.
  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await widget.repository.schoolEntitlements(widget.schoolId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _pendingAttempt = null;
      });
    } on ApiOfflineException {
      _setError("This school's subscription status is unavailable while SkulGen is offline.");
    } on SessionExpiredException catch (error) {
      _setError(error.message);
    } on ApiException catch (error) {
      _setError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    final billing = _summary?.billing;
    if (billing == null || _payBusy) return;
    setState(() => _payBusy = true);
    try {
      final checkout = await widget.repository.initializeCheckout(
        organizationId: billing.organizationId,
        invoiceId: billing.invoiceId,
      );
      final rawUrl = checkout.payment.checkoutUrl;
      final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('The Paystack checkout could not be opened on this device.');
        return;
      }
      if (!mounted) return;
      setState(() => _pendingAttempt = checkout.payment);
      _message('Paystack checkout opened. Return here after payment and refresh the status.');
    } on ApiOfflineException {
      _message('Could not reach SkulGen. Check your connection and try again.');
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('The payment checkout could not be opened.');
    } finally {
      if (mounted) setState(() => _payBusy = false);
    }
  }

  Future<void> _verify() async {
    final billing = _summary?.billing;
    final attempt = _pendingAttempt;
    if (billing == null || attempt == null || _payBusy) return;
    setState(() => _payBusy = true);
    try {
      final result = await widget.repository.verifyPayment(
        organizationId: billing.organizationId,
        reference: attempt.reference,
      );
      if (!mounted) return;
      _message(
        result.invoice.paid ? 'Payment confirmed. Thank you.' : 'Payment has not been confirmed yet.',
      );
      // Success is only ever shown once this school's entitlement status is reloaded fresh
      // from the server - never assumed locally just because checkout returned.
      await _load();
    } on ApiOfflineException {
      _message('Could not reach SkulGen. Check your connection and try again.');
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _payBusy = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.school_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "This school's subscription",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (summary != null && summary.subscriptionApplies)
                  Chip(label: Text(summary.paymentStatusLabel)),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
            ] else if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (summary != null) ...[
              const SizedBox(height: 14),
              _SchoolEntitlementDetails(
                summary: summary,
                payBusy: _payBusy,
                pendingAttempt: _pendingAttempt,
                onPay: _pay,
                onVerify: _verify,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SchoolEntitlementDetails extends StatelessWidget {
  const _SchoolEntitlementDetails({
    required this.summary,
    required this.payBusy,
    required this.pendingAttempt,
    required this.onPay,
    required this.onVerify,
  });

  final SchoolEntitlementSummary summary;
  final bool payBusy;
  final BillingPaymentAttempt? pendingAttempt;
  final VoidCallback onPay;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!summary.subscriptionApplies) {
      return Text(
        'This school is not attached to a SkulGen SaaS account. Subscription billing does '
        'not apply, and every premium capability stays available.',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final term = summary.academicTerm;
    final enrollment = summary.enrollment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _Metric(label: 'Current term', value: term == null ? 'Not configured' : term.name),
            _Metric(
              label: 'Fixed bracket',
              value: enrollment == null
                  ? 'No roster census yet'
                  : enrollment.isPriceKnown
                      ? enrollment.pricingLabel
                      : (enrollment.undefinedReason ?? 'Not yet determined'),
            ),
            if (enrollment?.billableStudentCount != null)
              _Metric(label: 'Billable students', value: '${enrollment!.billableStudentCount}'),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PremiumCapabilityChip(
              label: 'Publish CBT exams',
              capability: summary.capability('cbt_exam_publish'),
            ),
            _PremiumCapabilityChip(
              label: 'Generate report cards',
              capability: summary.capability('report_card_generation'),
            ),
          ],
        ),
        if (!summary.premiumEnforcementEnabled) ...[
          const SizedBox(height: 10),
          Text(
            'Premium enforcement is not active yet. These capabilities remain available '
            'regardless of payment status until SkulGen turns enforcement on.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        if (summary.canManageBilling) ...[
          const SizedBox(height: 16),
          _BillingSection(
            billing: summary.billing,
            payBusy: payBusy,
            pendingAttempt: pendingAttempt,
            onPay: onPay,
            onVerify: onVerify,
          ),
        ],
      ],
    );
  }
}

class _BillingSection extends StatelessWidget {
  const _BillingSection({
    required this.billing,
    required this.payBusy,
    required this.pendingAttempt,
    required this.onPay,
    required this.onVerify,
  });

  final SchoolBillingDetail? billing;
  final bool payBusy;
  final BillingPaymentAttempt? pendingAttempt;
  final VoidCallback onPay;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = billing;
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "No invoice has been issued for this school's current period yet.",
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final dueLabel = detail.dueAt == null ? null : _dateLabel(detail.dueAt!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.invoiceNumber,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${_money(detail.currency, detail.amountDueMinor)}'
                '${dueLabel == null ? '' : ' · due $dueLabel'}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (detail.payable)
            Wrap(
              spacing: 8,
              children: [
                if (pendingAttempt != null)
                  OutlinedButton.icon(
                    onPressed: payBusy ? null : onVerify,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh payment'),
                  ),
                FilledButton.icon(
                  onPressed: payBusy ? null : onPay,
                  icon: payBusy
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Pay with Paystack'),
                ),
              ],
            )
          else if (detail.paid)
            const Chip(avatar: Icon(Icons.check_circle_rounded, size: 18), label: Text('Paid')),
        ],
      ),
    );
  }
}

class _PremiumCapabilityChip extends StatelessWidget {
  const _PremiumCapabilityChip({required this.label, required this.capability});

  final String label;
  final SchoolEntitlementCapability capability;

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      avatar: Icon(
        capability.available ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
        size: 18,
      ),
      label: Text(label),
    );
    if (capability.available || capability.reason.isEmpty) return chip;
    return Tooltip(message: capability.reason, child: chip);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _money(String currency, int minor) {
  final safeMinor = minor < 0 ? 0 : minor;
  final major = safeMinor ~/ 100;
  final cents = safeMinor.remainder(100);
  final digits = major.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final symbol = currency == 'NGN' ? '₦' : '$currency ';
  return cents == 0 ? '$symbol$buffer' : '$symbol$buffer.${cents.toString().padLeft(2, '0')}';
}
