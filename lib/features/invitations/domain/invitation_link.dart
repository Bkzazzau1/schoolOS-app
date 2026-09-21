/// Pulls the secret out of what a person pasted or tapped: the whole link from
/// their email (`https://brightgate.schoolos.ng/invite/<secret>/`), just the last
/// part, or the bare secret. Returns null when it cannot be a link from a school.
///
/// It only finds the secret. Whether the link is still good is for the server to say.
String? invitationTokenFrom(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;

  // Anything after the secret is not part of it.
  text = text.split(RegExp(r'[?#\s]')).first;
  final marker = text.indexOf('/invite/');
  if (marker != -1) {
    text = text.substring(marker + '/invite/'.length);
  } else if (text.replaceAll(RegExp(r'/+$'), '').contains(RegExp(r'://|/'))) {
    // A link that is not an invitation link (another page, another site).
    return null;
  }
  text = text.split('/').first;
  // The web page for people without the app lives beside it and is not a secret.
  if (text.isEmpty || text == 'registration') return null;
  // Secrets are long and made of letters, digits, dashes and underscores.
  if (!RegExp(r'^[A-Za-z0-9_-]{20,128}$').hasMatch(text)) return null;
  return text;
}
