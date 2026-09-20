// Helpers for comparing people by phone number and national ID. Values are
// normalized first so "0803 123 4567", "+234 803 123 4567" and "08031234567"
// count as the same number.

/// Returns an 11-digit Nigerian mobile number (for example 08031234567), or
/// null when [input] is not a valid one.
String? normalizeNigerianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+234')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('234') && digits.length == 13) {
    digits = '0${digits.substring(3)}';
  }
  return RegExp(r'^0[789][01]\d{8}$').hasMatch(digits) ? digits : null;
}

/// Returns the 11-digit NIN, or null when [input] is not exactly 11 digits.
String? normalizeNin(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-]'), '');
  return RegExp(r'^\d{11}$').hasMatch(digits) ? digits : null;
}

/// Lower-cases and collapses spacing and punctuation so the same name typed
/// slightly differently still compares equal.
String normalizeName(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
