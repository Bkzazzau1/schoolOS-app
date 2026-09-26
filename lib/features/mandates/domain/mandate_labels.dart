import 'package:flutter/material.dart';

/// Direct-debit words as a school says them. Provider codes are the server's; the wording is SchoolOS's.

const mandateStatusLabels = <String, String>{
  'draft': 'Being set up',
  'pending_consent': 'Waiting for the payer to authorise',
  'pending_activation': 'Waiting for the payer to activate',
  'activating': 'Being activated',
  'pending_provider_setup': 'Provider is setting it up',
  'active': 'Active',
  'suspended': 'Suspended',
  'cancelled': 'Cancelled',
  'expired': 'Expired',
  'failed': 'Failed',
};

String mandateStatusLabel(String status) => mandateStatusLabels[status] ?? status;

Color mandateStatusColor(String status) => switch (status) {
      'active' => const Color(0xFF1B7F3B),
      'pending_consent' || 'pending_activation' || 'activating' || 'pending_provider_setup' || 'draft' => const Color(0xFF8A6D00),
      'suspended' || 'cancelled' || 'expired' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

const batchStatusLabels = <String, String>{
  'draft': 'Draft',
  'pending_approval': 'Waiting for approval',
  'rejected': 'Rejected',
  'approved': 'Approved',
  'processing': 'Debiting',
  'partially_successful': 'Completed with failures',
  'completed': 'Completed',
  'failed': 'Failed',
  'cancelled': 'Cancelled',
};

String batchStatusLabel(String status) => batchStatusLabels[status] ?? status;

Color batchStatusColor(String status) => switch (status) {
      'completed' || 'approved' => const Color(0xFF1B7F3B),
      'pending_approval' || 'processing' || 'draft' => const Color(0xFF8A6D00),
      'partially_successful' => const Color(0xFF8A6D00),
      'cancelled' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

const debitStatusLabels = <String, String>{
  'pending': 'Waiting',
  'skipped': 'Not selected',
  'debiting': 'Being debited',
  'unknown': 'Outcome not known yet',
  'success': 'Debited',
  'failed': 'Failed',
  'retrying': 'Trying again',
  'cancelled': 'Cancelled',
};

String debitStatusLabel(String status) => debitStatusLabels[status] ?? status;

Color debitStatusColor(String status) => switch (status) {
      'success' => const Color(0xFF1B7F3B),
      'pending' || 'debiting' || 'retrying' || 'unknown' => const Color(0xFF8A6D00),
      'skipped' || 'cancelled' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

const eligibilityLabels = <String, String>{
  'eligible': 'Ready to debit',
  'no_mandate': 'No mandate',
  'not_ready': 'Mandate not ready',
  'nothing_due': 'Nothing to collect',
  'provider_unavailable': 'Provider not working',
  'provider_cannot_debit': 'Provider cannot debit yet',
};

String eligibilityLabel(String status) => eligibilityLabels[status] ?? status;

Color eligibilityColor(String status) => status == 'eligible' ? const Color(0xFF1B7F3B) : const Color(0xFF8A6D00);

const transactionStatusLabels = <String, String>{
  'pending': 'Pending',
  'success': 'Successful',
  'failed': 'Failed',
  'reversed': 'Reversed',
  'refunded': 'Refunded',
  'unknown': 'Outcome not known yet',
  'not_found': 'The provider has no record of it yet',
};

String transactionStatusLabel(String status) => transactionStatusLabels[status] ?? status;

Color transactionStatusColor(String status) => switch (status) {
      'success' => const Color(0xFF1B7F3B),
      'pending' || 'unknown' || 'not_found' => const Color(0xFF8A6D00),
      'reversed' || 'refunded' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

/// Why a debit did not go through, in words a person can act on (the server sends the same words; this is only the fallback).
String debitFailureLabel(String code) => switch (code) {
      'insufficient_funds' => 'The account did not have enough money.',
      'payment_limit_exceeded' => 'The debit was more than the mandate allows.',
      'mandate_not_activated' => 'The mandate is not activated yet.',
      'mandate_expired' => 'The mandate has expired.',
      'mandate_deactivated' => 'The mandate has been stopped.',
      'changed_since_approval' => 'What the family owes, or the mandate, changed after approval. Nothing was debited.',
      'pending_documentation' => 'This provider\'s debit instructions are not available through SchoolOS yet.',
      '' => '',
      _ => 'The debit did not go through.',
    };

String consentRouteLabel(String route) => route == 'payer_app' ? 'The payer authorises in the SchoolOS app' : 'The payer authorises with the provider';

String batchEventLabel(String kind) => switch (kind) {
      'created' => 'Prepared',
      'preview_refreshed' => 'Preview refreshed',
      'selection_changed' => 'Selection changed',
      'amount_changed' => 'An amount was lowered',
      'submitted' => 'Submitted for approval',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'approval_invalidated' => 'Approval withdrawn: something changed',
      'started' => 'Debiting started',
      'retried' => 'Failed debits retried',
      'cancelled' => 'Cancelled',
      'revised' => 'Revised',
      _ => kind,
    };

String mandateEventLabel(String kind) => switch (kind) {
      'started' => 'Started',
      'consent_recorded' => 'The payer authorised it',
      'status_changed' => 'Status changed',
      'primary_changed' => 'Made the primary mandate',
      _ => kind,
    };

/// "Live" or "Test".
String mandateEnvironmentLabel(String environment) => environment == 'live' ? 'Live' : 'Test';

String shortDate(DateTime? value) {
  if (value == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String shortDateTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${shortDate(local)}, $hour:$minute';
}
