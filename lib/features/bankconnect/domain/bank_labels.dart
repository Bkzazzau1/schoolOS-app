// Words and formats the bank-connection screens share. The keys mirror the server's own lists.

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
  'needs_reauth': 'Needs reconnecting',
  'error': 'Problem',
  'revoked': 'Disconnected',
};

String connectionStatusLabel(String status) => connectionStatusLabels[status] ?? status;

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
      'bad_credentials' => 'The bank no longer accepts the saved credentials. Reconnect the account.',
      'account_changed' => 'The bank now reports a different account from the one that was connected.',
      'vault_error' => 'The saved credentials could not be opened. Reconnect the account.',
      'provider_unavailable' => 'This provider is not available on the server.',
      'not_supported' => 'This provider does not support that.',
      'invalid_signature' => 'The bank\'s message could not be verified.',
      _ => 'The last check with the bank failed ($code).',
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

/// What each entry in an account's activity trail means.
String auditKindLabel(String kind) => switch (kind) {
      'connection_created' => 'Account checked with the bank',
      'connected' => 'Confirmed and connected',
      'connect_failed' => 'A connection attempt failed',
      'test_passed' => 'Connection tested: working',
      'test_failed' => 'Connection tested: not working',
      'renamed' => 'Renamed or purpose changed',
      'disabled' => 'Disabled',
      'enabled' => 'Enabled',
      'credentials_rotated' => 'Credentials changed',
      'reconnected' => 'Reconnected',
      'disconnected' => 'Disconnected',
      'webhook_token_issued' => 'New callback address issued',
      'webhook_rejected' => 'A callback was refused (bad signature)',
      'synced' => 'Payments fetched',
      'sync_failed' => 'Fetching payments failed',
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
