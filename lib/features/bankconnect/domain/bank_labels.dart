// Words and formats the collection screens share. The keys mirror the server's own lists.

/// What an account collects money for.
const bankPurposes = <String, String>{
  'tuition': 'Tuition',
  'transport': 'Transport',
  'books': 'Books',
  'uniforms': 'Uniforms',
  'capital': 'Capital projects',
  'general': 'General collections',
  'other': 'Other',
};

String purposeLabel(String key) => bankPurposes[key] ?? key;

const connectionStatusLabels = <String, String>{
  'pending': 'Waiting for confirmation',
  'connected': 'Connected',
  'disabled': 'Disabled',
  'needs_reauth': 'Needs new credentials',
  'error': 'Problem',
  'revoked': 'Disconnected',
};

String connectionStatusLabel(String status) => connectionStatusLabels[status] ?? status;

const webhookStatusLabels = <String, String>{
  'not_configured': 'Webhook not set up',
  'awaiting_event': 'Webhook waiting for its first event',
  'active': 'Webhook active',
};

String webhookStatusLabel(String status) => webhookStatusLabels[status] ?? status;

/// Paystack or Monnify as a school says them ("paystack" -> "Paystack").
String providerDisplayName(String code) => switch (code) {
      'paystack' => 'Paystack',
      'monnify' => 'Monnify',
      'sandbox' => 'Test provider',
      '' => 'Provider',
      _ => code[0].toUpperCase() + code.substring(1),
    };

/// "live" / "test" in the words a bursar uses.
String environmentLabel(String environment) => environment == 'live' ? 'Live' : 'Test';

const paymentStatusLabels = <String, String>{
  'matched': 'Matched',
  'partially_matched': 'Partly matched',
  'possible_match': 'Possible match',
  'unmatched': 'Unmatched',
  'duplicate': 'Possible duplicate',
  'reversed': 'Reversed',
  'refunded': 'Refunded',
  'requires_review': 'Needs review',
  'unrelated_income': 'Not fees',
  'investigating': 'Being looked into',
  'not_applicable': 'Money out',
};

String paymentStatusLabel(String status) => paymentStatusLabels[status] ?? status;

/// The payments a person still has something to do with.
const paymentsNeedingAPerson = <String>{
  'possible_match',
  'requires_review',
  'unmatched',
  'duplicate',
  'partially_matched',
  'investigating',
};

/// What the server's short failure codes mean, in words a bursar can act on.
String bankErrorLabel(String code) => switch (code) {
      '' => '',
      'bad_credentials' => 'The provider no longer accepts the saved credentials. Replace them.',
      'vault_error' => 'The saved credentials could not be opened. Replace them.',
      'provider_unavailable' => 'The provider did not answer. Try again in a moment.',
      'not_supported' => 'This provider does not support that.',
      'invalid_signature' => 'A message from the provider could not be verified.',
      'environment_mismatch' => 'These credentials belong to the other mode (test or live).',
      'live_not_configured' => 'A live connection to this provider is not set up on the school\'s server yet.',
      'customer_details_missing' => 'The provider needs more details about the family\'s payer.',
      'customer_kyc_required' => 'The provider needs the payer\'s BVN or NIN.',
      _ => 'The last check with the provider failed ($code).',
    };

/// Kobo as naira: `5000000` -> `₦50,000`, `150050` -> `₦1,500.50`.
String formatMoneyMinor(int minor, {String currency = 'NGN'}) {
  final negative = minor < 0;
  final absolute = minor.abs();
  final whole = (absolute ~/ 100).toString();
  final kobo = absolute % 100;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  final symbol = currency == 'NGN' ? '₦' : '$currency ';
  final fraction = kobo == 0 ? '' : '.${kobo.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$symbol$buffer$fraction';
}

/// What a person typed as naira (`1500`, `1,500.5`, `1500.50`) as whole kobo, or null if it is not an amount.
int? parseNairaToMinor(String text) {
  final cleaned = text.replaceAll(',', '').replaceAll('₦', '').trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final kobo = int.parse((match.group(2) ?? '').padRight(2, '0'));
  return whole * 100 + kobo;
}

/// `3 hours ago`, `yesterday`, `12 Sep`: how long ago something happened, kindly.
String whenLabel(DateTime? value, {DateTime? now}) {
  if (value == null) return 'never';
  final current = now ?? DateTime.now();
  final local = value.toLocal();
  final difference = current.difference(local);
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  if (difference.inDays == 1) return 'yesterday';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${local.day} ${months[local.month - 1]}${local.year == current.year ? '' : ' ${local.year}'}';
}

/// What each entry in a provider's activity trail means.
String auditKindLabel(String kind) => switch (kind) {
      'provider_connected' => 'Connected and checked with the provider',
      'connect_failed' => 'A connection attempt failed',
      'provider_test_passed' => 'Connection tested: working',
      'provider_test_failed' => 'Connection tested: not working',
      'provider_renamed' => 'Renamed',
      'provider_disabled' => 'Disabled',
      'provider_enabled' => 'Enabled',
      'credentials_replaced' => 'Credentials replaced',
      'credentials_replace_failed' => 'Replacing the credentials failed',
      'provider_disconnected' => 'Disconnected',
      'webhook_address_renewed' => 'New webhook address issued',
      'webhook_confirmed' => 'Webhook confirmed by a verified event',
      'webhook_rejected' => 'A callback was refused (bad signature)',
      'active_provider_set' => 'Made the active collection provider',
      'provider_switched' => 'Became the active collection provider (switch applied)',
      _ => kind,
    };

/// What each decision in a payment's history means.
String decisionActionLabel(String action) => switch (action) {
      'auto_match' => 'Matched automatically',
      'engine_review' => 'Checked by SchoolOS',
      'assign' => 'Assigned to a student',
      'split' => 'Split between students',
      'unrelated_income' => 'Marked as not school fees',
      'duplicate' => 'Marked as a duplicate',
      'investigate' => 'Set aside to look into',
      'reversed' => 'Marked as reversed',
      'refunded' => 'Marked as refunded',
      'reopen' => 'Reopened for review',
      _ => action,
    };
