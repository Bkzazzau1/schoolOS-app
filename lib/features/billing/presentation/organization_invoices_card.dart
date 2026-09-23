import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exceptions.dart';
import '../../account/domain/organization_membership.dart';
import '../data/billing_repository.dart';
import '../domain/billing_invoice.dart';

class OrganizationInvoicesCard extends StatefulWidget {
  const OrganizationInvoicesCard({
    super.key,
    required this.organization,
    required this.repository,
  });

  final OrganizationMembership organization;
  final BillingRepository repository;

  @override
  State<OrganizationInvoicesCard> createState() => _OrganizationInvoicesCardState();
}

class _OrganizationInvoicesCardState extends State<OrganizationInvoicesCard> {
  List<BillingInvoice> _invoices = const [];
  bool _loading = true;
  bool _issuing = false;
  String? _busyInvoiceId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrganizationInvoicesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organization.organizationId != widget.organization.organizationId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoices = await widget.repository.invoices(
        widget.organization.organizationId,
      );
      if (!mounted) return;
      setState(() => _invoices = invoices);
    } on ApiOfflineException {
      _setError('Invoice details are unavailable while SchoolOS is offline.');
    } on SessionExpiredException catch (error) {
      _setError(error.message);
    } on ApiException catch (error) {
      _setError(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _issueInvoice() async {
    if (_issuing) return;
    setState(() => _issuing = true);
    try {
      await widget.repository.issueInvoice(widget.organization.organizationId);
      if (!mounted) return;
      _message('Invoice prepared from the latest billing usage snapshot.');
      await _load();
    } on ApiOfflineException {
      _message('Could not reach SchoolOS. Check your connection and try again.');
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  Future<void> _pay(BillingInvoice invoice) async {
    if (_busyInvoiceId != null) return;
    setState(() => _busyInvoiceId = invoice.id);
    try {
      final checkout = await widget.repository.initializeCheckout(
        organizationId: widget.organization.organizationId,
        invoiceId: invoice.id,
      );
      final rawUrl = checkout.payment.checkoutUrl;
      final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _message('The Paystack checkout could not be opened on this device.');
        return;
      }
      if (!mounted) return;
      _message('Paystack checkout opened. Return here after payment and refresh the status.');
      await _load();
    } on ApiOfflineException {
      _message('Could not reach SchoolOS. Check your connection and try again.');
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('The payment checkout could not be opened.');
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
    }
  }

  Future<void> _verify(BillingInvoice invoice, BillingPaymentAttempt attempt) async {
    if (_busyInvoiceId != null) return;
    setState(() => _busyInvoiceId = invoice.id);
    try {
      final result = await widget.repository.verifyPayment(
        organizationId: widget.organization.organizationId,
        reference: attempt.reference,
      );
      if (!mounted) return;
      _message(
        result.invoice.paid
            ? 'Payment confirmed. Thank you.'
            : 'Payment has not been confirmed yet.',
      );
      await _load();
    } on ApiOfflineException {
      _message('Could not reach SchoolOS. Check your connection and try again.');
    } on SessionExpiredException catch (error) {
      _message(error.message);
    } on ApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
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
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Invoices & payments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _issuing ? null : _issueInvoice,
                  icon: _issuing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: Text(_issuing ? 'Preparing…' : 'Prepare invoice'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Invoices are calculated by the server from the plan and an authoritative billing usage snapshot; this app cannot enter or alter the charge amount.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (_invoices.isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'No SchoolOS invoices have been issued for this organization yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              for (final invoice in _invoices.take(8)) ...[
                _InvoiceRow(
                  invoice: invoice,
                  busy: _busyInvoiceId == invoice.id,
                  onPay: () => _pay(invoice),
                  onVerify: (attempt) => _verify(invoice, attempt),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.busy,
    required this.onPay,
    required this.onVerify,
  });

  final BillingInvoice invoice;
  final bool busy;
  final VoidCallback onPay;
  final ValueChanged<BillingPaymentAttempt> onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    BillingPaymentAttempt? pendingAttempt;
    for (final attempt in invoice.paymentAttempts) {
      if (attempt.pending) {
        pendingAttempt = attempt;
        break;
      }
    }

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.number,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_money(invoice.currency, invoice.amountDueMinor)} · ${invoice.billableStudentCount} billable students · ${_statusLabel(invoice.status)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (invoice.payable)
            Wrap(
              spacing: 8,
              children: [
                if (pendingAttempt != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onVerify(pendingAttempt!),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh payment'),
                  ),
                FilledButton.icon(
                  onPressed: busy ? null : onPay,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Pay with Paystack'),
                ),
              ],
            )
          else if (invoice.paid)
            const Chip(
              avatar: Icon(Icons.check_circle_rounded, size: 18),
              label: Text('Paid'),
            ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'open' => 'Open',
      'paid' => 'Paid',
      'void' => 'Void',
      'uncollectible' => 'Uncollectible',
      'draft' => 'Draft',
      _ => status,
    };

String _money(String currency, int minor) {
  final major = minor ~/ 100;
  final cents = minor.remainder(100);
  final digits = major.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final symbol = currency == 'NGN' ? '₦' : '$currency ';
  return cents == 0
      ? '$symbol$buffer'
      : '$symbol$buffer.${cents.toString().padLeft(2, '0')}';
}
