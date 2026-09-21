/// The phone could not reach the server (no signal, timeout, server down).
/// Work is kept and tried again later; nothing is lost.
class ApiOfflineException implements Exception {
  const ApiOfflineException([this.message = 'The server could not be reached.']);

  final String message;

  @override
  String toString() => message;
}

/// The sign-in is no longer valid and could not be renewed. The person must
/// sign in again. Work on the device is kept.
class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Please sign in again.']);

  final String message;

  @override
  String toString() => message;
}

/// The server answered with an error. [message] is written for the person to
/// read (the server's own words when it gave any), and [code] is the server's
/// machine-readable code when it sent one.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.code, this.details});

  final int statusCode;
  final String message;
  final String? code;
  final Object? details;

  bool get isForbidden => statusCode == 403;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}
