import 'package:flutter/material.dart';

import '../../bankconnect/presentation/bank_widgets.dart';

// Words, colours and small formats the Smart Money Collection screens share. The keys mirror the server's own lists.

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String dateLabel(DateTime? value) {
  if (value == null) return 'Not set';
  final l = value.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}';
}

String dateTimeLabel(DateTime? value) {
  if (value == null) return 'Not set';
  final l = value.toLocal();
  return '${dateLabel(value)}, ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// What happens to the accounts already made when the provider is switched.
String switchPolicyWords(String policy) => switch (policy) {
      'retire_when_settled' => 'each one stays in use until its family has paid, then it is retired.',
      'retire_at_switch' => 'they are all retired when the switch is applied.',
      'manual' => 'they are left for a person to retire.',
      _ => policy,
    };

const batchStatusLabels = <String, String>{
  'draft': 'Draft',
  'pending_approval': 'Waiting for approval',
  'rejected': 'Rejected',
  'approved': 'Approved',
  'processing': 'Generating',
  'partially_successful': 'Generated with errors',
  'completed': 'Completed',
  'failed': 'Failed',
  'cancelled': 'Cancelled',
};

String batchStatusLabel(String status) => batchStatusLabels[status] ?? status;

Color batchStatusColor(String status) => switch (status) {
      'completed' || 'approved' => const Color(0xFF1B7F3B),
      'pending_approval' || 'processing' => const Color(0xFF3B5BA5),
      'partially_successful' || 'draft' => const Color(0xFF8A6D00),
      'cancelled' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

class BatchStatusChip extends StatelessWidget {
  const BatchStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: batchStatusLabel(status), color: batchStatusColor(status));
}

/// The buckets a batch's families fall into, in the order a person works through them.
const eligibilityBuckets = <String>[
  'eligible',
  'needs_override',
  'manual_approval',
  'excluded',
  'missing_details',
  'has_account',
  'provider_conflict',
  'unsupported_mode',
  'nothing_due',
];

const eligibilityLabels = <String, String>{
  'eligible': 'Eligible',
  'needs_override': 'Needs an override',
  'manual_approval': 'Needs approval',
  'excluded': 'Excluded by policy',
  'has_account': 'Already has an account',
  'provider_conflict': 'Account with another provider',
  'missing_details': 'Payer details missing',
  'unsupported_mode': 'Not supported by the provider',
  'nothing_due': 'Nothing due',
};

String eligibilityWords(String status) => eligibilityLabels[status] ?? status;

Color eligibilityColor(String status) => switch (status) {
      'eligible' => const Color(0xFF1B7F3B),
      'needs_override' || 'manual_approval' => const Color(0xFF8A6D00),
      'has_account' || 'nothing_due' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

class EligibilityChip extends StatelessWidget {
  const EligibilityChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(label: eligibilityWords(status), color: eligibilityColor(status));
}

String generationStatusLabel(String status) => switch (status) {
      'pending' => 'Waiting',
      'generating' => 'Being generated',
      'success' => 'Generated',
      'failed' => 'Failed',
      'retrying' => 'Trying again',
      'skipped' => 'Not selected',
      _ => status,
    };

Color generationStatusColor(String status) => switch (status) {
      'success' => const Color(0xFF1B7F3B),
      'failed' => const Color(0xFFB3261E),
      'generating' || 'retrying' || 'pending' => const Color(0xFF3B5BA5),
      _ => const Color(0xFF5F6B7A),
    };

/// A family's collection account in the words the finance side uses.
String accountStatusLabel(String status) => switch (status) {
      'provisioning' => 'Being set up',
      'active' => 'Active',
      'settled' => 'Settled',
      'grace' => 'In grace period',
      'dormant' => 'Dormant',
      'suspended' => 'Suspended',
      'closing' => 'Closing',
      'closed' => 'Closed',
      'failed' => 'Failed',
      _ => status,
    };

Color accountStatusColor(String status) => switch (status) {
      'active' => const Color(0xFF1B7F3B),
      'provisioning' || 'closing' || 'grace' => const Color(0xFF3B5BA5),
      'dormant' || 'settled' || 'closed' => const Color(0xFF5F6B7A),
      _ => const Color(0xFFB3261E),
    };

String scopeLabel(String scope) => switch (scope) {
      'school' || '' => 'Using school default',
      'session' => 'Override for this session',
      'term' => 'Override for this term',
      'batch' => 'Override for this batch',
      'family' => 'Override for this family',
      _ => scope,
    };

String expiryWords(String kind, {DateTime? on, String? term, String? session}) => switch (kind) {
      'one_time' => 'Used once',
      'end_of_term' => term == null ? 'Until the end of the term' : 'Until the end of $term',
      'end_of_session' => session == null ? 'Until the end of the session' : 'Until the end of $session',
      'at_date' => 'Until ${dateLabel(on)}',
      _ => 'Until removed',
    };

/// The steps in a batch's history.
String batchEventLabel(String kind) => switch (kind) {
      'created' => 'Prepared',
      'preview_refreshed' => 'Preview refreshed',
      'selection_changed' => 'Selection changed',
      'override_set' => 'Eligibility overridden',
      'override_cleared' => 'Override removed',
      'arrears_chosen' => 'Earlier balances chosen',
      'policy_changed' => 'Batch policy changed',
      'provider_changed' => 'Moved to the new active provider',
      'revised' => 'Revised after a rejection',
      'submitted' => 'Submitted for approval',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'approval_invalidated' => 'Approval withdrawn: something changed',
      'started' => 'Generation started',
      'retried' => 'Failed families retried',
      'finished' => 'Generation finished',
      'cancelled' => 'Cancelled',
      _ => kind,
    };

/// The words for a policy value that is a whole number of hours.
String hoursWords(Object? hours) {
  final h = hours is int ? hours : int.tryParse('$hours');
  if (h == null) return 'Not set';
  if (h % 24 == 0) return '${h ~/ 24} day${h == 24 ? '' : 's'}';
  return '$h hour${h == 1 ? '' : 's'}';
}
